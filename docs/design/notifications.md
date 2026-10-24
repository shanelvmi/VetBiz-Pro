# NOTIF-1: notification actions, removal and lifetime (DESIGN STOP)

Owner request: every notification gets a "more" menu (Remove, Mark as read or unread); a way to remove many at once; a sensible lifetime; subscription-expired and similar items always shown until resolved; offers handled sensibly. No code or rules change in this batch.

## 1. Current state (from the code, 2026-10-24)

**Where they live.** `facilities/{fid}/notifications/{id}`, one document per event. `FacilityNotification` (`lib/models/notification_model.dart`): `type`, `title`, `message`, `createdAt`, `readAt`, `expiresAt`, `relatedEntityType/Id`, `audience` (`all` | `admins` | `user`), `targetUserId`, `excludeUserId`. `isVisibleTo` decides who sees a document (display only, not access control).

**Read state is per FACILITY, not per person.** `readAt` sits on the shared document. One person's "Mark all as read" marks it read for everyone. The only read action is Mark all as read (`notifications_screen.dart:282`). There is no per-row read, no unread, and no remove.

**Two lifecycles (`isCurrentlyVisible`).**
- Ephemeral (`expiresAt` null): in the dropdown and the "Needs Attention"/"Earlier" lists only while unread.
- Persistent (`expiresAt` set): until `expiresAt`, read or not.

The full screen's history keeps read items and drops expired ones. It loads the newest 200 documents (the dropdown 50), with client-side search, filters and pages.

**Rules (`firestore.rules:405-409`).**
- Read: any member.
- Create: Platform Admin only. The Admin SDK bypasses rules.
- Update: any member, and `readAt` is the only field allowed to change (`isOnlyMarkingNotificationRead`).
- Delete: nobody from the app. The server deletes two kinds (see the table).

Counts today: `match` 39, `allow` 100, `function` 20.

**Rows built by the client (never stored).**
- **`subscription_expiring`:** `_reconcileSubscription` replaces the stored document (fixed id, written daily at 00:30 by `checkSubscriptionExpiry`, `expiresAt` = now + 2 days, deleted when renewed) with `SubscriptionProvider.attentionNoticeShown`.
  - Escalation: `hasEscalated = stored.message != attentionNotice.message`, comparing English text. When it is true, the row shows as new and unread again.
  - With no document yet, the row is inserted already marked read: it has no id to mark.
- **`trial_status`:** `SubscriptionProvider.trialInfoNotice` during a calm trial. Shown as read, `expiresAt` = now + 2 days, rebuilt on every change.

**Bell (`dashboard_screen.dart:2370-2440`).** A coloured dot, not a number.
- **Red:** any stored notification that is visible to me, unread and not expired; or something new since this device last opened Notifications (urgent `public_announcements`, a pending assistant; `NotificationSeenTracker`, stored per device).
- **Blue:** the calm trial (`isInCalmTrial`).
- **Accent:** an active promotion (`streamApplicablePromotion`, read live, not from the notification).

| Type | Created by | Who sees it | Stored or derived | What clears it today |
|---|---|---|---|---|
| criticalStock, lowStock, reorderSoon, restockShelf | `notifyOnProductStatusChange` (functions/index.js) on a worse status | everyone | stored, ephemeral | read by anyone; stays in history (200 window) |
| paymentReceived | `notifyOnPaymentReceived` | everyone | stored, ephemeral | read by anyone |
| serviceRecorded, newClient | `notifyOnServiceRecorded`, `notifyOnNewClient` | everyone | stored, ephemeral ("Earlier") | read by anyone |
| assistantPending | `membership.js` `notify` (register, join) | admins | stored, ephemeral | the server deletes it when approved, rejected or the person leaves; or read |
| roleChanged | `RoleChangeService._notify` (Platform Admin, app) | admins or the one person, `excludeUserId` | stored, ephemeral | read by anyone |
| subscription_rejected | operator `_reject` (Platform Admin, app) | everyone | stored, ephemeral | read by anyone; nothing resolves it |
| promotion | `_notifyFacilitiesOfPromotion` (`lib/models/promotion.dart:171`, Platform Admin) | everyone | stored; persistent until `endsAt` (ephemeral if no end) | `expiresAt` passes; read does not hide it |
| subscriptionExpiring | `checkSubscriptionExpiry` (daily) + the live row | everyone | stored + derived | the server deletes it when renewed; the live row vanishes at once |
| trialStatus | client (`trialInfoNotice`) | everyone | derived | the trial is no longer calm |
| urgent announcement | Platform Admin (`public_announcements`, urgent) | everyone | separate collection, shown in the dropdown | `hidden` set by the Platform Admin |
| trialStarted (legacy), debtReminder, productExpiry, general | nobody now (legacy, or types with no writer) | - | - | trialStarted is never shown |

Categories (filter tabs): critical, stock, payment, debt, system, other ("Updates").

## 2. Policy (assistant's defaults, for the owner to approve or change)

