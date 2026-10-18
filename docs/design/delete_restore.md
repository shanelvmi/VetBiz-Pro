# E2 design: deleting and restoring keep the books consistent

Batch E2-design (RUNBOOK2 section 4), a DESIGN STOP: no code and no rules are changed. Line numbers are at `b42f196`. Builds on `docs/design/atomic_sales.md` (E1, approved option b) and the Trash audit in `docs/design-open-questions.md` ("Trash and restore: books consistency").

## 1. Current behaviour

Every step below is its own round trip, run one after another; nothing is a transaction except the per-item stock writes.

### Sale: `SaleProvider.deleteSale` (`lib/providers/sale_provider.dart:571`)

| # | Delete writes | File:line | Restore (`TrashService.restore`) writes |
|---|---|---|---|
| 1 | Trash copy `trash_sales/{id}` = `sale.toMap()` from the cached list + `deletedAt`, `deletedBy` (no `updatedAt`, no `searchFields()`) | `sale_provider.dart:595` | `sales/{id}` = the trash copy minus deletedAt/deletedBy, and the trash doc deleted, one batch (`lib/services/trash_service.dart:33-51`) |
| 2 | `sales/{id}` deleted; the server trigger `updateDailySalesSummary` subtracts it from `dailySummaries/{day}` | `:607`; `functions/index.js:159` (archive check `:175`, reverse `:198`) | the trigger adds it back to its ORIGINAL day (the copy keeps `timestamp`) |
| 3 | Stock put back: per item `restoreSellableFIFO` to the batches in `batchAllocations`, or a product-level transaction for pre-batch sales | `:615` -> `:690-715` | **nothing**: the stock stays put back |
| 4 | Debt records deleted: query `debts where saleId == id` (E1a: `debts/sale_{id}`; older: random ids), one delete each | `:624-632` | **nothing**: no debt |
| 5 | Client balance `increment(-outstanding)`, then `oldestUnpaidDebtDate` recomputed from the remaining debts; errors swallowed | `:636` -> `:722-761` (recompute `:748`) | **nothing**: balance stays reduced |
| 6 | Upfront payment `payments/sale_{id}` and `dailyCollections`: not touched | n/a; `functions/index.js:247` | n/a (the cash stays counted while the sale is in Trash) |
| 7 | Activity entry "Deleted sale to ..." (random id) | `:641` | "Restored ..." entry, written AFTER the batch (`trash_service.dart:52`, `:81`) |

After a restore: stock too high by the sale's quantities, the client's balance and Active Debts too low by the outstanding amount, the sale not found by search (no `nameLower`/`phoneKey`) and never archived (no `updatedAt`, `functions/index.js:99`).

### Service: `ServiceProvider.deleteService` (`lib/providers/service_provider.dart:639`)

| # | Delete writes | File:line | Restore writes |
|---|---|---|---|
| 1 | Trash copy `trash_services/{id}` (cached `toMap()` or the server doc) | `:652-672` | `services/{id}` back, trash doc deleted (as sales) |
| 2 | `services/{id}` deleted; `updateDailyServiceSummary` subtracts it | `:674`; `functions/index.js:294` | trigger adds it back to its original day |
| 3 | Expense transaction(s) `transactions where serviceId == id` **hard-deleted** (E1b id `transactions/service_{id}`); `updateDailyTransactionSummary` subtracts the expense | `:681-690`; `functions/index.js:370` | **nothing**, and the expense is gone for good (not in Trash) |
| 4 | One batch: balance `increment(-owed)`, `debts/service_{id}` deleted, `oldestUnpaidDebtDate` recomputed only if this debt held it; errors swallowed | `:704-750` | **nothing** |
| 5 | Stock put back by `batchAllocations`, **only if the service was in the cached list** (`existing != null`) | `:753` -> `:1022` | **nothing** |
| 6 | Upfront payment: not touched | n/a | n/a |
| 7 | Activity entry "Deleted service for ..." | `:757` | "Restored ..." entry |

After a restore: stock too high, debt and balance too low, the expense missing from the books and from `dailyTransactionSummaries`, no search fields when the copy came from the cached list (as sales).

### Product and transaction (complete today)

