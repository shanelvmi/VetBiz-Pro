# E4 design: security hardening

Batch E4-design (RUNBOOK2 section 4), a DESIGN STOP: no code and no rules are changed. Line numbers are at `7e59cf9`. `firestore.rules` was read in full (458 lines). "Assistant" = a signed-in member of the facility with `role: assistant`; "outsider" = anyone with an account, who can always make one: `registerOwner` makes them an **admin** of a new facility of their own.

## 1. Current behaviour

### (a) The report keeps a copy of the activity log

- **Written:** `DailyReportService.generateDraftReport` (`lib/services/daily_report_service.dart:119`) reads today's `activity_logs` when `includeActivityLog` is true (`:157-164`). The caller passes `isAdmin` (`lib/screens/reports/view_reports_screen.dart:125,133`). It copies every entry (`:545-552`: `time`, `actionType`, `description`, `userName`) into the report and saves the whole report with `docRef.set(report.toMap())` (`:608`) at `facilities/{f}/dailyReports/{yyyy-mm-dd}`. Fields: `activityLogEntries` and `activityLogIncluded` (`lib/models/daily_report.dart:466-467`). Reports made before the flag always hold the log (`:513`).
- **Rewritten:** `submitReport` (`daily_report_service.dart:617`) reads the report and writes it all back (`:644`), entries included. Assistants do this too: they submit their own drafts and the admin's.
- **Read rule:** `dailyReports` allows `read` to every member (`firestore.rules:300`). It allows `update` to every member while `status == 'draft'`, for any field (`:302`). An assistant can `get` any admin-generated report through the SDK or REST and read everyone's activity for that day: who was approved, rejected or deactivated, and every sale and payment by name. This is exactly what `activity_logs` refuses them (`:393-396`). They can also overwrite a draft's `activityLogEntries` with invented entries.
- **Readers in the app:** `report_full_view_screen.dart:113-117` (admins only), `report_tabbed_content.dart:59,100,877-886` (tab shown to admins only). The PDF (`lib/services/daily_report_pdf_service.dart`) has no activity-log section, only "Debt Activity" (`:448`). Nothing else reads `activityLogEntries` (searched `lib/` and `functions/`). The protection is the screen, not the database.

### (b) User profiles

- **Rule:** `allow read: if isAuthenticated() && (request.auth.uid == userId || isAdmin() || isPlatformAdmin())` (`firestore.rules:134`). `isAdmin()` only checks the requester's own role (`:19-21`). **There is no facility check at all.** Any admin can `get` or `list` every profile in the database, not only those in a shared facility.
- **What a profile holds** (`functions/membership.js:337-347`): `fullName`, `email`, `phone`, `avatarUrl`, `role`, `status`, `facilityIds`, and `facilities: [{facilityId, name, type, code}]`. `code` is the facility's **invite code**.
- **Who can read what today:** an outsider registers as an owner and runs `collection('users').get()`. They then have every user's name, email and phone, every business's id and name, and its invite codes. With a code, `joinWithInvite` files them as a pending assistant of that business. An assistant reads only their own profile, which is correct.
- **Correction (E4b audit):** the two bullets above are wrong about the code. `facilities[].code` on a profile was the facility's permanent 8-character **facility code**, not an invite code: it cannot be used to join. `joinWithInvite` and `joinFacilityWithInvite` accept only the 6-character codes in `inviteCodes`, which are made by `createInviteCode` and readable only by that facility's admins. So an outsider got names, emails, phones and facility ids and codes, but not a way in. (b3) still removed the code from profiles.
- **What the app needs** (all callers of `Collections.users`):
  - Each person reads their own profile (`main.dart:318,328,430`, `user_role_provider.dart:33`, and others).
  - Admins read their team with queries already filtered to their facilities:
    - `manage_assistants_screen.dart:187-191`: `facilityIds arrayContainsAny` with my facilities.
    - `facility_picker_screen.dart:81-86`: `arrayContainsAny`.
    - `facility_screen.dart:351-355` and `dashboard_screen.dart:499-503`: `arrayContains` with the current facility.
  - Names by id: `payments_screen.dart:195`, the `paidById` of payments in my facility. For an assistant this is refused today and the names stay blank.
  - Platform Admin tools: `lib/screens/platform_admin/*`, `role_change_service.dart:250`.

