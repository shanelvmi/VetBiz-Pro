# PH1 design: phone and tablet foundations

Batch PH1 (RUNBOOK2 ledger), a DESIGN STOP: audit only, no code changed. The first customers test on one phone, one tablet and one computer, through the web link. Out of scope unless a shared piece is needed (already phone-ready): login, register and the wizard, the footer and info pages, the profile drawer and top bar, the notifications screen. Line numbers are at `17eeeaa`. Counts are from grep over `lib/` (81 files in `lib/screens`, 55,400 lines), so treat them as close, not exact.

## 1. Current state

**How the app decides the size.** `lib/theme/app_breakpoints.dart` has 3 tiers: `compact` 600 (used 14 times), `medium` 900 (29), `expanded` 1024 (3), plus 13 one-offs (`twoPane` 820, `formTwoColumn` 860, `stackSections` 700, `dialogFixedWidth` 700, `resultsTable` 760, `teamTable` 800, `filterRow` 640, `detailsSidePanel` 1100, `phoneNarrow` 480, `smallPhone` 420, `fiveColumnCards` 720, `registerTwoColumn` 720, `summaryCardCompact` 160). Screens read the width 51 times through `MediaQuery` and 49 times through `LayoutBuilder`, so there is no single "phone, tablet, desktop" signal. Two raw numbers bypass the tokens: `dashboard_screen.dart:2167-2168` (`height < 600 || width < 1024`).

**The shell.** `dashboard_screen.dart:1104`: at 1024 px and wider there is a permanent sidebar (`AppSizes.sidebarExpanded` 250, collapsible to 72) and the custom top bar. Below 1024 there is an `AppBar` with a slide-in `Drawer` (`:1160`). Every module (Sales, Products and the rest) is a full-page `MaterialPageRoute` with its own `Scaffold` and `AppBar` (58 pushes), so a module page has no sidebar at any width.

**Layout Fixed Mode** (`UiSettingsProvider.layoutFixed`) only holds the sidebar open: it hides the collapse button (`:1753`) and ignores the saved collapsed state (`:2163-2164`). Below 1024 it does nothing, because the drawer never collapses (`:2170`).

**Form modals.** 15 forms open as a centred modal at 900 px and wider: 60% of the width (72% for the two report views), at most 940, 88% of the height (`add_sale_screen.dart:1817-1823`, `add_payment_screen.dart:598-624`). Below 900 they are full pages. Each screen copies this helper.

**What a tablet gets today:**

| | 768 x 1024 (portrait) | 1024 x 768 (landscape) |
|---|---|---|
| Shell | AppBar and drawer | permanent sidebar and top bar |
| Dashboard summary grid | 3 columns (`:1271`, wider than 700) | 3 columns (`gridWidth` is about 774) |
| Form modals (Add Sale, Record Payment and the rest) | full page | modal, about 614 px wide |
| Bell | full Notifications page | 400 px dropdown |
| Lists (Sales, Services, Clients, Debtors, Payments, Transactions, archives) | the 7- or 8-column flex "table"; tapping a row opens a 340-380 px panel beside it, leaving the list about 388 px | the same table; with the panel open, about 644 px for 8 columns |
| Products and Stock Store filters | a drawer (below 900) | a side panel |

The installed web app (`web/manifest.json:9`) is locked to `"orientation": "portrait-primary"`, so an installed tablet cannot turn to landscape. A browser tab is not locked.

## 2. Pattern risks

