# LAYOUT DEFECTS (found and NOT fixed in the polish batches)

The owner's list of layout problems the POL batches found but did not fix
(they change only what is drawn), so none is lost before the page-frame
restructure. Each entry: screen, size, how far, the widget, the test that
shows it, and any skip. Add to it; strike an entry only in the commit that
fixes it.

**How these were measured (POL5 Step 0).** Each screen pumped with the POL4
seed (helpers/pol4_checks.dart, seedPol4Archives) at 768x1024, 1024x768 and
1200x800, text 1.0 and 1.3, the list first and then a row's details panel,
every error collected one by one (FlutterError.onError) with the widget's
file and line. A widget that overflows is reported once, so an empty
"details" cell means the list's overflow is still there, not that it went.

**Why some looked intermittent (POL4 was wrong).** flutter_test prints an
error only when a test raises more than one; a single error is held
silently, and the fingerprint tests take it into the fingerprint string
(`_errors(tester)`, then `treeFingerprint`). In POL4 commit 2 the Services
archive raised two (the page bar and the Payment information line); commit 4
fixed the second, so the page bar's became the only one and stopped being
printed. It never went away and it is not run-order dependent: it happens
every run, at every wide size, and it is recorded inside the current
pol4-services-archive fingerprints. The same holds for every entry below
that a fingerprint covers.

## Sales and Services (group 3, found in POL4)

| # | Screen | Size | Overflow | Widget | Shown by | Skip |
|---|---|---|---|---|---|---|
| 1 | ~~Sales list~~ FIXED LAY6c (ToolbarLayout) | 768x1024 | 103 px right (310 at text 1.3) | the filter toolbar, sales_screen.dart `_buildFiltersToolbar` Row (:415) | pol4_sales_services_test (knownWideOverflowOnly), ph5a_wide_unchanged fingerprints | none |
| 2 | ~~Sales list, details open~~ FIXED LAY6c (ListPageBar) | 768x1024; 1024x768 at text 1.3 | 217 px right (345 at 1.3); 89 px at 1024 x1.3 | the page bar, `_buildPaginationBar` Row (:754) | the same | none |
| 3 | ~~Sales list, details open~~ FIXED LAY6c (ToolbarLayout) | 1024x768 / 1200x800 | 228 / 52 px right (259 at 1200 x1.3; at 1024 x1.3, 54 on the list alone) | the filter toolbar (:415): the details panel (380 px) narrows it. POL4's ledger said "the page bar" here: wrong | the same | none |
| 4 | ~~Sales details panel~~ FIXED LAY6c (_totalsRow label Flexible at every width) | every wide size, text 1.3 | 44 px right | `_totalsRow` (:1146): the label is flexible on phones only | pol4_archives_receipts_test (text 1.3) | none |
| 5 | ~~Services list~~ FIXED LAY6d (ToolbarLayout) | 768x1024 | 129 px right (343 at 1.3) | the filter toolbar (services_screen.dart :454) | pol4_sales_services_test, ph5a_wide_unchanged | none |
| 6 | ~~Services list, details open~~ FIXED LAY6d (ListPageBar, ToolbarLayout) | 768 / 1024 / 1200 | 217 (page bar :714) / 254 / 78 (toolbar :454); at 1.3: page bar 345 / 89 (768, 1024), toolbar 292 (1200) and 87 on the 1024 list alone | page bar and toolbar | the same | none |
| 7 | ~~Services details panel~~ FIXED LAY6d (title Expanded; Payment information and totals labels Flexible at every width) | every wide size, text 1.3 | 24 (title row :975), 26 (Payment information row :1009), 55 and 3.8 (`_totalsRow` :1086) px right | rows whose label is flexible on phones only | pol4_archives_receipts_test | none |
| 8 | ~~Sales archive~~ FIXED LAY6c (ListPageBar with the archive wording) | 768x1024 (list), 1024x768 (details open) | 42 / 167 px right (232 / 357 at 1.3; 181 at 1200 x1.3) | the page bar, sales_archive_screen.dart :521 | pol4_fingerprints (pol4-sales-archive-*, inside the fingerprint) | none |
| 9 | ~~Sales archive, details, text 1.3~~ FIXED LAY6c (slide-over at 768: full-width table; totals label Flexible) | 768x1024 | 11 px bottom (table :401) and 44 px right (`_totalsRow` :700) | table header, totals rows | the measurement above (no test runs 768 x1.3 here) | none |
| 10 | ~~Services archive~~ FIXED LAY6d (ListPageBar with the archive wording) | 768 (list) / 1024 / 1200 (details open) | 80 / 205 / 29 px right (281 / 230 at 1.3; 25 at 1024 x1.3) | the page bar, services_archive_screen.dart :557 | pol4_fingerprints (pol4-services-archive-*, inside the fingerprint), pol4_sales_services_test | none |
| 11 | ~~Services archive details, text 1.3~~ FIXED LAY6d (title Expanded, Payment information and totals labels Flexible, header capped so the table keeps room) | every wide size | 24 (:630), 26 (:664), 55 and 17 (:715) px right; at 768 also 71 px bottom (table :422) | title row, Payment information row, totals rows, table | the measurement above | none |
| 12 | Sales archive, Services archive | 360x640 (phone) | about 450 and 488 px right | no phone layout at all: the wide table is drawn | pol4_archives_receipts_test | 4 cases skipped by name ("no phone layout: the wide table overflows at 360 (450 and 488 px); for a later batch") |

