# PH5a design: the standard phone list

Batch PH5a (RUNBOOK2 ledger). The owner wants record lists that feel like the best modern phone apps. This document fixes the pattern once; PH5a builds it in `lib/widgets/phone_list/` and pilots it on Sales and Services, and PH5b and PH7 move the other lists onto it. Line numbers are at `4d0032f`. Companions: `phone_foundations.md` (S3 text sizes, S5 `RecordList`, S6 forms, S7 receipts, the screen inventory) and `phone_shell.md` (the bar, the "+" sheet, tabs and deep screens).

## Scope

- **Phones only** (`AppLayout.isPhone`, landscape phones included). Each screen's `build` asks once: on a phone it returns the phone list; otherwise today's Scaffold, untouched: the metric cards, the Archive button, the filter toolbar, the table, the pagination bar, the 380 px details panel and the app bar buttons. Layout tests at 768x1024, 1024x768 and 1200x800 compare the whole widget tree (types, texts, sizes and positions) with a fingerprint taken from the code before PH5a.
- Everything is drawn with `context.colors` roles and named constants (`PhoneListMetrics` in `lib/theme/app_dimens.dart`). Texts come from the ARB (new Kiswahili marked draft).
- The providers, the list controllers (`CursorPaginatedListController`), the queries, the locked-facility guard (`navigateOrShowLockedDialog`), the admin gates, the delete confirmations and the Undo stay as they are. The phone list is another view of the same state: the same filter fields, the same `_open...ListSession` calls.

## Rules

**R1 App bar.** A back arrow when the screen was pushed, none when it is a tab (Sales as a tab, `asTab`). The title only, no subtitle. A search icon that turns the title into the search field in place (Close ends the search and clears it). ONE overflow menu with the secondary actions: Archive on both screens (no Export exists on them). No buttons in the bar; Refresh goes (R8).

