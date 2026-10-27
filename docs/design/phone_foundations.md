# PH1 design (B): phone and tablet foundations

Batch PH1 (RUNBOOK2 ledger), a DESIGN STOP: audit only, no code changed. Companion: `docs/design/phone_shell.md` (A, the shell and the phone home). This replaces the first PH1 version (`a1d1696`). Line numbers are at `2b9ceb8`; no screen except login changed since that audit. Counts are grep over `lib/screens` (81 files, 55,446 lines), so close, not exact. Out of scope unless a shared piece is needed (already phone-ready): login, register and the wizard, the footer and info pages, the profile drawer and top bar, the notifications screen.

## 6. Current state

**Size signals.** `lib/theme/app_breakpoints.dart` has 3 tiers: `compact` 600 (used 14 times), `medium` 900 (29), `expanded` 1024 (3), plus 13 one-offs (`twoPane` 820, `formTwoColumn` 860, `stackSections` 700, `dialogFixedWidth` 700, `resultsTable` 760, `teamTable` 800, `filterRow` 640, `detailsSidePanel` 1100, `phoneNarrow` 480, `smallPhone` 420, `fiveColumnCards` 720, `registerTwoColumn` 720, `summaryCardCompact` 160). The width is read 73 times through `MediaQuery` or `screenWidth` and 49 through `LayoutBuilder`; there is no single phone, tablet, desktop signal. Raw numbers bypass the tokens at `dashboard_screen.dart:2167-2168` (`height < 600 || width < 1024`) and `:1273` (grid columns at 700 and 1200).

**What each width gets.** Below 1024: an `AppBar` with a drawer (`dashboard_screen.dart:1104`, `:1160`). 1024 and wider: the permanent sidebar (`AppSizes.sidebarExpanded` 250, collapsible to 72) and the top bar. Below 900: forms, Insights, Activity log and the bell open as full pages; 900 and wider: a 60% modal (at most 940 wide, 88% high) or a 400 px dropdown. Every module is its own full-page route with its own `AppBar`, so a module has no sidebar at any width.

**Layout Fixed Mode** (`UiSettingsProvider.layoutFixed`) only holds the sidebar open: it hides the collapse button (`:1756`) and ignores the saved collapsed state (`:2163-2164`). Below 1024 it does nothing (the drawer never collapses, `:2170`). On a phone it has no effect, and in the shell it would have none either.

**Tablet:** see A section 5.

## 7. Pattern risks

