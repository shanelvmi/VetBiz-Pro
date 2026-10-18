# E1 design: a sale (or a service) and everything it changes succeed or fail together

Batch E1-design (RUNBOOK2 section 4). Design only: no feature code, no rules changed. Line numbers are at `7498bdd`.

## 1. Current behaviour

### Adding a sale (`AddSaleScreen` save -> `SaleProvider.addSale`)

| # | Step | File:line | A failure at this step leaves behind |
|---|---|---|---|
| 1 | Screen calls `addSale(sale, facilityId)`; `sale.id` is `''` | `lib/screens/sales/add_sale_screen.dart:783` | nothing |
| 2 | Reads the client's name, only if the screen did not pass it | `lib/providers/sale_provider.dart:333` | nothing (returns null) |
| 3 | Per item, its own transaction: query batches with `sellableQty > 0` outside it, then re-read them and the product, decrement batch and product `sellableQty` | `sale_provider.dart:362` -> `lib/providers/product_provider.dart:762` (query :779, transaction :797) | item k fails: items 1..k-1 are restored by the rollback loop (`sale_provider.dart:383`). If a restore also fails (the connection dropped), their stock is gone and there is no sale |
| 4 | Receipt number: a separate transaction on `counters/receiptNumber` | `sale_provider.dart:395` -> `lib/utils/receipt_numbering.dart:27` | **all items' stock is deducted, no sale, no rollback** (the outer catch at `sale_provider.dart:450` only returns null); a gap in the numbers |
| 5 | Sale document, `.add()` (random id); fires `updateDailySalesSummary` | `sale_provider.dart:397`; `functions/index.js:159` | same as 4 |
| 6 | Client balance `+= outstanding` (reads the client, then a small batch with `increment` and maybe `oldestUnpaidDebtDate`) | `sale_provider.dart:412` -> `:650` | errors are swallowed: sale saved, balance not raised, screen says "saved" |
| 7 | Upfront payment, `.add()`; fires `updateDailyCollections` and `notifyOnPaymentReceived` | `sale_provider.dart:422`; `functions/index.js:247`, `:1360` | sale, stock and balance saved, no payment; `addSale` returns null, the screen says "could not be saved", and a second Save records **a second sale and deducts the stock again** |
| 8 | Activity log "Recorded sale ..." | `sale_provider.dart:441` -> `lib/utils/activity_logger.dart:10` | errors swallowed (`activity_logger.dart:51`): entry missing |
| 9 | Screen: "Sale included expired stock" log | `add_sale_screen.dart:788` | entry missing |
| 10 | Screen: debt (random id) when unpaid and a client is chosen | `add_sale_screen.dart:811` -> `lib/providers/debt_provider.dart:77` | errors swallowed (returns null, ignored): balance raised but no debt, so Active Debts and the client balance disagree |

The screen already knows this: no Retry, "the sale and its debt are saved in two separate calls" (`add_sale_screen.dart:837`).

### Adding a service (`AddEditServiceScreen` save -> `ServiceProvider.addService`)

| # | Step | File:line | A failure at this step leaves behind |
|---|---|---|---|
| 1 | Screen calls `addService(service)` | `lib/screens/services/add_edit_service_screen.dart:947` | nothing |
| 2 | New id from `ref.doc()`, **a new one on every call** | `lib/providers/service_provider.dart:290` | nothing |
| 3 | Per matched item, quantity 1: the same FIFO transaction as sales | `service_provider.dart:296` -> `:784` | rollback as sale step 3 (`:808`), same hole if a restore fails |
| 4 | Receipt number (shared counter) | `service_provider.dart:302` | **stock deducted, no service, no rollback**; the error reaches the screen |
| 5 | Service document `set`; fires `updateDailyServiceSummary`, `notifyOnServiceRecorded` | `service_provider.dart:305`; `functions/index.js:294`, `:1403` | same as 4 |
| 6 | Local list updated before anything else is saved | `service_provider.dart:313` | the screen shows a service the server may not keep |
| 7 | Debt `service_{id}` + balance `increment` + `oldestUnpaidDebtDate`, one batch, after reading the client and the debt | `service_provider.dart:317` -> `:582`, commit `:718` | errors swallowed: service saved without its debt or balance, screen says "added" |
| 8 | Expense transaction: query old ones by `serviceId`, delete them, `.add()` the new one; fires `updateDailyTransactionSummary` | `service_provider.dart:318` -> `:729`, add `:765`; `functions/index.js:370` | error rethrown: service, stock and debt saved, screen says "save failed", a second Save **duplicates the service, its stock and its debt** (new id, step 2) |
| 9 | Upfront payment `.add()` | `service_provider.dart:323` | as 8 |
| 10 | Activity log | `service_provider.dart:343` | entry missing |