| Class | Types | Remove | Read/unread | Leaves the list |
|---|---|---|---|---|
| PERSISTENT | subscriptionExpiring (expiring, grace, locked), trialStatus, assistantPending, subscription_rejected | not offered while the condition holds | allowed (quiets the bell) | when resolved: renewed; trial over; decision made; rejection followed by a newer claim (pending or approved) |
| DISMISSIBLE | promotion, urgent announcement | yes, for me | yes | at `endsAt` (an offer with no end: as ROUTINE); a NEW promotion or an edited announcement shows again |
| ROUTINE | stock (4 types), paymentReceived, serviceRecorded, newClient, roleChanged, general | yes, for me | yes | read: 30 days after I read it; unread: 90 days after it was created |

Rules of the policy:
- **P1. Removal is per person.** It never deletes the document and never hides it from the other admins.
- **P2. Read becomes per person too** (recommended, owner decision D2). Otherwise my "Mark as read" hides an item from the other admin, which is the problem removal is meant to avoid. Documents read before the change keep their shared `readAt` as "read" for everyone (no migration).
- **P3. A persistent item re-escalates:** a new stage (expiring, then grace, then locked) is unread again for everyone, even if read.
- **P4. Lifetimes are measured on the device's clock.** The 30 days run from MY read time.

**Data design (recommended: one state document per person per facility).**
`facilities/{fid}/notificationState/{uid}` holds:
- `read: {notificationId: Timestamp}`;
- `unread: {notificationId: true}` (marked unread over a shared legacy `readAt`);
- `removed: {notificationId: Timestamp}`;
- `seenStage: {subscription_expiring: 'grace'}`;
- `updatedAt`.

Why one document:
- one listener gives the bell and the screen everything;
- a bulk action is one write, atomic, and Undo is the reverse write;
- entries for documents older than 120 days are pruned on each write, so the document stays far under 1 MB.

Rejected alternatives:
- **(b) A subcollection, one document per notification per person:** scales without a limit, but a bulk removal of 50 items is 50 writes, and the screen needs a second query.
- **(c) `removedBy`/`readBy` arrays on the shared document:** the rule can limit each person to adding their own uid, but every member can read everyone's arrays, and writes contend on popular documents.

**Who may write (`firestore.rules`):** `match /notificationState/{uid}`: read and write only if `request.auth.uid == uid && isInFacility(facilityId)`; keys `hasOnly(['read','unread','removed','seenStage','updatedAt'])`; delete allowed to the owner. `notifications` stays as it is; the shared `readAt` update stays for old app versions during rollout.

**Auto-expiry: a client-side age filter (recommended) plus an optional server cleanup.**
- The filter applies P4 when building the lists and the bell. It needs no deploy, works offline, and is exact per person. Its cost: old documents stay in Firestore and still fill the 200 window.
- A scheduled function (daily, like `checkSubscriptionExpiry`) would delete ROUTINE documents older than 120 days. That bounds storage and the window, but it is a functions change and an owner deploy, it deletes for everyone (fine after 120 days), and it is not exact per person. Recommended as a separate, later batch (NOTIF-2e).

## 3. UI

- **A "more" menu (three dots) on every row** (dropdown and full screen):
  - **Mark as read / Mark as unread:** whichever applies.
  - **Remove:** hidden on PERSISTENT items. In its place, an inactive line explains why, e.g. "Stays until the subscription is renewed".
  - **Open:** when the row links to a record.
  - Tapping a row marks it read for me (today nothing does).
- **Phone width (under `AppBreakpoints.compact`):** swipe left to Remove (ROUTINE and DISMISSIBLE only), swipe right to toggle read. The menu stays, because swipes are not discoverable.
- **Header (full screen and dropdown):**
  - **Mark all as read** (already exists; becomes per person);
  - **Remove read ones:** removes my read ROUTINE and DISMISSIBLE items, never PERSISTENT;
  - selection mode on the full screen (checkboxes, "Remove selected").
  - There is no "Delete everything".
- **Bulk removal:** a confirmation ("Remove 12 read notifications? Only you stop seeing them."), then `AppFeedback.undo` ("12 notifications removed" + Undo, about 6 s). Undo restores the previous `removed` entries. A single Remove has no dialog, only the Undo toast.
- **Empty state, in plain words:** keep "No notifications" and "New updates from your facility will appear here." (`notifications_empty`, `notifications_emptyHint`). No "all caught up" cheer. After a filter: "No notifications match your filters" (exists).
- **Bell:**
  - A number when anything unread needs me: unread items, visible to me, not removed, not expired, within the policy lifetimes. Shown 1-9, then "9+".
  - Persistent items count until I read them in their current stage.
  - Blue (trial) and accent (promotion) stay as dot colours, without a number. A dismissed promotion no longer lights the accent for me.
  - The per-device "new since viewed" blink stays for urgent announcements only.
- **New texts** go through the ARB (English given here as proposals: "Remove", "Mark as unread", "Remove read ones", "{count} notifications removed", the confirmation, the persistent reasons), with Kiswahili drafts. "Mark as read" may reuse existing keys if the English is identical.

