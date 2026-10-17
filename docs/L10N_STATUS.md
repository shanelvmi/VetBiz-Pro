# Localisation status (step 2F, English and Kiswahili)

Written at the close-out of step 2F (batch 2F-13, 2026-10-17). Rules: `docs/PHASE2_LOCALISATION_SPEC.md`; batch history: `docs/RUNBOOK.md` section 6.

## Keys

| | Count |
|---|---|
| Keys in `lib/l10n/app_en.arb` (each also in `app_sw.arb`) | 1,839 |
| Of which ICU plurals | 39 |
| Kiswahili marked `draft` | 1,839 |
| Kiswahili marked `reviewed` | 0 |

The owner's review file is `docs/kiswahili_review.csv` (last exported in 2F-13). The import tool has never been run: after editing the CSV, run `dart run tool/import_l10n_review.dart`.

R10 (raw user-facing string) is **0**. Everything left in English is allowlisted in `tool/hardcoded_baseline.json` as a whole folder or file, with its reason.

## Kept in English, and why

**Out of scope (spec 2.8), allowlisted:**
- `lib/screens/platform_admin/`: the operator console, used only by the platform owner. Also `lib/services/role_change_service.dart`, its role change, which writes stored notification text.
- `lib/screens/legal/`: privacy policy and terms need a legal translation, not a draft.
- Receipts, PDFs and the thermal printer: `receipt_pdf_service.dart`, `daily_report_pdf_service.dart`, `receipt_printer_service.dart`, and the receipt body drawn by the preview screens (`lib/utils/receipt_texts.dart`, pinned by a test). The language will be a facility setting (a later feature).
- Exported files: sheet names, headers, subtitles, fallback cells and share texts (`lib/utils/export_texts.dart`, including the Active Debts CSV share text "Active Debts Export"). The Active Debts CSV's headers and "Overdue"/"Current" cells too.
- Server text: `HttpsError` messages from `functions/` and the notification titles and messages the server writes are shown as they arrive or as stored. Future item: error and notice codes.
- Technical text: debug logs, `debugPrint`, field names, asset paths, technical error tags (`main.dart`, `friendly_error`, `invite_code`).

**Stored data (spec 2.5); only its display goes through a lookup:**
- Subscription plan labels "Daily", "Weekly", "Monthly", "Yearly" (`lib/constants/subscription_plans.dart`, allowlisted): saved as `planLabel` and compared by the Subscription History filter; the app shows `subscriptionPlanLabel`.
- Activity descriptions, "Unknown User" (`generatedByName`), the seller "Unknown", the debt source "Sale", the "SL-"/"SV-" numbers, Trash item titles ("Sale - {client} - {amount}", "Walk-in", "Transaction", "Untitled", which go into "Permanently deleted: ..."), "The assistant"/"This co-admin" fallbacks, and the name prefixes Mr./Mrs./Ms./Dr.
- Grouping and comparison keys: "Unknown" activity type, Insights "Unknown"/"Other", product category "Miscellaneous", filter values 'All'/'Unread'/'Read'/'Today'/'Last 7 days', role values 'Admin'/'Assistant'.
- Text the user must type: ERASE and DEACTIVATE (Manage Account), the facility's stored name or the fallback "this facility" (Delete Facility).
- The live subscription notice is built from the English ARB, because it is compared with the server's English message; the screen shows `attentionNoticeShown`.

**Other:** dates keep their "d Mon yyyy" / "h:mm AM" formats (spec 2.4); the compact "K"/"M" amount suffixes are typed in the code; raw error texts shown after "Could not delete the account:", "Could not load alerts:" and in the retention refusal.

## Messages sent to customers

One, not in the language files, English until the owner decides its language (`debtors_screen.dart` `_showReminderOptions`, by WhatsApp or SMS):

> Hi {clientName}, this is a reminder from {facilityName} that you have an outstanding balance of {amount}. Kindly settle at your earliest convenience. Thank you!

`{facilityName}` is "us" when the facility has no name, and a nameless debtor is "Unknown". `{amount}` is `Money.symbolPlain`. Suggested option: a facility setting for customer-facing language, together with receipts.

## Wording problems noted (English kept, owner's decision)

Full text in `docs/design-open-questions.md`, sections "Raised in step 2F". In short:
- Singular slips: fixed. "1 day"/"Over 1 day" in Active Debts (FIXES 3); "1 payment", "1 debt", "of 1 product", "1 unit", "1 found", "archived after 1 day", "of 1 sale", "of 1 service", "Expires in 1 day" (plural pass after 2F-13, pinned by test/plural_labels_test.dart).
- Login password: fixed (FIXES 1), login now checks only that both fields are filled; registration says "At least 8 characters". Enforcing 8 at login is the owner's option (report in `docs/FIXES.md`, item 2).
- Same meaning, two wordings: "Logout"/"Log in"/"Login"/"Sign out"; "Move to Stock"/"Remove from Sellable"; the two retention dialogs' failed-delete messages; the two "could not reach the server" sentences; "Total Owed"/"Total owed:"; plural and singular notification categories; "Vet"/"Veterinary"; "No submissions yet." with and without a full stop; "No facilities found." twice.
- Capitals: "Could Not Load Your Account"; "Ask your facility Admin"/"admin"; the retention refusal reason starts lower-case.
- Numbers typed into text: "Within 30 days" (Product Alerts), "© 2026 {appName} System".
- Odd labels: "All Status" (stock filter).
- Language fit: short relative times are long in Kiswahili ("dakika 5 zilizopita"); facility name and type order ("Kliniki ya Mifugo Ukuli"); sentences around links keep their pieces in English order; screen names inside Business Hours and Manage Account sentences are not placeholders yet.
- The one English change made in 2F: the facility picker footer's broken "â€¢" became "•" (2F-11).
- Behaviour notes: Payments source descriptions follow a language switch only on the next load; `planLabel` is still saved as English display text; older lower-case statuses and types now show capitalised (2F-3).