## 2. The problem and the failure windows

- Up to 10 separate writes per sale (8 per service), each its own round trip. A dropped connection, a closed tab, a rules refusal or a crash between any two leaves a partial state.
- Worst windows: **stock gone with no record** (sale 4-5, service 4-5, a failed rollback in step 3); **a record without its debt or balance** (sale 6 and 10, service 7, all silent); **a duplicate after an honest retry** (sale 7, service 8-9), because ids are random.
- Errors are swallowed in three places, so the screen says "saved" for an incomplete sale.
- Offline today: steps 3 and 4 are transactions, which need the server, so **a sale or a service cannot be saved offline at all**. On web, Firestore persistence is not enabled (nothing in `lib/main.dart`), so queued writes would live only in memory.
- Two devices selling the last unit: safe today (the FIFO transaction re-reads and throws), but only per item.
- Server triggers increment daily summaries per document written; they are at-least-once and not idempotent (pre-existing, outside E1).

## 3. Options

All options share: **one id per sale, made when the form opens** (`sales/{id}`), reused by a retry; the debt is `debts/sale_{id}` (as services already do), the payment `payments/sale_{id}`, the expense `transactions/service_{id}`, the activity entry `activity_logs/sale_{id}`; the expired-stock note joins the same write; errors are no longer swallowed.

**(a) `WriteBatch` with `FieldValue.increment`.** Read the batches and the client first (server when online, cache when offline), compute the FIFO allocation, then one batch: sale, `increment(-take)` per batch and product, balance increment, debt, payment, log.
- Atomicity: full, for what the batch contains. The plan is made from a read taken before the commit, so it can be stale.
- Offline: commits to the local cache and syncs later, but only with persistence on (not on web today). The receipt number cannot be taken offline (it is a read-then-write): it needs a new scheme (assigned by a server trigger at sync, or per-device numbers), which changes what the receipt shows. `timestamp` is a server timestamp, so an offline sale lands in the **sync day's** summary unless the triggers bucket on a client time field.
- Two devices: only a rule (`sellableQty >= 0` after the write) stops oversell; the losing sale is refused at sync, possibly after its receipt was printed, and the batch's other FIFO choices may be wrong (it took from a batch the other device emptied).
- Retries: a set with the same id is idempotent but **the increments are not**: a second commit of the same batch deducts twice. Needs a create-only marker (`sale_commits/{id}`, `allow update: if false`) in every batch.
- Triggers: unchanged (they see the same documents). Activity log: inside the batch, `serverTimestamp()` satisfies `timestamp == request.time`.
- Rules: floor on products and batches, the marker collection (also in `wipeFacilityData`/`deleteFacility` cleanup), the 20 document lookups per batch to check.

**(b) `runTransaction` (one per sale).** Query candidate batches outside (as today), then one transaction: read the sale doc (exists -> return it: retry done), the counter, every candidate batch, every product, the client; then write everything.
- Atomicity: full, including the receipt number (no gaps, no stock lost).
- Offline: fails with an error, exactly as today; nothing is written, so the error can now offer a safe Retry.
- Two devices: the transaction re-runs on conflict with fresh reads; oversell is impossible; the counter read serialises sales in a facility (already true today).
- Retries: idempotent by the sale-doc read; no marker needed.
- Triggers, activity log: as (a). Limits: 500 writes (about 30 for 10 items), reads before writes, at most 5 automatic re-runs.
- Rules: no new permission; add the stock floor as a second guard.

