# E4b: authorization review of every callable function

Batch E4b (RUNBOOK2 section 4), part 3: read-only, no code changed by this review. Line numbers are at `2a9f947` (after E4b's own changes). Found by searching `functions/index.js` and `functions/membership.js` for `onCall` and `onRequest`: **17 callables, 0 request (`onRequest`) functions.** The other exports are Firestore triggers and schedules, which no client can call (listed at the end).

Every callable is open to be *called* by anyone (the deploy grants that for callables, and `checkInviteCode` needs it). What protects the data is the check inside each function, because each one uses the Admin SDK and so bypasses `firestore.rules` entirely.

## Shared checks (membership.js)

| Helper | What it checks | Line |
|---|---|---|
| `requireAuth` | signed in (`context.auth`) | `membership.js:149` |
| `isActiveAdmin` | `role == 'admin'` and status not `deactivated` | `membership.js:84` |
| `assertCanManageFacility` | active admin with the facility in `facilityIds`, or a `platform_admins/{uid}` document | `membership.js:218` |
| `loadCallerAdmin` | active admin (inside the transaction) | `membership.js:595` |
| `assertAssistantInYourFacilities` | the target is `role == 'assistant'` and shares a facility with the caller | `membership.js:602` |
| `inviteProblem` | invite exists, unused, unexpired, has a facility | `membership.js:63` |

All membership callables reach these through `membershipCallable` (`index.js:1619`), 2nd gen, `africa-south1`.

## The table

| # | Function | Who may call it | What it checks | Where | Verdict |
|---|---|---|---|---|---|
| 1 | `checkInviteCode` | anyone, signed in or not | nothing about the caller (by design: sign-up checks a code before the account exists); answers only valid + facility name and type, never the id | `membership.js:285`, export `index.js:1628` | Sufficient (no rate limit: see LATER 11) |
| 2 | `registerOwner` | any signed-in account with no profile | signed in; profile must not exist (in the transaction); facility count from platform settings; input cleaned | `membership.js:301` | Sufficient (anyone may become the admin of a new facility of their own, by design) |
| 3 | `joinWithInvite` | any signed-in account with no profile | signed in; no profile; invite valid; facility exists; role and status forced to assistant / pending | `membership.js:368` | Sufficient |
| 4 | `joinFacilityWithInvite` | an assistant in no facility | signed in; profile exists; `role == 'assistant'`; no `facilityIds`; invite valid | `membership.js:438` | Sufficient (since C2 a removed assistant is disabled and cannot sign in to use it; owner's choice) |
| 5 | `addFacility` | an active admin | signed in; `isActiveAdmin`; facility limit, in the transaction | `membership.js:494` | Sufficient (a Co-admin can add one, by design and tested) |
| 6 | `createInviteCode` | an active admin of that facility, or a Platform Admin | signed in; `assertCanManageFacility`; facility exists | `membership.js:537` | Sufficient |
| 7 | `reassignAssistant` | an active admin of both facilities | signed in; `loadCallerAdmin`; `assertAssistantInYourFacilities`; caller administers the new facility | `membership.js:640` | Sufficient |
| 8 | `removeAssistantFromFacility` | an active admin of that facility | signed in; `loadCallerAdmin`; `assertAssistantInYourFacilities`; caller and assistant both in that facility | `membership.js:670` | Sufficient |
| 9 | `setAssistantStatus` | an active admin sharing a facility with the assistant | signed in; `loadCallerAdmin`; `assertAssistantInYourFacilities`; the action must fit the current status | `membership.js:721` | Sufficient |
| 10 | `syncFacilityDetails` | an active admin of that facility, or a Platform Admin | signed in; `assertCanManageFacility` | `membership.js:849` | Sufficient (it only copies the facility's own name and type) |
| 11 | `revokeAllSessions` | any signed-in person, for themselves | signed in; acts only on `context.auth.uid` | `index.js:501` | Sufficient |
| 12 | `wipeFacilityData` | an admin in that facility | signed in; `role == 'admin'`; facility in `facilityIds` | `index.js:542`, checks `:561-577` | **Too weak** (W3) |
| 13 | `deleteFacility` | a Platform Admin | signed in; `platform_admins/{uid}` exists; facility exists | `index.js:905`, check `:924` | Sufficient |
| 14 | `deleteOwnFacility` | the facility's creator | signed in; `facility.createdBy == uid`; no assistant left in it | `index.js:1021`, checks `:1048`, `:1058-1070` | Needs a closer look (W4) |
| 15 | `removeAssistant` | any signed-in account | signed in; then, ONLY if the profile exists: target is an assistant, caller `role == 'admin'`, shares a facility | `index.js:1143`, `:1161-1209` | **Too weak** (W2). Not called by the app |
| 16 | `platformRemoveUser` | a Platform Admin | signed in; Platform Admin; target not a Platform Admin; target `status == 'deactivated'` | `index.js:1254`, `:1271-1314` | Sufficient (the no-profile branch deletes any uid's Auth account, but only for a Platform Admin) |
| 17 | `sendAssistantCredentials` | **anyone, not even signed in** | **nothing**: no `context.auth`, no input check | `index.js:23` (1st gen, `us-central1`) | **Too weak** (W1). Not called by the app |

Called by the app (checked by searching `lib/` for `_call('` and `httpsCallable('`): 1-14 and 16. Not called: 15 `removeAssistant` and 17 `sendAssistantCredentials`, both left over from before the membership functions.

## Too weak, with proposed fixes

- **W1 `sendAssistantCredentials` (High).** Anyone on the internet can call it with any `email`, `name` and `password` text and the project's Gmail account sends "VetBiz Assistant Login Credentials" to that address: a ready-made phishing relay under the business's name, and a way to burn the Gmail account's sending reputation and quota. **Fix:** delete the export (nothing calls it; invite codes replaced it), and remove the `GMAIL_USER`/`GMAIL_PASS` secrets if nothing else uses them. Test: `endpoints.test.js` asserts it is no longer exported.
- **W2 `removeAssistant` (High).** When `users/{assistantUid}` does not exist, it calls `admin.auth().deleteUser(assistantUid)` **before any permission check** (`index.js:1161-1177`). Any signed-in account can delete the Auth account of anyone with no profile: an owner between account creation and `registerOwner`, a Platform Admin with no `users` document, an account whose profile was removed. When the profile exists, a deactivated admin still passes (`role == 'admin'` only, `:1192`), and it deletes the profile outright, bypassing the membership rules. **Fix:** delete the export (the app uses `removeAssistantFromFacility`, and `platformRemoveUser` for full removal). If it must stay: Platform Admin only, and no Auth delete without a profile check. Test: not exported (endpoints test).
- **W3 `wipeFacilityData` (Medium).** Checks `role == 'admin'` but not status (`index.js:564`), so a deactivated admin still in `facilityIds` can wipe every record of the facility, irreversibly. Any Co-admin can too. **Fix:** require an active admin (`isActiveAdmin`), and the facility's creator (`createdBy == uid`) or a Platform Admin, matching `deleteOwnFacility`. Owner decides whether a Co-admin may wipe. Tests: deactivated admin refused; Co-admin refused (if decided); creator allowed.

## Needs a closer look

- **W4 `deleteOwnFacility`.** `createdBy == uid` only: a creator who was later deactivated (by a Platform Admin) or demoted can still delete the facility and everything in it. Proposed: also require `isActiveAdmin`. Low risk while the owner is the only admin of their facilities.
- **W5 Platform Admin deactivation** (`lib/screens/platform_admin/user_detail_screen.dart:207`) writes `status` from the app, so it does **not** disable the Auth account the way C2 now does for facility admins. Proposed: move it to a callable (Platform Admin only) that sets the status and calls the same `setSignInAccess`.
- **W6 1st gen callables in `us-central1`** (11-17): not an authorization gap, but they run far from the database and `endpoints.test.js` covers only the membership ones. Moving them to `africa-south1` 2nd gen is a separate change.

## Not callable (no client can invoke them)

Triggers: `updateDailySalesSummary`, `updateDailyCollections`, `updateDailyServiceSummary`, `updateDailyTransactionSummary`, `notifyOnPaymentReceived`, `notifyOnServiceRecorded`, `notifyOnNewClient`, `notifyOnProductStatusChange`, `syncFacilityDetailsOnWrite`. Schedules: `archiveOldSales`, `archiveOldServices`, `purgeOldTrash`, `recordDailySnapshots`, `checkSubscriptionExpiry`. Their input is data that already passed `firestore.rules`.

## Recommendation

W1 and W2 first, one commit (delete two unused exports, with an endpoints test), then W3, then W5 with W4. All are server-only (`functions/`), deployed with `firebase deploy --only functions`; rollback is a redeploy of the previous commit.

OWNER DECISION: APPROVED. W1 and W2: delete both exports (sendAssistantCredentials, removeAssistant), with an endpoints test that they are no longer exported, and remove the GMAIL_USER and GMAIL_PASS references if nothing else uses them. W3: wipeFacilityData requires an active admin who is the facility's creator (createdBy == uid) or a Platform Admin; a Co-admin and a deactivated admin are refused. W4: deleteOwnFacility also requires an active admin. W5: the Platform Admin's deactivation and reactivation move to a Platform-Admin-only callable that sets the status and calls the same sign-in switch as C2. W6 stays LATER. Change to C2: removing an assistant from their only facility only revokes their sessions (revokeRefreshTokens) and does NOT disable their account, so they can still join another facility with an invite code; deactivation still disables, and reactivation still enables. When setSignInAccess reports "failed", the admin sees a clear AppFeedback warning ("The assistant was deactivated, but their sign-in could not be switched off. Reactivate and deactivate again.") with a Kiswahili draft marked draft.