## 2. Problems

- (a) The activity log's privacy is one `if` in two screens. Any assistant who opens DevTools reads it, and can forge it in a draft.
- (b) Anyone with an account can download the whole user directory and every invite code. This is the most serious item in this document.
- (c) The member-level rules let an assistant change money records directly: debts, client balances, sale totals, expenses, the receipt counter. The app never does these things for them, but the database allows it. Section 3(c) lists each one.

## 3. Options and proposals

### (a) Activity log in reports

- **(a1) Move it to an admin-only subdocument (recommended).** Store `dailyReports/{id}/private/activityLog` as `{entries, included}`, written once by the admin who generates the report. Rule: `read, create: isInFacility && isAdmin`; `update: false`; `delete: isAdmin`, for deleting a draft. `DailyReport.toMap` drops `activityLogEntries`, so `submitReport` no longer carries the log. The admin screens read the subdocument (1 extra read when a report is opened by an admin, 0 for an assistant). The report stays a frozen record of the day.
  - Also add to the `dailyReports` create/update rule: `!('activityLogEntries' in request.resource.data) || request.resource.data.activityLogEntries.size() == 0`.
- **(a2) Do not store it.** The admin screen queries `activity_logs` for the report's day, from start of day to `generatedAt`. It needs no new rule, since the `activity_logs` rule is already right. But the retention setting ("Keep logs for N days") would empty old reports' activity, and an admin-deleted entry would vanish from the record. That makes it a smaller change but a worse record.
- **Existing reports (both options):** a one-off script, `functions/scripts/move_report_activity.js` (Admin SDK, owner runs it, dry run by default). For each report it copies non-empty `activityLogEntries` into the subdocument (a1) or drops them (a2), then deletes the field with `FieldValue.delete()`. Submitted reports are immutable to the app, not to the Admin SDK. The report is written to a folder outside the repo, like `check_consistency.js`.
- **Tests (rules suite; the first three fail today, all pass after):**
  1. An assistant cannot `get` `private/activityLog`.
  2. A report created or updated with non-empty `activityLogEntries` is refused, for an assistant and for an admin.
  3. An assistant cannot write `private/activityLog`.
  4. An admin can read and create it.
  5. An assistant can still read and submit the report itself.
- **Old app versions:** an old admin app writes the field when it generates a report, so that generate is **refused** until the app is updated. An old assistant app submitting an old draft that still holds the field is refused until the script has run. Old app screens show "no activity" for new reports.
- **Rollout:** app first, then the script, then the rules. **Rollback:** revert the rules (the field is simply not written by the new app). The subdocuments are harmless to keep.

### (b) User profiles

- **(b1) Members of a shared facility only (recommended):**
  ```
  function myFacilityIds() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('facilityIds', []); }
  allow read: if isAuthenticated() && (request.auth.uid == userId || isPlatformAdmin() ||
    (isAdmin() && resource.data.get('facilityIds', []).hasAny(myFacilityIds())));
  ```
  - It reads the target from `resource.data`, so there is no second lookup. `users/{me}` is the same document `isAdmin()` already gets, and a rule pays for each path only once per request.
  - **Extra billed reads: 0 per get and 0 per query**, compared with today. Lookups per evaluation: 2 (`users/{me}`, `platform_admins/{me}`) of the 10 allowed.
  - Assistants stay as today: own profile only. The blank names on Payments for an assistant are unchanged, and would be a separate decision.
  - **Must be proven in the emulator first:** a LIST is allowed only if the rule follows from the query's filters. The app's `arrayContainsAny` (my facilities) and `arrayContains` (one facility) filters have to satisfy `hasAny(myFacilityIds())`. If the emulator refuses them, use (b2).
