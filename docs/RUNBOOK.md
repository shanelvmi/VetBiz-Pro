# RUNBOOK: the remaining mechanical work, resumable

**For:** Claude Code. **Owner:** Shanel (the only reviewer and tester).
**Why this file exists:** the owner's plan has usage limits. Work must survive a limit reset, a new session or a `/clear` with nothing lost. All state is in this file and in git, never in the conversation.

---

## 0. Project state (a handover for any new session or chat)

VetBiz Pro: Flutter + Firebase app for agrovets and vet clinics in Tanzania. Repo `shanelvmi/VetBiz-Pro` is **public**. Phase 2 (design tokens, config, data constants, feedback system) is complete: every raw style value is a token or is on a guard allowlist with a reason. Localisation (step 2F, English and Kiswahili) is in progress. Read, in this order, only what you need:
- `docs/PHASE2_LOCALISATION_SPEC.md` (the rules for 2F; this runbook adds hazards and batches)
- `docs/design-open-questions.md` (decisions and parked values; do not reopen)
- `CLAUDE.md` (on disk only, never committed)

---

## 1. Resume protocol (do this at the start of every session)

1. Read section 6 (the ledger). Run `git log --oneline -15`.
2. If `docs/FIXES.md` exists and has open items, **do them first**, one commit each, then continue.
3. Find the first batch that is not DONE. If it is IN PROGRESS, look at `git log` to see which of its commits exist and **finish it without redoing committed work**.
4. Do the batch. Then update its ledger row **in the batch's last commit** (never as a separate commit).
5. Go to the next batch. **Continue batch after batch** until a HARD STOP, a BLOCKED state, or the owner tells you to stop. If the usage limit is reached, wait and resume automatically.
6. At a HARD STOP, write what the owner must check into the ledger row, print it in under 15 lines, and stop.

## 2. Rules for every batch (the owner cannot supervise, so these are the safety net)

**Git**
- NEVER stage `CLAUDE.md` or `firestore.rules-backup`. Stage by explicit path only. Before every commit run `git diff --cached --name-only` and check.
- Commits of 300 lines or fewer. Generated files (`app_localizations*.dart`) in their own commits, split only between whole getters so every commit compiles.
- Never push. The owner pushes.

**Never touch:** `firestore.rules`, `storage.rules`, `functions/` (except tests named in a batch), `firestore.indexes.json`, `pubspec.yaml` (except batch Q2). If a batch seems to need it: mark BLOCKED.

**Gates, after EVERY commit**
- `flutter analyze`: 0 errors and no new issues compared with the ledger's baseline.
- `flutter test`: the log must say "All tests passed". Do not accept any other text.
- If a gate fails: fix it. If the same cause fails twice, **stop and mark the batch BLOCKED** with the exact error. Never skip a gate, never delete or weaken a test to pass.

**Data safety (localisation batches)**
- Stored values, saved text, activity descriptions, and Firestore query values NEVER change. Only what is displayed changes, through the lookups in `lib/l10n`. Dropdowns, chips and filters display the label but SAVE and COMPARE the stored value. Never compare against a label.
- **Text the user must type to confirm** (for example a word or a name to type before a delete) stays the compared literal. Localise only the sentence around it, passing the word as a placeholder.
- **Exported file contents** (CSV or Excel headers and sheet names), printed receipts, PDFs and the thermal printer test page stay English (spec 2.8).
- **Messages sent to customers** (WhatsApp and SMS reminders): keep the English text exactly, and record the exact text in the ledger row for the owner's decision. Do not localise them.
- **Stored notification text** (server-written titles and messages) is shown as stored. Localise only the screen's own labels and the synthetic rows the client builds itself.
- Do not reword the English. A sentence built from several pieces in the old code becomes ONE key; compare by hand that the English is identical. Note wording problems in `docs/design-open-questions.md`; do not fix them.
- Every NEW list of stored values gets a test pinning its exact values and order.
- Draft the Kiswahili for new keys following spec section 8, mark each `draft`, and **never run the import tool** (the owner reviews later). After each batch run `dart run tool/export_l10n_review.dart` and commit `docs/kiswahili_review.csv` and `docs/.kiswahili_snapshot.json` by explicit path. If the export refuses, STOP: that means the owner edited the CSV; mark BLOCKED.

