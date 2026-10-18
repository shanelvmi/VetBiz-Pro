# RUNBOOK 2: from "localised and tokenised" to "safe, refined, themed"

**For:** Claude Code. **Owner:** Shanel (the only reviewer and tester).
**Continues:** `docs/RUNBOOK.md`. Its batches Q1 (Radio) and Q2 (`dart:html`) are still to do and come first. Every rule in `docs/RUNBOOK.md` section 2 applies here too (git rules, gates, data safety, no logic changes unless a batch says so, no push, budget hygiene, the ledger in the batch's last commit). This file adds the rules below.

---

## 0. Where the project stands

Phase 2 foundation is done: every style value is a token or is allowlisted with a reason, config and data constants are centralised, feedback goes through `AppFeedback`, and the app is localised (1,839 keys, English and Kiswahili, all Kiswahili still `draft`). The guard (`tool/check_hardcoded.dart`) is at zero for R1 to R11, with 81 allowlist entries. Q1 (Radio to RadioGroup) and the plural pass are done and pushed; analyze is at 2 infos (the two `dart:html` ones that Q2 fixes); tests are about 247.

## 1. Stop types and resume protocol

Same resume protocol as `docs/RUNBOOK.md` section 1 (read the ledger and `git log`, finish any half-done batch without redoing committed work, update the ledger row in the batch's last commit). Do ONE batch per session unless the owner says otherwise.

**Block order (the owner chose the faster route):** after E1-check come R0 (owner screenshots), R1, R2, T0, T1, K0, K1, K2 to K5. Then, LATER: E2 to E5, R3, R4 and R5 (R5 compares the wording list, so it follows R4). The ledger (section 9) is in this order.

- **HARD STOP:** the owner must look at the app. Write what to check in the ledger row, print it in under 15 lines, stop.
- **DESIGN STOP:** write the design document the batch asks for, then stop. Do NOT write feature code. The owner approves by changing the line `OWNER DECISION: PENDING` in that document to `OWNER DECISION: APPROVED option N` (or edits it). Never start the implementation batch until that line says APPROVED.
- **BLOCKED:** a gate failed twice for the same cause, or a logic change seems necessary. Record the exact error and stop.

**Design document format** (`docs/design/<name>.md`, at most 120 lines): current behaviour with file and line references; the problem and how it can go wrong; two or three options with trade-offs; the recommended option; the exact files and rules that would change; the tests that would prove it; rollout and rollback; and a final line `OWNER DECISION: PENDING`.

## 2. Owner decisions, with defaults

**OWNER APPROVAL: APPROVED**   (the owner approved every default below, with the two edits already applied in D5 and D10.)

**THEME CHOICE: CHOSEN**   (the owner chose, after research and a contrast check: Pasture stays the default, and the new themes are Clinic, Harvest and Ledger. The exact colours are in D10 below. The old names Kilimanjaro Green, Serengeti Yellow and Victoria Blue are retired.)

| # | Decision | Default |
|---|---|---|
| D1 | Currency spelling | One spelling, "Tsh", everywhere (the receipt previews' "TSh" and the facility card's "TZS" change to "Tsh") |
| D2 | Negative amounts | One shape, "-Tsh 12,500" |
| D3 | Decimals | Totals, balances and amounts shown whole shillings; unit prices keep up to 2 decimals where the stored value has them. Stored numbers never change |
| D4 | Saved activity text | New entries use "Tsh 12,500" (with the separator). Old entries stay as they are |
| D5 | Tigo Pesa and Mixx by Yas | One name only: "Mixx by Yas". Records stored as 'Tigo Pesa' are SHOWN as "Mixx by Yas" in lists, filters, report grouping and icons (the phone icon), and "Tigo Pesa" is never shown as a separate option. Stored keys never change |
| D6 | App name | "VetBiz Pro" everywhere except legal text and the two-tone wordmark; the footer reads "© 2026 VetBiz Pro. All rights reserved." |
| D7 | `trendUp` and `trendDown` | Stay separate roles, not merged into success and danger |
| D8 | Parked style values (the allowlist entries for R1 to R9) | A colour with no role: add a role named by purpose if it is used twice or more, otherwise snap to the nearest role within 24 per channel. A size or duration: nearest token within 4 px or 100 ms, else keep. Each treatment is listed for the owner to see first (batch R1) |
| D9 | Wording | "Sign in" and "Sign out" for verbs, "Sign in" for the screen title; "All Statuses" for the filter; the capital slips listed in `docs/L10N_STATUS.md`; keep "Move to Stock" and "Remove from Sellable" (different actions). Stored values never change |
| D10 | Themes | FOUR themes, ids and names: `pasture` "Pasture" (default: primary #2F5D62, accent #FFB200, background #FDFDF9), `clinic` "Clinic" (primary #0F4C81, accent #5BC0EB, background #F6F9FC), `harvest` "Harvest" (primary #4A3426, accent #E3A72F, background #FBF7F0), `ledger` "Ledger" (primary #1E293B, accent #8B9CFF, background #F8FAFC). `onPrimary` is white in all four. Computed contrast already verified by the assistant: white on primary 7.3, 8.9, 11.6 and 14.6; primary on background 7.2, 8.4, 10.9 and 14.0; dark ink on accent 8.2, 7.2, 6.9 and 5.8; accent on primary 4.1, 4.3, 5.4 and 5.8. Rules for any theme: those four checks must keep passing in a test (4.5, 4.5, 4.5, 3.0); the accent is for interactive and selected states only; no theme may rely on colour alone to show a state; theme names are labels only, kept in one place (`AppColorTheme`). Legacy ids: the old id `kilimanjaro` maps to `pasture`; the old ids `serengeti` and `victoria` were never selectable, and any unknown saved id falls back to `pasture`; add a test for this. |
| D11 | Dark Mode | System, Light, Dark setting in UI Settings. Dark applies to all three colour themes. Receipts, PDFs and the thermal printer always stay light |

## 3. Block A: finish the quality items (no owner decisions)

- **Q1 Radio to RadioGroup** and **Q2 `dart:html` to `package:web`:** as specified in `docs/RUNBOOK.md` section 4 (Q2 is a HARD STOP).
- **Q3 Line endings.** `lib/l10n/app_en.arb`, `app_sw.arb` and `docs/kiswahili_review.csv` have mixed CRLF and LF. Add a `.gitattributes` with `*.arb text eol=lf`, `*.csv text eol=lf`, `*.json text eol=lf`, and normalise only those files in one commit. The tools that write them must keep writing LF. Verify with tests and a diff that the text content is identical. Also include the generated `lib/l10n/app_localizations*.dart` files: Flutter regenerates them with LF, and `pub get` was observed to rewrite the checked-in copies with line-ending changes only. Normalise them to LF too, and add `lib/l10n/app_localizations*.dart text eol=lf` to the `.gitattributes`. Do not renormalise anything else.

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

**T0 Theme design (DESIGN STOP; do not start while THEME CHOICE says PENDING).** Write `docs/design/themes.md` and a static `docs/design/theme_preview.html` (inline CSS only) for the owner's CHOSEN set (see D10), showing for each theme the primary, accent and background, and a mock row of a sidebar item, a button, a card, a chip and an alert. Include a table of contrast ratios (computed, not estimated) for text on primary, on accent, on surface and on background, and for each semantic role (success, warning, danger, info) on each theme's background. Reject any pair under 4.5:1 for text or 3:1 for icons and large text, and say what you changed to fix it. Also check that no theme's primary is so close to the danger red that errors would be hard to notice. **Derived colours (the part that usually breaks):** audit every `AppColors` role that is brand-linked rather than semantic (the sidebar hover fill, the teal glow, the deep-green variants, tints of the primary, chart roles that were taken from the brand, and anything named after the old green), and for each one write the rule that derives it from the theme's primary, accent and background (for example "primary blended 12% with white"), with the old Pasture value reproduced EXACTLY by that rule so Pasture does not change by a single value. Semantic roles (success, warning, danger, info) are not derived from the theme and stay the same in every theme, but their contrast on each theme's background must pass.

**T1 Implement (after APPROVED).** Wire the two themes into `AppPalette` and `AppColorTheme`, remove "coming soon" in the UI Settings dialog, keep the choice saved on the device. Add tests: each theme builds a complete `AppColors`; every text role on every surface role passes the contrast threshold, computed in the test; the saved theme survives a restart. **HARD STOP:** the owner views each theme on the 13 screens of R0.

## 7. Block D: Dark Mode

**K0 Audit and plan (DESIGN STOP).** Write `docs/design/dark_mode.md`: every `AppColors` role with its proposed dark value per theme; every place that is not role-driven (images and logos, charts, the loading screens, the maintenance screen, shadows and scrims, the PDF and receipt previews that must stay light, `Brightness`-dependent plugin widgets); and the contrast test plan.

**K1 Implement the setting and the dark `AppColors` (after APPROVED).** System, Light, Dark in the UI Settings dialog, saved on the device, following the platform setting when System. Tests: every text role on every surface role passes the contrast threshold in dark for all three themes; the setting survives a restart.

**K2 to K5 Visual fixes by area,** one batch each, each a HARD STOP: (K2) dashboard and sidebar, (K3) lists and cards, (K4) forms and dialogs, (K5) reports, charts and the receipt previews (which must stay light). Fix only colour problems found; no layout changes.

## 8. After all blocks

Update `CLAUDE.md` on disk (never committed) with the rules learned, write `docs/PROJECT_STATUS.md` (what is done, what is LATER, how to run every check), and mark Phase 2 complete in the ledger.

## 9. Ledger (update the batch's row in its last commit)

Baseline: analyze 2 infos (the `dart:html` ones, fixed by Q2); the guard at zero; keys 1,839.

| Batch | Status | Commits | Notes (10 lines max) |
|---|---|---|---|
| Q1 (in RUNBOOK.md) | DONE (9b0136f..d1a9c8e) | | |
| Q2 (in RUNBOOK.md) | DONE (f3ce926, owner confirmed CSV and Excel downloads and receipt Share in Chrome; "Print receipt" on desktop Chrome shows a platform error, expected: thermal printing needs the phone) | | |
| Q3 line endings | DONE | e187249, 7498bdd | .gitattributes: *.arb, *.csv, *.json, lib/l10n/app_localizations*.dart text eol=lf. Index changed only for app_en.arb and app_sw.arb (3,530 CRLF lines each); CSV, JSON and generated files were already LF in git. Proof: for all 6 files, HEAD with CRLF->LF hashes the same as the new blob; diff --ignore-cr-at-eol empty. Owner decision (asked in session): the CSV tool wrote CRLF on purpose, which left the CSV "modified" after every export under eol=lf; toCsv now writes LF and keeps the BOM, and parseCsv reads CRLF inside quoted cells as LF, so an Excel CRLF save with no changed cell is not an edit and import never writes CR into app_sw.arb. 3 tests added (export LF + BOM; import CRLF = LF; Excel CRLF save not an edit, a changed cell still is). After export and flutter gen-l10n, git status shows no change. analyze 0 issues (No issues found); 250 tests. Not renormalised: working copies of other CRLF files (index already LF). Check: next owner Excel review, save, run the import, then the export: it must not refuse. |
| E1-design sale and debt atomic | DESIGN STOP, waiting for the owner | (this commit) | docs/design/atomic_sales.md (104 lines). No feature code, no rules changed. Traced: a sale is up to 10 separate writes, a service 8. Worst windows: stock deducted with no record (receipt number or the record write fails after FIFO; no rollback there), record without debt or balance (errors swallowed, screen says saved), duplicates after an honest retry (random ids; sale payment and service expense failures report "failed" after the record is saved). Offline saving already fails today (FIFO and counter are transactions). Options: (a) WriteBatch + increment, (b) runTransaction, (c) Cloud Function. Recommended (b): one transaction per sale/service, id made when the form opens, deterministic debt/payment/expense/log ids, plus a rules floor sellableQty/stockQty >= 0. Needs owner approval for fake_cloud_firestore (pubspec). Owner: read section 4, set the last line to APPROVED option N. |
| E1a sales (runTransaction) | DONE (1f37822..a5686f3, 262 tests; owner confirmed all seven Chrome checks: cash, credit, partial, walk-in, double-click gives one sale, network cut saves nothing and Retry saves once, short stock gives the same error with no Retry) | 0db33b9..a5686f3 | analyze 0 issues, 250 -> 262 tests after every commit. pubspec: dev only `fake_cloud_firestore: 2.5.2` (pinned; lock adds it + 9 transitive, no version moved). addSale = one transaction: reads sale doc (exists: return it), counter, batches, products, client; writes sale, stock, counter, balance + oldestUnpaidDebtDate, debts/sale_{id}, payments/sale_{id}, activity_logs/sale_{id} (+ _expired). Not enough stock: no write, same error as before, no Retry; other errors: Retry with the same id. Id made in initState and after each save; double-click guard. Old code vs new tests: 2 sales (want 1); no debts/sale_credit1; stock test fails only in the fake (no rollback there). Fake limits: writes not awaited, SetOptions ignored, no rollback. Not touched: firestore.rules, functions/, daily-summary triggers, services. Check: cash, credit (ids sale_...), partial, walk-in, double-click = 1 sale, offline = nothing saved, Retry online = no duplicate. |
| E1b services (runTransaction) | DONE pending the owner's Chrome checks (f29310c..ba8c2a3, 269 tests; short stock now shows "Couldn't save the service" with no Retry and writes nothing, where it used to show "Service added" and save nothing; the owner accepted the new behaviour) | f29310c..ba8c2a3 | analyze 0 issues; 262 -> 263 (+5 skipped) -> 269 tests. addService = one transaction: reads service doc (exists: return it), counter, batches, products, client; writes service, stock (1 unit per matched item, SellableStockPlan), counter, balance + oldestUnpaidDebtDate, debts/service_{id}, transactions/service_{id}, payments/service_{id}, activity_logs/service_{id}; list updated after commit. Old code vs new tests: 2 services (want 1); no debts/service_credit1, transactions/service_exp1, activity_logs/service_log1 (random ids); retry returned a new id; short-stock guard passed on both. Short stock: before, addService returned null and the screen said "Service added" with nothing saved; now "Couldn't save the service", no Retry, nothing written. Other errors: Retry with the same id. Edit path untouched: updateService, _handleServiceDebt, _handleServiceTransaction, _deductStockForItems unchanged (only the injected Firestore passed through); edit errors keep no Retry. No new text, no ARB change. Check: cash + stock item; external item (expense id service_...); credit to client (debt service_..., balance = it); double-click = 1 service; offline = nothing saved, stock and counter unchanged, Retry online = no duplicate; short stock error. |
| E1c stock floor rule | DONE, NOT DEPLOYED (owner deploys: app first, then save the live rules to firestore.rules-backup, then `firebase deploy --only firestore:rules`; check a sale, a service and a product edit) | c3e8054, 737b706, (this commit) | Helper `areStockQuantitiesAtOrAboveZero()` on products create/update and batches create/update (batch `write` split; read/delete unchanged): a written stockQty/sellableQty must be >= 0 unless left exactly as it was. Writers checked (lib/ and functions/; functions only read or delete): never negative = addProduct + first batch, new batch, adjustExistingBatch (clamped), legacy quantity edit (validated), _deductLegacyAggregate, moveToSellable, batch values in FIFO/SellableStockPlan, _adjustProductStock (clamped). Negative only from bad old data = product aggregates recomputed from batches when a batch is negative (addBatch, deleteBatch, adjust); product sellableQty in deductSellableFIFO, SellableStockPlan, moveBatchToStock when the product total is below its batches'; merge or restore onto a negative; Trash restore of a product trashed while negative (a create: now refused). updateProduct rewrites quantities unchanged: allowed. Not floored: thresholds, stock logs. Rules tests 66 -> 71, each proven to fail by a mutation; functions 92; flutter 269; analyze 0 issues. |
| E1-check consistency script | DONE, NOT RUN on production (the owner runs it) | 5acb58e..(this commit) | `functions/scripts/check_consistency.js` (not in index.js, no new dependency): only get(); 8 checks per facility, each a count + up to 10 ids; report outside the repo (`<home>/VetBiz-Pro-reports/consistency-<project>-<time>.md`, or `--out`; an --out inside the repo is refused). Definitions in the report: every debt document is unpaid, `amountOwed` = what is left; a payment on a debt lowers amountOwed (deletes the debt at 0), the client balance and raises totalPaid; a payment on a client with no debt chosen lowers only the balance (shows as a mismatch). Product = sum of batches IS an invariant (`_recalculateProductAggregates`; legacy no-batch products skipped). Tests: a write guard (set/update/delete/create/add/batch/transaction throw at every level), all checks through it, data unchanged; a planted set() fails 5 of 6 tests; each check on fake data. functions 92 -> 98, flutter 269, analyze 0 issues. Commit 5acb58e is 311 lines (over 300). Owner, from `functions`: `gcloud auth application-default login`, `gcloud auth application-default set-quota-project vetbiz-pro`, then `node scripts/check_consistency.js --project vetbiz-pro [--facility <id>] [--out <folder>]`. |
| R0 baseline screenshots | OWNER | | |
| R1 parked values table | DESIGN STOP, waiting for the owner | (this commit) | docs/design/parked_values.md (124 lines). No code changed. All 72 R1-R9 allowlist entries (R1 27, R4 6, R5 36, R7 1, R8 2) and the style Open items. D8 gives: colours 5 new roles (sidebarHover, chartServices, brandTeal, brandTealGlow, rolePlatformAdmin; 18 uses, exact values), 9 snaps (7 visible), 9 KEEP, 1 owner-kept; sizes 2 snaps (B4 36->s32, B12 icon 28->i32), the rest KEEP; named durations 11 snaps (8 change by 20-100 ms); alphas KEEP (no D8 rule); 19 computed durations and the 2 'TSh' lines are not style values. Ties go up (D8 is silent). Colour classes for T0: BRAND-LINKED 8, SEMANTIC 9, ONE-OFF 7 rows. 8 FLAGs for the owner (purpose mismatches; the service palette split; tints snapping to grey, which the owner reversed before). R0 screenshots must exist before R2. Owner: read the FLAG rows, edit any treatment, set the last line to APPROVED. |
| R2 apply parked values | BLOCKED until R1 APPROVED | | |
| T0 theme design | TODO (after R2) | DESIGN STOP | |
| T1 themes | BLOCKED until T0 APPROVED | HARD STOP | |
| K0 dark audit | BLOCKED until T1 DONE | DESIGN STOP | |
| K1 dark setting and roles | BLOCKED until K0 APPROVED | | |
| K2 to K5 dark visual fixes | BLOCKED until K1 DONE | HARD STOP each | |
| E2-design delete and restore | LATER (after K5), DESIGN STOP | | |
| E2 implement | BLOCKED until E2-design APPROVED | | |
| E3 client soft delete | LATER (after K5) | | |
| E4-design security | LATER (after K5), DESIGN STOP | | |
| E4 implement | BLOCKED until E4-design APPROVED | | |
| E5-design customer language | LATER (after K5), DESIGN STOP | | |
| E5 implement | BLOCKED until E5-design APPROVED | | |
| R3 money, payments, name | LATER (after K5 and block E) | | |
| R4 wording | LATER (after R3) | | |
| R5 compare | LATER (after R4), HARD STOP | | |
| LATER (noted, not scheduled) | LATER | | (1) Sales: a deleted client can be recreated as a stub client record by a sale to it; belongs to E3 (client soft delete). (2) The daily-summary triggers (`functions/index.js`) are not idempotent: an at-least-once re-delivery counts a document twice. |
