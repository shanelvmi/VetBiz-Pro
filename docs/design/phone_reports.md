# PH7b plan: reports on phones

Batch PH7b (RUNBOOK2 ledger). The owner delegated the choices to the rules R1 to R12 of the PH7b prompt (2026-11-03); this page applies them to each screen. Line numbers are at `a8c4b33`. Companions: `phone_foundations.md` (S3 text, S6 forms, the reports inventory rows) and `phone_list_pattern.md` (the PH5a states, R11, R12).

## Scope and safety

- **Phones only** (`AppLayout.isPhone`, landscape phones included). Each screen asks once and builds either its phone layout or today's layout, untouched. Fingerprints of every screen and tab at 768x1024, 1024x768 and 1200x800 are recorded from the code before PH7b and compared after (`test/fixtures/ph5a_wide_fingerprints.json`, the `ph7b-` names).
- The PDF (`DailyReportPdfService`), the share text, the CSV exports and everything printed stay exactly as they are; the phone calls the same functions.
- No new queries or listeners (R12): the report is one document already loaded; the phone reads the same document and the same activity-log subdocument (admins only). Counted on the counting fake before and after.
- Seams first: `ViewReportsScreen`, `ReportReviewScreen`, `ReportDetailScreen`, `ReportFullViewScreen`, `ReportTabbedContent` and `ReportActivityLogLoader` take an optional `firestore:` (and View Reports an `auth:`), defaulting to `.instance`; Past Reports passes its own on. No behaviour change; a smoke test each.

## Shared pieces (`lib/widgets/phone_report/`, metrics in `PhoneReportMetrics`)

- `PhoneReportTabBar` (R1): today's 10 (9 for assistants) tab values and labels in a scrollable `TabBar` (`tabAlignment: start`), labels 14 px, at least 48 high; the selected tab is scrolled into view (the scrollable bar's own behaviour, also after a swipe).
- `PhoneReportRow` (R2): two lines, at least 56 high, 16 px sides. Line 1: the name (up to 2 lines, ellipsis) and the amount at the right (14 px, tabular figures). Line 2: short pieces in a `Wrap` (14 px, muted: in Kiswahili it is the longer line) and an optional status chip (text and colour, `StatusChip`). A row that opens nothing has no ink; one that does is a 48 px target.
- `PhoneReportStat` (R4): a label and its value on one row (14 px, 48 high, the label wraps, the value never squeezed); `bold` for totals.
- `PhoneReportSection`: a heading, an optional note, then its rows. With more than 5 rows (R3) it shows the first 5 and a "See all (N)" row that pushes `SeeAllPage`: the heading as the title, a back arrow, every row of the section in the same order. The tablet's report tabs have no search, so none is added.

## The 10 tabs (`report_tabbed_content.dart`; phone builders in `report_phone_tabs.dart`)

`build` asks `AppLayout.isPhone` once: the phone tab bar and the phone builders, or today's `TabBar` and the 10 `_build...Tab` methods unchanged. The tab values, the order, `_showActivityLog` (admins) and the controller are shared.