1. **Details panel beside the list at every width (highest).** 8 screens put a fixed 340-380 px panel beside an `Expanded` list when a row is tapped; at 390 px the list keeps about 9 px: `sales_screen.dart:313`, `debtors_screen.dart:275`, `clients_screen.dart:755`, `payments_screen.dart:514`, `transactions_screen.dart:202` (also services `:278`, both archives). `manage_assistants_screen.dart` already uses a bottom sheet below `detailsSidePanel`.
2. **Wide tables.** No `DataTable`; 8 lists draw 6-8 `Expanded` cells per row at every width (about 40 px a cell at 390): `sales_screen.dart:635-642`, `services_screen.dart:587-594`, `debtors_screen.dart:648-653`, `payments_screen.dart:483-489`, `transactions_screen.dart:415-421`. 4 already switch to a `_buildNarrowCard`: `stock_alerts_screen.dart:843`, `subscription_history_screen.dart:532`, `manage_assistants_screen.dart:1352`, `notifications_screen.dart:824`. Horizontal scrollers: 5 (`activity_log_screen.dart:751`, `facility_screen.dart:2041`, `services_archive_screen.dart:363`, 2 in the console).
3. **Fixed sizes over 320 px:** 39 in the screens (plus 13 named). Most sit inside a dialog or `Center` and are clamped; the risks are nested boxes: `add_sale_screen.dart:294` and `:338-339` (Browse Products 480 holding 448 x 480), `receipt_preview_screen.dart:541` and `service_receipt_preview_screen.dart:506` (400 px receipt plus 24 px padding a side), `add_client_screen.dart:809-810` and `add_transaction_screen.dart:519-520` (420 x 440 pickers).
4. **Rows of text with no Flexible or Expanded:** about 188 Rows hold Text with no `Expanded`, `Flexible`, `Wrap` or `Spacer`; most are an icon and a short label. The risky ones are labels beside values and pagination bars: `debtors_screen.dart:810`, `:1125`, `:1347`, `payments_screen.dart:564`, `receipt_preview_screen.dart:528`. Also the dashboard's subscription pill (`dashboard_screen.dart:1591`, a `Row(mainAxisSize: min)` of a long message).
5. **No scroll view:** of the 16 screens whose body is a `Column` or `Center`, only `business_profile_screen.dart:109` does not scroll. The other risk is the list screens' fixed header stack (metrics, filters, table header above an `Expanded` list: `sales_screen.dart:228-300`), which leaves little list with the keyboard open on a 740 px phone.
6. **Dialogs:** 83 `showDialog`, 20 `showGeneralDialog`, 2 `showModalBottomSheet` (`manage_assistants_screen.dart:1559`, `settings_screen.dart:495`). About 47 of the 80 `AlertDialog`/`Dialog` widgets bound their width; 1 sets `insetPadding`. 15 `showGeneralDialog` forms become a page below 900; 4 do not (2 bell dropdowns, wide only; Browse Products `add_sale_screen.dart:270`; `stockstore_screen.dart:92`). None becomes a bottom sheet.
7. **Tap targets:** 124 `IconButton`s get 48 px on a phone browser (adaptive density). 11 are shrunk outside the out-of-scope screens: `add_sale_screen.dart:328`, `:1221`, `:1281-1282`, `:1517`, `facility_screen.dart:737`, `:1764`, `:1786`, `add_edit_service_screen.dart:463`, `subscription_screen.dart:616`, `dashboard_screen.dart:1756`. `AppSizes.minTapTarget` is 40, below 48. 82 `InkWell`/`GestureDetector` taps have no minimum (rows are fine; chips and the pill's close `dashboard_screen.dart:1630`, 24 px, are not).
8. **Small text:** 896 font sizes under 14 px (f13 278, f12_5 181, f12 160, f11_5 100, f11 68, f13_5 61, f10_5 28, f9 12, f10 8) against 271 at 14 or more. Most: `report_tabbed_content.dart` 63, `facility_screen.dart` 48, `debtors_screen.dart` 34, `sales_screen.dart` 32.
9. **Keyboard:** no screen sets `resizeToAvoidBottomInset` (the default resizes, which is right). 9 `bottomNavigationBar` footers, 8 of them form buttons (add sale, add payment, add client, add product, add service, add transaction, report review, register). Only `wizard_nav_bar.dart:98` lifts itself over the keyboard. `SafeArea` is in 13 files in `lib`.
10. **Address bar and notch:** `web/index.html` has no viewport meta of its own (Flutter injects one) and no `viewport-fit=cover`, so Safari keeps the page inside the safe area in a tab; in an installed app a pinned bottom bar sits on the home indicator unless it adds `viewPadding.bottom`. `index.html:21` still says "A new Flutter project." and the iOS title is "vetbiz_pro" (`:26`): seen when the link is shared or saved to the home screen.
11. **Back gesture:** only `register_screen.dart:929` uses `PopScope`. Android back and the browser back pop the top route; the forms lose typed data without asking; back on the dashboard uncovers AppEntryPoint (A section 1).
12. **Kiswahili:** labels run 20-40% longer. Highest risk: the flex table headers (risk 2), the 2- and 4-column metric cards (`sales_screen.dart:354-359`), the dashboard titles that already truncate in English ("Completed Services (Tod...", LATER 18), and the Rows in risk 4.
13. **Hover-only:** 6 `MouseRegion`s, all decoration (`dashboard_screen.dart:149`, `HoverFab` `:283`); 10 `Tooltip`s repeat labels. No action exists only on hover.
14. **Streams and futures made in build() (the DASH-1 list).** 24 builders get a new stream or future on every build, so a rotation, a resize or any `setState` re-subscribes. Customer screens (11): `dashboard_screen.dart:1185`, `:1206` (the clock), `:2094`, `:2366`, `:2441`, `:2521`, `:2565`; `facility_screen.dart:1841`, `:2313`; `trash_screen.dart:249`; `subscription_screen.dart:654`. Console (13): `announcements_tab.dart:561`; `facility_detail_screen.dart:279`, `:307`, `:346`; `platform_admins_tab.dart:164`, `:196`; `platform_admin_home_screen.dart:311`; `promotions_screen.dart:52`; `users_tab.dart:229`, `:322`, `:339`; `subscription_requests_tab.dart:247`, `:471`. Already cached (15, safe): `main.dart:572`, `dashboard_panels.dart:176`, `activity_log_screen.dart:428`, `:702`, `manage_assistants_screen.dart:924`, `clients_screen.dart:605`, `debtors_screen.dart:955`, `:1003`, `:1101`, `facility_screen.dart:2145`, `payments_screen.dart:751`, `:1067`, `view_batches_screen.dart:416`, `report_activity_log_loader.dart:41`, `subscription_history_screen.dart:186`.

## 8. Proposed standards (for the owner to approve)

| # | Standard | Files that change |
|---|---|---|
| S1 | One signal: `AppLayout.of(context)` returns phone, tablet or desktop (phone as in A section 3, landscape phones included); new code asks it | `app_breakpoints.dart` (+`phoneLandscapeHeight`), new `lib/theme/app_layout.dart`; `dashboard_screen.dart:2167`, `:1104` |
| S2 | Tap targets at least 48 x 48 on touch; no shrinking on phones | `AppSizes.minTapTarget` 40 to 48; the 11 buttons in risk 7; a guard rule for `BoxConstraints()` on IconButtons |
| S3 | Body text at least 14 on phones; secondary at least 12; 9-11 only for badges | the list cells and panels (risk 8), screen by screen in the fix batches |
| S4 | One dialog helper `showAppSheet`: a bottom sheet (a full page for a form) on phones, a width-bound dialog above; one `showAdaptiveForm` replaces the 15 copies | new `lib/widgets/app_sheet.dart`; the 15 `show...Screen` helpers |
| S5 | One `RecordList`: table at 900 and wider, cards below; details as a full page or sheet on phones, the side panel only at `detailsSidePanel` and wider | new `lib/widgets/record_list.dart`; the 8 list screens |
| S6 | Forms: one column on phones, the action bar pinned with `SafeArea` and lifted over the keyboard (as `wizard_nav_bar`), a "discard changes?" check on back (`PopScope`) | the 8 footer forms |
| S7 | Receipts scale down to the width, never scroll sideways | both receipt previews |
| S8 | SafeArea: every pinned bottom bar and sheet adds `viewPadding.bottom`; tops come from the AppBar | the shell, the helpers, the forms |
| S9 | Streams and futures made once (`initState` or cached by key) | the 11 customer builders first, then the 13 console ones |
| S10 | Tablets: as today for the first test (A section 5); the installed app may turn (`manifest.json` `"orientation": "any"`) after the owner's answer | `web/manifest.json` |

## 9. Screen inventory

Ratings from the code, phone / tablet: A fine, B small fixes, C rework. P1 = a first customer uses it daily, P2 weekly, P3 rarely. Tab: where it lives in the shell (H Home, S Sales, K Stock, M More, + the sheet; "deep" = opened over the bar from there).

| P | File (lib/screens/) | Ph | Tb | Tab | Main reason |
|---|---|---|---|---|---|
| 1 | dashboard/dashboard_screen.dart | C | B | H | becomes the shell and phone home; raw 600/1024; 7 builders |
| 1 | dashboard/dashboard_panels.dart | B | A | H, All details | glance Wrap fine; the feed moves to All details |
| 1 | sales/sales_screen.dart | C | B | S | 8 flex columns, 380 px panel |
| 1 | sales/add_sale_screen.dart | B | A | +, deep | Browse Products 480 x 480; 5 shrunk buttons |
| 1 | sales/receipt_preview_screen.dart | B | A | deep | 400 px receipt plus padding |
| 1 | products/products_screen.dart | B | A | K | cards and a filter drawer work; needs `asTab` |
| 1 | products/add_edit_product_screen.dart | B | A | deep | `phoneNarrow` handled; long form, small text |
| 1 | products/stock_alerts_screen.dart | A | A | H strip, deep | narrow cards already |
| 1 | store/stockstore_screen.dart | B | A | K / Go to | as Products; its bell dialog `:92` |
| 1 | services/services_screen.dart | C | B | M, Go to | as Sales |
| 1 | services/add_edit_service_screen.dart | B | A | +, deep | 1 shrunk button |
| 1 | clients/clients_screen.dart | C | B | Go to | 6 columns, 340 px panel |
| 1 | clients/add_client_screen.dart | B | A | +, deep | 420 x 440 picker |
| 1 | debtors/debtors_screen.dart | C | B | Go to | 6 columns, 380 px panel, pagination Row |
| 1 | debtors/add_payment_screen.dart | B | A | +, deep | needs the debtor list fetched for the sheet |
| 1 | payments/payments_screen.dart | C | B | M | 7 columns, 340 px panel |
| 2 | transactions/transactions_screen.dart | C | B | Go to (Expenses) | 7 columns, 340 px panel |
| 2 | transactions/add_transaction_screen.dart | B | A | deep | 420 x 440 picker |
| 2 | reports/view_reports_screen.dart | B | A | Go to | narrow branch exists |
| 2 | reports/report_tabbed_content.dart | C | B | deep | 63 sizes under 14; dense tables |
| 2 | reports/report_review_screen.dart | B | A | deep | long form, pinned footer |
| 2 | reports/report_full_view_screen.dart | B | A | deep | page below 900 |
| 2 | reports/report_detail_screen.dart | A | A | deep | short wrapper |
| 2 | reports/past_reports_screen.dart | A | A | deep | plain list |
| 2 | reports/report_activity_log_loader.dart | A | A | (part) | loader, no layout |
| 2 | services/service_receipt_preview_screen.dart | B | A | deep | as the sale receipt |
| 2 | dashboard/insights_screen.dart | B | A | M | 16 small sizes; charts |
| 2 | dashboard/sales_revenue_chart.dart | B | A | All details | axis labels small |
| 2 | dashboard/notification_targets.dart | A | A | (part) | routing only |
| 2 | products/view_batches_screen.dart | B | A | deep | 3 dialogs, small text |
| 2 | products/add_batch_screen.dart | B | A | View all, deep | dialog, small text |
| 2 | products/move_expired_to_stock_dialog.dart | B | A | deep | 320 dialog, cramped at 360 |
| 2 | store/release_to_shop_flow.dart | B | A | deep | as above |
| 3 | sales/sales_archive_screen.dart | C | B | deep | as the lists |
| 3 | services/services_archive_screen.dart | C | B | deep | as the lists, plus a side scroller |
| 3 | activity/activity_log_screen.dart | B | A | M (admin) | narrow branch at 900; 320/360 dialogs |
| 3 | settings/settings_screen.dart | A | A | M | a sheet already |
| 3 | settings/ui_settings_dialog.dart | A | A | deep | bounded |
| 3 | settings/business_profile_screen.dart | B | A | deep | Column, no scroll view |
| 3 | settings/business_hours_screen.dart | B | A | M (admin) | small text |
| 3 | settings/printer_settings_screen.dart | B | A | deep | small text |
| 3 | settings/trash_screen.dart | B | A | M (admin) | a builder in build |
| 3 | settings/export_data_screen.dart | B | A | M (admin) | dialogs |
| 3 | settings/manage_account_screen.dart | B | A | deep | 7 dialogs; removes AppEntryPoint (`:168`) |
| 3 | settings/rebuild_search_index_dialog.dart | A | A | deep | bounded |
| 3 | admin/manage_assistants_screen.dart | B | A | M (admin) | cards and a sheet already; 340 box `:573` |
| 3 | admin/invite_assistant_dialog.dart | B | A | deep | one wide box, 5 small sizes |
| 3 | subscription/subscription_screen.dart | B | A | M (admin) | 1 shrunk button; a builder in build |
| 3 | subscription/subscription_history_screen.dart | A | A | deep | narrow cards already |
| 3 | facilities/facility_screen.dart | C | B | M (admin) | 2,950 lines, 9 dialogs, 340/360 panels, a side scroller |
| 3 | facilities/facility_picker_screen.dart | B | A | (sign-in) | 360 card with padding at 360 |
| 3 | facilities/select_facility_screen.dart | A | A | (sign-in) | simple |
| - | platform_admin/ (13 files: announcements_tab, facilities_directory_tab, facility_detail_screen, overview_details_screen, overview_tab, platform_admin_home_screen, platform_admins_tab, platform_settings_screen, poster_picker_field, promotions_screen, subscription_requests_tab, user_detail_screen, users_tab) | B | A | M (operator) | not for customers: LATER |

## 10. Test plan

- **Overflow matrix.** A helper `test/helpers/screen_size_matrix.dart` pumps a screen at 360x740, 390x844, 768x1024, 1024x768 and 1200x800 (`tester.view.physicalSize`, `devicePixelRatio` 1), each in Light, Dark and Kiswahili, with seeded data (long Kiswahili names, an 8-digit amount). It fails on any `tester.takeException()` (RenderFlex overflow lands there), checks `androidTapTargetGuideline` on phones, and that no text is under 12 px (walking the `RenderParagraph`s). Text scale 1.3 at 360 once per screen.
- **Buildable now** (providers take an injected Firestore; `test/helpers/fake_firestore.dart`): sales_screen, transactions_screen, stockstore_screen, stock_alerts_screen, view_batches_screen, add_batch_screen, move_expired_to_stock_dialog, add_client_screen, add_edit_service_screen, the report widgets, both receipts, settings_screen, ui_settings_dialog, past_reports_screen.
- **Need a seam first** (one optional `firestore:`/`auth:` parameter defaulting to `.instance`, like `LoginScreen.firestore`): dashboard 9/7 (`FirebaseFirestore.instance`/`FirebaseAuth.instance`), facility 13/1, debtors 7/0, payments 7/0, add_payment 9/0, add_edit_product 4/0 plus Storage, add_sale 2/0, clients 1/0, services 1/0, both archives 1/0, products 1/0, insights 3/0, activity_log 3/1, manage_assistants 4/2, subscription 3/1, export 4/0, manage_account 3/2, trash 3/0, business_profile 1/0, business_hours 1/0, add_transaction 1/0, view_reports 1/0, release_to_shop_flow 1/0. The new Home takes its figures as a value (A section 2), so it is testable without Firebase.
- **The shell:** with fake tab roots (the shell takes its four children): switching tabs keeps each tab's state (a counter and a scroll offset survive); a tab is built only on first visit; a pushed route covers the bar; the bar is gone when `viewInsets.bottom > 0`; back on Sales goes to Home, back on Home stays; the "+" sheet shows its four rows from every tab and calls the guard when locked; an assistant's More and Go to have no admin item; 360x740 landscape (740x360) still shows the shell; 768x1024 does not.

## 11. Screenshot plan for the owner

Capture each at 390x844 (phone), 768x1024 and 1024x768 (tablet); starred ones also at 360x740 and in Kiswahili. Real devices: the browser's screenshot (Android: power + volume down; iPad: top + volume up), portrait and landscape. A computer: Chrome DevTools (F12), the device toolbar (Ctrl+Shift+M), type the size, then "Capture screenshot" in the ⋮ menu.

| # | Screen | File | # | Screen | File |
|---|---|---|---|---|---|
| 1 | Dashboard * | dashboard/dashboard_screen.dart | 13 | Clients, a row tapped | clients/clients_screen.dart |
| 2 | The drawer open | dashboard/dashboard_screen.dart | 14 | Add Client | clients/add_client_screen.dart |
| 3 | Sales list * | sales/sales_screen.dart | 15 | Active Debts * | debtors/debtors_screen.dart |
| 4 | Sales, a row tapped * | sales/sales_screen.dart | 16 | Record Payment | debtors/add_payment_screen.dart |
| 5 | Add Sale, 3 items * | sales/add_sale_screen.dart | 17 | Payments | payments/payments_screen.dart |
| 6 | Browse Products | sales/add_sale_screen.dart | 18 | Transactions | transactions/transactions_screen.dart |
| 7 | Sale receipt | sales/receipt_preview_screen.dart | 19 | Add Transaction | transactions/add_transaction_screen.dart |
| 8 | Products * | products/products_screen.dart | 20 | Daily Report * | reports/view_reports_screen.dart |
| 9 | Add / Edit Product | products/add_edit_product_screen.dart | 21 | Report review | reports/report_review_screen.dart |
| 10 | Stock Store | store/stockstore_screen.dart | 22 | Stock alerts | products/stock_alerts_screen.dart |
| 11 | Services | services/services_screen.dart | 23 | Settings | settings/settings_screen.dart |
| 12 | Add Service | services/add_edit_service_screen.dart | 24 | Facilities | facilities/facility_screen.dart |

Save them as `D:\VetBiz-Pro-screens\phone-before\<size>\<nn>-<name>.png` (outside the repo).

## 12. Fix batches

Each is a HARD STOP with before and after screenshots and the owner's phone and tablet check; commits of 300 lines or fewer, tests first. Sessions are rough.

| Batch | Content | Sessions |
|---|---|---|
| PH2 foundations | S1 `AppLayout`; S4 `showAppSheet` and `showAdaptiveForm` (the 15 copies); S5 `RecordList`; S7 receipts fit; S2 guard rule and `minTapTarget` 48; S8; the size-matrix helper; seams for the money screens | 2 |
| PH3 the shell | `PhoneShell` (lazy tabs, bar, "+" sheet, back), `asTab` on Sales and Products, More page, `PhoneShellMetrics`, ARB drafts; tablets and computers unchanged | 2 |
| PH4 phone home | figures as one value (period streams, debts, products), Today card, Quick access, Go to, Needs attention, All details list (with chart and feed if approved), `listenToProducts` at activation; the 7 dashboard builders (S9) | 2 |
| PH5 money lists | sales, services, clients, debtors, payments, transactions onto `RecordList`; details as a page or sheet; 14 px cells | 3 |
| PH6 money forms | Add Sale (Browse Products as a sheet, the 5 buttons), Record Payment, Add Client and Add Transaction pickers, the expired and release dialogs, S6 | 2 |
| PH7 products, stock, reports, receipts | products, stock store, batches, reports and `report_tabbed_content`, receipts, stock alerts | 2 |
| PH8 the rest | archives, activity log, settings pages, Team Members, facilities, subscription; the 4 other customer builders | 2 |
| PH9 tablet pass | the owner's answer to A section 5 and S10; landscape tablets; the console builders if wanted | 1 |

**Questions only the owner can answer** (with A's six):
1. Minimum text 14 px on phones (S3), knowing the tables will hold fewer columns?
2. Row details on a phone: a full page (more room, recommended) or a bottom sheet (keeps the list)?
3. May the installed app turn to landscape (`manifest.json`)?
4. The web page's description and iOS title (risk 10): "VetBiz Pro" and a one-line description, before the first link is shared?
5. Order: PH2 to PH4 before any list (recommended: the first thing a customer sees is the home), or the money lists first?

OWNER DECISION: PENDING