- **(b2) Same rule, plus a callable `listTeam(facilityId)`** in `functions/membership.js`, used by the 4 team screens. It returns only `uid, fullName, role, status, phone, avatarUrl, createdAt`, with no `facilities`/codes. More code, but it works for any query shape.
- **(b3, either way) Take the invite `code` out of `users.facilities`.** It is a server change in `registerOwner`/`addFacility` plus a cleanup script. A code belongs on the facility, readable by its admins through `inviteCodes` (`:447-455`).
- **Tests (rules suite; fixtures already have `outsider`, an admin of F2):**
  1. The outsider cannot `get` `users/owner` or `users/assistant`. Fails today.
  2. The outsider cannot run `collection('users').get()`. Fails today.
  3. The outsider cannot run the `arrayContainsAny ['F1']` query. Fails today.
  4. The owner and the Co-admin still run the Manage Assistants query and the `arrayContains F1` queries. Passes on both. This is the existing test at `firestore.rules.test.js:338`, extended.
  5. The owner can `get` `users/assistant`, and cannot `get` `users/outsider`.
- **Old app versions:** the same queries, so they are unaffected. Only reads outside the app are refused.
- **Rollout:** rules only, once test 4 passes. With (b2), app and functions first, then rules. **Rollback:** revert the one rule line.

### (c) Every rule broader than the app needs

| # | Rule (line) | What a member could do today | Sev. | Proposed tightening |
|---|---|---|---|---|
| C1 | `users` read (`134`) | see (b) | **High** | (b1) / (b2), (b3) |
| C2 | Rules never check `status` (`8-18`) | A **deactivated** or removed assistant keeps full database access with their token. The app signs them out, but the SDK or REST does not care. | **High** | In `membership.js` deactivate and remove, also `auth.updateUser(uid, {disabled: true})` + `revokeRefreshTokens` (reactivate re-enables). No rules latency. Test in the functions suite. |
| C3 | `dailyReports` read and update (`300-302`) | see (a); also rewrite any draft's figures, counts and cash before submit, or create a report for any date with invented numbers | Med | (a1). Update: `affectedKeys().hasOnly(['status','submittedAt','productMovement','paymentReconciliation','declarationConfirmed'])` and `status` becomes `'submitted'`. Prove that `submitReport`'s full `set` leaves the other values identical. |
| C4 | `debts` read, write (`247`) | Delete or zero any debt, or raise one (forgive a friend's debt, inflate a stranger's) | Med | Create: `clientId is string && amountOwed > 0`. Update: only `amountOwed`/`updatedAt`(/payment history), and only lower, `>= 0`. Delete: admin, or the same request lowers the client's balance (`getAfter(clients/{resource.data.clientId}).data.balance < get(...).data.balance`; +2 lookups, only on delete). Check every writer first (E1 and E2 transactions, Add Payment) as E1c did. |
| C5 | `clients` update (`242`) | Set any client's `balance` to 0 (they leave Active Debts) | Med | Changing `balance`/`oldestUnpaidDebtDate` needs a debt or payment write in the same request (`existsAfter`/`getAfter` on the deterministic `debts/sale_{id}`). Needs a writer audit; may move to E1-style server calls. Proposed as LATER if the audit shows it can't be expressed. |
| C6 | `sales`, `services` update (`221`, `231`) | Change any past sale's items, prices or total (daily summary trigger follows) | Med | An assistant only changes payment fields (`totalPaid`, the realized/unrealized profit fields `Sale.applyPayment` sets, `updatedAt`, `paymentStatus`); admins as today. Writer audit (`sale.dart:171`, Add Payment, service payments). |
| C7 | `transactions` create, update (`237`) | Edit any expense or income amount | Med | Update: admin, or `recordedBy == uid` on the same day. Check `add_transaction_screen.dart:107` gating first. |
| C8 | `batches` delete (`214`) | Delete stock batches outright (no Trash, no log) | Med | Delete: admin only. Writer check: `ProductProvider.deleteBatch` (`product_provider.dart:417`) from `view_batches_screen.dart:321`, and whether that screen allows assistants. |
| C9 | `counters` read, write (`348`) | Reset the receipt number (duplicate receipt numbers) or delete it | Low-Med | Write: `value` only grows; delete false. Check the writer at `lib/utils/receipt_numbering.dart:57`, which sets a given value. |
| C10 | `stockAdditions`, `stock_adjustments` create (`357`, `367`) | Add invented entries under another person's name | Low | Same shape as `activity_logs` (`:379`): own uid, `timestamp == request.time` (field names from their writers). |
| C11 | `payment_submissions` create (`328`) | Create a claim with any `status` (e.g. `approved`) | Low | `status == 'pending'` and submitter `== request.auth.uid`. Nothing on the server reads it automatically (no trigger), so only the review screen is misled. |
| C12 | `products` create (`209`) | An assistant creates products with any price (update of price is admin-only) | Low | Owner decides whether assistants may create products. If not: admin only. |
| C13 | `promotions` read (`435`); `public_announcements`, `app_config`, `platform_config` read `true` (`419`, `427`, `431`) | Read by any account or by anyone | Low | By design (login poster, announcements). Check that `platform_config` holds nothing private. No change proposed. |
| C14 | `isAdmin()` is global (`19`) | An admin who is also listed in another facility is an admin there too | Low | Membership decides `facilityIds` on the server, so this needs a server bug first. Note only. |