| Item | Delete writes | Restore writes | Left inconsistent |
|---|---|---|---|
| Product `ProductProvider.deleteProduct` (`lib/providers/product_provider.dart:1201`) | trash copy (`:1223`), `products/{id}` deleted (`:1234`); batches stay at `products/{id}/batches`; **no activity entry** | product back; it finds its batches again | nothing (the purge deletes the batches with the trash copy, `functions/index.js:654`) |
| Transaction `TransactionProvider.deleteTransaction` (`lib/providers/transaction_provider.dart:352`) | trash copy (`:384`), doc deleted (`:395`), trigger subtracts it, activity entry (`:402`) | doc back, trigger adds it back | nothing |

### Undo and warning dialogs today

- Undo (`AppFeedback.undo` -> `TrashService.restoreById`): products (`products_screen.dart:405`, `stockstore_screen.dart:350`), transactions (`transactions_screen.dart:602`). **None** for sales (`sales_screen.dart:839-842`) or services (withdrawn, `services_screen.dart:792-795`).
- Trash screen Restore asks first for sales and services only (`trash_screen.dart:144-178`, `trash_restoreSaleBody`/`trash_restoreServiceBody`: "restoring will NOT change stock, debt, client balance (, expenses)").
- Delete dialogs: sale "This permanently deletes {invoice} and restores its stock. This cannot be undone." (`sales_deleteBody`, wrong: it goes to Trash); service "... Restoring from Trash brings back the record only." (`services_deleteBody`).
- Rules: every `trash_*` is admin-only (`firestore.rules:305-319`); `sales`/`services` create is refused while the subscription is locked (`:226`, `:233`).

## 2. The problem, for a real business

- **A restored credit sale silently forgives the debt.** The client's balance and Active Debts no longer show the money; the WhatsApp reminder is never sent; the oldest-unpaid date can be wrong.
- **A restored sale or service leaves phantom stock.** The shelf count is higher than the goods in the shop, so the next sales and the reorder alerts work from wrong numbers, and the stock value on the dashboard is overstated.
- **A restored service loses its expense for good**, so the day's profit is overstated and cannot be corrected from the app.
- **Delete itself is not atomic.** A dropped connection between steps 2 and 5 leaves a sale gone but its stock not back, or the debt gone but the balance unchanged (errors swallowed, the screen says "deleted"). A service deleted from outside the cached list never gets its stock back (`service_provider.dart:753`).
- **Restore is not retry-safe for the side effects**: once those are added, a second tap or a retry after a lost answer must not take stock or raise the balance twice.
- **The warnings are the only guard**: an owner who clicks through gets wrong books, with no way to see which restores were "record only".

## 3. Options