1. **Details panels beside the list at every width (highest risk).** 8 screens put a fixed `SizedBox(width: 340-380)` beside an `Expanded` list as soon as a row is tapped. On a 390 px phone the list keeps about 9 px: `sales_screen.dart:313`, `debtors_screen.dart:275`, `clients_screen.dart:755`, `transactions_screen.dart:202`, `payments_screen.dart:514` (also `services_screen.dart:278`, `sales_archive_screen.dart:291`, `services_archive_screen.dart:294`). `manage_assistants_screen.dart` already uses a bottom sheet below `detailsSidePanel` (1100).
2. **Wide flex "tables" with no card fallback.** There is no `DataTable`. Instead 8 lists draw a header and rows of 6-8 `Expanded` cells at every width: `sales_screen.dart:635-642`, `services_screen.dart:587-594`, `debtors_screen.dart:648-653`, `payments_screen.dart:483-489`, `transactions_screen.dart:415-421` (also clients, both archives). At 390 px a cell is about 40 px. 4 screens already switch to `_buildNarrowCard` below `resultsTable` or `teamTable`: `stock_alerts_screen.dart:843`, `subscription_history_screen.dart:532`, `manage_assistants_screen.dart:1352`, `notifications_screen.dart:824`. Horizontal scrollers (5): `activity_log_screen.dart:751`, `facility_screen.dart:2041`, `services_archive_screen.dart:363`, and 2 in the platform console.
3. **Fixed sizes over 320 px.** 33 widths and 5 heights are written in widgets, plus 13 named ones. Inside a dialog or `Center` most are clamped by the parent, so the real risks are nested fixed sizes and Row children: `add_sale_screen.dart:294/338` (Browse Products, 480, holding a 448 x 480 box), `receipt_preview_screen.dart:541` and `service_receipt_preview_screen.dart:506` (a 400 px receipt with 24 px padding on each side), `add_client_screen.dart:809` and `add_transaction_screen.dart:519` (420 x 440 pickers), `dashboard_screen.dart:1660` and `products_screen.dart:128` (400 px bell panels, wide only).
4. **Rows of text with no Flexible or Expanded.** A rough scan finds 188 Rows that hold Text with no Expanded, Flexible, Wrap or Spacer inside. Most are an icon plus a short label; the risky ones are labels beside values and pagination bars: `debtors_screen.dart:810` (rows per page), `:1125`, `:1347`, `payments_screen.dart:564`, `receipt_preview_screen.dart:528`. Most per file: add_sale, payments and facility_screen (9 each).
5. **Pages built from a Column with no scroll view.** These overflow when the keyboard opens or on a short phone: `business_profile_screen.dart:109-114` (Center, then a Column), and the list screens' fixed header stack (metrics grid, filters and the table header above an `Expanded` list: `sales_screen.dart:228-300`). With the keyboard open on a 740 px phone the list gets very little room.
6. **Dialogs.** There are 94 `showDialog`, 20 `showGeneralDialog` and 2 `showModalBottomSheet` calls (`manage_assistants_screen.dart:1559`, `settings_screen.dart:495`). 50 of the 89 `AlertDialog` or `Dialog` widgets have a width bound; 1 sets `insetPadding`. 15 `showGeneralDialog` forms switch to a page below 900. 4 do not: the two bell dropdowns (wide only), `add_sale_screen.dart:270` (Browse Products) and `stockstore_screen.dart:92` (its bell). None becomes a bottom sheet on a phone.
7. **Tap targets.** 128 `IconButton`s get 48 px by default on a phone browser (adaptive density). 21 are shrunk with `BoxConstraints()`, `shrinkWrap` or `compact`: `add_sale_screen.dart:328, 1221, 1281, 1282, 1517`, `facility_screen.dart:737`, `dashboard_screen.dart:1753`. There are also 82 `InkWell` or `GestureDetector` taps with no minimum size (row taps are fine; small chips and icon taps are not).
8. **Small text.** In `lib/screens`, 896 font sizes are under 14 px (f13 278, f12_5 181, f12 160, f11_5 100, f11 68, f13_5 61, f10_5 28, f9 12, f10 8) and 271 are 14 px or more. Most per file: `report_tabbed_content.dart` (63), `facility_screen.dart` (48), `debtors_screen.dart` (34), `sales_screen.dart` (32). Table cells and secondary lines at 11-12 px are hard to read on a phone.
9. **Keyboard and safe areas.** No screen sets `resizeToAvoidBottomInset` (the default resizes, which is right). 8 forms pin their buttons in `bottomNavigationBar` with a `SafeArea` (add sale, add payment, add client, add product, add service, add transaction, report review, register). Only `wizard_nav_bar.dart:98` lifts itself over the keyboard. `SafeArea` is used in 13 files; the list pages rely on `AppBar`.
10. **Browser bar and notch.** Flutter web sets the viewport itself; `web/index.html` has no `viewport-fit=cover`, so Safari keeps the page inside the safe area in a tab. Risks: content pinned to the bottom under the iOS home bar in an installed app, and the dynamic address bar resizing the page (the pinned footers move with it, which is fine).
11. **Back gesture and dead ends.** Only `register_screen.dart` uses `PopScope`. Android back and the browser back pop the top route, a modal or a dialog. The forms (Add Sale, Record Payment, Add Product and the rest) lose typed data on back without asking. Back from the dashboard leaves the app.
12. **Kiswahili.** Labels run about 20-40% longer. The highest risk is the fixed-flex table headers (risk 2), the 2- and 4-column metric cards (`sales_screen.dart:354-359`), and the Rows in risk 4.
13. **Hover-only.** There are 9 `MouseRegion`s, all decoration (sidebar hover `dashboard_screen.dart:149`, `HoverFab` `:283`, `HoverLink`, `HoverElevateCard` in the console). 10 `Tooltip`s duplicate labels. I found no action that exists only on hover.
14. **Streams and futures created in build() (the DASH-1 list).** 24 builders pass a call. 9 are cached and safe: `main.dart:570`, `clients_screen.dart:605`, `dashboard_screen.dart:1714`, `debtors_screen.dart:955, 1003, 1101`, `facility_screen.dart:2145`, `payments_screen.dart:751, 1067`. 15 are made on every build (they re-subscribe or refetch, and cost reads on each rotation or resize): `dashboard_screen.dart:1185, 1206, 2094, 2366, 2441, 2521, 2565`, `facility_screen.dart:2313`, `platform_admin/facility_detail_screen.dart:279, 307`, `platform_admins_tab.dart:164, 196`, `platform_admin_home_screen.dart:311`, `promotions_screen.dart:52`, `users_tab.dart:322`. A phone rotation or a tablet split-screen rebuilds them all.