| Tab | Phone layout (same figures, same lookups as the tablet) |
|---|---|
| Summary | Daily Summary as stat rows: Total Sales, Service Revenue, Debt Repayments, Expenses (admins only, R4), Other Income, Outstanding New Debt, Transactions, Services Performed, Products Sold, Total Revenue Today; then "Generated at ... by ..." and "Submitted at ...". The four preview cards go (their rows are one swipe away). A screen may add a footer (View Reports: Accountability and Declaration) |
| Sales | rows: customer / `Money.format(amount)`; line 2: receipt no., time, items (plural), payment method label. First 5, See all. Total Sales (bold). Payment Methods: stat rows of `PaymentMethod.mergeShown` |
| Services | rows: service / revenue; line 2 "Performed: N". Total Service Revenue. Payment Methods merged |
| Products | the System-tracked note; rows: name (a star chip "Watch-listed" when so) / expected closing with its unit; line 2: Opening, Added, Adjusted (the warning colour when not 0; a long press shows the adjustment detail, the tablet's tooltip), Sold. Total Units Sold |
| Stock Reconciliation | the same two empty states; rows (R5): product / the difference ("+2", "-1", "0"); line 2 "Expected: 10  \|  Physical: 12" (existing key) and a chip "Variance" (danger) or "Match" (success); the reason as a third line when there is one |
| Debt | the three stat rows (New debt, Repayments collected, Outstanding change, bold); By Customer rows: client / closing; line 2: Opening, New Debt, Repayment |
| Expenses | rows: description / amount; line 2: category label, time. Total Expenses |
| Transactions | the note; rows: description / "-12,500" (danger) or "+12,500" (success); line 2: Expense or Other Income (the same colour), category, time. Other Income, Expenses (bold) |
| Activity Log | admins only, as today (R6); the same loader states; rows: description / time; line 2: the type label (its colour and icon) and who |
| Payment Methods | Combined (all) with its note: stat rows of `combineShown`, Total (bold); then Sales, Services, Debt Repayments and Other Income one under the other, each `mergeShown` (R7: Tigo Pesa and Mixx by Yas stay one row) |

A label and its value in line 2 use one new key, `phoneReport_labelValue` ("{label}: {value}"), with today's column labels.

## The screens

- **View Reports (R9).** Phone: the title only, ONE overflow menu (Past Reports, View Full Report, Download PDF, Delete Draft for admins on a draft, Share with Admin for assistants: today's Quick Actions), the report date under the bar, the tabs filling the page, and today's primary action (Generate, Continue Closing, or the Submitted state) pinned at the bottom (S8 safe area). Accountability and Declaration become the Summary tab's footer. States: a spinner while loading as today; the empty state with today's texts and the Generate button; a load error shows the PH5a error with Retry (today it fell through to the empty state).
- **Past Reports (R9).** Phone: the PH5a `PhoneListScaffold`: search in the bar (the same filter of the loaded rows), quick chips for the four time filters (stored enum, same reload), no Filter button, the summary line "N reports" with the Summary sheet (Reports generated, Loaded period, Latest), rows by MONTH under pinned headers ("November 2026", `groupByDay`'s month variant, no total), `RecordTile`: the date / revenue, line 2 who generated it, chip Completed or Not Submitted; the same taps (a draft opens Review, a submitted one the detail); skeleton, empty, error with Retry; Load more as today (scroll near the end, button fallback). The same two queries (page and count).
- **Review form (R8).** Phone: one column, the PH6 shell: count fields 48 high with the number keyboard, reason fields below, each field's error line reserved so nothing moves; the declaration checkbox (a 48 px row) above the pinned `FormActionBar` (Cancel, Submit Daily Closing), the blocked reason as its summary line; `PhoneDiscardScope` (kind `report`: "Discard this report's counts?") asks on back once anything is typed or ticked. It submits exactly what today's form submits (`submitReport` arguments recorded from the old code for fixed inputs, `test/fixtures/ph7b_submitted_report.json`).
- **Full view and detail (R10).** Phone: text at least 14 (labels 14, values 14), every label-value row lets the label wrap beside its value, nothing scrolls sideways; the detail screen's bar puts the date and status in the title and the PDF button as an icon. The sections and their order are unchanged.

## Tests (written first, committed skipped)

Per tab, the phone figures equal the tablet tab's for the same fake report (numbers compared as text sets); See all opens the page and its rows equal the section's; role rules (an assistant has no Activity Log tab and no Expenses row in Summary; nothing named Net Profit exists today); the review form's recorded submission, the bar above the keyboard, the discard question; Tigo Pesa and Mixx merged; the phone matrix (360x740, 390x844, 740x360; Light, Dark, Kiswahili; long Kiswahili names, 8-digit amounts) for View Reports, each tab, See all, Review, Full view, Detail and Past Reports: no overflow, 48 px targets, nothing under 12, body at least 14; the wide fingerprints; PH2a's 7 skipped Past Reports cases un-skipped; listener and read counts.

## Notes for the owner (not changed)

The Expenses and Transactions tabs, the full view and the PDF show expenses to assistants today, on every width; PH4b hid Total Expenses only on the dashboard. PH7b hides it only in the phone Summary, as asked.

OWNER DECISION: APPROVED (delegated in the PH7b prompt of 2026-11-03: rules R1 to R12).