Entries 1 to 11 are the same before POL4 (checked on f0167c7 for Sales) and
after it. The tests let them through only as RenderFlex overflows
(knownWideOverflowOnly), never another error.

## Products (group 4, POL5)

None found. Products, Stock Store and Stock Alerts were pumped at 360x640,
390x844, 768x1024, 1024x768 and 1200x800, text 1.0 and 1.3 (reduced motion),
every error collected one by one: no overflow (pol5_products_test.dart).
~~At 1024 Stock Alerts' kind FilterRow scrolls sideways (Expired is off the
edge until scrolled).~~ Fixed in POL6 Step 0: the kinds are by severity and
the row wraps (FilterRow `wrap`); measured before: 86 px too wide at 1024
and 342 at 768 (200 and 456 in Kiswahili). pol6_alerts_kind_row_test.dart.

## Clients, Debtors, Payments and Transactions (group 5, found in POL6)

Measured as above (POL6 seed, helpers/ph5b_seed.dart), errors one by one.
Each was there before POL6 at text 1.0 (the same before and after each
commit; checked by running the code before the commit); POL6 removed the
cards' own overflows (Payments: bottom 11-45, right 8.8-105 px;
Transactions: bottom 16 and 42 px; Clients: the type and status chips, 26,
33, 47 px). At text 1.3 none is in a widget POL6 changed. A widget that
overflows is reported once: Transactions' time cell at 768 shows its 55 px
with the details open only because the list no longer overflows first.

| # | Screen | Size | Overflow (text 1.0; at 1.3) | Widget | Shown by | Skip |
|---|---|---|---|---|---|---|
| 13 | ~~Clients, details open~~ FIXED LAY6a (ListPageBar wraps) | 768 / 1024 | 177 px right; at 1.3 305 / 49 | the page bar, clients_screen.dart `_buildPaginationBar` Row | ph5b fingerprints (inside), pol6_money_lists_test | none |
| 14 | ~~Clients, details open, text 1.3~~ FIXED LAY6a (ToolbarLayout; the title wraps) | 768 / every wide size | 60 (toolbar Row :218); 45 (details title row :484) | toolbar, details title | pol6_money_lists_test (1.3) | none |
| 15 | ~~Debtors~~ FIXED LAY6a (ToolbarLayout, the action cell wraps, ListPageBar, totals label Flexible, title wraps) | 768 list; details open at every wide size | toolbar 57 / 182 / 5.6 px (244 / 369 / 193 at 1.3); the row's action cell 23 / 31 / 50 (89 at 1.3); page bar 217 (345 / 89 at 1.3); a details row 23 (9.5 / 78 / 130 at 1.3), the details title 2.7 at 1.3 | debtors_screen.dart toolbar :523, row actions :761, page bar :814, `_totalsRow` :1507, title :1054 | ph5b fingerprints (inside), pol6_money_lists_test | none |
| 16 | ~~Payments~~ FIXED LAY6b (ToolbarLayout; details title Expanded, date row Flexible beside the list; time cell Flexible) | 768 / 1024 / 1200 | toolbar 204 px (381 / 125 / 290 at 1.3); a details row 1.2 (32 / 49 / 14 at 1.3); at 1.3 the details title 66, the date row 65, a row cell 116 | payments_screen.dart toolbar :782, row :1206, title :659, date :678, :1170 | the same | none |
| 17 | ~~Transactions~~ FIXED LAY6b (ToolbarLayout; time cell Flexible; details title Expanded, date row Flexible beside the list; app bar title one line with ellipsis, the date range button gives way) | details open, every wide size | the time cell 4.2 (1024), 55 (768); toolbar 77; a day header 45 and 6.8; a details row 59 (150 at 1.3); at 1.3 the app bar title 104, details date row 65, toolbar 197, day header 99 | transactions_screen.dart time cell :488, toolbar :323, day header :448, details :678 / :699, app bar :247 | the same | none |
| 18 | Home, All details (phone): the Sales revenue chart | 390 and 360, text 1.3 | the header row 383 / 413 px; the totals row 197 / 227 (both older than POL7). The legend row overflowed too (402 / 432); POL7 made it a Wrap, so it no longer does | sales_revenue_chart.dart header Row :85, totals Row :126 | pol7_sales_chart_test (phone) | none |
| 19 | Report Summary tab (wide): the Debt and Expenses preview cards | 768 | the card header row 88 px and 42 px (older than POL7; in the ph7b fingerprints). At text 1.3 the same row also overflows in View Reports at 1024 and 1200 (3 times): before POL7 the taller tiles left the preview cards no room, so it was not laid out; the old status-row overflow there is gone (pol7_reports_matrix_test pins the counts) | report_tabbed_content.dart `_previewCardShell` Row :319 | ph7b_wide_unchanged_test | none |