**The "English unchanged" check, after every localisation batch**
For every key added in the batch, confirm its English text appears unchanged in the code before the batch (join adjacent string literals first; check plurals and multi-part sentences by hand). Put the result in the ledger row as `moved n | found n | by hand n | not found 0`. A key that is not found must be fixed before the commit.

**No logic changes.** If a logic change seems necessary, do not make it: mark BLOCKED and explain.

**Budget hygiene:** do not re-read files you have already processed; use `grep -n` and read only the lines you need. One `flutter test` run per commit. No long explanations: the ledger row is the report (10 lines maximum).

## 3. Localisation batches

Common to all: apply spec sections 4 and 5, reuse existing keys (search the ARB first), placeholders not concatenation, ICU plurals, amounts pre-formatted with `Money`, `{appName}`, units through `productUnitLabel`, stored values through the existing lookups. R10 (strings) for the batch's folders must reach zero or be allowlisted per folder with a reason.

**2F-5 transactions, debtors, clients.** (The owner started this by hand; finish it if incomplete.) Hazards: the debtors reminder messages (see rules); client type, animal, crop and status lookups; transaction category lookup.

**2F-6 `lib/screens/admin`, `lib/screens/settings`.** Hazards: Team Members status, role and history labels use the lookups; the typed-confirmation words in Manage Account (see rules); Business hours are stored as grouped fields (weekday, Saturday, Sunday); keep every stored field name and value unchanged and localise only the screen's own labels; export screen file contents stay English; the printer test page stays English; Trash screen messages are on-screen text (localise); the UI Settings dialog; the invite dialog.

**2F-7 `lib/screens/reports`, `lib/screens/services`.** Hazards: report breakdowns show stored payment methods and activity types through lookups; the report PDF and the receipt BODY (the receipt layout shown in the preview) stay English, but the surrounding buttons and headings are localised; service category lookup; archive filters keep stored values in queries.

**2F-8 `lib/screens/products`, `lib/screens/sales`.** Hazards: **the Release flow's "Remove from Sellable" dialog compares labels: change it to compare the stored value, then localise**; units in sentences; payment chips; "Walk-in Customer" is a stored client name: keep stored and compared as is, display through a lookup; receipts English; smart-defaults text.

**2F-9 `lib/screens/login_screen.dart`, `register_screen.dart`, any other top-level screen, and the loading, error and no-facility screens in `lib/main.dart`.** Hazards: validation messages; the auth error mapping is already localised (keep behaviour); role chips store 'Admin'/'Assistant'; facility type lookup; invite-code input. **HARD STOP after this batch.** The owner must check sign-in, sign-up (owner and assistant), password reset, in both languages.

**2F-10 `lib/screens/dashboard` (dashboard, insights, notifications).** Hazards: stored notification text is shown as stored; the synthetic "Free Trial" and subscription rows are built by the client (localise); sidebar items; chart labels; the greeting; do NOT touch the bell's blink and read logic, the trial pill's condition, or Layout Fixed Mode.

**2F-11 `lib/screens/facilities`.** Hazards: the delete flow's typed confirmation; the "Checking..." feedback; facility type and status lookups; the restock dropdown saves the stored name. **HARD STOP after this batch.** The owner must check the delete flow (a facility with an assistant is blocked; one without is deleted after the typed confirmation) in both languages.

**2F-12 `lib/screens/activity` plus the FINAL SWEEP.** First the activity log screen (do not touch the streams, scoped queries, retention cleanup or filters). Then sweep everything else in `lib/` outside the excluded folders for user-visible text the guard cannot see: functions that `return 'text'` or `=> 'text'` shown in the UI, providers and services that build messages shown to people, models with display getters. Produce a table (file, line, text, displayed or saved or technical, decision) in the ledger row. Move the displayed ones; leave saved and technical ones in English with a code comment.

**2F-13 close-out.** R10 is zero or allowlisted per folder or file with a reason. Run the export tool once more. Write `docs/L10N_STATUS.md`: key count, draft count, reviewed count, every string kept in English with its reason, the outgoing customer messages with their exact text, and all wording problems noted. Update `CLAUDE.md` on disk (never committed) with the localisation rules. **HARD STOP.**