## 3. Proposed standards (for the owner to approve)

| # | Standard | What changes |
|---|---|---|
| S1 | One size signal: `AppLayout.of(context)` returns phone (below 600), tablet (600-1023) or desktop (1024 and wider), from `AppBreakpoints`; new code asks it, not a raw width | `lib/theme/app_breakpoints.dart`, a new `lib/theme/app_layout.dart`; `dashboard_screen.dart:2167` uses it |
| S2 | Tap targets at least 48 x 48 on touch; no `BoxConstraints()` shrinking on phones | the 21 shrunk buttons (risk 7); a guard rule against `constraints: const BoxConstraints()` |
| S3 | Body text at least 14 px on phones (f14), secondary at least 12 px; 9-11 px only for badges | the list screens' cells and detail panels (risk 8), screen by screen |
| S4 | Dialogs: one helper, `showAppSheet`: a bottom sheet (or a full page for a form) below 600, a width-bound dialog above | a new `lib/widgets/app_sheet.dart`; the 15 copied modal helpers become one `showAdaptiveForm` |
| S5 | Lists: one `RecordList` widget: a table at 900 and wider, cards below; row details in a bottom sheet or a full page below `detailsSidePanel`, the side panel only above it | a new `lib/widgets/record_list.dart`; the 8 list screens (risks 1 and 2) |
| S6 | Forms: one column below 860 (as today), the action bar pinned with `SafeArea` and lifted over the keyboard (as `wizard_nav_bar`), and a "discard changes?" check on back (`PopScope`) | the 8 pinned-footer forms |
| S7 | Fixed-width documents (receipts) scale down to fit (`FittedBox` within the width) and never scroll sideways | both receipt previews |
| S8 | SafeArea: every pinned bottom bar and sheet; tops come from `AppBar` | the forms, the new helpers |
| S9 | Streams and futures are made once (in `initState` or cached by key), never in `build()` | the 15 in risk 14 |
| S10 | The tablet. Portrait (768): the drawer as today, lists as cards with 2 columns, forms as full pages, details as a bottom sheet. Landscape (1024 and wider): the sidebar, the table, the details panel only at 1100 and wider (else a sheet), forms as the modal. The installed app allows landscape (`manifest.json` `"orientation": "any"`) | the S5 widget, `web/manifest.json` |

## 4. Screen inventory

Ratings are from the code, phone / tablet: A fine, B small fixes, C needs rework. P is the priority (1 = a first customer uses it daily). The out-of-scope screens are skipped. The platform console (`lib/screens/platform_admin/`, 13 files) is not for customers: B/A, LATER.