**(a) Restore reverses every effect, in one transaction (E1a/E1b style); delete becomes one transaction too.**
Restore of a sale: outside, query candidate batches (`sellableQty > 0`) per product. Inside `runTransaction`: read `trash_sales/{id}`, `sales/{id}` (exists and trash gone -> already restored: return, writes nothing), the products, their batches, the client, `debts/sale_{id}`. Plan with `SellableStockPlan` for every item; **not enough stock -> return null, write nothing, throw `InsufficientStockException` naming the product** (the screen says "add stock first"; the record stays in Trash). Write: `sales/{id}` (the trash copy + `updatedAt` + `searchFields()`; the stored prices and profits are kept, so the summary matches the original day exactly; only `batchAllocations` take the new plan, so a later delete returns stock to the right batches), the stock, `debts/sale_{id}` (if a client and outstanding > 0), the balance `increment(+outstanding)` and `oldestUnpaidDebtDate` (the sale's date if earlier than the stored one), delete the trash doc, and the entry `activity_logs/restore_sale_{id}_{deletedAtMillis}`. Services the same, plus `transactions/service_{id}` re-created from the expense kept in the trash copy (new field `trashedExpense`, written by the new delete), or for services already in Trash, recomputed by E1b's rule (`Service.externalExpenseTotal`, `service_provider.dart:931`). Delete mirrors it: one transaction that writes the trash copy (+ `trashedExpense`, + `stockReturned: true`), deletes the record, returns the stock by `batchAllocations`, deletes the debt(s) (queried by `saleId` outside, re-read inside), lowers the balance, recomputes `oldestUnpaidDebtDate` from the pre-read debts minus this one, and logs `activity_logs/delete_sale_{id}_{millis}`.
- Correctness: full, both ways. Retry/duplicates: idempotent by the existence reads (live doc vs trash doc). Undo: can return for sales and services (same method); the warning dialogs go. Summaries: unchanged triggers, original day, same amounts. Purge: unchanged (restore only works while the trash doc exists). Records already in Trash: restorable with full effects (their delete already reversed stock, debt and balance; expense recomputed); risk: a service deleted by the old code while not cached never got its stock back, so restoring takes it again (cannot be told from the copy; rare: the screen deletes from the list). Rules: none needed (sales/services create, debts, clients, products/batches with the E1c floor, transactions, activity_logs and admin-only trash are all already allowed); restore is refused while the subscription is locked (the create rule), which is honest. Size: medium, about 600-900 lines in 5-7 commits, the E1 helpers reused.

**(b) Replace delete with a VOID.** The record stays in `sales`/`services` with `status: 'void'`, `voidedAt`, `voidedBy`; one transaction posts the reversing effects (stock back, debt deleted or zeroed, balance lowered, expense voided). Nothing is ever recreated; an "unvoid" is the same transaction backwards.
- Correctness: strong, and the audit trail is better (the record never disappears). Retry: idempotent by the status read. Undo: an unvoid. Summaries: **the triggers must change** to treat `void` as absent (`functions/index.js:159`, `:294`, `:370`), and the at-least-once re-delivery problem (LATER 2) stays. Purge: does not apply; Trash for sales and services becomes a "Voided" filter. Existing Trash records: need a migration or the old restore path kept. Rules: an update that sets `void` must be admin-only and a voided record must refuse other edits. Size: large: every query and total that reads sales or services (lists, debtors, reports and their PDF, insights, exports, the dashboard, `archiveOldSales`, the consistency script) must exclude voids; easy to miss one, and a miss counts a voided sale as revenue.

**(c) Keep delete; Restore creates a NEW record from the trash copy through E1's `addSale`/`addService`.**
- Correctness: stock, debt, balance and expense come out right, because the normal path makes them. But it is a **new sale**: a new receipt number (the printed receipt no longer matches), today's date (the revenue moves from the original day to today in the summaries and reports), today's cost prices and profit; the old id is gone, so links from payments (`payments/sale_{oldId}`) and old activity entries point at nothing. Retry: safe only if the new id is derived (`{id}_r{deletedAtMillis}`) and the trash doc deleted in the same transaction (needs an `addSale` variant). Undo: works but "Undo" producing a different receipt is confusing. Summaries: correct totals, wrong day. Purge, rules, existing Trash: no change. Size: small to medium; but the delete stays non-atomic unless it is also rewritten.

## 4. Recommendation: option (a)

- It is the only option that gives back exactly the record that was deleted (same id, receipt, day, prices) with every effect, and it fixes the non-atomic delete too.
- It reuses what E1 already proved in Chrome (`runTransaction`, `SellableStockPlan`, deterministic ids, no swallowed errors), touches no triggers, no rules and no indexes, and needs no migration.
- (b) is the better long-term ledger, but it is a cross-cutting change to every read and to three triggers; it fits better after E4 and the trigger idempotency work (LATER 2). (c) moves money between days and changes receipt numbers, which a shop cannot explain to a customer or a tax check.
- Owner decisions inside (a): (1) not enough stock to restore: refuse (recommended) or offer "restore record only" as today; (2) the client document is gone (hard-deleted, until E3): refuse (recommended) or restore as walk-in without a debt; (3) the upfront payment stays counted while a sale is in Trash (unchanged; a refund flow is a separate decision); (4) the new dialog and message wording (the English is a wording change, so listed for the owner, not invented).

## 5. What would change

**Files (batch E2, after APPROVED):**
- `lib/providers/sale_provider.dart`: `deleteSale` as one transaction; new `restoreSale(id, facilityId)`; `_restoreStock`/`_adjustClientBalance` logic moved inside.
- `lib/providers/service_provider.dart`: the same (`deleteService`, new `restoreService`), `trashedExpense` and `stockReturned` in the trash copy; stock always returned (not only when cached).
- `lib/providers/product_provider.dart`: a "return stock by allocations" step that runs inside a given transaction (next to `SellableStockPlan`).
- `lib/services/trash_service.dart`: `restore`/`restoreById` dispatch sales and services to the new methods; strips `trashedExpense`/`stockReturned`; products, clients and transactions unchanged.
- `lib/screens/settings/trash_screen.dart`: the two warnings removed; a refused restore shows the stock (or client) reason. `lib/screens/sales/sales_screen.dart`, `lib/screens/services/services_screen.dart`: Undo on delete.
- `lib/l10n/app_en.arb`, `app_sw.arb` (draft) and the generated files: new dialog, Undo and refusal texts; `trash_restoreSaleTitle/Body`, `trash_restoreServiceTitle/Body` retired; `docs/kiswahili_review.csv` export.
- Not changed: `firestore.rules`, `functions/` (triggers, purge), indexes, `pubspec.yaml`.

**Tests that FAIL on today's behaviour (fake_cloud_firestore, as E1):**
1. Credit sale to a client, delete, restore: stock, `debts/sale_{id}` (amount), client balance and `oldestUnpaidDebtDate` equal what they were before the delete (today: stock high, no debt, balance low).
2. Restore twice (a retry after a lost answer): one sale, stock taken once, balance raised once (today the second call throws or writes nothing, and the stock was never taken).
3. Restore with the stock now short: nothing written, the trash doc still there, `InsufficientStockException` (today: restored anyway).
4. Service with stock and an external item: delete, restore: `transactions/service_{id}` back with the same amount, debt and balance back (today: expense gone).
5. A service not in the cached list: delete returns its stock (today: not returned).
6. A service already in Trash from the old code (no `trashedExpense`): restore recomputes the expense from its items.
7. Restored sale has `searchFields()` and `updatedAt` (today: neither).
8. Widget: deleting a sale and a service shows Undo; Undo restores with effects (today: no Undo).
Regression guards: product and transaction delete/restore unchanged; the E1 tests; the functions trigger tests (`cd functions && npm test`) unchanged; the rules suite unchanged.

**Rollout:** app only; no deploy of rules, functions or indexes. Owner checks in Chrome: delete and restore (Trash and Undo) a cash sale, a credit sale, a service with stock and an external item; restore with stock sold out in between (refused, nothing changes); double-click Restore (one restore); Active Debts, client balance, product stock and the day's report before delete and after restore match.
**Rollback:** revert the app commits. Trash copies written by the new delete carry two extra fields; the old restore copies them into the live doc, where nothing reads them (harmless). Records restored by the new code are ordinary records.
**Verification with the E1-check script** (`functions/scripts/check_consistency.js`, read-only): run it on the owner's test facility before a delete and after the restore; `salesWithoutDebt`, `debtsWithoutRecord`, `clientBalanceMismatch`, `productVsBatches`, `negativeQuantities` and `servicesAndPayments` must show the same counts. Optional (needs the owner's OK, it is in `functions/`): a ninth check, services with external items and no `transactions/service_{id}`.