## 4. Quality batches (after 2F-13)

**Q1 Radio to RadioGroup** (about 36 deprecation infos in about 14 files). One commit per screen, no behaviour change, the group value keeps its type, dialogs included. Target: those infos gone, nothing else changed. Describe in the ledger what to check in Chrome (every radio in a form: select, change, save).

**Q2 `dart:html` to `package:web`** (`lib/utils/web_download_web.dart`). This is the ONE batch allowed to change `pubspec.yaml` (add the `web` package). Keep the function's behaviour identical. **HARD STOP:** the owner must test a data export download in Chrome.

## 5. Not in this runbook (they need the owner's decisions)

Step 2R (the 52 parked values and the scales, with screenshots), the other colour themes, Dark Mode, making a sale and its debt one atomic write, making deletes and restores keep the books consistent, making client deletion soft, the remaining security hardening, and the lost debt-settings screen and transactions pagination UI. Do not start any of these.

## 6. Ledger (update the batch's row in its last commit)

Baseline when this runbook was written: analyze 38 infos (0 errors, 0 warnings); 228 Flutter tests, 92 server tests; R10 about 1,236 before 2F-5.

| Batch | Status | Commits | Notes (10 lines max) |
|---|---|---|---|
| 2F-5 transactions, debtors, clients | DONE | 4295fcb..c4acde2 | R10 1,078; analyze 38 (0 E, 0 W); 230 tests. 189 keys (all draft). English check: 206 found, 5 by hand, not found 0. Reminder sent to debtors kept English, exact text in design-open-questions.md (2F-5). |
| 2F-6 admin, settings | DONE | b526d05..(this commit) | R10 1,078 -> 824 (254 moved; admin and settings at 0, export_data_screen allowlisted as a file: exported file text, 2.8). analyze 38 (0 E, 0 W) after every commit; 230 tests. 272 keys, all draft. English check: moved 305 | found 290 | by hand 15 | not found 0. Kept English: typed words ERASE/DEACTIVATE (compared), Trash titles (saved in activity text), exported file contents, activity descriptions. Check in Chrome, both languages: Team Members (approve, reject, deactivate, reassign, remove, details panel), Invite dialog, Settings list and dialogs, UI Settings, Business Hours, Profile, Printer, Trash (restore warnings, delete forever), Export (date range, formats, one export), Manage Account (wipe and deactivate typed words still English). |
| 2F-7 reports, services | DONE | b56606e..74addc7 | R10 824 -> 647 (177 moved; reports and services at 0; receipt body in lib/utils/receipt_texts.dart, allowlisted as a file, pinned by a test). analyze 38 (0 E, 0 W) after every commit; 232 tests. 250 keys, all draft. English check: moved 303 | found 301 | by hand 2 | not found 0. Kept English: receipt body and its share text, report PDF share text and fallback facility name, "Unknown User" (saved), activity descriptions. Stored payment methods, transaction categories and units now shown through lookups (English identical). Check in Chrome, both languages: Service Records (filters, details panel, delete), Services Archive (date search, pagination), Record/Edit Visit (validation, item suggestions), service receipt preview (format choices, side panel; receipt still English), View Reports (generate, delete draft, quick actions), Review & Submit (counts, variances, blocked reasons), report tabs, Full Report, Past Reports. |
| 2F-8 products, sales | DONE | f473542..2b74de6 | R10 647 -> 382 (265 moved; products and sales at 0, no new allowlist; receipt body through lib/utils/receipt_texts.dart, which gains Subtotal and Discount, pinned by its test). analyze 38 (0 E, 0 W) after every commit; 232 tests. 243 keys, all draft. English check: moved 243 | found 229 | by hand 14 (8 plurals, 6 sentences built from pieces) | not found 0; reused keys matched exactly. Hazard fixed: Move to Stock chose its message by comparing the label; now by the value MoveToStockAction (Stock Store call sites changed only that argument). Kept English: receipt body and share text, saved activity descriptions, saved seller "Unknown", debt source "Sale", "SL-" invoice numbers; no customer messages in this batch. Check in Chrome, both languages: Sellable Products (cards, menu, delete and undo, smart defaults), Add/Edit Product (validation, duplicate name, destination dialog), Add Batch, View Batches (adjust, delete, Move to Stock and its message), Product Alerts (cards, filters, search, Remove expired from Stock Store and from Alerts: message must say "Removed ... from Sellable"), Sales list (filters still filter, details panel, delete), Sales Archive (date search, pagination), Record Sale (warnings, discount, browser, expired-stock warning, save), sale receipt preview (receipt still English). |
| 2F-9 login, register, main.dart screens | DONE (owner confirmed the sign-in checks) | b837bb4..e1382f8 | R10 382 -> 278 (104 moved; login_screen, register_screen and main.dart at 0, no new allowlist; the logo letters 'VB.' and 'v2.0.0' moved to AppInfo.logoMark/versionLabel). analyze 38 (0 E, 0 W) after every commit; 232 tests. 163 new keys, all draft; 12 reused. English check: moved 163 | found 162 | by hand 1 | not found 0; reused keys matched exactly. Sign-in error mapping unchanged; role values 'Admin'/'Assistant', name prefixes and every saved field unchanged; facility types in "Joining: ...", tiles and Edit Profile now through facilityTypeLabel (English identical). Kept English: Mr./Mrs./Ms./Dr. (saved in the name), technical error tags, raw error inside "Could not delete the account: ..." (noted). No customer messages. HARD STOP. Check in Chrome, both languages (switch in Settings, sign out, the login screen follows it): Sign-in (empty or short password, wrong password, Remember Me, announcements card, footer links); Sign-up as owner (empty form: field errors and "Please fix n fields"; Add with name or type missing; facility tile shows type and code; terms links; "Account registered"; lands on the dashboard); Sign-up as assistant (invite code: invalid, checking, "Joining: name (type)"; "Assistant registered, waiting for admin approval"; signing in before approval shows "not active yet"); Password reset (no email: error on the form; any email: the same "If an account exists..." message); also Edit Profile (role locked, Save changes) and the no-facility screen (join with a code, add a facility, delete-account dialog errors). |
| 2F-10 dashboard | DONE | c1e75ff..54595fc | R10 278 -> 156 (122 moved; dashboard, insights, notifications and subscription_provider at 0, no new allowlist). analyze 38 (0 E, 0 W) after every commit; 232 tests. 147 new keys, all draft; shared words and screen titles reused. English check: moved 147 | found 134 | by hand 13 (6 plurals, 5 pieced sentences, 2 with escapes) | not found 0; reused keys matched exactly. Hazard found: Notifications compared the live subscription notice's message with the stored (English, server-written) one to detect escalation; that notice stays English (from the English ARB) and the rows show attentionNoticeShown. Period filters keep 'Today'/'Last 7 days'... and the status filter 'All'/'Unread'/'Read' as values (labels only localised); facility type compared as stored, shown through facilityTypeLabel; Insights 'Unknown'/'Other' grouping keys unchanged. Not touched: bell blink/read logic, trial pill condition, Layout Fixed Mode. Kept English: stored notification text, compact "M" suffix, raw error in "Could not load alerts" (noted). No customer messages. Check in Chrome, both languages: Dashboard (greeting by time, period menu and card titles, trends "vs ...", subscription banner as admin and assistant, Recent Activity, chart period and tooltip, glance strip, Net Profit breakdown tooltip, quick actions, search results, help dialog, sidebar items and facility line, profile panel and logout dialog, change-password dialog); Insights (pulse, three charts, "Other" slice); Notifications screen and bell dropdown (cards, status and date filters still filter, table, paging, Mark all read, sections, trial row; a subscription notice must not turn unread again after a language switch). |
| 2F-11 facilities | TODO, HARD STOP after | | |
| 2F-12 activity + final sweep | TODO | | |
| 2F-13 close-out | TODO, HARD STOP after | | |
| Q1 Radio to RadioGroup | TODO | | |
| Q2 dart:html to package:web | TODO, HARD STOP after | | |

## 7. Corrections protocol

After each session the owner pushes and sends the ledger to the assistant, who audits in bulk and writes `docs/FIXES.md` (a numbered list: file, problem, fix). The next session starts with it (section 1, step 2). When all items are done, mark the file `ALL DONE`.