## 4. Edge cases

- **A removed item whose escalation changes:** PERSISTENT items cannot be removed, so this only concerns read state. A new stage clears my `seenStage` match and the item is unread again (P3). Today's comparison of the English message is replaced by a stage key (`expiring` / `grace` / `locked`), so a day count changing within "expiring" does not re-alert daily, and a language switch cannot trip it.
- **Two admins:** A removes or reads; B still sees the item unread (P1, P2). The server's deletion of assistantPending after a decision still removes it for both.
- **Offline:** state writes are queued by Firestore's offline cache and applied optimistically on screen; Undo works offline (a second write). A conflict between two devices of the same person: the last write wins per field; maps are merged with `SetOptions(merge: true)` and dotted keys, so two removals on two phones both survive.
- **A very long list:** the query stays `orderBy(createdAt desc)` with a window. The full screen gains "Load older" (cursor `startAfter`, 100 at a time) because removed and expired items now use up the window. The dropdown keeps 50. The state document is pruned (120 days).
- **Old data:** documents written before rollout have no state.
  - A shared `readAt` counts as read for everyone; P4 then hides them 30 days after that `readAt`. Many old read items vanish on the first day (expected; say so in the release note).
  - Old promotions with no `endsAt` become ROUTINE.
  - The legacy trialStarted stays hidden.
  - Nothing is deleted by the app.
- **An assistant:** the same rules for what they can see (audience). Their removals are their own.
- **A person who leaves the facility:** their state document is no longer readable (`isInFacility`) and is harmless. The server could delete it on removal (later; `membership.js`).

## 5. Tests, rules, rollout, batches

**Flutter tests written first; each fails today:**
1. The policy (pure Dart, `NotificationPolicy.classOf(type)`): the table in section 2, pinned type by type, including subscription_rejected staying until a newer claim exists.
2. Lifetimes: read ROUTINE hidden 30 days after MY read; unread hidden after 90 days; a promotion hidden after `endsAt`; PERSISTENT never hidden by age.
3. Per person: user A removes an item; user B's list (same fake Firestore) still shows it; A's "Mark as read" leaves B unread.
4. The more menu on a row: Remove present for ROUTINE, absent for subscriptionExpiring, assistantPending, trialStatus; Mark as unread toggles.
5. "Remove read ones" leaves PERSISTENT items; the confirmation, then Undo, restores the list exactly.
6. Escalation: read at stage `expiring`, then `grace`: unread again; read at "7 days", then "6 days": still read.
7. Bell: the count follows 2 to 6; a removed or read item does not count; a number above 9 shows "9+".
8. Swipe at 390 px removes a ROUTINE row; swipe does nothing on a PERSISTENT one.

**Rules, emulator tests written first** (they fail on today's rules: no match for `notificationState`):
- a member reads and writes their own state document;
- another member (admin or assistant) cannot read or write it;
- a non-member cannot;
- an unknown key is refused;
- `notifications` documents still cannot be deleted from the app;
- the shared `readAt` update still works (old app versions).

Expected counts: `match` 39 to 40, `allow` 100 to 102, `function` 20 to 20 or 21.

**Rollout:** these rules only add, so they go out BEFORE the app (unlike the usual order). An old app keeps working; a new app without the rule would fail every state write.
1. `firebase deploy --only firestore:rules`, after the rules tests pass.
2. The app.
3. Later, NOTIF-2e: `firebase deploy --only functions` (the cleanup).

No index is needed (no new query shape).

**Rollback:**
- **App:** revert the batch commits. The state documents are ignored and lists fall back to the shared `readAt`.
- **Rules:** leaving the added match is harmless; removing it means re-deploying the previous `firestore.rules`.
- **Cleanup function:** `firebase functions:delete <name>`. What it deleted cannot come back; it only touches ROUTINE documents older than 120 days.

**Proposed batches (each 300 lines or fewer per commit, tests first):**
- **NOTIF-2a:** rules and emulator tests for `notificationState` (HARD STOP: deploy rules).
- **NOTIF-2b:** `NotificationPolicy` and lifetimes, pure Dart, plus the state model and service (fake Firestore tests 1-3, 6).
- **NOTIF-2c:** screen and dropdown: the more menu, tap to read, swipe, header actions, confirmation and Undo, Load older, texts with Kiswahili drafts (tests 4, 5, 8; HARD STOP, Chrome and phone).
- **NOTIF-2d:** the bell count from the same policy (test 7).
- **NOTIF-2e (optional):** the scheduled cleanup function and its tests (functions deploy).

**Decisions for the owner** (defaults as above):
- **D1:** the class of each type (section 2 table).
- **D2:** read becomes per person.
- **D3:** 30 and 90 days.
- **D4:** a number on the bell.
- **D5:** urgent announcements are DISMISSIBLE.
- **D6:** NOTIF-2e (server cleanup at 120 days), yes or no.

OWNER DECISION: PENDING
