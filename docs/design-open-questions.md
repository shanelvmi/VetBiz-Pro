# Design open questions (Phase 2)

Values and decisions the spec gives no home for. Each one is kept exactly as it is in the code until the owner decides.
Format: file, line, value, what it seems to be for.

## Open

For step 2R. Each needs before/after screenshots first; the owner's leanings are noted, not decided.

### Money (raised in step 2C, for step 2R)

Leanings: one currency spelling, "Tsh"; one decimals rule; one shape for a negative amount.

Every amount below keeps its exact current output through a named `Money` method, so each can be changed in one place later.

- **Saved text with no thousands separator** (`Money.savedWhole`, `Money.savedAsStored`): activity descriptions written to Firestore, e.g. "Recorded sale to Walk-in - Tsh 12500". `sale_provider.dart` (recorded, deleted sale), `service_provider.dart` (recorded, updated service; the deleted-service one prints the stored value as Dart does, so a stored double reads "Tsh 12500.0"), `transaction_provider.dart` (added, updated), `add_payment_screen.dart` (recorded payment). Old entries keep what they say; should NEW entries use "Tsh 12,500"? (A mixed log is the cost.)
- **On-screen and printed amounts with no thousands separator** (`Money.symbolWhole`): `facility_detail_screen.dart` plan price, `view_batches_screen.dart` (sell price, batch buy price), `trash_screen.dart` (item titles), `receipt_printer_service.dart` (thermal receipt: total, paid, balance, transaction amount). Not saved, so these could simply switch to `Money.symbolPlain`.
- **Raw stored values** (`Money.symbolAsStored`): subscription amounts shown as stored ("Tsh 50000", or "Tsh 50000.0" for a double): `facility_detail_screen.dart`, `subscription_requests_tab.dart` (2), `subscription_screen.dart`.
- **Three spellings of the currency**: "Tsh" (everywhere, `AppDefaults.currencySymbol`), "TSh" on the TOTAL line of the two receipt previews (`receipt_preview_screen.dart:609`, `service_receipt_preview_screen.dart:584`, left as typed: no home for it), and "TZS" before the facility card's compact total (`facility_screen.dart:1936`, now `AppDefaults.currencyCode`) where the same screen's other two totals say "Tsh". One spelling?
- **Two shapes for a negative amount**: `Money.format` gives "-Tsh 12,500", `Money.symbolPlain` gives "Tsh -12,500". Each screen keeps the one it had.
- **Decimals**: reports, PDFs, the dashboard and transactions use `Money.decimal` (up to 3 decimals, "12,500.5"); most other screens round to whole shillings. One rule?

### Payment methods: Tigo Pesa and Mixx by Yas (raised in step 2C, for step 2R)

Leaning: merge Tigo Pesa into Mixx by Yas for display, filters and report grouping (stored keys unchanged).

Stored keys never change, and both display everywhere. Three places treat them as two different methods today; each is kept as it is:

- Icon (`lib/widgets/payment_method_selector.dart`, `iconForPaymentMethod`): Mixx by Yas gets the mobile-money phone icon; an old record stored as 'Tigo Pesa' gets the generic payment icon. Give Tigo Pesa the phone icon too?
- Daily report breakdowns (`daily_report_service.dart`, report screens, PDF): totals are grouped by the stored string, so a day with both shows two rows. Count them as one (display only; the stored keys stay)?
- Payments ledger filter (`payments_screen.dart:860`) and the subscription history filter: the ledger's method filter lists only current methods, so old 'Tigo Pesa' entries can only be seen under "All"; the history filter lists both as separate choices. Merge?

### App name (raised in step 2C, for step 2R)

Leaning: one name, "VetBiz Pro".

User-facing "VetBiz Pro" now reads `AppInfo.name` (titles, Settings, support line, register intro, report fallback names, export share text, PDF and thermal-receipt headers and footers). These keep the name typed, on purpose:

- **Must stay literal**: code identifiers (`VetBizProApp`, `VetBizLoadingIndicator`, `VetBizLoadingStyle`); the Dart package `vetbiz_pro` and bundle ids (`com.example.vetbiz_pro`, `com.example.vetbizPro`) across android/ios/linux/macos; the Firebase project id `vetbiz-pro` (`.firebaserc`, `firebase.json`); the asset `assets/vetbizpro_illustration.png`.
- **Legal text, left as written**: `lib/screens/legal/privacy_policy_screen.dart`, `terms_of_service_screen.dart`, and the "© 2026 VetBiz Pro System. All rights reserved." lines (`login_screen.dart:424, 446`).
- **The two-tone wordmark**: "VetBiz " and "Pro" as separately styled spans (`receipt_preview_screen.dart:568, 655`, `service_receipt_preview_screen.dart:542, 630`, `receipt_pdf_service.dart:342`). A logo, not a sentence: a new name would need a design decision.
- **Server text** (not touched in Phase 2): the credential email in `functions/index.js:37-51` says "VetBiz Admin" and "the VetBiz system".
- **Two names in use**: "VetBiz Pro" and "VetBiz Pro System" (login header, register header, © line). One name?
- **The version** "v1.0.0" is typed in Settings (`settings_screen.dart:239`); it could come from the build (pubspec) instead.

### Raised in step 2D, batch D6

