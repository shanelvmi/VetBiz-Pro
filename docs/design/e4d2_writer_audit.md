# E4d-2 writer audit: the owner's decision, products, counters, stock logs, payment claims

Batch E4d-2 (RUNBOOK2 section 4; security_hardening.md 3(c) rows C4 update, C6 services, C7, C9, C10, C11, C12; the owner's decision on the last line of `e4d1_writer_audit.md`). Read-only audit of every write in `lib/` and `functions/` to the documents these rules cover, made BEFORE any rule changed. `functions/` writes none of them except with the Admin SDK (wipe, delete facility, purge), which the rules do not apply to. Line numbers at `d1c5949`. "Member" = owner, Co-admin or assistant.

Shapes marked *captured* are recorded from the real provider code into `firestore_rules_tests/fixtures/app_write_shapes.json` (`test/providers/write_shapes_capture_test.dart`) and replayed in the emulator as each role; *refused* = replayed as that role and expected to fail.

## The owner's decision: Edit Service, Edit Transaction, transaction delete (C4 update, C6 services, C7)

| Writer | Who today | Operation and fields |
|---|---|---|
| `ServiceProvider.updateService`, `service_provider.dart:547` | member: Edit in the row menu (`services_screen.dart:702`) and the details panel (`:914`) | `update({...toMap(), ...searchFields(), updatedAt})` (`:574`): any field; then `_handleServiceDebt` (`:785` set the whole debt, can RAISE amountOwed; `:799` delete) and `_handleServiceTransaction` (`:870` delete the old expense, `:895` add a new one) |
| `TransactionProvider.updateTransaction`, `transaction_provider.dart:306` | member: Edit in the row menu (`transactions_screen.dart:561`) -> `add_transaction_screen.dart:107` | `set({...toMap(), ...searchFields()})` (`:323`), keeps `recordedBy` (a NAME) and `date` |
| `TransactionProvider.deleteTransaction`, `:352` | menu item already admin-only (`transactions_screen.dart:562`) | `trash_transactions` set (`:389`, admin-only rule) then delete (`:395`, admin-only rule) |
| `PaymentProvider.addPayment/deletePayment` -> `updateService` (`payment_provider.dart:384`, `:496`) | - | no callers in `lib/` (dead code, as in E4d-1) |
| `TransactionProvider.addTransaction`, `:268` | member | counter (`nextReceiptNumber`, `:276`), then create (`:280`) |
| `ServiceProvider.addService` (E1b) | member | creates `transactions/service_{id}` in its transaction (`:432`) |
| `AddPaymentScreen._save`, `add_payment_screen.dart:337-367` | member | debt `update({amountOwed: lower})` (`:343`) or delete at 0 (`:341`); service `update(copyWith(totalPaid, updatedAt).toMap())` (`:367`): changes `totalPaid, updatedAt, totalServiceProfit, unrealizedServiceProfit` only. It does NOT write `paymentStatus` (`searchFields()` is not added), for sales either |
| Trash (admin) | admin | delete / restore of services and transactions (E2) |

No other screen reaches the three methods: receipts (`service_receipt_preview_screen.dart`) only print; the archives only read; Trash restores (a create) and is admin-only.

## C12 products create

| Writer | Who today | Operation |
|---|---|---|
| `ProductProvider.addProduct`, `product_provider.dart:116` | member: Add Product on Sellable Products (`products_screen.dart:833`), Stock Store (`stockstore_screen.dart:757`) and the dashboard quick action (`dashboard_screen.dart:2501`) | create product (`:137`), first batch (`:153`), `stockAdditions` entry (`:166`) |
| `ProductProvider.addBatch`, `:221` | member (Add Batch from the product menus, View Batches, Product Alerts) | batch create (`:305`) or merge update (`:287`), `stockAdditions` (`:320`), product update of `stockQty, sellableQty, expiry, batchNo, updatedAt` (`:363`, already allowed to assistants by `isOnlyChangingStockFields`) |
| Undo of a product delete / Trash restore | admin (product delete is admin-only) | create |

## C9 counters

| Writer | Who | Operation |
|---|---|---|
| `claimReceiptNumber` + `ReceiptNumberClaim.write`, `receipt_numbering.dart:56` (E1a/E1b: `sale_provider.dart:400/457`, `service_provider.dart:368/418`) | member | in the sale or service transaction: `set(counters/receiptNumber, {value: old + 1}, merge)` |
| `nextReceiptNumber`, `receipt_numbering.dart:28` (`transaction_provider.dart:276`) | member | own transaction: `set(counters/expenseReceiptNumber` or `otherIncomeReceiptNumber, {value: old + 1}, merge)` |

The first write of each counter is a create (`value: 1`); every later one is an update that raises `value` by exactly 1. Nothing deletes a counter (searched `lib/` and `functions/`).

## C10 stock logs

| Writer | Fields |
|---|---|
| `stockAdditions`: `addProduct` (`product_provider.dart:166`), `addBatch` (`:320`), `moveToSellable` (`:1046`) | `productId, sellableDelta, stockDelta, timestamp: serverTimestamp()`. **No author field.** |
| `stock_adjustments`: `moveBatchToStock` (`product_provider.dart:1163`), Edit Product quantity change (`add_edit_product_screen.dart:961`) | `productId, productName, oldStockQty, oldSellableQty, newStockQty, newSellableQty, userId` (`ActivityLogger.getCurrentUserInfo`: the Auth uid), `userName, source, (reason), timestamp: serverTimestamp()` |

## C11 payment_submissions

| Writer | Fields |
|---|---|
| `SubscriptionScreen._submitPayment`, `subscription_screen.dart:195` | `facilityId, facilityName, planId, planLabel, amount, promotionLabel, discountPercent, method, reference, proofImageUrl, status: 'pending', submittedAt: serverTimestamp(), submittedBy: user.email ?? user.uid ?? 'Unknown'` |
| Review (`platform_admin/subscription_requests_tab.dart:102`, `:146`) | Platform Admin: update `status` approved / rejected (rule unchanged) |

`submittedBy` holds the person's EMAIL (the uid only when the account has no email). Nothing on the server reads the collection.

## Found while auditing (not changed here)

- Edit Service writes `receiptNumber: null` (the form does not carry it; captured in E4d-1: 5 -> null). Edit Transaction builds a new `TransactionModel` without `receiptNumber` (`add_transaction_screen.dart:95`), `toMap` leaves a null out, and `set()` without merge replaces the document, so the number is removed.
- A payment never updates `paymentStatus` on the sale or service it pays, so a settled credit sale still reads "Partial" in the status filter (captured in E4d-1, "settles it").

## Result

(filled in at the end of the batch)
