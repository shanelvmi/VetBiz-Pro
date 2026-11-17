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
| 1 | Sales list | 768x1024 | 103 px right (310 at text 1.3) | the filter toolbar, sales_screen.dart `_buildFiltersToolbar` Row (:415) | pol4_sales_services_test (knownWideOverflowOnly), ph5a_wide_unchanged fingerprints | none |
| 2 | Sales list, details open | 768x1024; 1024x768 at text 1.3 | 217 px right (345 at 1.3); 89 px at 1024 x1.3 | the page bar, `_buildPaginationBar` Row (:754) | the same | none |
| 3 | Sales list, details open | 1024x768 / 1200x800 | 228 / 52 px right (259 at 1200 x1.3; at 1024 x1.3, 54 on the list alone) | the filter toolbar (:415): the details panel (380 px) narrows it. POL4's ledger said "the page bar" here: wrong | the same | none |
| 4 | Sales details panel | every wide size, text 1.3 | 44 px right | `_totalsRow` (:1146): the label is flexible on phones only | pol4_archives_receipts_test (text 1.3) | none |
| 5 | Services list | 768x1024 | 129 px right (343 at 1.3) | the filter toolbar (services_screen.dart :454) | pol4_sales_services_test, ph5a_wide_unchanged | none |
| 6 | Services list, details open | 768 / 1024 / 1200 | 217 (page bar :714) / 254 / 78 (toolbar :454); at 1.3: page bar 345 / 89 (768, 1024), toolbar 292 (1200) and 87 on the 1024 list alone | page bar and toolbar | the same | none |
| 7 | Services details panel | every wide size, text 1.3 | 24 (title row :975), 26 (Payment information row :1009), 55 and 3.8 (`_totalsRow` :1086) px right | rows whose label is flexible on phones only | pol4_archives_receipts_test | none |
| 8 | Sales archive | 768x1024 (list), 1024x768 (details open) | 42 / 167 px right (232 / 357 at 1.3; 181 at 1200 x1.3) | the page bar, sales_archive_screen.dart :521 | pol4_fingerprints (pol4-sales-archive-*, inside the fingerprint) | none |
| 9 | Sales archive, details, text 1.3 | 768x1024 | 11 px bottom (table :401) and 44 px right (`_totalsRow` :700) | table header, totals rows | the measurement above (no test runs 768 x1.3 here) | none |
| 10 | Services archive | 768 (list) / 1024 / 1200 (details open) | 80 / 205 / 29 px right (281 / 230 at 1.3; 25 at 1024 x1.3) | the page bar, services_archive_screen.dart :557 | pol4_fingerprints (pol4-services-archive-*, inside the fingerprint), pol4_sales_services_test | none |
| 11 | Services archive details, text 1.3 | every wide size | 24 (:630), 26 (:664), 55 and 17 (:715) px right; at 768 also 71 px bottom (table :422) | title row, Payment information row, totals rows, table | the measurement above | none |
| 12 | Sales archive, Services archive | 360x640 (phone) | about 450 and 488 px right | no phone layout at all: the wide table is drawn | pol4_archives_receipts_test | 4 cases skipped by name ("no phone layout: the wide table overflows at 360 (450 and 488 px); for a later batch") |

Entries 1 to 11 are the same before POL4 (checked on f0167c7 for Sales) and
after it. The tests let them through only as RenderFlex overflows
(knownWideOverflowOnly), never another error.

## Products (group 4, POL5)

None found. Products, Stock Store and Stock Alerts were pumped at 360x640,
390x844, 768x1024, 1024x768 and 1200x800, text 1.0 and 1.3 (reduced motion),
every error collected one by one: no overflow (pol5_products_test.dart).
Not a defect but worth knowing: at 1024 Stock Alerts' kind FilterRow
scrolls sideways (Expired is off the edge until scrolled).
