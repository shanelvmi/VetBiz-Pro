# E4d-1 writer audit: debts, sales, services, transactions, batches

Batch E4d-1 (RUNBOOK2 section 4, security_hardening.md 3(c) rows C4, C6, C7, C8). Read-only audit of every write in `lib/` and `functions/` to the documents these rules cover, made BEFORE any rule changed. `functions/` writes them only with the Admin SDK (archives, purge, wipe, delete facility), which the rules do not apply to. Line numbers at `e78ddbe`. "Member" = owner, Co-admin or assistant.

The shapes marked *captured* are recorded from the real provider code in `firestore_rules_tests/fixtures/app_write_shapes.json` (`test/providers/write_shapes_capture_test.dart`) and replayed in the emulator as each role.

## Debts (C4)

| Writer | Who | Operation and fields | Captured |
|---|---|---|---|
| `SaleProvider.addSale` (E1a), `sale_provider.dart:491` | member | in the sale transaction: create `debts/sale_{id}` = `Debt.toMap()` (clientId, clientName, clientPhone, saleId, serviceId, source, amountOwed > 0, timestamp, updatedAt, items), only with a client and something owed; client `balance` increment, `oldestUnpaidDebtDate` | yes |
| `ServiceProvider.addService` (E1b), `service_provider.dart:516` | member | in the service transaction: create `debts/service_{id}`, same fields | yes |
| `ServiceProvider.updateService` -> `_handleServiceDebt`, `:785`, `:799` | member (Edit Service has no admin check) | batch: `set` the whole debt with the NEW amountOwed (can be HIGHER), or `delete` it when edited down to paid, with client `balance` increment(delta) | yes (raise) |
| `AddPaymentScreen._save`, `add_payment_screen.dart:337-343` | member | batch: payment create, client `balance` increment(-amount), debt `update {amountOwed: lower}` or `delete` at 0, the sale or service update | yes (mirrored) |
| `RecordTrash.delete` (E2), `record_trash.dart:144` | admin (Trash) | in a transaction: delete the record's debts, client `balance` increment(-owed) | yes |
| `RecordTrash.restore` (E2), `record_trash.dart:285` | admin (Trash) | in a transaction: create `debts/{prefix}_{id}` with amountOwed = owed > 0 | yes |
| `DebtProvider.addDebt/updateDebt/deleteDebt/addOrUpdateDebtForClient` | - | no callers in `lib/` (dead code) | - |
| `PaymentProvider.addPayment/deletePayment` | - | no callers in `lib/` (dead code) | - |

## Sales and services (C6)

| Writer | Who | Operation and fields | Captured |
|---|---|---|---|
| `addSale`, `addService` (E1a/E1b) | member | create (rule unchanged) | yes |
| `AddPaymentScreen._save`, `:349-367` | member | sale: `update(Sale.applyPayment(amount).toMap())`: changes `totalPaid, items` (each item's realizedProfit/unrealizedProfit), `realizedProfit, unrealizedProfit, updatedAt`. Service: `update(copyWith(totalPaid, updatedAt).toMap())`: changes `totalPaid, updatedAt, totalServiceProfit, unrealizedServiceProfit` | yes |
| `ServiceProvider.updateService`, `service_provider.dart:574` | member (Edit Service) | `update({...toMap(), ...searchFields(), updatedAt})`: any field (total, items, date, client...) | yes |
| `RecordTrash.delete/restore` | admin | delete / create of the record (rules unchanged) | yes |
| No sale edit screen exists; no other update of `sales`. | | | |

## Transactions (C7)

| Writer | Who | Operation and fields |
|---|---|---|
| `TransactionProvider.addTransaction`, `transaction_provider.dart:280` | member | create, `recordedBy` = the person's NAME (`add_transaction_screen.dart`, `_fetchCurrentUserFullName`) |
| `TransactionProvider.updateTransaction`, `:323` | member (Edit is shown to everyone, `transactions_screen.dart:561`) | `set({...toMap(), ...searchFields()})`, keeps the original `recordedBy` (a name) and `date` |
| `addService` expense `transactions/service_{id}`; `updateService` -> `_handleServiceTransaction` (`:870` delete old ones, `:895` add) | member | create; delete (admin-only today, so an assistant editing a service with an external item already fails at that step) |
| `RecordTrash.delete/restore` | admin | delete / create |

## Batches (C8)

| Writer | Who | Operation |
|---|---|---|
| `ProductProvider.deleteBatch`, `product_provider.dart:458` | admin (the delete button is `if (isAdmin)`, `view_batches_screen.dart:512`) | transaction: delete the batch, update the product's stockQty, sellableQty, expiry, updatedAt (shape written from the source in the rules test: the provider uses `FirebaseFirestore.instance`) |
| Trash "delete forever" of a product, `trash_screen.dart:214` | admin (Trash) | deletes its batches |
| Sales, services, restores, stock moves, Add Batch, Adjust | member | create / update only (rule unchanged, E1c floor) |

## Result: what each design row can and cannot do

- **C4 create** (`clientId is string`, `amountOwed > 0`): every create above qualifies. Applied.
- **C4 delete** (admin, or the same request lowers the client's balance): the payment batch and `_handleServiceDebt` lower the balance in the same batch; Trash deletes are admin. Applied.
- **C4 update** ("only amountOwed/updatedAt, only lower"): REFUSES a real shape. `updateService` (Edit Service, any member) rewrites the debt with a higher amountOwed and new `items`/`updatedAt` (captured flow "updateService raises the unpaid amount"). Not applied: owner decision.
- **C6 sales** (assistant: payment fields only): the only update is the payment; the rule allows `totalPaid, items, realizedProfit, unrealizedProfit, updatedAt, paymentStatus`. `items` must stay changeable because applyPayment rewrites each item's profit split; a rule cannot compare inside a list, so an assistant could still rewrite an item's price. Applied.
- **C6 services**: REFUSES a real shape: an assistant's Edit Service changes any field. Not applied: owner decision (make Edit Service admin-only, or move it to the server).
- **C7** ("admin, or recordedBy == uid on the same day"): REFUSES a real shape: `recordedBy` holds a NAME, never a uid, so every assistant edit (Edit is open to everyone) would be refused. Not applied: owner decision (write a `recordedById` at create, or make Edit admin-only).
- **C8** (batch delete admin only): applied.

OWNER DECISION: Edit Service and Edit Transaction (and deleting a transaction) become admin-only: assistants record, take payments and see everything, the owner corrects. Creating a product becomes admin-only (assistants still add batches to existing products). This settles C4 update (an assistant may only lower a debt's amountOwed, through the payment shape), C6 services (an assistant may change only the payment fields, like sales), C7 (transactions: create for members, update and delete for admins) and C12 (products create: admin).