| P | Screen (lib/screens/) | Phone | Tablet | Main reason |
|---|---|---|---|---|
| 1 | sales/sales_screen.dart | C | B | 8-column flex table, 380 px panel beside the list |
| 1 | sales/add_sale_screen.dart | B | A | compact list exists; Browse Products is 480 x 480 with a 448 box; 5 shrunk buttons |
| 1 | sales/receipt_preview_screen.dart | B | A | 400 px receipt with 48 px padding |
| 1 | products/products_screen.dart | B | A | cards and a drawer filter work; 400 px bell panel (wide) |
| 1 | products/add_edit_product_screen.dart | B | A | `phoneNarrow` handled; long form, small text |
| 1 | store/stockstore_screen.dart | B | A | as Products |
| 1 | products/stock_alerts_screen.dart | A | A | narrow cards already |
| 1 | services/services_screen.dart | C | B | as Sales |
| 1 | services/add_edit_service_screen.dart | B | A | 1 shrunk button; two-column summary below 860 stacks |
| 1 | clients/clients_screen.dart | C | B | 6-column table, 340 px panel |
| 1 | clients/add_client_screen.dart | B | A | 420 x 440 picker dialog |
| 1 | debtors/debtors_screen.dart | C | B | 6-column table, 380 px panel, pagination Row |
| 1 | debtors/add_payment_screen.dart | B | A | page below 900; check keyboard and footer |
| 1 | payments/payments_screen.dart | C | B | 7-column table, 340 px panel |
| 2 | transactions/transactions_screen.dart | C | B | 7-column table, 340 px panel |
| 2 | transactions/add_transaction_screen.dart | B | A | 420 x 440 picker |
| 2 | reports/view_reports_screen.dart | B | A | narrow branch exists (`formTwoColumn`); 320 px side column wide only |
| 2 | reports/report_tabbed_content.dart | C | B | 63 text sizes under 14 px; dense report tables |
| 2 | reports/report_review_screen.dart | B | A | long form with a pinned footer |
| 2 | reports/past_reports_screen.dart | A | A | a plain list |
| 2 | reports/report_full_view_screen.dart, report_detail_screen.dart | B | A | the page below 900; content as above |
| 2 | dashboard/dashboard_screen.dart | B | B | drawer and grid work; raw 600 and 1024; 7 streams in build |
| 2 | dashboard/insights_screen.dart, sales_revenue_chart.dart, dashboard_panels.dart | B | A | chart labels at small sizes |
| 2 | services/service_receipt_preview_screen.dart | B | A | as the sale receipt |
| 3 | sales/sales_archive_screen.dart, services/services_archive_screen.dart | C | B | as the lists, plus a horizontal scroller |
| 3 | products/view_batches_screen.dart, add_batch_screen.dart | B | A | dialogs, small text |
| 3 | products/move_expired_to_stock_dialog.dart, store/release_to_shop_flow.dart | B | A | fixed 320 dialogs (clamped, but cramped at 360) |
| 3 | activity/activity_log_screen.dart | B | A | narrow branch at 900; 320 and 360 dialogs |
| 3 | settings/settings_screen.dart, ui_settings_dialog.dart | A | A | a bottom sheet is already used |
| 3 | settings/business_profile_screen.dart | B | A | Column with no scroll view |
| 3 | settings/business_hours_screen.dart, printer_settings_screen.dart, trash_screen.dart | B | A | small text, row actions |
| 3 | settings/export_data_screen.dart, manage_account_screen.dart, rebuild_search_index_dialog.dart | B | A | dialogs (7 in manage_account) |
| 3 | admin/manage_assistants_screen.dart, invite_assistant_dialog.dart | B | A | narrow cards and a sheet already; 340 box at `:573` |
| 3 | subscription/subscription_screen.dart | B | A | modal and page; 1 shrunk button |
| 3 | subscription/subscription_history_screen.dart | A | A | narrow cards already |
| 3 | facilities/facility_screen.dart | C | B | 2,950 lines, 9 dialogs, 340/360 panels, horizontal scroller, 48 small sizes |
| 3 | facilities/facility_picker_screen.dart, select_facility_screen.dart | B | A | 360 px ideal card at 360 px with padding |

## 5. Test plan

- **Detection.** One harness, `test/helpers/screen_size_matrix.dart`, pumps a screen at 360x740, 390x844, 768x1024, 1024x768 and 1200x800 (`tester.view.physicalSize`, `devicePixelRatio` 1), in Light, Dark and Kiswahili. It fails on any `tester.takeException()` (RenderFlex overflow is reported there), and also checks that no visible tap target is under 48 px (`meetsGuideline(androidTapTargetGuideline)`) and that no text is under 12 px (walk the `RenderParagraph`s). It runs the same seeded data each time, including long Kiswahili names and an 8-digit amount.
- **Buildable today** (providers accept an injected Firestore: `SaleProvider`, `ServiceProvider`, `TransactionProvider`, `ProductProvider`, `ClientProvider`, `DebtProvider`, `PaymentProvider`, `FacilityProvider`, `SubscriptionProvider`, `UserRoleProvider`; no `FirebaseFirestore.instance` in the screen): sales_screen, transactions_screen, stockstore_screen, stock_alerts_screen, view_batches_screen, add_batch_screen, move_expired_to_stock_dialog, add_client_screen, add_edit_service_screen, the 4 report widgets, both receipt previews, settings_screen, ui_settings_dialog, past_reports_screen.
- **Need a `firestore:` (and `auth:`) seam first**, like `LoginScreen.firestore`. Count of `FirebaseFirestore.instance` / `FirebaseAuth.instance` in the screen: dashboard_screen 9/7, facility_screen 13/1, debtors_screen 7/0, payments_screen 7/0, add_payment_screen 9/0, add_edit_product_screen 4/0 plus Storage, add_sale_screen 2/0, clients_screen 1/0, services_screen 1/0, both archives 1/0, products_screen 1/0, insights_screen 3/0, activity_log_screen 3/1, manage_assistants_screen 4/2, subscription_screen 3/1, export_data 4/0, manage_account 3/2, trash 3/0, business_profile 1/0 plus Storage, business_hours 1/0, add_transaction 1/0, view_reports 1/0, release_to_shop_flow 1/0. Each seam is one optional constructor parameter, defaulting to `.instance`, a test-only change.

