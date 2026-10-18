# RUNBOOK 2: from "localised and tokenised" to "safe, refined, themed"

**For:** Claude Code. **Owner:** Shanel (the only reviewer and tester).
**Continues:** `docs/RUNBOOK.md`. Its batches Q1 (Radio) and Q2 (`dart:html`) are still to do and come first. Every rule in `docs/RUNBOOK.md` section 2 applies here too (git rules, gates, data safety, no logic changes unless a batch says so, no push, budget hygiene, the ledger in the batch's last commit). This file adds the rules below.

---

## 0. Where the project stands

Phase 2 foundation is done: every style value is a token or is allowlisted with a reason, config and data constants are centralised, feedback goes through `AppFeedback`, and the app is localised (1,839 keys, English and Kiswahili, all Kiswahili still `draft`). The guard (`tool/check_hardcoded.dart`) is at zero for R1 to R11, with 81 allowlist entries. Analyze is at 38 infos before Q1 and Q2; tests are about 247.

## 1. Stop types and resume protocol

Same resume protocol as `docs/RUNBOOK.md` section 1 (read the ledger and `git log`, finish any half-done batch without redoing committed work, update the ledger row in the batch's last commit). Do ONE batch per session unless the owner says otherwise.

- **HARD STOP:** the owner must look at the app. Write what to check in the ledger row, print it in under 15 lines, stop.
- **DESIGN STOP:** write the design document the batch asks for, then stop. Do NOT write feature code. The owner approves by changing the line `OWNER DECISION: PENDING` in that document to `OWNER DECISION: APPROVED option N` (or edits it). Never start the implementation batch until that line says APPROVED.
- **BLOCKED:** a gate failed twice for the same cause, or a logic change seems necessary. Record the exact error and stop.

**Design document format** (`docs/design/<name>.md`, at most 120 lines): current behaviour with file and line references; the problem and how it can go wrong; two or three options with trade-offs; the recommended option; the exact files and rules that would change; the tests that would prove it; rollout and rollback; and a final line `OWNER DECISION: PENDING`.

## 2. Owner decisions, with defaults

**OWNER APPROVAL: PENDING**   (the owner changes this word to APPROVED to accept every default below; batches in block B, C and D must not start while it says PENDING. Any default can be edited in place first.)

| # | Decision | Default |
|---|---|---|
| D1 | Currency spelling | One spelling, "Tsh", everywhere (the receipt previews' "TSh" and the facility card's "TZS" change to "Tsh") |
| D2 | Negative amounts | One shape, "-Tsh 12,500" |
| D3 | Decimals | Totals, balances and amounts shown whole shillings; unit prices keep up to 2 decimals where the stored value has them. Stored numbers never change |
| D4 | Saved activity text | New entries use "Tsh 12,500" (with the separator). Old entries stay as they are |
| D5 | Tigo Pesa and Mixx by Yas | Merged for display, filters and report grouping (stored keys unchanged); Tigo Pesa gets the phone icon |
| D6 | App name | "VetBiz Pro" everywhere except legal text and the two-tone wordmark; the footer reads "© 2026 VetBiz Pro. All rights reserved." |
| D7 | `trendUp` and `trendDown` | Stay separate roles, not merged into success and danger |
| D8 | Parked style values (the allowlist entries for R1 to R9) | A colour with no role: add a role named by purpose if it is used twice or more, otherwise snap to the nearest role within 24 per channel. A size or duration: nearest token within 4 px or 100 ms, else keep. Each treatment is listed for the owner to see first (batch R1) |
| D9 | Wording | "Sign in" and "Sign out" for verbs, "Sign in" for the screen title; "All Statuses" for the filter; the capital slips listed in `docs/L10N_STATUS.md`; keep "Move to Stock" and "Remove from Sellable" (different actions). Stored values never change |
| D10 | Themes | Three: Kilimanjaro Green (current), Serengeti Yellow, Victoria Blue. Text on every primary must pass WCAG AA contrast (4.5:1); a theme may set its own `onPrimary` (dark text on yellow) |
| D11 | Dark Mode | System, Light, Dark setting in UI Settings. Dark applies to all three colour themes. Receipts, PDFs and the thermal printer always stay light |

## 3. Block A: finish the quality items (no owner decisions)

- **Q1 Radio to RadioGroup** and **Q2 `dart:html` to `package:web`:** as specified in `docs/RUNBOOK.md` section 4 (Q2 is a HARD STOP).
- **Q3 Line endings.** `lib/l10n/app_en.arb`, `app_sw.arb` and `docs/kiswahili_review.csv` have mixed CRLF and LF. Add a `.gitattributes` with `*.arb text eol=lf`, `*.csv text eol=lf`, `*.json text eol=lf`, and normalise only those files in one commit. The tools that write them must keep writing LF. Verify with tests and a diff that the text content is identical. Do not renormalise anything else.

## 4. Block E: data integrity and security (design first; these protect real businesses)

Each item is a pair: **E-n-design** (a DESIGN STOP) then **E-n** (implementation, only after APPROVED). Every implementation includes tests that FAIL on the old behaviour, and for anything touching `firestore.rules` also rules tests (the emulator suite) run before and after. Never deploy; the owner deploys.

**E1 A sale and everything it changes must succeed or fail together.**
Today a sale writes the sale, its debt, the upfront payment, the client's balance, and the stock decrement as separate writes, so a failure in the middle leaves the books inconsistent. Trace the real order of writes in `SaleProvider.addSale`, `DebtProvider`, `PaymentProvider`, `ClientProvider` and the stock update, and list every window where a failure leaves a partial state. The design must compare at least: (a) a Firestore `WriteBatch` with `FieldValue.increment` for stock and balances (atomic and works offline, but cannot read-then-write, so stock floors must be enforced by rules or checked beforehand); (b) `runTransaction` (can read-then-write but fails when offline); (c) a Cloud Function. It must address offline use (shops with unstable connectivity), two devices selling the same stock, retries (use the sale's id as the document id so a retry cannot create a duplicate), the server triggers that update the daily summaries, the activity log entry, and what the rules need to allow. Same analysis for services (E1 covers sales and services).

**E2 Deleting and restoring must keep the books consistent.**
From the Trash audit in `docs/design-open-questions.md`: deleting a sale or service puts stock back, deletes the debt, reduces the client's balance (and, for a service, deletes its expense transaction for good), but Restore moves only the record back. The design must choose between: making Restore reverse each of those effects atomically (re-take the stock, re-create the debt, restore the balance and the expense), or replacing delete with a void that keeps the record and posts reversing entries. Include what happens to the Undo that was withdrawn for sales and services, and how daily summaries stay right. Until E2 is approved and done, keep the restore warning dialog.

**E3 Client deletion goes to Trash (no design stop; implement directly).**
`ClientProvider.deleteClient` deletes the document outright. Move it to `trash_clients` (already supported by the rules, the 30-day purge in `functions/index.js`, and the Trash screen's list and restore), add Undo like products and transactions, add tests. Client restore must not touch balances (a client's balance comes from their debts).

**E4 Security hardening (design stop, then implement the approved options).**
(a) Reports store a copy of the activity log in the report document, so an assistant who may not see the Activity Log can read it from the report. Propose how to keep it admin-only (for example a subcollection with its own rule) and how existing reports are handled. (b) Admins of a shared facility can read other users' documents; propose the narrowest rule that still lets Team Members work, and measure the extra reads. (c) List any other rule that is broader than the app needs, from reading `firestore.rules` in full. For every change, rules tests prove both what is now allowed and what is now refused.

**E5 Customer language setting (design stop, then implement).**
Messages sent to customers (the debtor reminder by WhatsApp or SMS, and later receipts) should follow a facility setting, not the app user's language. Design a facility field `customerLanguage` (`en` or `sw`, default `en`), where it is edited (Settings), who may edit it (rules), how the reminder text becomes two ARB keys that are looked up for the facility's language rather than the current locale, and that receipts and PDFs stay English until the owner decides otherwise.

**E6 Later, not now:** transactions pagination UI, the lost debt-settings screen, structured notification and server error codes so server text can be localised. Do not start these; list them in the ledger as LATER.

## 5. Block B: refinement (needs OWNER APPROVAL: APPROVED)

**R0 Baseline screenshots (the owner does this, not Claude Code).** Before R1, the owner saves screenshots, in English, at a wide window, to `D:\VetBiz-Pro-screens\before\` (outside the repo): Login, Dashboard, Sales list, Add Sale, Products list, Stock Store, Services list, Active Debts, Payments, a Daily Report view, UI Settings dialog, Facilities, Team Members. Claude Code never touches that folder.

**R1 Parked values table (DESIGN STOP).** Write `docs/design/parked_values.md`: every allowlist entry for R1 to R9 in `tool/hardcoded_baseline.json` and every "Open" item in `docs/design-open-questions.md` that is about a style value, with file, value, what it is used for, and the treatment the D8 rule gives it. Do not change code.

**R2 Apply the parked values (after the owner marks R1 APPROVED).** By area, commits of 300 lines or fewer, each treatment exactly as the table says. The guard allowlist shrinks accordingly; every remaining entry keeps a reason.

**R3 Money, payment methods, app name (D1 to D6).** One commit per decision. Money goes through the existing `Money` methods only. Add tests: the exact output of each `Money` method for 0, 1, 12500, 12500.5, a negative, and a very large number, taken from the decision. The merged payment-method grouping in reports must not change stored keys. Include every place the currency is typed (receipt previews, the facility card).

**R4 Wording pass (D9).** Only the changes listed in the decision, as ARB edits (English and Kiswahili draft), with the export tool run. The "English unchanged" check does not apply; instead list every changed string old to new in the ledger row.

**R5 HARD STOP.** The owner compares the baseline screenshots with the app and the old with the new wording list.

## 6. Block C: colour themes

**T0 Palette proposals (DESIGN STOP).** Write `docs/design/themes.md` and a static `docs/design/theme_preview.html` (inline CSS only) showing, for each of the three themes, the primary, accent and background, and a mock row of a button, a card, a chip and an alert. Propose the hex values and `onPrimary` for Serengeti Yellow and Victoria Blue, with a table of contrast ratios (computed, not estimated) for text on primary, on accent, on surface and on background, and for each semantic role (success, warning, danger, info) on the background. Reject any pair under 4.5:1 for text or 3:1 for icons and large text, and say what you changed to fix it.

**T1 Implement (after APPROVED).** Wire the two themes into `AppPalette` and `AppColorTheme`, remove "coming soon" in the UI Settings dialog, keep the choice saved on the device. Add tests: each theme builds a complete `AppColors`; every text role on every surface role passes the contrast threshold, computed in the test; the saved theme survives a restart. **HARD STOP:** the owner views each theme on the 13 screens of R0.

## 7. Block D: Dark Mode

**K0 Audit and plan (DESIGN STOP).** Write `docs/design/dark_mode.md`: every `AppColors` role with its proposed dark value per theme; every place that is not role-driven (images and logos, charts, the loading screens, the maintenance screen, shadows and scrims, the PDF and receipt previews that must stay light, `Brightness`-dependent plugin widgets); and the contrast test plan.

**K1 Implement the setting and the dark `AppColors` (after APPROVED).** System, Light, Dark in the UI Settings dialog, saved on the device, following the platform setting when System. Tests: every text role on every surface role passes the contrast threshold in dark for all three themes; the setting survives a restart.

**K2 to K5 Visual fixes by area,** one batch each, each a HARD STOP: (K2) dashboard and sidebar, (K3) lists and cards, (K4) forms and dialogs, (K5) reports, charts and the receipt previews (which must stay light). Fix only colour problems found; no layout changes.

## 8. After all blocks

Update `CLAUDE.md` on disk (never committed) with the rules learned, write `docs/PROJECT_STATUS.md` (what is done, what is LATER, how to run every check), and mark Phase 2 complete in the ledger.

## 9. Ledger (update the batch's row in its last commit)

Baseline: analyze 38 infos before Q1 and Q2; the guard at zero; keys 1,839.

| Batch | Status | Commits | Notes (10 lines max) |
|---|---|---|---|
| Q1, Q2 (in RUNBOOK.md) | TODO | | |
| Q3 line endings | TODO | | |
| E1-design sale and debt atomic | TODO, DESIGN STOP | | |
| E1 implement | BLOCKED until E1-design APPROVED | | |
| E2-design delete and restore | TODO, DESIGN STOP | | |
| E2 implement | BLOCKED until E2-design APPROVED | | |
| E3 client soft delete | TODO | | |
| E4-design security | TODO, DESIGN STOP | | |
| E4 implement | BLOCKED until E4-design APPROVED | | |
| E5-design customer language | TODO, DESIGN STOP | | |
| E5 implement | BLOCKED until E5-design APPROVED | | |
| R0 baseline screenshots | OWNER | | |
| R1 parked values table | BLOCKED until OWNER APPROVAL | DESIGN STOP | |
| R2 apply parked values | BLOCKED until R1 APPROVED | | |
| R3 money, payments, name | BLOCKED until OWNER APPROVAL | | |
| R4 wording | BLOCKED until OWNER APPROVAL | | |
| R5 compare | HARD STOP | | |
| T0 palettes | BLOCKED until OWNER APPROVAL | DESIGN STOP | |
| T1 themes | BLOCKED until T0 APPROVED | HARD STOP | |
| K0 dark audit | BLOCKED until T1 DONE | DESIGN STOP | |
| K1 dark setting and roles | BLOCKED until K0 APPROVED | | |
| K2 to K5 dark visual fixes | BLOCKED until K1 DONE | HARD STOP each | |