**(c) A Cloud Function (`recordSale` / `recordService`, `onCall`, v2, `africa-south1`).** The app sends the form; the server runs the transaction with the Admin SDK.
- Atomicity, two devices, retries: as (b), on the server; the rules can then forbid the app from creating sales, debts and stock changes directly (strongest).
- Offline: fails; plus cold starts and a round trip to the region on every sale.
- Cost: FIFO, costing, profit, receipt and debt logic rewritten in JS and kept in step with the Dart models; every other writer of stock (batches, restore, edit) must move too before the rules can be closed. Triggers unchanged; the log is written by the server.
- Rules: `sales`, `services` create -> `false` for clients after the move; functions tests added.

## 4. Recommendation: option (b), runTransaction

- It closes every window in section 2 with the least change: one Dart method per flow, same documents, same triggers, no new collection.
- It loses nothing offline: offline already fails today, because the FIFO and the counter are transactions. Real offline selling needs an owner decision on receipt numbers and on what to show when a synced sale is refused; (a) is the path for that later, and (b)'s deterministic ids are what it needs.
- (c) is safer against a tampered client but is a rewrite and adds latency for shops on weak connections; it belongs with E4.

## 5. What would change

**Files (implementation batch E1, after APPROVED):**
- `lib/providers/sale_provider.dart`: `addSale` becomes one transaction; uses `sale.id` when not empty; writes debt, payment, logs; `_adjustClientBalance` logic moves inside.
- `lib/providers/product_provider.dart`: FIFO split into "plan from read docs" (pure) and "apply in a given transaction"; `deductSellableFIFO` kept for other callers.
- `lib/utils/receipt_numbering.dart`: a variant that runs inside a given transaction.
- `lib/screens/sales/add_sale_screen.dart`: id made once in `initState`; the debt and expired-stock calls removed (now inside); Retry on failure.
- `lib/providers/service_provider.dart`, `add_edit_service_screen.dart`: the same, with `_handleServiceDebt` / `_handleServiceTransaction` inside the transaction and the local list updated after commit.
- `lib/utils/activity_logger.dart`: a helper that adds the entry to a given transaction.
- `firestore.rules`: `products` update and `batches` write also require `sellableQty >= 0` and `stockQty >= 0` (after checking every writer). Rules tests run before and after; `git diff firestore.rules`.
- `pubspec.yaml`: `fake_cloud_firestore` as a dev dependency (owner approval needed: the runbook forbids pubspec changes).

**Tests that FAIL on the old code and pass on the new** (same `addSale(sale, facilityId)` signature):
1. Calling `addSale` twice with the same `sale.id` leaves one sale, one payment, one stock deduction (old: two of each).
2. A credit sale to a client: after `addSale` returns, `debts/sale_{id}` exists with the unpaid amount and the client balance equals it (old: no debt).
3. `addService` twice with the same id: one service, one debt, one expense, stock deducted once (old: two).
4. A service with an external item: the expense is `transactions/service_{id}` (old: random id).
5. Rules: a product or batch update to `sellableQty: -1` is refused, by an assistant and by an admin (old rules allow it).
Regression guards (pass on both): not enough stock for item 2 leaves zero writes; the activity entry passes the existing rule; the daily-summary function tests still pass.

**Rollout:** no new index. Deploy the app first, then the rules (CLAUDE.md order). Old clients still work against the new rules (their transactions never go below zero; `_adjustProductStock` clamps at 0). Owner checks in Chrome: cash sale, credit sale, a service with stock and an external item, a sale with the network cut in DevTools (nothing saved, Retry works once online, no duplicate).

**Rollback:** revert the app commits; the data shape is unchanged (deterministic ids are ordinary ids to the old code, which finds sale debts by the `saleId` query, `sale_provider.dart:556`). The rules floor can stay.

OWNER DECISION: APPROVED option (b), runTransaction, with these conditions: (1) the stock floor rule applies only when the quantity changes and tolerates unchanged legacy negative values, after checking every writer; (2) a new sale id is created for every new sale, including "add another"; (3) a read-only consistency check script follows; (4) dev dependency fake_cloud_firestore approved, version pinned.