- **Alpha 0.95**, `lib/screens/products/add_edit_product_screen.dart` (the brand-green category and type picker dialogs' background, x2): 0.1 above `a85`, no step. Kept as is (owner, after D6); listed for 2R.
- **Photo placeholder alpha 0.6**, same file (the `add_photo_alternate_outlined` icon, now `AppIconSize.i40`): 0.1 from `a50`/`a70`, beyond the standing rule. Kept.
- **No Undo on sale delete**, `lib/screens/sales/sales_screen.dart` `_confirmDeleteSale`: see "Trash and restore: books consistency" below. The message is a plain success ("Sale deleted"); the confirmation still says "permanently deletes ... This cannot be undone." Make sale restore re-apply stock, debt and balance (then add Undo and change the dialog text), or keep it as is?

### Raised in step 2D, batch D7

- **List bottom gap 80**, `lib/screens/platform_admin/announcements_tab.dart` (`_fabClearance`, under the announcements list, clear of the New Announcement button): a size, same value and purpose as view_batches_screen's. Kept exact as a named local constant.
- **`Colors.redAccent[700]`**, `lib/screens/platform_admin/subscription_requests_tab.dart` (a small bold label in the request card): not in the 4.1 table; no danger role is within 12 on every channel (`dangerAccent` is redAccent, `dangerStrong` red[700]). Kept. Snap to `dangerAccent`, or a role?
- **Platform-admin badge `Colors.deepPurple`** (x6), `lib/screens/platform_admin/users_tab.dart` (the "Platform Admin" chip, its icon and the avatar fill): no role; a category colour. A `rolePlatformAdmin` role with the exact value?
- **Status chip fills `Colors.blue.shade100` / `Colors.orange.shade100`**, same file (pending / other status chips): not in the 4.1 table, no role within 12. Kept. Roles, or `info`/`warning` at an alpha?
- **`tealGlow` `#3E8E82`**, `lib/screens/platform_admin/platform_admin_home_screen.dart` (the sidebar's facility badge: fill at a15, border at a50, icon): more than 12 from every role. Kept as the named constant. A role named for it, or snap to `roleCoAdmin`/teal?
- **Chart height 220**, `lib/screens/platform_admin/overview_details_screen.dart` (`_chartHeight`, the daily earnings chart): a size. Kept exact as a named local constant.

### Raised in step 2D, batch D8

- **Login teals `#3E8E82` (`tealAccent`) and `#7EE8CB` (`tealGlow`)**, `lib/screens/login_screen.dart` (header and welcome-panel gradients, the welcome badge, the form card's top accent and lock badge, the Forgot / Register links; in `register_screen.dart` the welcome panel and the legal links): more than 12 from every role. Kept as named `static const` fields, one pair per screen. `#3E8E82` is also the platform admin's `tealGlow` (D7). One `brandTeal` role (and a second for the light glow)?
- **Online dot `Colors.greenAccent`**, `login_screen.dart` (the "System Online" pill in the header): no role within 12 (`success` is green, `trendUp` is `#10B981`). Kept.
- **Login timings with no token**, `login_screen.dart`, kept exact as named constants: `_announcementSlide` 600 ms (carousel page), `_shakeDuration` 420 ms (form card shake), `_alertSwitch` 260 ms (alert fade-in), `_hoverSweep` 450 ms (Login button hover), `_alertHoverGrace` 3 s (alert countdown restart after hover), `_blinkStep` 600 ms and `_blinkHold` 3 s (the NEW badge). The nearest AppMotion steps are 20 to 100 ms away; the 3 s delays have no AppTimeouts entry.
- **Card fill alpha 0.97**, `login_screen.dart` and `register_screen.dart` (the floating card over the photo, `surface` at 0.97): no AppAlpha step within 0.05. Kept.
- **Register timings and sizes**, `register_screen.dart`, kept exact as named constants: `_alertSwitch` 260 ms and `_alertHoverGrace` 3 s (as on login), `_scrollToField` 350 ms (scroll to the first field in error; 50 from `slow` and `slower`), `_welcomePanelWidth` 290 (the welcome panel beside the form).
- **Outline alpha 0.6**, `register_screen.dart` (the welcome panel's "Log in" button outline, `onPrimary` at 0.6): 0.1 from `a50`/`a70`, as in D4. Kept.
- **Login card widths 1100 / 480**, `login_screen.dart` (`targetWidth`, wide and narrow): content widths, not in 4.10 (480 is `dialogMd`'s snap source, but this is a page card, not a dialog). Kept.

### Raised in step 2D, batch D9

- **Services steel blue `#5C7C99`**, `lib/screens/dashboard/dashboard_screen.dart` (`servicesSteelBlue`): no role within 12 (`roleAssistant` is 14 off on blue). Kept as a named constant. A role for it?
- **Drawer hover fills `Colors.teal.shade700` / `shade800`**, `dashboard_screen.dart` (`DrawerHoverItem`, the drawer's platform-admin button hover and press, the end drawer's Logout hover): `shade700` has the value of `roleCoAdminStrong`, a different purpose. Kept.
- **End drawer close icon 28**, `dashboard_screen.dart`: 4 px from `i24`/`i32`. Kept. `_logoutClearance` 80 (gap under the profile panel) kept exact as a named constant.
- **Small-screen check `height < 600 || width < 1024`**, `dashboard_screen.dart` `_buildDrawerContent`: sits with the Layout Fixed Mode collapse logic, so left as written (owner's D9 rule) although `AppBreakpoints.compact`/`expanded` hold the same values.
- **Drawer item timings**, `dashboard_screen.dart`, kept as named constants: `_hoverFade` 200 ms (between `fast` and `normal`), `_tooltipWait` 300 ms (`tooltipDelay` is 400).
- **Subscription banner**, `dashboard_screen.dart` `_buildSubscriptionBanner`: `deepAmber` `#C77800` and `cream` `#FFF6E7` (local consts; no role within 12), the cream at alpha 0.92 (no step within 0.05), and `_bannerSwitch` 550 ms (50 above `slowest`). All kept.
- **Quick action tints `#E3F0EC` (Record Visit) and `#FCEFD9` (Add Product)**, `dashboard_screen.dart` `_buildQuickActionCards`: `#E3F0EC` is within 12 of `divider`, but snapping a tinted fill to a grey is what the owner reversed for the alerts after D8, so both are kept exact. Tint roles (like `dangerSurface`)?
- **Chart loading gap 40**, `dashboard_screen.dart` (`EdgeInsets.symmetric(vertical: 40)` around the chart spinner): 8 above `s32`. Kept.
- **Service breakdown palette**, `lib/screens/dashboard/insights_screen.dart` `_servicePalette`: steel blue `#5C7C99`, sage `#8FA998`, terracotta `#B98B6F`, lavender `#9B8AA6` (the brand teal and amber now read `AppPalette`). A fixed chart palette with no roles. `chart` roles with the exact values?
- **Inline raw error**, `insights_screen.dart`: "Could not load insights: $_error". Fixed before D10 (owner): "Couldn't load insights." plus `FriendlyError.messageFor(error)`.
- **Debt category `#E59A00`**, `lib/screens/dashboard/notifications_screen.dart` `_categoryColor`: no role within 12 (`warning` is 26 off). Kept.
- **Left as written on purpose (owner's D9 rule):** the bell's `_BlinkingDot` class (its 700/1400/400 ms timings, 9 px dot, red default), and the 900 ms delay before the subscription pill shows.

### Raised in step 2D, batch D10

- **Facility teal `#3E8E82`**, `lib/screens/facilities/facility_screen.dart` (`_tealAccent`, the Total Products metric): the login teal again (see D8). Kept as a named constant.
- **Facility type `Colors.purple`** (any type other than agrovet or vet), `lib/screens/facilities/facility_picker_screen.dart` `_typeColor`: same value as `chart4`, different purpose. Kept.
- **Loading gaps 40**, `facility_screen.dart` (`EdgeInsets.symmetric(vertical: 40)`, inventory and sales tabs): 8 above `s32`. Kept. List panel sizes `_listPanelHeight` 360 and `_listPanelWidth` 340 kept exact as named constants.

### Raised in step 2D, batch D11

- **`Colors.blue.shade900`**, `lib/screens/activity/activity_log_screen.dart` `_buildScopeNote` (the text of the assistant's "You see your own activity" note): no role (`infoStrong` is blue 700). On the guard allowlist with that reason. Snap to `infoStrong`, or a role?
- **Everything still raw in `lib/screens` is allowlisted** (`tool/hardcoded_baseline.json`), each entry naming the question above (D4, D7 to D10, Money) or the owner's D9 rule it belongs to. Deciding a question in 2R means removing its entry.

### Raised in step 2E

- **`Colors.orange.shade900`**, `lib/main.dart` (the text of the "removed from facility" note on the no-facility screen): no role (`warningStrong` is orange 800). On the guard allowlist with that reason. Snap to `warningStrong`, or a role?
- **New category roles `chart8` (amber 700) and `chart9` (deep orange)**, `lib/theme/app_colors.dart`, for the Reorder Soon and Debt Reminder notification colours (spec 4.1: category colour -> chartN), next to `chart7` (indigo, Transactions activity). Exact legacy values; for review in 2R with the other chart roles.
- **PDF snaps (output difference)**, `daily_report_pdf_service.dart` and `receipt_pdf_service.dart`: font 8 and 8.5 -> 9, 9.5 -> 10, spacing 1.5 -> 2, 3.5 and 5 -> 4 (spec tables and the standing rule). Printed text in those spots grows by up to 1pt. Check one printed daily report and receipt.

### Raised in step 2F, batch 2F-2 (wording; English kept as it was)

- **"All Status"**, `lib/widgets/product_catalog_side_panel.dart` (key `products_statusAll`): the no-filter row of the STOCK STATUS list. Reads oddly ("All statuses"? "Any status"? "All"?). The Kiswahili draft says "Hali Zote".
- **Short relative times are much longer in Kiswahili**, `lib/widgets/notification_row.dart` `relativeTime()` (keys `time_minutesAgo`, `time_hoursAgo`, `time_daysAgo`): "5m ago", "2h ago", "3d ago" become "dakika 5 zilizopita", "saa 2 zilizopita", "siku 3 zilizopita" in the draft. Check the notification row at a narrow width; a short Kiswahili form (for example "dak. 5"), or a longer English one to match, is the owner's call.

### Raised in step 2F, batch 2F-3 (stored-value labels; stored values unchanged)

- **`planLabel` is saved as English display text.** `lib/screens/subscription/subscription_screen.dart` saves `'planLabel': _selectedPlan.label` ("Daily", "Weekly"...) on every payment submission, next to `planId`. Since 2F-3 the app shows a plan's name from `planId` (`subscriptionPlanLabel`), and falls back to the saved `planLabel` only for an unknown id. The Subscription history's plan filter still lists and compares the saved `planLabel` values. `planLabel` was left as saved, as decided. Open: keep writing it, or stop and filter on `planId` (old submissions would still need `planLabel`). The platform-admin console still shows `planLabel` as stored.
- **"Vet" and "Veterinary" name the same product group.** The category filter chips show "Vet" (`productGroup_vet`), and the catalog side panel shows "Veterinary" (`productGroup_veterinary`). Both English texts were kept as they were. One name, or both on purpose?
- **Older lower-case facility statuses and activity types now show capitalised.** The facility status chip and the Activity Log's type badge used to show the stored text as-is ("active", "pending", "sales"). They now show the label, matched ignoring case as their readers already did ("Active", "Pending", "Sales"). These are the only English display changes in 2F-3.
- **Facility name with its type**, `facility_screen.dart` `_nameWithType` ("Ukuli Agrovet"): it joins the name and the stored type, so it stays English. In Kiswahili the type would read better before the name ("Kliniki ya Mifugo Ukuli"). This belongs to the Facilities screen batch.

### Raised in step 2F, batch 2F-4 (wording; English kept as it was)

- **"1 payments", "1 debts", "of 1 products".** The Payments metric cards (`payments_paymentCount`, `payments_debtCount`) and the Stock Store pagination (`products_showingRange`) never had a singular form in English. The keys are ICU plurals with one `other` branch, so the English reads exactly as before; the Kiswahili already has its own forms. Adding `=1{...}` English branches is a one-line change per key once agreed.
- **"Payment Details"** is one key (`payments_detailsTitle`) for the Payments detail panel and the Subscription form's payment section. The Kiswahili ("Maelezo ya Malipo") fits both; split it if either should read differently.
- **"No submissions yet." and "No submissions yet"** (Subscription screen with a full stop, Subscription history without) are two keys because the English differs.

### Raised in step 2F, batch 2F-7 (wording and language; English kept as it was)

- **"1 units", "1 found", "archived after 1 days", "of 1 services"** (report summary tile, services archive banner, subtitle and pagination): `reports_unitsCount`, `services_foundCount`, `services_archiveSubtitle` and `services_archiveShowing` are ICU plurals with one `other` branch, so the English reads as before. An `=1{...}` branch is a one-line change once agreed.
- **Receipt body stays English** (header, labels, totals, "Thank you for choosing us.", "Powered by ..."): moved to `lib/utils/receipt_texts.dart`, pinned by `test/receipt_texts_test.dart` and allowlisted as a file. The preview's buttons, format choices and "Receipt Details" panel are localised; the panel shows its own status keys. The sales receipt preview (2F-8) can use the same file.
- **Share texts stay English**, like the files they go with: the service receipt's "Receipt" (`ReceiptTexts.shareText`) and the report PDF's "Daily Closing Report" (`DailyReportPdfService.shareText`).
- **Saved or PDF-only fallbacks stay English**: "Unknown User" (saved in the report as `generatedByName`), "{app} Facility" (the facility name passed to the report PDF), and the "Draft report for ... deleted" activity description.
- **Stored values now through lookups in the reports**: payment method names (also inside sentences such as "No income via {method} today"), transaction categories in the Expenses and Transactions tabs, and product units in the Full Report and the visit form's product suggestions. In English every known label equals its stored key, so the English reads as before.
- **Same English, separate keys** because the meaning differs: "Reason: {reason}" (`subscription_rejectReason`, `reports_reasonValue`), "Service" (`debtSource_service`, `services_fallbackName`, `reports_colService`), "Products" (`activityType_products`, `reports_tabProducts`).
- **2F-6 note on Business Hours**: "Generate Today's Report" and "View Reports" now have keys (`reports_generateToday`, `reports_viewTitle`); the Business Hours sentences can take them as placeholders. Not done here (it changes 2F-6 keys).

### Raised in step 2F, batch 2F-6 (wording and language; English kept as it was)

- **Other screens named inside sentences**: Business Hours says "Generate Today's Report" and "View Reports", Manage Account says "View Facilities". The Kiswahili drafts keep those names in English until the Reports and Facilities batches give them keys; then the sentences should take them as placeholders.
- **Trash item titles stay English** ("Sale - {client} - {amount}", "Walk-in", "Transaction", "Untitled"): the same text goes into the saved "Permanently deleted: ..." activity description. Showing a label on screen while saving English needs two titles; decide in the activity batch (2F-12).
- **Team Members fallbacks in saved text**: "The assistant" / "This co-admin" stand in for a missing name in both the activity description (saved) and the success message, so the message can show English in Kiswahili for a nameless person.
- **Export screen is allowlisted for R10 as a whole file** (its remaining strings are inside the exported file). The guard test only accepts whole-file entries, so a new on-screen string added there later would not be caught; moving the file-building code to a service would remove the need. **Fixed (71c79c7):** the exported-file texts are in `lib/utils/export_texts.dart`, which is allowlisted instead; the screen is checked again.

### Raised in step 2F, batch 2F-5 (wording and language; English kept as it was)

- **Debt reminder sent by WhatsApp or SMS** (`debtors_screen.dart` `_showReminderOptions`): the message goes to the debtor, not to the app's user, so it is not in the language files and stays English ("Hi {name}, this is a reminder from {facility} that you have an outstanding balance of {amount}. Kindly settle at your earliest convenience. Thank you!", with "us" when no facility name). Options: keep English; follow the app language; or (suggested) a facility setting for customer-facing language, together with receipts. A nameless debtor appears as "Unknown" in it, so that word stays English too.
- **"1 days", "Over 1 days"** (Active Debts table and metric): `debtors_daysCount` is an ICU plural with one `other` branch and `debtors_overDays` a plain number, so the English reads as before. An `=1{1 day}` branch is a one-line change once agreed.
- **"Total Owed" and "Total owed:"** on the debt screens (metric, table, panel vs the Record Payment header), and **"Could not load clients: ..."** next to the usual "Couldn't ..." messages: kept as they were.
- **Active Debts CSV export** (headers, "Overdue"/"Current", the share text "Active Debts Export") stays English, like receipts and PDFs.

### Trash and restore: books consistency (audit after D6, read-only)

`TrashService.restore` (used by the Trash screen and every Undo) only copies the document back from `trash_*` to its live collection, drops `deletedAt`/`deletedBy`, and logs "Restored ...". Anything else the delete changed is reversed only if a server trigger reacts to the document reappearing (the `onDocumentWritten` daily summaries do).

| Item | What deleting it changes besides moving the document | Reversed by Restore / Undo? |
|---|---|---|
| Product (`ProductProvider.deleteProduct`; Undo on Products and Stock Store) | Nothing else. Its batches stay at `products/{id}/batches` while it is in Trash | Yes: the restored product finds its batches again. Complete |
| Sale (`SaleProvider.deleteSale`; no Undo) | Stock put back on the products it sold (`_restoreStock`) | **No**: the stock stays added back |
| | Its debt record(s) deleted (`debts` where `saleId`) | **No**: the debt is not re-created |
| | Client balance reduced by the unpaid part (`_adjustClientBalance`) | **No**: the balance stays reduced |
| | Daily sales summary reversed (server trigger `updateDailySalesSummary`) | Yes: the trigger counts it again on restore |
| | Upfront payment (`payments`, `dailyCollections`) | Not touched by the delete (the cash stays counted even while the sale is in Trash) |
| Service (`ServiceProvider.deleteService`; Undo withdrawn after this audit) | Stock it used put back (`_restoreStockForItems`) | **No** |
| | Its debt `service_{id}` deleted; client balance reversed; `oldestUnpaidDebtDate` recomputed | **No** |
| | Its expense transaction(s) (`transactions` where `serviceId`) **hard-deleted**, so the daily transaction summary drops them | **No**: gone for good, not in Trash |
| | Daily service summary reversed (server trigger) | Yes, on restore |
| | Upfront payment (`payments`, `dailyCollections`) | Not touched by the delete |
| Transaction (`TransactionProvider.deleteTransaction`; Undo on Transactions) | Daily transaction summary reversed (server trigger) | Yes, on restore. Complete |

Incomplete: **sales** and **services**. After restoring either one, stock is too high and the client's balance and debts are too low. The Trash screen's Restore now asks for confirmation for these two and says what it will not change (behaviour unchanged). Open: make `TrashService` re-apply stock, debt and balance for sales and services (and decide what to do about the hard-deleted service expenses). The Services Undo is withdrawn until then (see Decided, "Undo after the Trash audit").

## Decided

### D11 (decided and done in batch D11)

- **Standing snap rule applied to the D7 to D10 open questions:** none falls within it. All are colours (not covered), durations or sizes (not covered), or beyond the limits (alpha 0.97, 0.92 and 0.6; icon 28; gaps 40). They stay Open for 2R.
- **Computed durations allowlisted** (`tool/hardcoded_baseline.json`, one reason each): the D7 questions (`subscription_requests_tab.dart` plan length and attended window; `overview_details_screen.dart` chart days; `facility_detail_screen.dart` manual override) and the D8 one (login's `_errorDisplayDuration`; its method name was also an R5 false positive). Same kind, also allowlisted: register's computed alert time and the dashboard and insights date maths.
- **The two screens never in a 2D batch** (raised in 2E): `activity_log_screen.dart` and `legal_document_screen.dart` are on the tokens. Snaps: alpha 0.06/0.04 -> `a05`, 0.12 -> `a10`, the black54 barrier -> `scrim` at `a50`, 250 ms -> `AppMotion.normal`, font 16.5 -> `f17`, icon 17 -> `i18`.
- **Guard:** R1 to R9 are at zero in `lib/`, with everything kept on the allowlist.

### D8 follow-up (decided after batch D8; done before D9)

- **`AppColors.dangerSurface`** (exact `#FFF1F0`): the login and register error alert boxes use it, so they keep their pink tint (the D8 snap to `surfaceMuted` made them grey).
- **`AppMotion.toastDetailed`** (6 s): an AppFeedback message with a second line stays at least this long; a type whose own time is already longer (error, 7 s) keeps it.
- **Service delete dialog** (`services_screen.dart` `_confirmDeleteService`): "This moves the service to Trash and puts its stock back, removes its debt and updates the client's balance. Restoring from Trash brings back the record only."

### Undo after the Trash audit (decided after D7; done before D8)

- **Services: Undo withdrawn.** Deleting a service shows "Service moved to Trash" with no Undo (`services_screen.dart` `_confirmDeleteService`), because a service restore is incomplete (see "Trash and restore: books consistency"). The Trash screen's confirmed Restore stays.
- **Products and transactions: Undo kept.** Their restore is complete.

### D6 follow-up (decided after batch D6; done before D7)

- **Info notes:** the three exact roles stay (`infoNote`, `infoNoteText`, `infoNoteTextSoft`). Merging them is a 2R decision.
- **`Colors.orange[900]`** (add_edit_product_screen's duplicate-name hint titles) snaps to `warningStrong`.
- **Alpha 0.95** (category and type picker dialogs): kept and listed (see Open, D6).
- **`AppIconSize.i40`** added. The 40 px empty-items icon (add_sale_screen) uses it exactly; the 36 px photo placeholder (add_edit_product_screen) snaps up to it.
- **Sizes 80 and 96** stay as the named local constants `_fabClearance` (view_batches_screen) and `_qtyColumnWidth` (add_sale_screen).
- **`tool/oneoff_2d_tokens.dart`** stays uncommitted for D7 to D10 and is deleted when 2D ends.
- **CLAUDE.md** analyze baseline: 160 (0/16/144).

The questions as raised:

- **List bottom gap 80**, `lib/screens/products/view_batches_screen.dart` (`_fabClearance`, under the batch list so the floating Add Batch button does not cover the last card): a size above the spacing ladder, no token. Kept exact as a named local constant.
- **`Colors.orange[900]`**, `lib/screens/products/add_edit_product_screen.dart` (the duplicate-name hint's titles, "... already exists" and "Similar products already exist"): not in the 4.1 table; `warningStrong` (orange[800]) is more than 12 away on green. Snap to `warningStrong`, or a `warningDeep` role?
- **Alpha 0.95**, same file (the brand-green category and type picker dialogs' background, x2): 0.1 above `a85`, no step. Kept. Snap to full `primary`, or add `a95`?
- **Photo placeholder icon**, same file: `size: 36` (4 px from `i32`) at alpha 0.6 (0.1 from `a50`/`a70`). Kept, beyond the standing rule.
- **Qty column width 96**, `lib/screens/sales/add_sale_screen.dart` (`_qtyColumnWidth`, the wide items table, header and rows): a size above the spacing ladder. Kept exact as a named local constant.
- **Empty items icon 40**, same file (`_buildEmptyProductsState`, `Icons.playlist_add_outlined`): 8 px from `i32` and `i48`, beyond the standing rule. Kept.

### D5 follow-up (decided after batch D5; done before D6)

- **Info notes:** `infoNote` roles with the exact current values, one role per value: `infoNote` (blueGrey[400], the icon in every note), `infoNoteText` (blueGrey[600], the receipt notes' text) and `infoNoteTextSoft` (blueGrey[500], the report review note's text). The three shades needed three roles to stay exact.
- **Report summary tiles:** `chart4` (purple, Debt Repayments), `chart5` (blueGrey, Transactions), `chart6` (teal, Services Performed), exact values. They share values with `roleAssistant`/`roleCoAdmin` but not purpose, so they stay separate.
- **Receipt amber:** `ReceiptPalette.amber = Color(0xFFE0A32E)` in `lib/theme/pdf_palette.dart`; `PdfPalette.amber` is built from it. Both receipt previews use it. Receipts stay unthemed on purpose.
- **Delete outline `Colors.red[200]`:** `danger` at `AppAlpha.a50` (services_screen, and sales_screen in D6).
- The standing snap rule (D4 follow-up) keeps applying.

The questions as raised:

- **Info note `Colors.blueGrey[400]` / `[500]`**, `lib/screens/reports/report_review_screen.dart` (the "No income came in via ..." hint under a payment method), and the same note style in `lib/screens/services/service_receipt_preview_screen.dart` (`blueGrey[400]` icon, `blueGrey[600]` text, on the `#EFF5F8` box now `surfaceMuted`): no role. `textHint` is grey[500] (not blue-grey). A `noteMuted` role, or snap to `textHint`/`textDisabled`?
- **Report summary tiles**, `lib/screens/reports/report_tabbed_content.dart`: Debt Repayments `Colors.purple`, Transactions `Colors.blueGrey`, Services Performed `Colors.teal` (the other tiles already use info/success/danger/primary/warning). Category colours: `chart` roles with exact values? blueGrey and teal match `roleAssistant`/`roleCoAdmin` in value, but not in purpose.
- **Receipt wordmark amber `#E0A32E`**, `service_receipt_preview_screen.dart` ("Pro" in the on-screen receipt): the same value as `PdfPalette.amber`, which is a `PdfColor` with no Flutter twin. The green half is now `AppPalette.primary` (unthemed, so the preview matches print). A Flutter `receiptAmber` constant next to the brand colours? (The wordmark is also in the 2R "App name" question.)
- **`Colors.red[200]`**, `lib/screens/services/services_screen.dart` (the Delete button's outline in the details panel): not in the 4.1 table; the lightest danger role is `dangerSoft` (red[400]). A `dangerBorder` role, or snap to `dangerSoft`?

### D4 follow-up (decided after batch D4; done in D4g to D4j)

- **Team role colours (D4g):** six roles with exact current values: `roleOwner` (indigo), `roleCoAdmin` (teal), `roleAssistant` (blueGrey), each with a `Strong` variant (shade 700) for the chip label. The Team Members role chip uses them.
- **`MembershipService.errorMessage` (D4h):** its fallback (anything that is not a Functions error) goes through `FriendlyError.messageFor`. Server-provided messages are unchanged.
- **`FirestoreErrorView` (D4i):** shows the friendly message, keeps the missing-index detection and its link, and puts the raw error behind a Details action.
- **Standing snap rule (from D4j on):** a leftover value snaps to the nearest existing token when the shift is at most 0.05 in opacity, 2 px in spacing, radius or icon size, or 1 px in font size; ties go up. Otherwise it is kept and listed here. Applied to the D4 leftovers in D4j: upload overlay black38 -> `scrim` at `a40`; the 9 px team-table dot -> `AppSizes.statusDot`. Kept (beyond the rule): border alpha 0.6 (0.1 from a50/a70), padding 36 (4 px above s32), the 6 px separator dot (no icon step within 2 px), and the Reassign button and empty-team icon teal (colours are not covered by the rule).

The questions as raised:

- **Upload overlay `Colors.black38`**, `lib/screens/settings/business_profile_screen.dart` (over the logo while it uploads): a scrim, but 0.38 has no AppAlpha step and no snap rule. Kept. `scrim` at `a40`?
- **`FirestoreErrorView` shows raw Firestore text** (`lib/widgets/firestore_error_view.dart`, used by Payments, Team Members and others): by design it shows the error so the missing-index link can be opened, but any other error also appears raw. Show `FriendlyError.messageFor(error)` when there is no index link? It is a shared widget, so this changes every screen that uses it.
- **`MembershipService.errorMessage` falls back to `error.toString()`** (`lib/services/membership_service.dart`, 9 callers, e.g. the invite dialog): anything that isn't a Functions error reaches the screen raw. Route that fallback through `FriendlyError.messageFor`?
- **Team role colours**, `lib/screens/admin/manage_assistants_screen.dart` `_roleChip`: Admin = `Colors.indigo`, Co-admin = `Colors.teal`, Assistant = `Colors.blueGrey`, each as a 10% fill with its `shade700` as the label. Spec 4.1 says category colours become roles with exact values. Proposal: `teamAdmin`/`teamAdminStrong`, `teamCoAdmin`/`teamCoAdminStrong`, `teamAssistant`/`teamAssistantStrong` (6 roles). Kept raw until decided. `Colors.blueGrey` is also the Assistant colour in `platform_admin/user_detail_screen.dart`.
- **Other teal**, same file: the "Reassign" action button (`Colors.teal`) and the empty-team icon (`Colors.teal.shade300`). Teal is also an activity-type colour on four other screens (activity log, dashboard, facility, notifications). Reuse `teamCoAdmin` here, and a separate `chart` role for the activity types?
- **Border alpha 0.6** (action buttons) and **vertical padding 36** (empty-team state), same file: no AppAlpha step / above the spacing ladder, no snap rule. Kept.
- **Small dots**, same file: a 6 px `Icons.circle` used as a "·" separator, and a 9 px status dot in the team table (`AppSizes.statusDot` is 8). Snap the 9 px dot to `statusDot`?

### D3 follow-up (decided after batch D3; done in D3g)

- Transactions delete dialog: "This cannot be undone." -> "You can restore it from Trash."
- Debtors bell `Colors.orange[700]` -> `warningStrong`. Active chip label `Colors.green[800]` -> `successStrong`.
- `AppSizes.statusDot` = 8, used for every 8 px status dot found: clients (Active/Inactive), product catalog side panel (stock status), login and platform-admin users tab (online), view batches (expired), view reports (submitted). The platform-admin bar chart's 8 px bar width is not a dot and is left for its batch.
- Clients list load error: the raw error is replaced by `FriendlyError.messageFor(error)`; the missing-index text and its Create Index button stay.
- **Standing rule:** any inline raw error text found in a batch ("Could not load ...: ${error}") is fixed the same way, with `FriendlyError.messageFor`, and listed in the batch report.

The questions as raised:

- **"This cannot be undone."**, `lib/screens/transactions/transactions_screen.dart` (delete confirmation): the delete is a soft delete into `trash_transactions` (restorable from Trash for 30 days), and the message after it now offers Undo (PHASE2_FEEDBACK_SPEC section 8). The dialog sentence is kept as written. Change it to "You can restore it from Trash."?
- **`Colors.orange[700]`**, `lib/screens/debtors/debtors_screen.dart` (the "send reminder" bell icon): not in the 4.1 table, and no role is within 12 on every channel (`warning` is orange, `warningStrong` is orange[800]). Kept. Snap to `warningStrong`, or add a role?
- **`Colors.green[800]`**, `lib/screens/clients/add_client_screen.dart` (the selected "Active" status chip's label): not in the 4.1 table, and no role is within 12 (`successStrong` is green[700]). Kept. Snap to `successStrong`, or add a role?
- **Status dot 8 px**, `lib/screens/clients/clients_screen.dart` (`Icons.circle`, Active/Inactive): no `AppIconSize` step and no snap rule. Kept.
- **Inline raw error**, `clients_screen.dart`: "Could not load clients: <raw error>" when the list fails to load (the missing-index case has its own text and a Create Index button). Same pattern the owner fixed in the subscription history (D2f). Switch it to `FriendlyError.messageFor(error)` too?

### D2 follow-up (decided after batch D2; done in D2f, the dialog swap in D2g)

- Modal barrier `Colors.black54` -> `scrim` at `AppAlpha.a50`.
- Offer banner gradient 0.75 -> `a70`.
- `AppIconSize.i24` added; the 26 px offer icon snaps to it. Icons 11 -> `i12`, 13 -> `i14`.
- Stock store shadow alpha 0.03 -> `a05`.
- "Release to Shop" -> "Release to Shelf" in both dialog texts of `release_to_shop_flow.dart` (identifiers and file names stay).
- `payments_screen.dart`'s private `_DateRangeDialog` is replaced by the shared `lib/widgets/date_range_dialog.dart`.
- The subscription history's inline load error shows `FriendlyError.messageFor(error)` instead of the raw error.

Other user-facing "shop", for a later copy pass (not changed): none left in `lib/` or `functions/` after the rename. The word remains only in code comments (`facility_screen.dart:1224` "how's this shop doing", `payments_screen.dart` "the whole shop's ledger") and identifiers (`release_to_shop_flow.dart`, `releaseProductToShop`, `_releaseToShop`).

The questions as raised:

- **Modal barrier** `Colors.black54`, `lib/screens/subscription/subscription_screen.dart` (`showSubscriptionScreen`): the spec maps black54 to `textSecondary`, but this is a scrim. `scrim` at 0.54 has no AppAlpha step. Snap to `scrim` + `a50`, or add `a55`?
- **Offer banner gradient**, `subscription_screen.dart`: `accent` fading to 0.75. No AppAlpha step and no snap rule. Snap to `a70`, or add `a75`?
- **Offer icon 26 px**, `subscription_screen.dart`: no `AppIconSize` step and no snap rule.
- **Icon sizes 11 and 13**, `lib/screens/payments/payments_screen.dart` (the trend-pill arrow, 11, like the summary card's, which was decided to snap to `i12`; the "Payment Received" check, 13). No step and no snap rule. Snap both to `i12`? `stockstore_screen.dart` has another 11 px icon (the list row's "Restock Shelf" badge; the card's badge uses 12).
- **Shadow alpha 0.03**, `lib/screens/store/stockstore_screen.dart` (metric cards): now the `shadow` role, but 0.03 is not in the snap table (0.04 and 0.06 snap to `a05`). Snap to `a05`?
- **"Shop" in the release flow**, `lib/screens/store/release_to_shop_flow.dart`: the dialog title "Release to Shop" and the question "Do you still want to release it to the shop?" call the selling shelf a shop (CLAUDE.md: never call a business a shop). The success message now says "to the shelf"; the two dialog texts are kept until a copy pass. "Release to Shelf"?
- **Duplicate date-range dialog**, `payments_screen.dart` `_DateRangeDialog`: a line-for-line private copy of `lib/widgets/date_range_dialog.dart` (same parameters, same output), now on the same tokens. Replace it with the shared widget (about 115 lines removed, no visible change)?

### D1 follow-up (decided after batch D1; done in D1c)

- `scrim` and `shadow` roles (exact `Colors.black`): `auth_background.dart` 0.18 -> `a20`, `notification_row.dart` 0.04 -> `a05`.
- `AppMotion.pulseSlow` (2 s, maintenance pulse), `emphasis` (900 ms one-shot: summary card glow, loading entrance), `float` (1400 ms: trend arrow; the 1500 ms loading subtitle pulse snaps to it).
- The 320 ms entry switcher (`facility_activation.dart`) snaps to `AppMotion.slow`.
- `AppTimeouts.tooltipDelay` (400 ms, trend tooltip).
- `AppIconSize.i48`; 44 (maintenance) snaps to it; the 11 px trend icon snaps to `i12`.
- `AppAlpha.a85` (selected-row count text); the animated 0.45 glow snaps to `a50`.
- Guard allowlist: `trial_period_helper.dart` `Duration(days: days)`, "computed from the configured trial days".
- The subscription-locked dialog keeps the 340 snap (`AppSizes.dialogXs`); the `dialogFixedWidth` comment now says 340.
- `trendUp` and `trendDown` stay separate roles; revisit in 2R.

The questions as raised:

- **Black scrim and shadow**, `lib/widgets/auth_background.dart:37` (`Colors.black` at 0.18 over the login photo) and `lib/widgets/notification_row.dart:47` (`Colors.black` at 0.04, a card shadow). The spec maps `Colors.black` to `textStrong`, but these are not text: in Dark Mode a text role turns light, a scrim or shadow should not. Add `scrim` and `shadow` roles (exact `Colors.black`)? 0.18 also has no AppAlpha step.
- **Maintenance pulse**, `lib/widgets/maintenance_gate.dart:162`: a 2 s repeating pulse. `AppMotion.loop` is 900 ms. Add `AppMotion.pulseSlow` (2 s)?
- **Entry switcher**, `lib/utils/facility_activation.dart:176`: `AnimatedSwitcher` 320 ms. Not in the motion table; nearest is `slow` (300). Snap?
- **Trial length**, `lib/utils/trial_period_helper.dart:30`: `Duration(days: days)` from the configured trial days. Business date math, not a literal; add a guard allowlist entry?
- **Icon sizes**: 48 (`firestore_error_view.dart:30`) and 44 (`maintenance_gate.dart:197`) have no `AppIconSize` step and no snap rule. Add `i48` (and snap 44 to it)?
- **Width snap applied**: the subscription-locked dialog (`lib/utils/subscription_guard.dart`) was 360 wide on wide screens; `AppSizes.dialogXs` makes it 340 (spec 4.10). The `AppBreakpoints.dialogFixedWidth` comment still says 360 and should change if the snap is kept.
- **One-shot 900 ms**, `lib/widgets/summary_card.dart:115` (the value-changed glow) and `lib/widgets/vetbiz_loading_indicator.dart:66` (the entrance): both play once, and `AppMotion.loop` (900) is for repeating motion. Add `AppMotion.emphasis` (900)?
- **Slow repeating floats**, `summary_card.dart:316` (trend arrow, 1400 ms, same value as `AppMotion.colorCycle` but a different purpose) and `vetbiz_loading_indicator.dart:92` (subtitle pulse, 1500 ms). Reuse `colorCycle`, or add a `float` token?
- **Tooltip delay**, `summary_card.dart:345`: 400 ms before the trend tooltip shows. A delay, not motion; leave inline or add to `AppTimeouts`?
- **Alphas with no step**: `summary_card.dart` glow `0.45 * glow` (animated) and `product_catalog_side_panel.dart` count text on a selected row (`onPrimary` at 0.85). Add `a85`, or snap to `onPrimaryMuted` (0.7)?
- **Trend icon 11 px** (`summary_card.dart`, compact pill): no `AppIconSize` step; the 12 px one became `i12`.
- **New colour roles** `trendUp` (`#10B981`) and `trendDown` (`#EF4444`): the trend pill's green and red, more than 12 away from `success` and `danger`. Merge into them in 2R?
- **Snaps applied here**: amber[700] -> `warning` ("Reorder Soon" dot) and grey[800] -> `textPrimary` (side-panel row labels), both per the 4.1 table; the loading screen's paw marks were the brand at alpha 0x0A (0.039), now `a05`.

### To do in the batch named

- **Services batch:** switch `DateFormat.yMMMMd` in `add_edit_service_screen.dart` to `AppDateFormat.date`, and list it as an output difference. As raised: `lib/screens/services/add_edit_service_screen.dart:541`, `DateFormat.yMMMMd()` ("March 5, 2026"), now `AppDateFormat.monthDayYearLong`: the only date format that follows the locale; every other screen uses a fixed pattern such as `dd MMM yyyy` ("05 Mar 2026"). When step 2F turns on Kiswahili this one will change shape and the others won't. Switch it to `AppDateFormat.date` so it matches the rest?
- **Login batch (done in D8):** reword the sign-in texts to the copy rules, and merge "No account found with that email address." into "Incorrect email or password." so the screen does not reveal which emails are registered. Show the owner the before/after list. "Incorrect password" merged too, as it would still confirm the email exists. The texts stay sentences, like FriendlyError's, because FriendlyError shows them as a second line. As raised:
  Sign-in error texts, now shared by the login screen and `FriendlyError` (`lib/ui/feedback/auth_error_messages.dart`), kept word for word. Against the copy rules (PHASE2_FEEDBACK_SPEC section 6) they end with a full stop and some say "Please":
  - "No account found with that email address."
  - "Incorrect password. Please try again." ("Please")
  - "Incorrect email or password."
  - "This account has been disabled. Contact your admin."
  - "Too many attempts. Please wait a moment and try again." ("Please")
  - "Network error - check your connection and try again."
  - fallback "Login failed. Please try again." ("Please"), and an unknown code shows Firebase's own message.
  Reword to the copy rules? (The login screen would change too.)

### For step 2E (done in step 2E, commits 6bb62cd to be0b55b)

- **New activity entries write `'Sales'`.** Both spellings stay readable, which also gives old `'Sale'` rows the right icon. As raised: Activity type `'Sale'` vs `'Sales'`, `lib/screens/sales/add_sale_screen.dart:793` vs `lib/providers/sale_provider.dart:441, 570`: two spellings for sale entries, both already stored. The icon/colour readers lower-case and match `'sales'`, so entries written as `'Sale'` get the default icon. Both are kept in `ActivityType` (stored strings never change). Should new entries all write `'Sales'`? Old `'Sale'` entries would still need to display. **Done (6bb62cd):** the add-sale screen writes `ActivityType.sales`; `ActivityType.canonicalKey` reads `'Sale'` as `'Sales'` for the log's summary chips, filter, icon and colour.
- **One shared activity-type icon/colour helper** replacing the four copies. As raised: Activity-type readers, `activity_log_screen.dart:348, 373`, `dashboard_screen.dart:1784, 1807`, `facility_screen.dart:1802, 1825`, `report_tabbed_content.dart:815, 840`: four copies of the same lower-case `switch` for icon and colour, including types nothing writes any more (`clients`, `settings`, `admin`). Keep as is, or one shared helper (a behaviour-neutral change, but outside 2B)? **Done (ff9e3c3):** `lib/theme/activity_type_style.dart`; services `chart4`, clients `chart6`, transactions a new `chart7` (indigo). The dashboard and facility copies had no Transactions case; those entries now get the receipt icon in indigo there too.
- **A `FacilityStatus` enum.** As raised: Facility status, `lib/screens/facilities/facility_screen.dart:1229-1240, 2444, 2606`: `'Active'` / `'active'` / `'pending'` / `'inactive'`, compared case-insensitively. A third kind of "status" (not a user or payment-submission status). Its own enum in `lib/data`? **Done (a0e8e2d):** `lib/data/facility_status.dart`, read ignoring case, missing = Active.
- **`Fields.active`.** As raised: Promotion `active` field, `lib/models/promotion.dart:78-152`, `lib/screens/platform_admin/promotions_screen.dart:228, 561`: `'active'` is a boolean field NAME on `promotions/{id}`, not a status value. Add it to `Fields`, or leave it with the model? **Done (b3825d5).**
- **A membership-history action enum, with a link test against `functions/membership.js`.** As raised: Membership-history action keys, `lib/screens/admin/manage_assistants_screen.dart:242, 1650-1656`: `'approved'`, `'rejected'`, `'deactivated'`, `'reactivated'` are the `statusHistory[].action` values written by `functions/membership.js:92-95` (`history:`). Shared with the server, so an enum here would want a link test like UserStatus has. **Done (be0b55b):** `lib/data/membership_history_action.dart` holds request and stored key; `functions/test/endpoints.test.js` compares it with `STATUS_ACTIONS` and fails if either side cannot be parsed.

### Separate task, after 2D and before 2F

- **Make client deletion soft** (write to `trash_clients`) so it gets Undo. As raised: `ClientProvider.deleteClient` (`lib/providers/client_provider.dart`) deletes the client document outright, so its message ("Client deleted") has no Undo. Everything else that can be deleted from the app (products, sales, services, transactions) goes to a `trash_*` collection first. `trash_clients` is already supported end to end: `firestore.rules` has a rule for it, `functions/index.js` purges it after 30 days, and the Trash screen lists and restores it. Nothing in the app writes to it. Moving clients to Trash would give them Undo too (a behaviour change, so not done in Phase 2).

### Decided after step 2A


- `lib/theme/app_text.dart` (`AppText` colours): **caption → `textMuted`, bodySm → `textSecondary`, all others → `textPrimary`.** Applied in 2B-0.
- `lib/screens/subscription/subscription_screen.dart:395`, `'Tigo Pesa'`: **switch the subscription form to Mixx by Yas in step 2C, as its own commit.** New requests store `'Mixx by Yas'`; `PaymentMethod.tigoPesa` stays so old records still display.
- `lib/services/usage_calculator_service.dart:75`, `'Rarely'`: **keep all four restock frequencies.**
- `lib/data/subscription_keys.dart`, `'expired'`: **removed** (nothing stores it). Done in 2B-0.
- `lib/screens/admin/manage_assistants_screen.dart:452-468`, `'owner'`, `'coadmin'`: **a small `TeamMemberKind` enum (owner, coAdmin, assistant) next to the code that computes it, in that screen, not in `lib/data`.** Done in step 2B.
- Sidebar widths `240` (platform admin) and `250` (dashboard): **keep both.**
- `lib/screens/dashboard/dashboard_screen.dart:185`, `1400 ms`: **`AppMotion.colorCycle`.** Added in 2B-0.
- `sales_screen.dart:121` (2 s) and `services_screen.dart:110` (500 ms): **keep both, named separately:** `AppTimeouts.salesSummaryRefresh` and `AppTimeouts.servicesSummaryRefresh`. Added in 2B-0.
- File-name stamps `yyyyMMdd_HHmm` / `yyyyMMdd`: **in `DataKeys`.**
- `lib/services/receipt_pdf_service.dart:27`, `0xFFE0A32E`: **keep as `PdfPalette.amber`.**