## 6. Screenshot plan for the owner

Capture each at 390x844 (phone), 768x1024 and 1024x768 (tablet); the starred ones also at 360x740. On the real devices, use the browser's screenshot (Android: power + volume down; iPad: top + volume up), in portrait and landscape. On a computer, use Chrome DevTools (F12), the device toolbar (Ctrl+Shift+M), type the size, then "Capture screenshot" from the ⋮ menu.

| # | Screen | File | | # | Screen | File |
|---|---|---|---|---|---|---|
| 1 | Dashboard * | dashboard/dashboard_screen.dart | | 13 | Clients, a row tapped | clients/clients_screen.dart |
| 2 | The drawer open | dashboard/dashboard_screen.dart | | 14 | Add Client | clients/add_client_screen.dart |
| 3 | Sales list * | sales/sales_screen.dart | | 15 | Active Debts * | debtors/debtors_screen.dart |
| 4 | Sales, a row tapped * | sales/sales_screen.dart | | 16 | Record Payment | debtors/add_payment_screen.dart |
| 5 | Add Sale with 3 items * | sales/add_sale_screen.dart | | 17 | Payments | payments/payments_screen.dart |
| 6 | Browse Products | sales/add_sale_screen.dart | | 18 | Transactions | transactions/transactions_screen.dart |
| 7 | Sale receipt | sales/receipt_preview_screen.dart | | 19 | Add Transaction | transactions/add_transaction_screen.dart |
| 8 | Products * | products/products_screen.dart | | 20 | Daily Report * | reports/view_reports_screen.dart |
| 9 | Add / Edit Product | products/add_edit_product_screen.dart | | 21 | Report review | reports/report_review_screen.dart |
| 10 | Stock Store | store/stockstore_screen.dart | | 22 | Settings | settings/settings_screen.dart |
| 11 | Services | services/services_screen.dart | | 23 | Team Members | admin/manage_assistants_screen.dart |
| 12 | Add Service | services/add_edit_service_screen.dart | | 24 | Facilities | facilities/facility_screen.dart |

Save them as `D:\VetBiz-Pro-screens\phone-before\<size>\<nn>-<name>.png` (outside the repo).

## 7. Fix batches (each a HARD STOP with before and after screenshots; commits of 300 lines or fewer, tests first)

| Batch | Content | Size |
|---|---|---|
| PH2 foundations | S1 `AppLayout`; S4 `showAppSheet` and `showAdaptiveForm` (the 15 copies replaced); S5 `RecordList` (table or cards, details as panel or sheet); S7 receipt fit; S2 guard rule; the size-matrix harness; seams for the money screens | about 8 commits; no screen redesigned |
| PH3 money lists | sales, services, clients, debtors, payments, transactions onto `RecordList`; row details as a sheet on phones; 14 px cells | about 12 commits, 2 per screen |
| PH4 money forms and dialogs | Add Sale (Browse Products as a sheet, the 5 buttons), Record Payment, Add Client and Add Transaction pickers, move expired and release to Stock Store dialogs, discard check on back (S6) | about 8 |
| PH5 products, stock, reports, receipts | products, stock store, batches, the reports and `report_tabbed_content` text, both receipts | about 8 |
| PH6 the rest | dashboard (S1, the streams), archives, activity log, settings pages, Team Members, facilities, subscription | about 10 |
| PH7 streams | S9 for the 15 builders (console last) | about 4 |

**Questions only the owner can answer:**
1. Phones: keep the drawer (as today) or add a bottom navigation bar (Dashboard, Sales, Products, Debts, More)?
2. Tablet portrait and landscape: approve S10, or keep the desktop layout on landscape tablets?
3. On a tablet, lists as a table or as cards (S10 proposes cards in portrait, the table in landscape)?
4. Row details on a phone: a bottom sheet (quick, keeps the list) or a full page (more room)?
5. May the installed app turn to landscape (`manifest.json`)?
6. Minimum text: 14 px body on phones (S3), knowing the tables will hold fewer columns?

OWNER DECISION: PENDING
