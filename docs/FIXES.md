# FIXES (corrections found in review; do these FIRST, one commit each)

Source: the assistant's audit of batch 2F-6 (commits b526d05..b5ec037).
Status of this file: ALL DONE (item 1: 3144693; item 2: the commit "FIXES 2"; item 3 skipped, not APPROVED)

## 1. RUNBOOK.md: remove a wrong hazard

In `docs/RUNBOOK.md`, batch 2F-6, the hazard text says business-hours weekday names are stored keys that must be displayed through a lookup. **That is wrong for this app.** Business hours store grouped fields (`weekdayClosingTime`, `weekdayClosed`, `sundayClosingTime`, `sundayClosed`, and the Saturday equivalents), not weekday names. Replace that sentence with: "Business hours are stored as grouped fields (weekday, Saturday, Sunday); keep every stored field name and value unchanged and localise only the screen's own labels."

## 2. Narrow the export screen's R10 allowlist

`lib/screens/settings/export_data_screen.dart` is allowlisted for R10 as a whole file because its remaining strings are the contents of the exported file, which stay English. A new on-screen string added there later would not be caught.

Fix: move every string that goes INTO the exported file (headers, sheet names, row labels, the share text) into a new file `lib/utils/export_texts.dart`, kept in English with a comment saying why (exported files are documents; see spec 2.8). Allowlist that new file for R10 as a whole, with that reason. Then remove the whole-file allowlist entry for `export_data_screen.dart`, so the screen's own on-screen text is checked again. Behaviour must be identical: an export before and after must produce byte-identical file contents (write a test that builds the export data from a fixed sample and compares it with a fixed expected result, taken from the old code, before moving anything).

## 3. (Optional, needs the owner's OK; do not do it unless this line says APPROVED)

The English "1 days" and "Over 1 days" (Active Debts) should be "1 day" and "Over 1 day". Use an ICU plural key in both languages. This is a deliberate English wording change.

## Done criteria

Analyze with no new infos, "All tests passed", the guard baseline lowered or unchanged, no push. Mark this file `ALL DONE` and list the commits when finished.
