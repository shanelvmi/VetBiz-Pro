# E4d-3 writer audit: edits that drop stored fields, a payment's paymentStatus, stock-addition and payment-claim authors

Batch E4d-3 (RUNBOOK2 section 4; the two bugs found in `e4d2_writer_audit.md` and the halves of C10 and C11 left for the owner). Read-only audit of `lib/` and `functions/`, made BEFORE any code or rule changed. Line numbers at `59b5c9e`. `functions/` writes none of these documents (only Admin SDK wipe, purge and delete facility).

## (1) Edit Service: what it drops, nulls or resets

The stored service is `{...toMap(), ...searchFields(), updatedAt}` from `addService` (`service_provider.dart:421`): category, name, description, totalAmount, totalPaid, clientId, clientName, serviceDate, providedByName, updatedAt, itemsUsed (with batchAllocations), totalServiceProfit, unrealizedServiceProfit, paymentMethod, receiptNumber, transactionId, clientNameLower, paymentStatus.

| Field or effect | Today | Owner of the value |
|---|---|---|
| `receiptNumber` | The screen builds a new `Service` without it (`add_edit_service_screen.dart:967`); `updateService` writes `toMap()` with `'receiptNumber': null` through `doc.update` (`service_provider.dart:585`). **Erased.** | the counter, at create: the provider keeps it from the stored document |
| `clientId` | `_selectedClient` (`:53`) is never set from the service being edited, so its validator (`:440`) refuses the form until the client is picked again; `clientId: _selectedClient?.id` (`:974`). An unchanged edit cannot be saved. | the screen: seeded from the stored client |
| `totalServiceProfit`, `unrealizedServiceProfit` | the screen leaves them 0; `service.copyWith()` (`:572`) recomputes both. Same values. | derived |
| `itemsUsed[].batchAllocations` | the form drops them (`_collectItemsUsed`, `:273`); the old allocations are put back and FIFO takes them again (`:579-583`). Same values with the same stock. | the provider |
| Stock, debt, client balance | `previous` is the CACHED service (`_findCachedService`, `:570`), which holds only the live page (25, `listenToServices`) and loaded older pages. A service outside them: its stock is taken a second time and never put back, and `_handleServiceDebt` (`:727`) sees `previousOwed = 0`, so the client's `balance` rises by the whole amount owed again. | the stored document |
| paymentMethod, transactionId, category, name, description, providedByName, serviceDate, clientName, totalAmount, totalPaid | seeded from the service (`:110-135`) and written back. Kept. | the screen |
| Unknown fields | `doc.update` keeps every field it does not name. Kept. | - |
| Expense `transactions/...` (external items) | `_handleServiceTransaction` (`:870`) deletes the old expense and `add()`s a new one dated now (`:906`): an unchanged edit moves the expense to today, under a new id. **Found, not changed** (a separate document and flow; LATER). | |

## (1) Edit Transaction: what it drops

The stored transaction is `{...toMap(), ...searchFields()}` (`transaction_provider.dart:298`): date, description, amount, type, category, recordedBy, paymentMethod, receiptNumber, note, descriptionLower; a service expense also has `serviceId` (`service_provider.dart:717`).

- The screen builds a new `TransactionModel` without `receiptNumber` (`add_transaction_screen.dart:95`); `toMap` leaves a null out; `set()` without merge (`transaction_provider.dart:339`) replaces the document. **Erased: `receiptNumber`, and `serviceId` on a service expense** (the next Edit Service then cannot find that expense to replace it, and adds a second one).
- `date` and `recordedBy`: the screen copies them from the transaction it was given. Kept, but they belong to the stored document.
- Owned by the screen: description, amount, type, category, paymentMethod, note (empty = removed).

## (2) A payment's paymentStatus

`AddPaymentScreen._save` writes `updatedService.toMap()` (`add_payment_screen.dart:367`) and `updatedSale.toMap()` (`:354`). `paymentStatus` is only in `searchFields()` (`service.dart:113`, `sale.dart:225`), although `lib/data/payment_status.dart` documents it as written by both `toMap()`s. **Both** a service and a sale keep their old status after a payment (the prompt said sales were fine: `Sale.toMap` does not write it either; `e4d2_writer_audit.md` already said "for sales either"). Rules: sales already allow `paymentStatus` to an assistant (E4d-1); services refuse it (E4d-2).

## (3) C10 stockAdditions writers (complete list)

`addProduct` (`product_provider.dart:171`), `addBatch` (`:325`), `moveToSellable` (`:1051`): `productId, sellableDelta, stockDelta, timestamp`, no author. No other writer in `lib/` or `functions/`. `ProductProvider` has no user seam (`:19`); `moveToSellable` already reads the uid through `ActivityLogger.getCurrentUserInfo` (`:937`). Reader: `DailyReportService` (`daily_report_service.dart:501`) reads only `productId` and `sellableDelta`; an extra field is ignored.

## (4) C11 payment_submissions writer (complete list)

`SubscriptionScreen._submitPayment` (`subscription_screen.dart:195-213`), `submittedBy: user?.email ?? user?.uid ?? 'Unknown'`. No other writer. Readers (`subscription_screen.dart:117`, `:637`, `subscription_history_screen.dart:114`, the platform-admin tabs) never read `submittedBy` or a uid; the review only updates `status`.

## Result

(filled in by the batch's commits)

OWNER DECISION: given in the E4d-3 prompt (fix (1) and (2), C10 `userId`, C11 `submittedById`).