## The wide shell (found in LAY2, deferred to LAY2b)

Not overflows: shell behaviour noted while LAY2 moved the sidebar onto the
registry. Line numbers at LAY2 (8).

| # | Where | What | Why it waits |
|---|---|---|---|
| 20 | dashboard_screen.dart `_buildDrawerContent` facility tagline | The `StreamBuilder` gets a new `snapshots()` stream on every build (the "resets to waiting" pitfall in CLAUDE.md); harmless today, a flicker risk when the shell rebuilds more often (LAY4) | cache it once (LAY2b), not mixed into a block that must only move the planned pixels |
| 21 | dashboard_screen.dart `platformAdminItem` | The `FutureBuilder` calls `_isPlatformAdmin()` on every build, so the amber item can blink out and back while it answers | the same (LAY2b) |
| 22 | dashboard_screen.dart `isSmallScreen` | A window 1024 wide or more but under 600 high shows the expanded sidebar, which never collapses there, while the top bar still shows the collapse button (it does nothing) | owner: rail at that height, or hide the button (LAY2b) |

## The wide shell (found in LAY4c, for LAY7)

| # | Where | What | Why it waits |
|---|---|---|---|
| 23 | ~~Settings side panel (content 900 or wider) embedding `SubscriptionScreen`~~ | The embedded pane keeps its own AppBar with the implied back arrow (`automaticallyImplyLeading: !widget.isModal`); tapping it closes Settings (as before LAY4, now back to Home in the shell). Pinned by lay4_shell_screens_test (only that one arrow allowed) | FIXED LAY7: SettingsPaneScope; no pane implies a back arrow (lay4_shell_screens_test, lay7_settings_test) |

## Found in LAY7

| # | Where | What | Why it waits |
|---|---|---|---|
| 24 | ~~business_hours_screen.dart, the wide day card (`Row` spaceBetween at :242: the day title and the "Closed all day" label with its Switch, neither flexible)~~ | Overflows 222 px on the right in Kiswahili at text 1.3, at every wide width (the card is capped at 700); standalone too, so before LAY7. Pinned in lay7_settings_test | FIXED LAY7b: title, the label group and the label Flexible (wrap); ph8a-business-hours-* re-recorded (+9 Flexible, no size moved); lay7_settings_test asserts no overflow; UX5: also clean as the Business Hours tab of Business Profile (ux5_settings_test, 768/1200/1920, Kiswahili 1.3) |
| 25 | Receipt previews (receipt_preview_screen.dart, service_receipt_preview_screen.dart), Print with the Thermal format (the default) on web and desktop: it goes to the Bluetooth printer (print_bluetooth_thermal), which has no web or desktop support, so it shows No printer or Print failed, never the system print dialog | Open for UX1c (owner 2026-11-21): build a PDF and open the system dialog on web/desktop; Android Bluetooth unchanged; needs a Step 0; UX6: the Printer settings row is now hidden on web and all desktop (Android and iOS only); the receipt previews and Transactions still offer Print with the Thermal format there, unchanged |
| 26 | ~~Receipt previews (Sales and Services) on PC/tablet, Kiswahili at text 1.3, content 950 and 1128: a RenderFlex in the body overflows by 40 px on the right (before UX1b too; found by ux1b_pages_test, allowed there as known)~~ | FIXED UX2: the side panel's "Quick actions" heading (a Row: icon + Text, not flexible) is Flexible and wraps; ux1b_pages_test no longer allows it |
| 27 | printer_settings_screen.dart, the "Paired devices" row (`Row` spaceBetween at :241: the title and the Refresh button, neither flexible off the phone) | Overflows 19-23 px on the right in Kiswahili at text 1.3 on PC/tablet (the body is capped at 700, so also before UX3, in the Settings pane); found by UX3 lay7_settings_test | Open; UX7 made the body full width off the phone (no 700 cap), which should give the row room, but the row itself is unchanged and lay7_settings_test still allows the overflow: not verified closed |

## Found in UX7

| # | Where | What | Why it waits |
|---|---|---|---|
| 28 | ~~dashboard_screen.dart, the wide subscription pill (`Positioned(top: 56)` over the shell)~~ | Floated over the top bar and the page header of every wide page | FIXED UX7: AppShell.banner, in the layout under the top bar (ux7_settings_template_test) |
| 29 | ~~trash_screen.dart, PC/tablet: the five kinds as a TabBar spread across the header~~ | Tabs not left-aligned, in the header area | FIXED UX7: a left-aligned FilterRow in the body (ux7_settings_template_test, ph8a-trash re-recorded) |