OWNER DECISION: APPROVED option (a), with these decisions and conditions. (1) Not enough stock to restore: refuse and name the product. (2) The client no longer exists: refuse. (3) The upfront payment stays counted while a sale is in Trash, and the delete dialog says so when there is one. (4) A product in the sale no longer exists: refuse with a named reason. (5) A trash copy without stockReturned (deleted by the old code) restores with the extra line "This item was deleted before the update. Check its stock afterwards." (6) Add a test for a partly repaid credit sale: delete then restore gives back the same debt, balance and oldestUnpaidDebtDate. (7) The optional ninth check in the consistency script is approved, as the last commit. (8) Wording, English, with Kiswahili drafts marked draft: Delete sale dialog: title "Delete this sale?"; body "{invoice} moves to Trash and its stock goes back on the shelf. If it was sold on credit, the client's debt is removed too. Money already received (Tsh {paid}) stays in your payments. You can undo this now or restore it from Trash for 30 days." (omit the money sentence when nothing was received). Delete service dialog: the same, with "its stock goes back, and its debt and its expense are removed until you restore it". Delete messages keep "Sale moved to Trash" and "Service moved to Trash", now with Undo. Restore success: "Sale restored" with the second line "Stock, debt and client balance are updated." (service: "Service restored", "Stock, debt, expense and client balance are updated."). Refusals, title "Can't restore this sale" (or service), second line: "Not enough {product} in stock: {needed} needed, {available} left. Add stock first." or "The client no longer exists." or "{product} no longer exists."