Not broader than needed: facilities, invite codes, payments update/delete, activity log create (`:379`, which fixes CLAUDE.md's open item; that note is stale), trash (admin), archives, summaries, notifications and platform admins.

**Tests for C2-C12:** for each, one test that does the forbidden write as `assistant` (fails today, refused after) and one that does the app's own write (passes on both). C2's tests go in the functions suite (`cd functions && npm test`).

**Old app versions (C3-C12):** each tightening is written to allow exactly what the current app writes, after the writer audit. An app older than E1 (non-transaction sale, separate debt writes) may be refused on the debt and balance writes. The owner decides whether to wait until every device is updated.

**Rollout:** one rule group per commit with its tests (rules suite before and after, `git diff firestore.rules`). App changes, if any, are deployed first, then the rules, as in CLAUDE.md. **Rollback:** revert that rule group. The data is untouched.

## 4. Recommendation and priority

1. **C1 / (b1)**, rules only. If the emulator refuses the list proof, then (b2). Then (b3) to stop invite codes riding on profiles. Highest severity, smallest change.
2. **C2**, disable the Auth account on deactivate and remove (server).
3. **(a1) + C3**, report log in an admin-only subdocument, the script for old reports, and draft update limited to the submit fields.
4. **C4, C6, C7, C8**, money and stock writes limited to what each role's app path writes (after a writer audit like E1c).
5. **C9, C10, C11, C12**, low severity, one commit together.
6. **C5**, only if C4's `getAfter` pattern works for balances; otherwise LATER, with server-side payments.
7. C13, C14: no change.

**Files that would change:** `firestore.rules`, `firestore_rules_tests/firestore.rules.test.js`, `functions/membership.js` (C2, b2, b3) with its tests, `lib/services/daily_report_service.dart`, `lib/models/daily_report.dart`, the two report screens, `functions/scripts/move_report_activity.js` (new), and possibly the team screens (b2). Not `pubspec.yaml`, and no new index (b2's callable reads with the Admin SDK).

OWNER DECISION: APPROVED, in four batches, each with its own rules tests and the owner's deploy step. The system has no customers and the owner is the only tester, so there is NO need for backward compatibility with old app versions and NO need for data-migration scripts (test data may simply be cleaned or recreated); the writer audits and the tests stay mandatory. E4a: (b1) the users read rule, falling back to (b2) listTeam only if the emulator refuses the app's real list queries, plus ALL Storage rules tightened at once (payment_proofs readable only by members of that facility and Platform Admins; avatars and user_avatars writable only by the person whose uid is in the file name; facility_logos writable only by a member of that facility; an image content type and a size limit on every upload path), after auditing the exact file names the app uses. E4b: (b3) the invite code out of users.facilities (audit every reader first, no cleanup script), C2 disabling the Auth account only when the person has no active membership left, with revokeRefreshTokens, and a read-only review of every callable function's authorization (what each one checks, and a list of any that checks too little). E4c: (a1) the report activity log in an admin-only subdocument, and C3 with submitReport changed to update only the submit fields. E4d: C4, C6, C7, C8, then C9 to C12, each rule group in its own commit after its writer audit. C5 stays LATER unless C4's pattern works. C13 and C14 unchanged. A minimum app version gate is LATER, before the first customer.