**R2 Primary action.** An extended floating button at the bottom right (`CollapsingFab`): it collapses to its icon while the person scrolls down and extends when they scroll up; it is hidden while the keyboard is open; the list keeps bottom padding so it never covers the last row (on a tab the tab's Scaffold already sits above the bar). It goes through the same guard and gates as the old app bar button. Services: Record Visit. Sales: no button, the bar's raised "+" records a sale. (Sales pushed from All details covers the bar and so has no record action: the owner's rule, noted for PH5b.)

**R3 Search and filters.** Search is always one tap away (R1). Under the bar, a sideways row of QUICK STATUS CHIPS: All, Unpaid, Partial, Paid (stored `PaymentStatus` values, shown through `paymentStatusLabel`); a chip sets the same status field the toolbar's dropdown sets. One Filter button (a dot when any filter differs from its default) opens a bottom sheet (`showAppSheet`) with EVERY toolbar filter: Sales date, payment status, seller; Services date, category, status; Apply and Reset (Reset puts the defaults in the sheet; Apply applies). Applied filters other than the status (already shown by the chips) show as removable chips ("Date: Last 7 days", `common_filterValue`). Filters keep the toolbar's stored values and defaults (date Last 30 days, everything else All) and call the same session opener, so the results are the toolbar's (a parity test runs both on the same fake data).

**R4 Summary.** The metric cards go on phones. ONE line under the chips, "Last 30 days: 14 services, Tsh 620,000", from the same figures and period the cards show (`_rangeSummary`, always the last 30 days, whatever the filters), with a "Summary" link that opens a sheet listing every old card as a label and value row. Sales: count and Revenue on the line; the sheet has Total Sales, Revenue, Collected, Pending. Services: count and the amount billed (paid plus outstanding) on the line; the sheet has Total Services, Paid Amount, Outstanding, Digital Payments. No new queries (R12).

**R5 Grouping by day.** Rows sit under day headers pinned while their day scrolls (`SliverMainAxisGroup`): Today, Yesterday, then the weekday and date ("Monday, 27 Oct"). A header shows the day's total at the right only when the day is fully loaded: the last day's total is left out while more pages exist. No Date column. Exception: search results come in client-name order (the queries sort by `clientNameLower`), so while searching the rows are not grouped and line 2 also gives the date.

**R6 Rows (`RecordTile`).** Two lines, at least 64 high. A 40 px round leading: the client's initials (a person icon for Walk-in), or the category icon for services, on a tint of one of the nine chart roles chosen from the name (initials in `textPrimary`, so contrast does not depend on the role). Line 1: the person and the amount (right, tabular figures via `FontFeature.tabularFigures`, whole shillings by `Money.format`). Line 2: the supporting text and a status chip with TEXT and colour. No buttons inside rows. The per-screen table:

| Screen | Leading | Line 1 | Line 2 | Chip |
|---|---|---|---|---|
| Sales | client initials, or a person icon for Walk-in | client (or Walk-in) / total | invoice no. (SL-000123) and time | payment status |
| Services | the category's icon | client (or Walk-in) / total | category and time | payment status |
| Clients (PH5b) | initials | name / balance | phone, client type | owing or clear |
| Debtors (PH5b) | initials | name / owed | oldest debt date | overdue or current |
| Payments (PH5b) | method icon | client / amount | receipt no. and time | method |
| Transactions (PH5b) | category icon | category / amount | note and time | income or expense |

**R7 Details.** A tap opens a FULL PAGE with today's details panel content: the same builder (`_buildSaleDetailsPanel`, `_buildServiceDetailsPanel`), without its close row, under an app bar with the panel's title and a back arrow. Its actions are the old row and panel actions: Print and Share (the receipt preview), Edit (services, admins), Delete (admins, today's confirmation, then the page closes and Undo is offered). Back returns to the list where it was (the list is not rebuilt). Labels under 12 px become 12 on the page (S3).

**R8 Pull to refresh** replaces the Refresh button and calls today's two refresh paths: the summary reload (`_loadRangeSummary`, the old button) and the list restart (`_open...ListSession(forceRefresh: true)`, as after a new record). The "N new sales available - Refresh" banner stays, above the rows.

**R9 States.** Loading: SIX skeleton rows (a soft pulse; still when the platform asks for reduced motion). Empty: an icon, one plain line (today's empty texts), and the primary action as a button (Record Sale on Sales, Record Visit on Services; through the guard). Error: the message (`FirestoreErrorView`) with Retry (the list restart).

**R10 Paging.** More loads by itself when the person scrolls near the end, with a visible Load more button as the fallback; the same page size (`AppLimits.pageSize`, or what the person last chose on a wider window) and cursor logic: the phone shows every page reached so far (`CursorPaginatedListController.loadedItems`) and asks for the next with `goToNextPage`. No page bar on phones.

**R11 Accessibility.** 48 px targets. Each row's Semantics label reads naturally: "Amina Juma, Tsh 45,000, Paid, 27 Oct 10:15" (one ARB key). Text at least 14 px (line 2 and chips at least 12). Kiswahili wraps, never overflows. Status is never colour alone.

**R12 Cost.** No new queries. The old cards' figures come from one-time gets, not streams (Sales: `getRangeTotals` and `getTotalCollected`; Services: one get of the last 30 days); the phone keeps exactly those loads and reads the summary line and sheet from them, so a cold open costs what it costs today. A return to a tab costs nothing (the tab is kept); a return from the details page costs nothing. The counts before and after are measured on the counting fake and written in the ledger.

## Building blocks (`lib/widgets/phone_list/`, no new packages)

- `PhoneListScaffold<T>`: the app bar (R1), search, the header slot (chips, filter button, applied chips, summary line, banner), the grouped sliver list with pinned day headers, the FAB behaviour, pull to refresh, the three states and paging.
- `PhoneQuickChips`, `PhoneFilterSheet` (`showPhoneFilterSheet`), `PhoneSummarySheet` (`showPhoneSummarySheet`), `groupByDay` with `DayGroup` totals, `RecordTile`, `PhoneListSkeleton`, `CollapsingFab`.
- `RecordList` (PH2b) keeps the table and cards for wider panes; the phone pieces reuse its error and Load more texts. `showAppSheet` opens both sheets.

## Reuse plan

PH5b gives Clients, Debtors, Payments and Transactions a phone branch on the same scaffold: their filters become quick chips and the filter sheet, their metric cards the summary line and sheet, their panels the details page. PH7 does the same for Products, Stock Store and Reports, where the "rows" are products and reports (grouping off where a list has no date). A screen supplies only: its filters, its chips, its summary rows, its tile and its details builder.

## Tests (written first, committed skipped)

`groupByDay` and the day totals (a partly loaded last day shows none); the filter sheet against the toolbar on the same fake data; the quick chips; the summary line and sheet against today's cards; the FAB (shown, collapse and extend, hidden with the keyboard, none on Sales, the guard); pull to refresh calls both paths; skeleton, empty and error states; an assistant sees no Delete; the details page against the panel, and delete then Undo; the Semantics label; the wide fingerprints; the size matrix at 360x740, 390x844 and 740x360 in Light, Dark and Kiswahili on both screens; the read counts.

## Rollout and rollback

Phones only; each screen's phone branch is one `if` in `build`, so a rollback is a revert of that screen's commits. Nothing stored changes.

OWNER DECISION: APPROVED (the owner delegated these decisions to the assistant after the discussion, PH5a prompt of 2026-11-02; the choices above marked as the assistant's are R2's Sales-pushed note, R3's Reset and status-chip rules, R4's figures on the line, R5's search exception, R8's two paths and R10's loaded pages).
