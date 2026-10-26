// Allowed / denied tests for ../firestore.rules, run against the Firebase
// emulator - never against the real project (the project id starts with
// "demo-", which the emulator treats as fully offline).
//
// WHY THIS EXISTS: a rules change that looks right can silently break a
// screen (an earlier tightening of the facilities rule did exactly that to
// Manage Assistants), and the only way to find out used to be deploying it.
// Run these BEFORE `firebase deploy --only firestore:rules`.
//
//   cd firestore_rules_tests
//   npm install                                   (once)
//   cd ..
//   firebase emulators:exec --only firestore --project demo-vetbiz-rules "npm --prefix firestore_rules_tests test"
//
// These test the RULES. The server functions that now do the privileged
// writes (registering, joining, adding a facility...) have their own tests:
// cd functions && npm test

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
// The compat SDK the test contexts use, for FieldValue.serverTimestamp().
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const serverTime = () => firebase.firestore.FieldValue.serverTimestamp();

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vetbiz-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

const tomorrow = () => new Date(Date.now() + 24 * 60 * 60 * 1000);

// Two separate businesses, so "someone else's" is always a real other
// business:
//   Facility F1 (Ukuli Agrovet) - owner, a Co-admin, an Assistant
//   Facility F2 (Other Vet)     - its own owner ("outsider")
// plus a Platform Admin and a brand-new account with no profile at all.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const f1 = [{ facilityId: 'F1', name: 'Ukuli', type: 'Agrovet', code: 'AAAA1111' }];
    const f2 = [{ facilityId: 'F2', name: 'Other Vet', type: 'Vet Clinic', code: 'BBBB2222' }];
    const user = (uid, data) => db.collection('users').doc(uid).set({ uid, status: 'active', ...data });

    await user('owner', { fullName: 'Asha Owner', role: 'admin', facilityIds: ['F1'], facilities: f1 });
    await user('coadmin', { fullName: 'Juma Coadmin', role: 'admin', previousRole: 'assistant', facilityIds: ['F1'], facilities: f1 });
    await user('assistant', { fullName: 'Neema Assistant', role: 'assistant', facilityIds: ['F1'], facilities: f1 });
    await user('outsider', { fullName: 'Omar Outsider', role: 'admin', facilityIds: ['F2'], facilities: f2 });
    await user('pa', { fullName: 'Platform Admin', role: 'admin', facilityIds: [], facilities: [] });
    await db.collection('platform_admins').doc('pa').set({ email: 'pa@example.com' });

    await db.collection('facilities').doc('F1').set({
      name: 'Ukuli', type: 'Agrovet', code: 'AAAA1111', createdBy: 'owner',
      trialExpiresAt: new Date(2026, 9, 19), subscriptionPlan: 'basic', subscriptionExpiresAt: new Date(2027, 0, 1),
    });
    await db.collection('facilities').doc('F2').set({ name: 'Other Vet', type: 'Vet Clinic', code: 'BBBB2222', createdBy: 'outsider' });

    const invite = (code, facilityId) =>
      db.collection('inviteCodes').doc(code).set({
        facilityId, facilityName: 'x', facilityType: 'y', createdByUserId: 'owner',
        expiresAt: tomorrow(), usedAt: null, usedByEmail: null,
      });
    await invite('ABC123', 'F1');
    await invite('ZZZ999', 'F2');

    const payment = (facilityId, id) =>
      db.collection('facilities').doc(facilityId).collection('payments').doc(id).set({
        clientId: null, amount: 5000, timestamp: new Date(), paidById: 'assistant',
      });
    await payment('F1', 'p1');
    await payment('F2', 'p2');

    // Activity log entries: one the OWNER did about someone else (an admin
    // matter), one the ASSISTANT did, one the owner did ABOUT the assistant,
    // and one in another business entirely.
    const log = (facilityId, id, data) =>
      db.collection('facilities').doc(facilityId).collection('activity_logs').doc(id)
        .set({ timestamp: new Date(), actionType: 'Sale', description: 'x', ...data });
    await log('F1', 'L-admin-matter', { userId: 'owner', userName: 'Asha', actionType: 'Account', description: 'Rejected assistant Baraka', targetUserId: 'someone' });
    await log('F1', 'L-by-assistant', { userId: 'assistant', userName: 'Neema', description: 'Sale recorded' });
    await log('F1', 'L-about-assistant', { userId: 'owner', userName: 'Asha', actionType: 'Account', description: 'Approved assistant Neema', targetUserId: 'assistant' });
    await log('F2', 'L-other-business', { userId: 'outsider', userName: 'Omar' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();
const users = (uid) => as(uid).collection('users');
const facilities = (uid) => as(uid).collection('facilities');
const payments = (uid, facilityId) => as(uid).collection('facilities').doc(facilityId).collection('payments');

// ======================================================================
// INVITE CODES - the app no longer reads or writes one directly, except an
// Admin looking at / revoking their OWN facility's. The server checks codes
// (checkInviteCode), creates them (createInviteCode) and uses them up
// (joinWithInvite).
// ======================================================================

test('invite codes: a signed-out visitor can NOT fetch one, nor list them (the server checks codes now)', async () => {
  await assertFails(signedOut().collection('inviteCodes').doc('ABC123').get());
  await assertFails(signedOut().collection('inviteCodes').get());
});

test('invite codes: a brand-new signed-in account can NOT fetch or list them', async () => {
  await assertFails(as('newbie').collection('inviteCodes').doc('ABC123').get());
  await assertFails(as('newbie').collection('inviteCodes').get());
});

test('invite codes: an admin of another business can NOT fetch or list them, even filtered', async () => {
  await assertFails(as('outsider').collection('inviteCodes').doc('ABC123').get());
  await assertFails(as('outsider').collection('inviteCodes').get());
  await assertFails(as('outsider').collection('inviteCodes').where('facilityId', '==', 'F1').get());
});

test('invite codes: an assistant can NOT fetch or list them', async () => {
  await assertFails(as('assistant').collection('inviteCodes').doc('ABC123').get());
  await assertFails(as('assistant').collection('inviteCodes').where('facilityId', '==', 'F1').get());
});

test('invite codes: the owner CAN run the exact query Manage Assistants runs', async () => {
  await assertSucceeds(
    as('owner').collection('inviteCodes').where('facilityId', '==', 'F1').where('usedAt', '==', null).get()
  );
  await assertSucceeds(as('owner').collection('inviteCodes').doc('ABC123').get());
});

test('invite codes: a Co-admin CAN list their own facility\'s codes', async () => {
  await assertSucceeds(as('coadmin').collection('inviteCodes').where('facilityId', '==', 'F1').get());
});

test('invite codes: a Platform Admin can fetch and list them', async () => {
  await assertSucceeds(as('pa').collection('inviteCodes').get());
  await assertSucceeds(as('pa').collection('inviteCodes').doc('ABC123').get());
});

test('invite codes: NOBODY can create or change one from the app (the server does, with the Admin SDK)', async () => {
  const code = { facilityId: 'F1', usedAt: null, expiresAt: tomorrow() };
  await assertFails(as('owner').collection('inviteCodes').doc('NEW111').set(code));
  await assertFails(as('coadmin').collection('inviteCodes').doc('NEW222').set(code));
  await assertFails(as('assistant').collection('inviteCodes').doc('NEW333').set(code));
  await assertFails(as('newbie').collection('inviteCodes').doc('NEW444').set(code));
  await assertFails(signedOut().collection('inviteCodes').doc('NEW555').set(code));
  // ...nor "use one up" - that happens inside joinWithInvite, atomically.
  await assertFails(as('assistant').collection('inviteCodes').doc('ABC123').update({ usedAt: new Date(), usedByEmail: 'a@b.c' }));
  await assertFails(as('owner').collection('inviteCodes').doc('ABC123').update({ expiresAt: new Date(2099, 0, 1) }));
});

test('invite codes: a Platform Admin can create and change them', async () => {
  await assertSucceeds(as('pa').collection('inviteCodes').doc('PA1234').set({ facilityId: 'F1', usedAt: null, expiresAt: tomorrow() }));
  await assertSucceeds(as('pa').collection('inviteCodes').doc('ABC123').update({ usedAt: new Date() }));
});

test('invite codes: the owner can revoke (delete) their own code; an outsider and an assistant can not', async () => {
  await assertFails(as('outsider').collection('inviteCodes').doc('ABC123').delete());
  await assertFails(as('assistant').collection('inviteCodes').doc('ABC123').delete());
  await assertSucceeds(as('owner').collection('inviteCodes').doc('ABC123').delete());
});

// ======================================================================
// PAYMENTS
// ======================================================================

test('payments: the owner can edit and delete their facility\'s payments', async () => {
  await assertSucceeds(payments('owner', 'F1').doc('p1').update({ amount: 6000 }));
  await assertSucceeds(payments('owner', 'F1').doc('p1').delete());
});

test('payments: a Co-admin can edit their facility\'s payments', async () => {
  await assertSucceeds(payments('coadmin', 'F1').doc('p1').update({ amount: 6000 }));
});

test('payments: an admin of ANOTHER business can NOT edit or delete them', async () => {
  await assertFails(payments('outsider', 'F1').doc('p1').update({ amount: 1 }));
  await assertFails(payments('outsider', 'F1').doc('p1').delete());
});

test('payments: an assistant can NOT edit or delete (admins only)...', async () => {
  await assertFails(payments('assistant', 'F1').doc('p1').update({ amount: 1 }));
  await assertFails(payments('assistant', 'F1').doc('p1').delete());
});

test('payments: ...but can still RECORD one for their own facility', async () => {
  await assertSucceeds(
    payments('assistant', 'F1').add({ clientId: null, amount: 100, timestamp: new Date(), paidById: 'assistant' })
  );
});

test('payments: a Platform Admin can delete one', async () => {
  await assertSucceeds(payments('pa', 'F1').doc('p1').delete());
});

// ======================================================================
// USERS - delete
// ======================================================================

test('users delete: a person can delete their OWN record (Delete Account) - assistant and admin alike', async () => {
  await assertSucceeds(users('assistant').doc('assistant').delete());
  await assertSucceeds(users('owner').doc('owner').delete());
});

test('users delete: an admin can NOT delete someone else, in their own facility...', async () => {
  await assertFails(users('owner').doc('assistant').delete());
  await assertFails(users('owner').doc('coadmin').delete());
});

test('users delete: ...nor in another business, nor the owner', async () => {
  await assertFails(users('outsider').doc('owner').delete());
  await assertFails(users('coadmin').doc('owner').delete());
});

test('users delete: an assistant can NOT delete anyone else', async () => {
  await assertFails(users('assistant').doc('owner').delete());
});

test('users delete: a Platform Admin can delete any user', async () => {
  await assertSucceeds(users('pa').doc('assistant').delete());
});

// ======================================================================
// USERS - create. Profiles are created by the server (registerOwner,
// joinWithInvite), never by the app.
// ======================================================================

test('users create: a new account can NOT create its own profile - however it dresses it up', async () => {
  const attempts = [
    { uid: 'newbie', role: 'admin', status: 'active', facilityIds: ['F1'] },       // an active admin of someone else's facility
    { uid: 'newbie', role: 'assistant', status: 'active', facilityIds: ['F1'] },   // an assistant who skipped approval
    { uid: 'newbie', role: 'admin', status: 'active', facilityIds: [] },
    { uid: 'newbie', fullName: 'Plain Person' },
  ];
  for (const data of attempts) await assertFails(as('newbie').collection('users').doc('newbie').set(data));
});

test('users create: an admin can NOT create a profile for someone else, and nobody signed out can create one', async () => {
  await assertFails(as('owner').collection('users').doc('someone').set({ uid: 'someone', role: 'assistant', status: 'active', facilityIds: ['F1'] }));
  await assertFails(signedOut().collection('users').doc('x').set({ uid: 'x', role: 'admin' }));
});

test('users create: a Platform Admin can', async () => {
  await assertSucceeds(as('pa').collection('users').doc('made').set({ uid: 'made', role: 'assistant', status: 'pending', facilityIds: [] }));
});

// ======================================================================
// USERS - update
// ======================================================================

const statusChange = (status) => ({
  status,
  statusChangedBy: 'someone@example.com',
  statusChangedByRole: 'Facility Admin',
  statusChangedAt: new Date(),
});

test('users update: a person CAN edit their own details (name, phone, photo, last active, default facility)', async () => {
  await assertSucceeds(users('assistant').doc('assistant').update({ fullName: 'Neema J', phone: '0712345678', avatarUrl: 'https://x/y.jpg' }));
  await assertSucceeds(users('assistant').doc('assistant').update({ lastActiveAt: new Date() }));
  await assertSucceeds(users('owner').doc('owner').update({ defaultFacilityId: 'F1' }));
});

test('users update: a person can NOT put themselves in a facility - the hole that mattered most', async () => {
  await assertFails(users('outsider').doc('outsider').update({ facilityIds: ['F2', 'F1'] }));
  await assertFails(users('assistant').doc('assistant').update({ facilityIds: ['F1', 'F2'] }));
  await assertFails(users('outsider').doc('outsider').update({ facilityIds: ['F1'], facilities: [{ facilityId: 'F1', name: 'Ukuli', type: 'Agrovet', code: 'AAAA1111' }] }));
  await assertFails(users('assistant').doc('assistant').update({ facilities: [] }));
});

test('users update: ...nor change their own role or approve themselves', async () => {
  await assertFails(users('assistant').doc('assistant').update({ role: 'admin' }));
  await assertFails(users('owner').doc('owner').update({ role: 'assistant' }));
  await assertFails(users('assistant').doc('assistant').update({ status: 'pending' }));
  // an allowed change with a forbidden one tucked in alongside is still refused
  await assertFails(users('assistant').doc('assistant').update({ fullName: 'Neema J', facilityIds: ['F1', 'F2'] }));
});

test('users update: a person CAN deactivate their own account', async () => {
  await assertSucceeds(users('assistant').doc('assistant').update({ status: 'deactivated', updatedAt: new Date() }));
});

test('users update: an Admin can deactivate / reactivate an Assistant in their facility', async () => {
  await assertSucceeds(users('owner').doc('assistant').update(statusChange('deactivated')));
  await assertSucceeds(users('coadmin').doc('assistant').update(statusChange('active')));
});

test('users update: ...but can NOT move an assistant or rename them (the server does that: reassignAssistant)', async () => {
  await assertFails(users('owner').doc('assistant').update({ facilityIds: ['F2'], facilities: [] }));
  await assertFails(users('owner').doc('assistant').update({ facilityIds: [], facilities: [] }));
  await assertFails(users('owner').doc('assistant').update({ fullName: 'Renamed' }));
});

test('users update: the OWNER can deactivate and reactivate a Co-admin (the emergency brake)', async () => {
  await assertSucceeds(users('owner').doc('coadmin').update(statusChange('deactivated')));
  await assertSucceeds(users('owner').doc('coadmin').update(statusChange('active')));
});

test('users update: ...but only the status - not their name, and not their role', async () => {
  await assertFails(users('owner').doc('coadmin').update({ fullName: 'Renamed' }));
  await assertFails(users('owner').doc('coadmin').update({ role: 'assistant' }));
  await assertFails(users('owner').doc('coadmin').update(statusChange('pending')));
});

test('users update: a Co-admin can NOT deactivate the owner', async () => {
  await assertFails(users('coadmin').doc('owner').update(statusChange('deactivated')));
});

test('users update: an admin of another business can NOT deactivate anyone here', async () => {
  await assertFails(users('outsider').doc('assistant').update(statusChange('deactivated')));
  await assertFails(users('outsider').doc('coadmin').update(statusChange('deactivated')));
});

// Kept as separate tests on purpose: a Platform Admin's successful change turns
// the Assistant into a Co-admin, so later checks in the same test would be
// running against someone who is no longer an Assistant.
test('users update: an Admin can NOT change an Assistant\'s role (owner or Co-admin)', async () => {
  await assertFails(users('owner').doc('assistant').update({ role: 'admin' }));
  await assertFails(users('coadmin').doc('assistant').update({ role: 'admin' }));
});

test('users update: a Platform Admin CAN change a role', async () => {
  await assertSucceeds(users('pa').doc('assistant').update({ role: 'admin', previousRole: 'assistant' }));
});

test('users update: a Platform Admin CAN add and remove facilities (the Platform Admin tools)', async () => {
  await assertSucceeds(users('pa').doc('assistant').update({ facilityIds: ['F2'], facilities: [] }));
});

test('users read: an admin can load the team (users in my facilities); an assistant can not', async () => {
  await assertSucceeds(as('owner').collection('users').where('facilityIds', 'array-contains-any', ['F1']).get());
  await assertSucceeds(as('coadmin').collection('users').where('facilityIds', 'array-contains-any', ['F1']).get());
  await assertFails(as('assistant').collection('users').where('facilityIds', 'array-contains-any', ['F1']).get());
});

// E4a (b1): a profile holds email, phone and the facilities' invite codes,
// and anyone can register as the admin of a facility of their own. So
// "is an admin" alone must not open every profile: only an admin who
// shares a facility with the person.
test('users read [E4a]: an admin of another facility can NOT read F1\'s profiles, list every user, or query F1\'s team', async () => {
  await assertFails(users('outsider').doc('owner').get());
  await assertFails(users('outsider').doc('assistant').get());
  await assertFails(users('outsider').get());
  await assertFails(users('outsider').where('facilityIds', 'array-contains-any', ['F1']).get());
  await assertFails(users('outsider').where('role', '==', 'assistant').where('facilityIds', 'array-contains-any', ['F1']).get());
  await assertFails(users('outsider').where('role', '==', 'assistant').where('facilityIds', 'array-contains', 'F1').get());
  await assertFails(users('outsider').where('role', '==', 'assistant').where('status', '==', 'pending').where('facilityIds', 'array-contains', 'F1').get());
});

test('users read [E4a]: the owner can NOT read the profile of someone in no facility of theirs', async () => {
  await assertFails(users('owner').doc('outsider').get());
});

// The where clauses below are copied from the app, so a rule that refuses
// a real screen fails here and not in production.
test('users read [E4a]: the owner and the Co-admin run exactly the app\'s team queries', async () => {
  for (const uid of ['owner', 'coadmin']) {
    // manage_assistants_screen.dart:187-191
    await assertSucceeds(users(uid).where('facilityIds', 'array-contains-any', ['F1']).get());
    // facility_picker_screen.dart:81-86
    await assertSucceeds(users(uid).where('role', '==', 'assistant').where('facilityIds', 'array-contains-any', ['F1']).get());
    // facility_screen.dart:351-355
    await assertSucceeds(users(uid).where('role', '==', 'assistant').where('facilityIds', 'array-contains', 'F1').get());
    // dashboard_screen.dart:499-503
    await assertSucceeds(users(uid).where('role', '==', 'assistant').where('status', '==', 'pending').where('facilityIds', 'array-contains', 'F1').get());
    // payments_screen.dart:195, the name of whoever recorded a payment
    await assertSucceeds(users(uid).doc('assistant').get());
  }
});

test('users read [E4a]: everyone reads their own profile; an assistant reads only their own', async () => {
  for (const uid of ['owner', 'coadmin', 'assistant', 'outsider', 'pa']) {
    await assertSucceeds(users(uid).doc(uid).get());
  }
  await assertFails(users('assistant').doc('owner').get());
  await assertFails(users('assistant').doc('coadmin').get());
  await assertFails(users('assistant').doc('outsider').get());
});

test('users read [E4a]: a Platform Admin reads any profile and lists every user (the operator console)', async () => {
  for (const uid of ['owner', 'assistant', 'outsider']) {
    await assertSucceeds(users('pa').doc(uid).get());
  }
  // users_tab.dart:105
  await assertSucceeds(users('pa').orderBy('fullName').get());
  // role_change_service.dart:250
  await assertSucceeds(users('pa').where('role', '==', 'admin').where('facilityIds', 'array-contains', 'F1').get());
});

// ======================================================================
// FACILITIES
// ======================================================================

test('facilities read: the owner can run Manage Assistants\' query (created by me)', async () => {
  await assertSucceeds(facilities('owner').where('createdBy', '==', 'owner').get());
});

test('facilities read: members can read their facility; an outsider can not', async () => {
  await assertSucceeds(facilities('coadmin').doc('F1').get());
  await assertSucceeds(facilities('assistant').doc('F1').get());
  await assertFails(facilities('outsider').doc('F1').get());
});

test('facilities create: nobody can create one from the app (the server does: registerOwner, addFacility)', async () => {
  const f = { name: 'Mine', type: 'Agrovet', code: 'ZZZZ9999', createdBy: 'owner', trialExpiresAt: new Date(2099, 0, 1) };
  await assertFails(facilities('owner').add(f));
  await assertFails(facilities('newbie').add({ ...f, createdBy: 'newbie' }));
  await assertSucceeds(facilities('pa').add(f));
});

test('facilities update: an admin of the facility CAN change its ordinary settings', async () => {
  await assertSucceeds(facilities('owner').doc('F1').update({
    name: 'Ukuli Renamed', type: 'Vet Clinic', phone: '0712345678', email: 'a@b.co', address: 'Dar', description: 'd',
    tagline: 't', licenseNo: 'L1', tin: '123', ownership: 'Private', restockFrequency: 'Weekly', status: 'active',
    updatedAt: new Date(), debtOverdueDays: 30, activityLogRetentionDays: 60,
  }));
  await assertSucceeds(facilities('owner').doc('F1').update({ logoUrl: 'https://x/logo.png' }));
  await assertSucceeds(facilities('owner').doc('F1').update({
    allowAnytime: false, businessHours: {}, weekdayClosed: false, weekdayClosingTime: '18:00',
    saturdayClosed: false, saturdayClosingTime: '14:00', sundayClosed: true, sundayClosingTime: '00:00',
  }));
  await assertSucceeds(facilities('coadmin').doc('F1').update({ phone: '0755111222' }));
});

// RW2b2: Edit facility saves an Other facility's own words (typeDetail) next
// to its type, and removes them when the type changes away from Other.
test('facilities update: an admin of the facility CAN set and remove typeDetail (RW2b2)', async () => {
  await assertSucceeds(facilities('owner').doc('F1').update({ name: 'Ukuli', type: 'Other', typeDetail: 'Pet shop', updatedAt: new Date() }));
  await assertSucceeds(facilities('coadmin').doc('F1').update({ typeDetail: 'Pet clinic' }));
  await assertSucceeds(facilities('owner').doc('F1').update({
    type: 'Agrovet', typeDetail: firebase.firestore.FieldValue.delete(), updatedAt: new Date(),
  }));
  await assertFails(facilities('assistant').doc('F1').update({ typeDetail: 'Defaced' }));
  await assertFails(facilities('outsider').doc('F1').update({ typeDetail: 'Defaced' }));
  await assertFails(facilities('owner').doc('F1').update({ typeDetail: 'Pet shop', code: 'HIJACKED' }));
});

test('facilities update: ...but can NOT touch billing or ownership - not even their own facility\'s', async () => {
  const future = new Date(2099, 0, 1);
  for (const patch of [
    { subscriptionExpiresAt: future },
    { trialExpiresAt: future },
    { subscriptionPlan: 'enterprise' },
    { lastPaymentAt: new Date() },
    { lastPaymentAmount: 999999 },
    { lastManualOverrideBy: 'me' },
    { createdBy: 'outsider' },
    { createdAt: new Date() },
    { code: 'HIJACKED' },
  ]) {
    await assertFails(facilities('owner').doc('F1').update(patch));
  }
});

test('facilities update: an allowed change with a billing change tucked in alongside is refused', async () => {
  await assertFails(facilities('owner').doc('F1').update({ name: 'Fine', subscriptionExpiresAt: new Date(2099, 0, 1) }));
});

test('facilities update: an admin of ANOTHER business can NOT change anything here, billing or not', async () => {
  await assertFails(facilities('outsider').doc('F1').update({ subscriptionExpiresAt: new Date(2099, 0, 1) }));
  await assertFails(facilities('outsider').doc('F1').update({ name: 'Defaced' }));
});

test('facilities update: an assistant can NOT change the facility', async () => {
  await assertFails(facilities('assistant').doc('F1').update({ name: 'Defaced' }));
});

test('facilities update: a Platform Admin CAN change billing (it\'s their job)', async () => {
  await assertSucceeds(facilities('pa').doc('F1').update({
    subscriptionExpiresAt: new Date(2099, 0, 1), subscriptionPlan: 'pro', lastPaymentAt: new Date(), lastPaymentAmount: 50000,
  }));
});

test('facilities delete: nobody but a Platform Admin (owners delete through the server)', async () => {
  await assertFails(facilities('owner').doc('F1').delete());
  await assertSucceeds(facilities('pa').doc('F1').delete());
});

// ======================================================================
// ACTIVITY LOG - an assistant sees only what is theirs
//
// Used to be "any member reads everything": an assistant saw every admin
// matter (who was rejected, who was deactivated...), and since that was the
// RULE, not just the screen, could read it straight from the database.
// These mirror the exact queries the app runs.
// ======================================================================

const logsOf = (uid, facilityId = 'F1') => as(uid).collection('facilities').doc(facilityId).collection('activity_logs');
const cutoff = () => new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
// the shape of the app's own queries
const windowed = (q) => q.where('timestamp', '>=', cutoff()).orderBy('timestamp', 'desc');

test('activity log: the owner reads everything in their facility (the app\'s own query)', async () => {
  const snap = await assertSucceeds(windowed(logsOf('owner')).limit(500).get());
  assert.equal(snap.size, 3);
});

test('activity log: a Co-admin reads everything too', async () => {
  const snap = await assertSucceeds(windowed(logsOf('coadmin')).limit(500).get());
  assert.equal(snap.size, 3);
});

test('activity log: an assistant can NOT list the whole log', async () => {
  await assertFails(logsOf('assistant').get());
  await assertFails(windowed(logsOf('assistant')).limit(500).get());
});

test('activity log: an assistant CAN list what they did (the app\'s own query)', async () => {
  const snap = await assertSucceeds(windowed(logsOf('assistant').where('userId', '==', 'assistant')).limit(500).get());
  assert.deepEqual(snap.docs.map((d) => d.id), ['L-by-assistant']);
});

test('activity log: an assistant CAN list what is ABOUT them (approved, promoted...)', async () => {
  const snap = await assertSucceeds(windowed(logsOf('assistant').where('targetUserId', '==', 'assistant')).limit(500).get());
  assert.deepEqual(snap.docs.map((d) => d.id), ['L-about-assistant']);
});

test('activity log: the Dashboard\'s latest-five query works for an assistant, scoped the same way', async () => {
  await assertSucceeds(logsOf('assistant').where('userId', '==', 'assistant').orderBy('timestamp', 'desc').limit(5).get());
});

test('activity log: an assistant can NOT read an admin matter, even by its exact id', async () => {
  await assertFails(logsOf('assistant').doc('L-admin-matter').get());
});

test('activity log: an assistant CAN read an entry of their own, or one about them, by id', async () => {
  await assertSucceeds(logsOf('assistant').doc('L-by-assistant').get());
  await assertSucceeds(logsOf('assistant').doc('L-about-assistant').get());
});

test('activity log: an assistant can NOT widen the question to someone else\'s entries', async () => {
  await assertFails(windowed(logsOf('assistant').where('userId', '==', 'owner')).get());
  await assertFails(windowed(logsOf('assistant').where('targetUserId', '==', 'someone')).get());
});

test('activity log: someone in ANOTHER business reads none of it, however they ask', async () => {
  await assertFails(logsOf('outsider').get());
  await assertFails(logsOf('outsider').where('userId', '==', 'outsider').get());
  await assertFails(logsOf('outsider').doc('L-by-assistant').get());
});

test('activity log: an admin of ANOTHER business can not read this one', async () => {
  await assertFails(windowed(logsOf('outsider', 'F1')).get());
  await assertSucceeds(logsOf('outsider', 'F2').get()); // ...but their own, yes
});

test('activity log: members can still WRITE entries (an assistant logging their own sale)', async () => {
  await assertSucceeds(logsOf('assistant').add({ userId: 'assistant', userName: 'Neema', actionType: 'Sale', description: 'Sale recorded', timestamp: serverTime() }));
});


// ----------------------------------------------------------------------
// Activity log CREATE. It used to be "any signed-in user", so anyone could
// forge an entry in any facility, under anyone's name, at any date. Now:
// a member of the facility (or a Platform Admin), in their own name, with
// the server's clock - which is what ActivityLogger.logActivity sends.
// ----------------------------------------------------------------------
const entry = (userId, timestamp = serverTime()) =>
  ({ userId, userName: 'x', actionType: 'Sale', description: 'Sale recorded', timestamp });

test('activity log create: a member (assistant) CAN add an entry in their own name with the server time', async () => {
  await assertSucceeds(logsOf('assistant').add(entry('assistant')));
});

test('activity log create: a member can NOT add an entry under someone else\'s name', async () => {
  await assertFails(logsOf('assistant').add(entry('owner')));
  await assertFails(logsOf('owner').add(entry('assistant')));
});

test('activity log create: someone NOT in the facility can NOT add one (not even an admin of another facility)', async () => {
  await assertFails(logsOf('outsider', 'F1').add(entry('outsider')));
  await assertSucceeds(logsOf('outsider', 'F2').add(entry('outsider'))); // ...but in their own, yes
});

test('activity log create: a signed-out visitor can NOT add one', async () => {
  await assertFails(signedOut().collection('facilities').doc('F1').collection('activity_logs').add(entry('assistant')));
});

test('activity log create: a Platform Admin CAN add one in any facility, in their own name', async () => {
  await assertSucceeds(logsOf('pa', 'F1').add(entry('pa')));
  await assertSucceeds(logsOf('pa', 'F2').add(entry('pa')));
  await assertFails(logsOf('pa', 'F1').add(entry('owner')));
});

test('activity log create: a member can NOT backdate an entry (a device date instead of the server time)', async () => {
  await assertFails(logsOf('assistant').add(entry('assistant', new Date())));
  await assertFails(logsOf('assistant').add(entry('assistant', new Date(2020, 0, 1))));
  await assertFails(logsOf('assistant').add({ userId: 'assistant', userName: 'x', actionType: 'Sale', description: 'no time' }));
});

// ======================================================================
// STOCK FLOOR (E1c) - a product's or a batch's stockQty / sellableQty can
// never be written below zero, by anyone. An old document that is ALREADY
// negative (from past bugs) keeps working: a change that leaves the
// quantity exactly as it was is allowed, and the quantity can be raised
// to zero or more, but not to another negative value.
// ======================================================================

const products = (uid) => as(uid).collection('facilities').doc('F1').collection('products');
const batches = (uid, productId) => products(uid).doc(productId).collection('batches');

// P5: an ordinary product with 5 of each, and one batch b5 the same.
// PLEGACY: a product left at -3 by an old bug, and its batch bLegacy too.
const seedStock = async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const p = ctx.firestore().collection('facilities').doc('F1').collection('products');
    await p.doc('P5').set({ name: 'Dawa', stockQty: 5, sellableQty: 5 });
    await p.doc('P5').collection('batches').doc('b5').set({ batchNo: 'A1', stockQty: 5, sellableQty: 5 });
    await p.doc('PLEGACY').set({ name: 'Old', stockQty: -3, sellableQty: -3 });
    await p.doc('PLEGACY').collection('batches').doc('bLegacy').set({ batchNo: 'L1', stockQty: -3, sellableQty: -3 });
  });
};

test('stock floor: an update to -1 is refused, for an assistant and for an admin (product and batch)', async () => {
  await seedStock();
  for (const uid of ['assistant', 'owner']) {
    await assertFails(products(uid).doc('P5').update({ sellableQty: -1 }));
    await assertFails(products(uid).doc('P5').update({ stockQty: -1 }));
    await assertFails(batches(uid, 'P5').doc('b5').update({ sellableQty: -1 }));
    await assertFails(batches(uid, 'P5').doc('b5').update({ stockQty: -1 }));
  }
});

test('stock floor: 5 to 0 is allowed (selling the last units), product and batch', async () => {
  await seedStock();
  await assertSucceeds(products('assistant').doc('P5').update({ sellableQty: 0, stockQty: 0 }));
  await assertSucceeds(batches('assistant', 'P5').doc('b5').update({ sellableQty: 0, stockQty: 0 }));
});

test('stock floor: a legacy product at -3 can still have its name changed (quantities untouched, or rewritten as they are)', async () => {
  await seedStock();
  await assertSucceeds(products('owner').doc('PLEGACY').update({ name: 'Old renamed' }));
  // updateProduct writes the whole document back with set(), quantities included.
  await assertSucceeds(products('owner').doc('PLEGACY').set({ name: 'Old again', stockQty: -3, sellableQty: -3 }));
  await assertSucceeds(batches('owner', 'PLEGACY').doc('bLegacy').update({ batchNo: 'L2' }));
});

test('stock floor: at -3 a quantity can NOT be changed to -2, but CAN be changed to 0', async () => {
  await seedStock();
  await assertFails(products('owner').doc('PLEGACY').update({ sellableQty: -2 }));
  await assertFails(products('owner').doc('PLEGACY').update({ stockQty: -2 }));
  await assertFails(batches('owner', 'PLEGACY').doc('bLegacy').update({ sellableQty: -2 }));
  await assertFails(batches('owner', 'PLEGACY').doc('bLegacy').update({ stockQty: -2 }));
  await assertSucceeds(products('owner').doc('PLEGACY').update({ sellableQty: 0, stockQty: 0 }));
  await assertSucceeds(batches('owner', 'PLEGACY').doc('bLegacy').update({ sellableQty: 0, stockQty: 0 }));
});

test('stock floor: creating a product or a batch with a negative quantity is refused; zero or more is allowed', async () => {
  await seedStock();
  await assertFails(products('owner').doc('PNEW').set({ name: 'New', stockQty: -1, sellableQty: 0 }));
  await assertFails(products('owner').doc('PNEW').set({ name: 'New', stockQty: 0, sellableQty: -1 }));
  await assertFails(batches('owner', 'P5').doc('bNew').set({ batchNo: 'N1', stockQty: -1, sellableQty: 0 }));
  await assertFails(batches('owner', 'P5').doc('bNew').set({ batchNo: 'N1', stockQty: 0, sellableQty: -1 }));
  await assertSucceeds(products('owner').doc('PNEW').set({ name: 'New', stockQty: 0, sellableQty: 4 }));
  await assertSucceeds(batches('assistant', 'P5').doc('bNew').set({ batchNo: 'N1', stockQty: 4, sellableQty: 0 }));
});

// ======================================================================
// DAILY REPORTS [E4c]. (a1) The day's activity log is stored in an
// admin-only subdocument, dailyReports/{date}/private/activityLog, not in the
// report every member reads. (C3) A draft can only be SUBMITTED: the update
// may change exactly the submit fields, never the figures.
// The shapes below are the app's: DailyReport.toMap() (no activity log
// entries) and DailyReportService.submitUpdate() (pinned on the Dart side by
// test/daily_report_shape_test.dart).
// ======================================================================

const { getCountFromServer } = require('firebase/firestore');
const reports = (uid) => as(uid).collection('facilities').doc('F1').collection('dailyReports');
const activityLogDoc = (uid, reportId) => reports(uid).doc(reportId).collection('private').doc('activityLog');

// DailyReport.toMap(), as generateDraftReport writes it.
const reportMap = (extra = {}) => ({
  facilityId: 'F1', reportDate: new Date(2026, 9, 18), generatedAt: new Date(), generatedByName: 'Asha Owner',
  status: 'draft', submittedAt: null,
  salesCount: 2, salesTotalValue: 12500, salesByPaymentMethod: { Cash: 12500 }, salesLineItems: [],
  servicesCount: 0, servicesTotalValue: 0, servicesByPaymentMethod: {}, serviceBreakdown: [],
  totalOtherIncome: 0, otherIncomeByPaymentMethod: {}, totalExpenses: 0, expensesByCategory: {},
  expenseLineItems: [], otherIncomeLineItems: [],
  newDebtValue: 0, repaymentsValue: 0, repaymentsByPaymentMethod: {}, outstandingChange: 0, clientDebtEntries: [],
  paymentReconciliation: [{ method: 'Cash', expected: 12500, physicalCount: null, varianceReason: null, requiresCount: true }],
  productMovement: [],
  activityLogIncluded: true,
  declarationConfirmed: false,
  ...extra,
});
const logEntries = [{ time: new Date(), actionType: 'Account', description: 'Rejected assistant Baraka', userName: 'Asha' }];

// DailyReportService.submitUpdate(): the only change a draft may get.
const submitUpdate = () => ({
  status: 'submitted',
  submittedAt: new Date(),
  productMovement: [],
  paymentReconciliation: [{ method: 'Cash', expected: 12500, physicalCount: 12000, varianceReason: 'short', requiresCount: true }],
  declarationConfirmed: true,
});

// R-draft: a draft generated by the owner, with its log. R-done: a submitted one.
const seedReports = async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const r = ctx.firestore().collection('facilities').doc('F1').collection('dailyReports');
    await r.doc('R-draft').set(reportMap());
    await r.doc('R-draft').collection('private').doc('activityLog').set({ entries: logEntries, included: true });
    await r.doc('R-done').set(reportMap({ status: 'submitted', submittedAt: new Date(), declarationConfirmed: true }));
  });
};

test('reports [E4c]: an assistant can NOT read the activity log, nor write it; an outsider can not read it', async () => {
  await seedReports();
  await assertFails(activityLogDoc('assistant', 'R-draft').get());
  await assertFails(activityLogDoc('assistant', 'R-draft').set({ entries: [], included: true }));
  await assertFails(activityLogDoc('outsider', 'R-draft').get());
});

test('reports [E4c]: no report may carry the activity log itself, where every member reads it (assistant or admin)', async () => {
  for (const uid of ['assistant', 'owner']) {
    await assertFails(reports(uid).doc(`R-${uid}`).set(reportMap({ activityLogEntries: logEntries })));
  }
});

test('reports [E4c]: the owner and the Co-admin read the activity log; nobody changes it', async () => {
  await seedReports();
  await assertSucceeds(activityLogDoc('owner', 'R-draft').get());
  await assertSucceeds(activityLogDoc('coadmin', 'R-draft').get());
  await assertFails(activityLogDoc('owner', 'R-draft').update({ entries: [] }));
});

test('reports [E4c]: an admin generates a report and its log in one batch (the app\'s write)', async () => {
  const db = as('owner');
  const ref = db.collection('facilities').doc('F1').collection('dailyReports').doc('2026-10-19');
  const batch = db.batch();
  batch.set(ref, reportMap());
  batch.set(ref.collection('private').doc('activityLog'), { entries: logEntries, included: true });
  await assertSucceeds(batch.commit());
});

test('reports [E4c]: an assistant generates one without a log, and can NOT add a log to it', async () => {
  await assertSucceeds(reports('assistant').doc('2026-10-19').set(reportMap({ generatedByName: 'Neema', activityLogIncluded: false })));
  await assertFails(activityLogDoc('assistant', '2026-10-19').set({ entries: logEntries, included: true }));
});

test('reports [E4c] C3: a draft\'s figures can NOT be rewritten, by an assistant or an admin', async () => {
  await seedReports();
  for (const uid of ['assistant', 'owner']) {
    await assertFails(reports(uid).doc('R-draft').update({ salesTotalValue: 1 }));
    await assertFails(reports(uid).doc('R-draft').update({ ...submitUpdate(), salesTotalValue: 1 }));
    // The old submit, a full rewrite with set(), is refused too.
    await assertFails(reports(uid).doc('R-draft').set(reportMap({ ...submitUpdate(), salesTotalValue: 1 })));
  }
});

test('reports [E4c] C3: an update that leaves it a draft is refused', async () => {
  await seedReports();
  await assertFails(reports('assistant').doc('R-draft').update({ ...submitUpdate(), status: 'draft' }));
  await assertFails(reports('assistant').doc('R-draft').update({ declarationConfirmed: true }));
});

test('reports [E4c] C3: the assistant and the admin submit with the app\'s exact update', async () => {
  await seedReports();
  await assertSucceeds(reports('assistant').doc('R-draft').update(submitUpdate()));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('facilities').doc('F1').collection('dailyReports').doc('R-draft').set(reportMap());
  });
  await assertSucceeds(reports('owner').doc('R-draft').update(submitUpdate()));
});

test('reports [E4c]: a submitted report can not be changed, even with the submit shape', async () => {
  await seedReports();
  await assertFails(reports('owner').doc('R-done').update(submitUpdate()));
});

test('reports [E4c]: members run the app\'s reads (today\'s report, the pages, the count); an outsider can not', async () => {
  await seedReports();
  for (const uid of ['owner', 'coadmin', 'assistant']) {
    await assertSucceeds(reports(uid).doc('R-draft').get());
    await assertSucceeds(reports(uid).orderBy('reportDate', 'desc').limit(20).get());
    await assertSucceeds(reports(uid).orderBy('reportDate', 'desc').where('reportDate', '>=', new Date(2026, 0, 1)).limit(20).get());
    // getReportsCount: count() (modular API; the compat query wraps one).
    const counted = reports(uid).where('reportDate', '>=', new Date(2026, 0, 1)).where('reportDate', '<', new Date(2027, 0, 1));
    await assertSucceeds(getCountFromServer(counted._delegate));
  }
  await assertFails(reports('outsider').doc('R-draft').get());
});

test('reports [E4c]: an admin deletes a draft with its log (one batch); an assistant can not', async () => {
  await seedReports();
  await assertFails(activityLogDoc('assistant', 'R-draft').delete());
  await assertFails(reports('assistant').doc('R-draft').delete());
  const db = as('owner');
  const ref = db.collection('facilities').doc('F1').collection('dailyReports').doc('R-draft');
  const batch = db.batch();
  batch.delete(ref.collection('private').doc('activityLog'));
  batch.delete(ref);
  await assertSucceeds(batch.commit());
});

// ======================================================================
// MONEY AND STOCK WRITES [E4d-1]. C4 debts, C6 sales, C8 batch delete.
//
// GUARDS: every write shape the app really makes, captured from the
// provider code by test/providers/write_shapes_capture_test.dart into
// fixtures/app_write_shapes.json, replayed as each role that makes it, as
// ONE batch per flow (the app's transaction or batch). They pass on the
// rules before and after E4d-1.
// ======================================================================

const appShapes = require('./fixtures/app_write_shapes.json');
const f1 = (db, p) => db.doc(`facilities/F1/${p}`);
// The capture ran as the harness user 'user1' (test/helpers/fake_firestore.dart):
// the app writes the signed-in person's uid there, so the replay does too.
const CAPTURE_UID = 'user1';
const decodeShape = (v, uid) => {
  if (v === CAPTURE_UID && uid) return uid;
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    if (typeof v.$ts === 'string') return new Date(v.$ts);
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, decodeShape(x, uid)]));
  }
  return Array.isArray(v) ? v.map((x) => decodeShape(x, uid)) : v;
};
const seedShape = async (changes, uid) => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const c of changes) if (c.before) await f1(ctx.firestore(), c.path).set(decodeShape(c.before, uid));
  });
};
// [E4d-2] Fields the app writes with FieldValue.serverTimestamp() (checked in
// the writers: product_provider.dart addProduct, addBatch, moveToSellable)
// are replayed the same way: the fake stored a time there, and the rule
// compares them with request.time (C10).
const SERVER_TIME_FIELDS = { stockAdditions: ['timestamp'] };
const withServerTime = (path, data) => {
  const fields = SERVER_TIME_FIELDS[path.split('/')[0]] || [];
  return { ...data, ...Object.fromEntries(fields.map((f) => [f, serverTime()])) };
};
const replayShape = (uid, changes) => {
  const db = as(uid);
  const batch = db.batch();
  for (const c of changes) {
    c.after ? batch.set(f1(db, c.path), withServerTime(c.path, decodeShape(c.after, uid))) : batch.delete(f1(db, c.path));
  }
  return batch.commit();
};

test('app shapes [E4d-1]: the fixture holds the flows E4d-1 depends on', () => {
  const names = appShapes.flows.map((f) => f.name);
  for (const n of ['addSale cash, walk-in', 'addSale credit, nothing paid', 'addSale partly paid',
    'payment on a sale debt, partial', 'payment on a sale debt, settles it', 'payment on a service debt, partial',
    'updateService raises the unpaid amount (Edit Service)', 'deleteSale credit (to Trash)',
    'restoreSale credit (from Trash)', 'deleteService (to Trash)', 'restoreService (from Trash)']) {
    assert.ok(names.includes(n), `missing flow: ${n}`);
  }
});

test('app shapes [E4d-2]: the fixture holds the flows E4d-2 depends on, refused to assistants where the owner decided', () => {
  const byName = Object.fromEntries(appShapes.flows.map((f) => [f.name, f]));
  for (const n of ['payment on a service debt, settles it', 'addTransaction, the first expense (its counter is created)',
    'addTransaction, the next expense (its counter goes up)', 'addBatch to an existing product (Add Batch)']) {
    assert.deepStrictEqual(byName[n] && byName[n].roles, ['owner', 'coadmin', 'assistant'], `flow: ${n}`);
  }
  for (const n of ['updateService raises the unpaid amount (Edit Service)', 'updateService with an external item (Edit Service)',
    'updateTransaction (Edit Transaction)', 'deleteTransaction (to Trash)', 'addProduct with its first batch (Add Product)']) {
    assert.deepStrictEqual(byName[n] && [byName[n].roles, byName[n].refused], [['owner', 'coadmin'], ['assistant']], `flow: ${n}`);
  }
});

for (const flow of appShapes.flows) {
  for (const uid of flow.roles) {
    test(`app shapes [E4d-1]: ${uid} - ${flow.name}`, async () => {
      await seedShape(flow.changes, uid);
      await assertSucceeds(replayShape(uid, flow.changes));
    });
  }
}

// Deleting a batch (ProductProvider.deleteBatch, product_provider.dart:458,
// not injectable, so written from the source): the batch goes and the
// product's totals are recalculated, in one transaction.
const seedBatchToDelete = () => env.withSecurityRulesDisabled(async (ctx) => {
  const p = f1(ctx.firestore(), 'products/PB');
  await p.set({ name: 'Dawa', stockQty: 5, sellableQty: 7, expiry: new Date(2030, 0, 1) });
  await p.collection('batches').doc('keep').set({ batchNo: 'K', stockQty: 5, sellableQty: 4, expiry: new Date(2030, 0, 1) });
  await p.collection('batches').doc('gone').set({ batchNo: 'G', stockQty: 0, sellableQty: 3, expiry: new Date(2026, 0, 1) });
});
const deleteBatchShape = (uid) => {
  const db = as(uid);
  const batch = db.batch();
  batch.delete(f1(db, 'products/PB/batches/gone'));
  batch.update(f1(db, 'products/PB'), { stockQty: 5, sellableQty: 4, expiry: new Date(2030, 0, 1), updatedAt: serverTime() });
  return batch.commit();
};

test('C8 [E4d-1]: the owner and the Co-admin delete a batch (the app\'s write)', async () => {
  await seedBatchToDelete();
  await assertSucceeds(deleteBatchShape('owner'));
  await seedBatchToDelete();
  await assertSucceeds(deleteBatchShape('coadmin'));
});

test('C8 [E4d-1]: an assistant can NOT delete a batch (no Trash, no log)', async () => {
  await seedBatchToDelete();
  await assertFails(deleteBatchShape('assistant'));
  await assertFails(f1(as('assistant'), 'products/PB/batches/gone').delete());
});


// ---------------------------------------------------------------------------
// C4 debts.

const debtsOf = (uid) => as(uid).collection('facilities').doc('F1').collection('debts');
const seedDebt = () => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await f1(db, 'clients/cD').set({ name: 'Juma', balance: 5000 });
  await f1(db, 'debts/sale_D1').set({ clientId: 'cD', amountOwed: 5000, saleId: 'D1', source: 'Sale', timestamp: new Date() });
});

test('C4 [E4d-1]: a debt must name a client and owe more than zero (assistant and admin)', async () => {
  for (const uid of ['assistant', 'owner']) {
    await assertFails(debtsOf(uid).doc(`zero-${uid}`).set({ clientId: 'c1', amountOwed: 0 }));
    await assertFails(debtsOf(uid).doc(`neg-${uid}`).set({ clientId: 'c1', amountOwed: -100 }));
    await assertFails(debtsOf(uid).doc(`noclient-${uid}`).set({ amountOwed: 100 }));
    await assertSucceeds(debtsOf(uid).doc(`ok-${uid}`).set({ clientId: 'c1', amountOwed: 100 }));
  }
});

test('C4 [E4d-1]: an assistant can NOT delete a debt without lowering the client\'s balance (forgiving it)', async () => {
  await seedDebt();
  await assertFails(debtsOf('assistant').doc('sale_D1').delete());
  // ...nor by "lowering" it by nothing.
  const db = as('assistant');
  const batch = db.batch();
  batch.delete(f1(db, 'debts/sale_D1'));
  batch.update(f1(db, 'clients/cD'), { balance: 5000 });
  await assertFails(batch.commit());
});

test('C4 [E4d-1]: an assistant deletes a debt in the same write that lowers the balance (a payment that settles it)', async () => {
  await seedDebt();
  const db = as('assistant');
  const batch = db.batch();
  batch.delete(f1(db, 'debts/sale_D1'));
  batch.update(f1(db, 'clients/cD'), { balance: firebase.firestore.FieldValue.increment(-5000) });
  await assertSucceeds(batch.commit());
});

test('C4 [E4d-1]: an admin may delete a debt on its own, as today', async () => {
  await seedDebt();
  await assertSucceeds(debtsOf('coadmin').doc('sale_D1').delete());
});


// ---------------------------------------------------------------------------
// C6 sales: an assistant only records payments on a sale.

const seedSale = () => env.withSecurityRulesDisabled(async (ctx) => {
  await f1(ctx.firestore(), 'sales/S6').set({
    clientId: 'c1', clientName: 'Juma', totalAmount: 6000, totalPaid: 1000, receiptNumber: 41,
    timestamp: new Date(2026, 9, 1), updatedAt: new Date(2026, 9, 1), soldById: 'assistant', saleOnCredit: true,
    items: [{ productId: 'p1', quantity: 3, unitPrice: 2000, realizedProfit: 500, unrealizedProfit: 2500 }],
    realizedProfit: 500, unrealizedProfit: 2500, totalProfit: 3000, paymentStatus: 'Partial',
  });
});
const sales = (uid) => as(uid).collection('facilities').doc('F1').collection('sales');

test('C6 [E4d-1]: an assistant can NOT change a past sale\'s amounts, client, date or receipt number', async () => {
  await seedSale();
  for (const change of [{ totalAmount: 1 }, { clientId: 'c2' }, { timestamp: new Date() }, { receiptNumber: 1 },
    { totalProfit: 0 }, { soldById: 'owner' }, { saleOnCredit: false }]) {
    await assertFails(sales('assistant').doc('S6').update({ ...change, updatedAt: new Date() }));
  }
});

test('C6 [E4d-1]: an assistant records a payment on a sale (the fields Sale.applyPayment changes)', async () => {
  await seedSale();
  await assertSucceeds(sales('assistant').doc('S6').update({
    totalPaid: 2000, realizedProfit: 1000, unrealizedProfit: 2000, updatedAt: new Date(),
    items: [{ productId: 'p1', quantity: 3, unitPrice: 2000, realizedProfit: 1000, unrealizedProfit: 2000 }],
    paymentStatus: 'Partial',
  }));
});

test('C6 [E4d-1]: admins still edit a sale, as today', async () => {
  await seedSale();
  await assertSucceeds(sales('owner').doc('S6').update({ totalAmount: 5000 }));
  await assertSucceeds(sales('coadmin').doc('S6').update({ clientId: 'c2' }));
});


// ======================================================================
// [E4d-2] THE OWNER'S DECISION (C4 update, C6 services, C7), C12 products,
// C9 counters, C10 stock logs, C11 payment claims.
// docs/design/e4d2_writer_audit.md lists every writer.
// ======================================================================

// A flow the app refuses to a role (the button is hidden and the provider
// throws AdminOnlyException), replayed as that role: the rules refuse it too.
const assertRefusedShape = async (name, uid) => {
  const flow = appShapes.flows.find((f) => f.name === name);
  assert.ok(flow && flow.refused.includes(uid), `${name}: not refused to ${uid} in the fixture`);
  await seedShape(flow.changes, uid);
  await assertFails(replayShape(uid, flow.changes));
};

// ---------------------------------------------------------------------------
// C7 transactions: members record; editing and deleting are admin-only.

const transactionsOf = (uid) => as(uid).collection('facilities').doc('F1').collection('transactions');
const seedTransaction = () => env.withSecurityRulesDisabled(async (ctx) => {
  await f1(ctx.firestore(), 'transactions/T7').set({
    date: new Date(2026, 9, 1), description: 'Fuel', descriptionLower: 'fuel', amount: 3000, type: 'expense',
    category: 'Transport', recordedBy: 'Neema Assistant', receiptNumber: 4,
  });
});

test('C7 [E4d-2]: an assistant can NOT edit a transaction (Edit Transaction\'s shape, or any change)', async () => {
  await assertRefusedShape('updateTransaction (Edit Transaction)', 'assistant');
  await seedTransaction();
  await assertFails(transactionsOf('assistant').doc('T7').update({ amount: 1 }));
  await assertFails(transactionsOf('assistant').doc('T7').set({ amount: 1 }));
});

test('C7 [E4d-2]: an assistant can NOT delete a transaction, with or without the Trash copy', async () => {
  await assertRefusedShape('deleteTransaction (to Trash)', 'assistant');
  await seedTransaction();
  await assertFails(transactionsOf('assistant').doc('T7').delete());
});

test('C7 [E4d-2]: an assistant still records one; admins edit and delete', async () => {
  await assertSucceeds(transactionsOf('assistant').doc('T8').set({ amount: 500, type: 'expense', recordedBy: 'Neema' }));
  await seedTransaction();
  await assertSucceeds(transactionsOf('coadmin').doc('T7').update({ amount: 3500 }));
  await assertSucceeds(transactionsOf('owner').doc('T7').delete());
});

// ---------------------------------------------------------------------------
// C4 debts, update: an admin (Edit Service rewrites the debt and may raise
// it), or an assistant lowering amountOwed only, as a payment does
// (AddPaymentScreen: {amountOwed}). Never below zero. (seedDebt: cD owes 5000.)

test('C4 update [E4d-2]: an assistant can NOT raise a debt, keep it, change what it is, or take it below zero', async () => {
  await seedDebt();
  for (const change of [{ amountOwed: 6000 }, { amountOwed: 5000, updatedAt: new Date() }, { amountOwed: -1 },
    { clientId: 'c2' }, { amountOwed: 4000, clientId: 'c2' }, { amountOwed: 4000, items: [] }, { saleId: 'other' }]) {
    await assertFails(debtsOf('assistant').doc('sale_D1').update(change));
  }
});

test('C4 update [E4d-2]: an assistant can NOT replay Edit Service, which raises the debt', async () => {
  await assertRefusedShape('updateService raises the unpaid amount (Edit Service)', 'assistant');
});

test('C4 update [E4d-2]: an assistant lowers a debt (a payment), with or without updatedAt', async () => {
  await seedDebt();
  await assertSucceeds(debtsOf('assistant').doc('sale_D1').update({ amountOwed: 4000 }));
  await assertSucceeds(debtsOf('assistant').doc('sale_D1').update({ amountOwed: 3000, updatedAt: new Date() }));
});

test('C4 update [E4d-2]: an admin may raise or rewrite a debt, but not below zero', async () => {
  await seedDebt();
  await assertSucceeds(debtsOf('owner').doc('sale_D1').update({ amountOwed: 9000, updatedAt: new Date() }));
  await assertSucceeds(debtsOf('coadmin').doc('sale_D1').update({ amountOwed: 8000, items: [] }));
  await assertFails(debtsOf('owner').doc('sale_D1').update({ amountOwed: -5 }));
});

// ---------------------------------------------------------------------------
// C6 services: an assistant only records payments on a service - the
// fields the payment's copyWith(totalPaid, updatedAt).toMap() changes
// (captured: totalPaid, updatedAt, totalServiceProfit,
// unrealizedServiceProfit; since E4d-3 also paymentStatus). Admins edit.

const servicesOf = (uid) => as(uid).collection('facilities').doc('F1').collection('services');
const seedService = () => env.withSecurityRulesDisabled(async (ctx) => {
  await f1(ctx.firestore(), 'services/V6').set({
    category: 'Treatment', name: 'Deworming', description: '', totalAmount: 10000, totalPaid: 4000,
    clientId: 'c2', clientName: 'Neema', serviceDate: new Date(2026, 9, 1), providedByName: 'Neema Assistant',
    updatedAt: new Date(2026, 9, 1), itemsUsed: [{ itemName: 'Gloves', price: 700, productId: null }],
    totalServiceProfit: 3300, unrealizedServiceProfit: 6000, paymentMethod: 'Cash', receiptNumber: 12,
    transactionId: null, clientNameLower: 'neema', paymentStatus: 'Partial',
  });
});

test('C6 services [E4d-2]: an assistant can NOT change a service\'s amount, items, client, date, receipt or status', async () => {
  await seedService();
  for (const change of [{ totalAmount: 1 }, { itemsUsed: [] }, { clientId: 'c1' }, { serviceDate: new Date() },
    { receiptNumber: 1 }, { providedByName: 'Someone' }, { paymentStatus: 'Paid' }, { name: 'Other' }]) {
    await assertFails(servicesOf('assistant').doc('V6').update({ ...change, updatedAt: new Date() }));
  }
});

test('C6 services [E4d-2]: an assistant can NOT write Edit Service\'s service change (either captured edit)', async () => {
  for (const name of ['updateService raises the unpaid amount (Edit Service)', 'updateService with an external item (Edit Service)']) {
    const flow = appShapes.flows.find((f) => f.name === name);
    assert.ok(flow.refused.includes('assistant'), name);
    const serviceOnly = flow.changes.filter((c) => c.path.startsWith('services/'));
    assert.strictEqual(serviceOnly.length, 1, name);
    await seedShape(serviceOnly, 'assistant');
    await assertFails(replayShape('assistant', serviceOnly));
    await assertSucceeds(replayShape('owner', serviceOnly));
  }
});

test('C6 services [E4d-2]: an assistant records a payment on a service (the payment\'s fields)', async () => {
  await seedService();
  await assertSucceeds(servicesOf('assistant').doc('V6').update({
    totalPaid: 5000, totalServiceProfit: 4300, unrealizedServiceProfit: 5000, updatedAt: new Date(),
  }));
});

// [E4d-3] A payment also writes paymentStatus (Service.toMap), so the
// Paid/Partial/Unpaid filter follows it; only to the status of the new
// totalPaid against totalAmount (PaymentStatus.of).
const servicePayment = (totalPaid, paymentStatus) => ({
  totalPaid, totalServiceProfit: totalPaid - 700, unrealizedServiceProfit: 10000 - totalPaid, updatedAt: new Date(), paymentStatus,
});

test('C6 services [E4d-3]: an assistant\'s payment refreshes paymentStatus (settles: Paid; part: stays Partial)', async () => {
  await seedService();
  await assertSucceeds(servicesOf('assistant').doc('V6').update(servicePayment(5000, 'Partial')));
  await assertSucceeds(servicesOf('assistant').doc('V6').update(servicePayment(10000, 'Paid')));
});

test('C6 services [E4d-3]: an assistant can NOT write a paymentStatus its amounts do not give', async () => {
  await seedService();
  for (const [paid, status] of [[5000, 'Paid'], [5000, 'Unpaid'], [10000, 'Partial'], [4000, 'Paid'], [5000, 'paid']]) {
    await assertFails(servicesOf('assistant').doc('V6').update(servicePayment(paid, status)));
  }
  await assertFails(servicesOf('assistant').doc('V6').update({ ...servicePayment(10000, 'Paid'), paymentStatus: null }));
});

test('C6 services [E4d-3]: the captured payments write paymentStatus (partial: Partial, settles: Paid)', async () => {
  const status = (name, path) => appShapes.flows.find((f) => f.name === name).changes.find((c) => c.path === path).after.paymentStatus;
  assert.strictEqual(status('payment on a service debt, partial', 'services/v1'), 'Partial');
  assert.strictEqual(status('payment on a service debt, settles it', 'services/v2'), 'Paid');
  assert.strictEqual(status('payment on a sale debt, settles it', 'sales/part1'), 'Paid');
});

test('C6 services [E4d-2]: admins still edit a service', async () => {
  await seedService();
  await assertSucceeds(servicesOf('owner').doc('V6').update({ totalAmount: 12000, updatedAt: new Date() }));
  await assertSucceeds(servicesOf('coadmin').doc('V6').update({ itemsUsed: [], clientId: 'c1' }));
});

// ---------------------------------------------------------------------------
// C12 products: creating one is admin-only (owner decision); an assistant
// still adds batches to existing products (Add Batch, captured: everyone).

test('C12 [E4d-2]: an assistant can NOT create a product (Add Product\'s shape, or directly)', async () => {
  await assertRefusedShape('addProduct with its first batch (Add Product)', 'assistant');
  await assertFails(products('assistant').doc('PNEW').set({ name: 'New', stockQty: 0, sellableQty: 4 }));
});

test('C12 [E4d-2]: admins create products; an assistant adds a batch to an existing one', async () => {
  await seedStock();
  await assertSucceeds(products('owner').doc('PNEW').set({ name: 'New', stockQty: 0, sellableQty: 4 }));
  await assertSucceeds(products('coadmin').doc('PNEW2').set({ name: 'New 2', stockQty: 3, sellableQty: 0 }));
  await assertSucceeds(batches('assistant', 'P5').doc('bNew').set({ batchNo: 'N1', stockQty: 4, sellableQty: 0 }));
});

// Every flow the app refuses to a role is refused by the rules as well.
for (const flow of appShapes.flows) {
  for (const uid of flow.refused) {
    test(`app shapes [E4d-2]: refused to ${uid} - ${flow.name}`, async () => {
      await seedShape(flow.changes, uid);
      await assertFails(replayShape(uid, flow.changes));
    });
  }
}

// ---------------------------------------------------------------------------
// C9 counters: a receipt counter only grows, and is never deleted. Every
// writer sets {value: old + 1} (receipt_numbering.dart: claimReceiptNumber
// in the sale and service transactions, nextReceiptNumber for expenses and
// other income; captured, create and update, everyone).

const counterOf = (uid, id = 'receiptNumber') => f1(as(uid), `counters/${id}`);
const seedCounter = () => env.withSecurityRulesDisabled(async (ctx) => {
  await f1(ctx.firestore(), 'counters/receiptNumber').set({ value: 41 });
});

test('C9 [E4d-2]: nobody lowers, resets, keeps or deletes a receipt counter (assistant and admin)', async () => {
  for (const uid of ['assistant', 'owner']) {
    await seedCounter();
    for (const change of [{ value: 40 }, { value: 0 }, { value: 41 }, { value: '42' }, { value: 42, note: 'x' }]) {
      await assertFails(counterOf(uid).update(change));
    }
    await assertFails(counterOf(uid).set({ value: 1 }));
    await assertFails(counterOf(uid).delete());
  }
});

test('C9 [E4d-2]: a new counter starts above zero and holds only its value', async () => {
  await assertFails(counterOf('assistant', 'otherIncomeReceiptNumber').set({ value: 0 }));
  await assertFails(counterOf('assistant', 'otherIncomeReceiptNumber').set({ value: 1, note: 'x' }));
  await assertSucceeds(counterOf('assistant', 'otherIncomeReceiptNumber').set({ value: 1 }, { merge: true }));
});

test('C9 [E4d-2]: the next receipt number is taken as the app takes it (set value + 1, merged)', async () => {
  await seedCounter();
  await assertSucceeds(counterOf('assistant').set({ value: 42 }, { merge: true }));
  await assertSucceeds(counterOf('owner').set({ value: 43 }, { merge: true }));
});

// ---------------------------------------------------------------------------
// C10 stock logs, create. stockAdditions (addProduct, addBatch,
// moveToSellable: productId, sellableDelta, stockDelta, userId, timestamp;
// the author since E4d-3, captured) and stock_adjustments (moveBatchToStock,
// Edit Product's quantity change: written here from those writers, which
// are not injectable / live in the screen) also name their author, userId.

const stockLog = (uid, collection) => as(uid).collection('facilities').doc('F1').collection(collection);
const addition = (userId, timestamp) => ({ productId: 'P5', sellableDelta: 3, stockDelta: -3, userId, timestamp });
const adjustment = (userId, timestamp) => ({
  productId: 'P5', productName: 'Dawa', oldStockQty: 5, oldSellableQty: 5, newStockQty: 2, newSellableQty: 5,
  userId, userName: 'Neema Assistant', source: 'Moved batch to Stock Store', reason: 'Damaged', timestamp,
});

test('C10 [E4d-2]: a stock addition can NOT be backdated or left without a time', async () => {
  for (const uid of ['assistant', 'owner']) {
    await assertFails(stockLog(uid, 'stockAdditions').add(addition(uid, new Date(2026, 0, 1))));
    await assertFails(stockLog(uid, 'stockAdditions').add({ productId: 'P5', sellableDelta: 3, stockDelta: -3, userId: uid }));
  }
});

test('C10 [E4d-3]: a stock addition can NOT be filed under someone else, or without an author', async () => {
  for (const uid of ['assistant', 'owner']) {
    const other = uid === 'owner' ? 'assistant' : 'owner';
    await assertFails(stockLog(uid, 'stockAdditions').add(addition(other, serverTime())));
    await assertFails(stockLog(uid, 'stockAdditions').add(addition(null, serverTime())));
    const { userId, ...noAuthor } = addition(uid, serverTime());
    await assertFails(stockLog(uid, 'stockAdditions').add(noAuthor));
  }
});

test('C10 [E4d-2]: a stock adjustment can NOT be filed under someone else, or backdated', async () => {
  for (const uid of ['assistant', 'owner']) {
    const other = uid === 'owner' ? 'assistant' : 'owner';
    await assertFails(stockLog(uid, 'stock_adjustments').add(adjustment(other, serverTime())));
    await assertFails(stockLog(uid, 'stock_adjustments').add(adjustment(uid, new Date())));
    await assertFails(stockLog(uid, 'stock_adjustments').add({ ...adjustment(uid, serverTime()), userId: null }));
  }
});

test('C10 [E4d-2]: members log stock with the server\'s time, adjustments in their own name (the writers\' shapes)', async () => {
  for (const uid of ['assistant', 'coadmin']) {
    await assertSucceeds(stockLog(uid, 'stockAdditions').add(addition(uid, serverTime())));
    await assertSucceeds(stockLog(uid, 'stock_adjustments').add(adjustment(uid, serverTime())));
    const { reason, ...productEdit } = adjustment(uid, serverTime());
    await assertSucceeds(stockLog(uid, 'stock_adjustments').add({ ...productEdit, source: 'Product edit' }));
  }
});

// ---------------------------------------------------------------------------
// C11 payment_submissions, create: a claim starts 'pending'; only the
// Platform Admin's review changes it. The writer (SubscriptionScreen's
// submit) stores the submitter's EMAIL in submittedBy, for people to read,
// and since E4d-3 the uid in submittedById, which the rule checks.

const claimsOf = (uid) => as(uid).collection('facilities').doc('F1').collection('payment_submissions');
const claim = (status, submittedById) => ({
  facilityId: 'F1', facilityName: 'Ukuli', planId: 'basic_monthly', planLabel: 'Basic (Monthly)', amount: 20000,
  promotionLabel: null, discountPercent: null, method: 'M-Pesa', reference: 'QX12', proofImageUrl: null,
  status, submittedAt: serverTime(), submittedBy: 'neema@example.com', submittedById,
});

test('C11 [E4d-2]: a payment claim can NOT be created already approved, rejected, or without a status', async () => {
  for (const uid of ['assistant', 'owner']) {
    await assertFails(claimsOf(uid).add(claim('approved', uid)));
    await assertFails(claimsOf(uid).add(claim('rejected', uid)));
    const { status, ...noStatus } = claim('pending', uid);
    await assertFails(claimsOf(uid).add(noStatus));
  }
});

test('C11 [E4d-3]: a payment claim can NOT be submitted in someone else\'s name, or with no submitter id', async () => {
  for (const uid of ['assistant', 'owner']) {
    const other = uid === 'owner' ? 'assistant' : 'owner';
    await assertFails(claimsOf(uid).add(claim('pending', other)));
    await assertFails(claimsOf(uid).add(claim('pending', null)));
    const { submittedById, ...noId } = claim('pending', uid);
    await assertFails(claimsOf(uid).add(noId));
  }
});

test('C11 [E4d-2]: members submit a claim as the app does (pending); the review stays the Platform Admin\'s', async () => {
  await assertSucceeds(claimsOf('assistant').add(claim('pending', 'assistant')));
  const ref = await claimsOf('owner').add(claim('pending', 'owner'));
  await assertFails(f1(as('owner'), `payment_submissions/${ref.id}`).update({ status: 'approved' }));
  await assertSucceeds(f1(as('pa'), `payment_submissions/${ref.id}`).update({ status: 'approved' }));
});

// SUBS-1: the claim also names its submitter (submittedByName: the profile's
// full name, or the email), and the review its reviewer (reviewedByName).
// Neither needs a rule change: create checks only status and submittedById.
test('C11 [SUBS-1]: the claim as the app now submits it (with submittedByName) is accepted; the review stores reviewedByName', async () => {
  for (const uid of ['assistant', 'owner']) {
    const ref = await assertSucceeds(claimsOf(uid).add({ ...claim('pending', uid), submittedByName: 'Neema Mushi' }));
    await assertSucceeds(f1(as('pa'), `payment_submissions/${ref.id}`).update({
      status: 'approved', reviewedAt: serverTime(), reviewedBy: 'pa@example.com', reviewedByName: 'Asha Admin',
    }));
  }
  // Still only in your own name, name or not.
  await assertFails(claimsOf('owner').add({ ...claim('pending', 'assistant'), submittedByName: 'Neema Mushi' }));
});

// P1: the invite-code rate limit's counts (inviteAttempts) are written by
// the server (Admin SDK) only. No rule matches the collection, so every
// client read and write is refused; this pins that.
test('P1: inviteAttempts is server-only: nobody can read, list or write it from the app', async () => {
  for (const db of [signedOut(), as('newbie'), as('assistant'), as('owner'), as('pa')]) {
    await assertFails(db.collection('inviteAttempts').doc('uid_newbie').get());
    await assertFails(db.collection('inviteAttempts').get());
    await assertFails(db.collection('inviteAttempts').doc('uid_newbie').set({ failures: 0 }));
    await assertFails(db.collection('inviteAttempts').doc('uid_newbie').delete());
  }
});

// ======================================================================
// NOTIF-2a: each person's own notification state, read and removal kept per
// person (docs/design/notifications.md, sections 2 and 5, APPROVED):
// facilities/{fid}/notificationState/{uid} = { read: {id: time},
// unread: {id: true}, removed: {id: time}, seenStage: {id: stage},
// updatedAt }. Only that person, while a member of the facility, reads or
// writes it; each map holds at most 2000 entries.
// ======================================================================

const stateOf = (db, uid, facilityId = 'F1') => db.doc(`facilities/${facilityId}/notificationState/${uid}`);
const ids = (n, prefix = 'n') => Array.from({ length: n }, (_, i) => `${prefix}${i + 1}`);
const mapOf = (keys, value) => Object.fromEntries(keys.map((k) => [k, value]));
const FieldValue = firebase.firestore.FieldValue;

// A state document already there, written with the rules off.
const seedState = (uid, data, facilityId = 'F1') =>
  env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc(`facilities/${facilityId}/notificationState/${uid}`).set(data));

test('NOTIF-2a: members read and write their OWN state document (admin, Co-admin, assistant)', async () => {
  for (const uid of ['owner', 'coadmin', 'assistant']) {
    await assertSucceeds(stateOf(as(uid), uid).set({ read: { n1: serverTime() }, updatedAt: serverTime() }, { merge: true }));
    await assertSucceeds(stateOf(as(uid), uid).get());
  }
});

test('NOTIF-2a: nobody else reads or writes it - another member, a Platform Admin, a non-member, signed out', async () => {
  await seedState('owner', { read: { n1: new Date() }, updatedAt: new Date() });
  await seedState('assistant', { removed: { n2: new Date() }, updatedAt: new Date() });
  const attempts = [
    ['assistant', 'owner'], ['coadmin', 'owner'], ['owner', 'assistant'], ['pa', 'owner'], ['outsider', 'owner'],
  ];
  for (const [who, whose] of attempts) {
    await assertFails(stateOf(as(who), whose).get());
    await assertFails(stateOf(as(who), whose).set({ removed: { n9: serverTime() } }, { merge: true }));
    await assertFails(stateOf(as(who), whose).delete());
  }
  await assertFails(stateOf(signedOut(), 'owner').get());
  // Nor list the facility's state documents.
  await assertFails(as('owner').collection('facilities/F1/notificationState').get());
});

test('NOTIF-2a: not in a facility you are not a member of, even under your own uid', async () => {
  await assertFails(stateOf(as('outsider'), 'outsider', 'F1').set({ read: {}, updatedAt: serverTime() }));
  await assertFails(stateOf(as('pa'), 'pa', 'F1').set({ read: {}, updatedAt: serverTime() }));
  await assertSucceeds(stateOf(as('outsider'), 'outsider', 'F2').set({ read: {}, updatedAt: serverTime() }));
});

test('NOTIF-2a: only read, unread, removed, seenStage and updatedAt', async () => {
  const mine = stateOf(as('owner'), 'owner');
  await assertSucceeds(mine.set({ read: {}, unread: {}, removed: {}, seenStage: {}, updatedAt: serverTime() }));
  await assertFails(mine.set({ read: {}, muted: { n1: true } }, { merge: true }));
  await assertFails(mine.set({ role: 'admin' }, { merge: true }));
});

test('NOTIF-2a: each of read, unread, removed, seenStage is a map; updatedAt a timestamp', async () => {
  const mine = stateOf(as('owner'), 'owner');
  for (const key of ['read', 'unread', 'removed', 'seenStage']) {
    for (const wrong of ['n1', 5, true, ['n1'], null]) {
      await assertFails(mine.set({ [key]: wrong }));
    }
  }
  for (const wrong of ['yesterday', 5, { at: 1 }, null]) {
    await assertFails(mine.set({ updatedAt: wrong }));
  }
  await assertSucceeds(mine.set({ updatedAt: new Date() }));
  await assertSucceeds(mine.set({ updatedAt: serverTime() }));
});

test('NOTIF-2a: each map holds at most 2000 entries', async () => {
  const mine = stateOf(as('owner'), 'owner');
  for (const key of ['read', 'unread', 'removed', 'seenStage']) {
    await assertSucceeds(mine.set({ [key]: mapOf(ids(2000), true) }));
    await assertFails(mine.set({ [key]: mapOf(ids(2001), true) }));
  }
  // Growing past the bound one entry at a time is refused too.
  await seedState('owner', { removed: mapOf(ids(2000), new Date()) });
  await assertFails(mine.update({ 'removed.extra': serverTime() }));
});

test('NOTIF-2a: the owner of a state document can delete it', async () => {
  await seedState('assistant', { read: { n1: new Date() }, updatedAt: new Date() });
  await assertSucceeds(stateOf(as('assistant'), 'assistant').delete());
});

test('NOTIF-2a: the shapes the app will write all pass (one read, one removal, bulk 50, Undo, seenStage, mark unread)', async () => {
  const mine = stateOf(as('coadmin'), 'coadmin');
  // The first write creates it: a merge, as the app does every time.
  await assertSucceeds(mine.set({ read: { n1: serverTime() }, updatedAt: serverTime() }, { merge: true }));
  // One read and one removal: dotted keys.
  await assertSucceeds(mine.update({ 'read.n2': serverTime(), updatedAt: serverTime() }));
  await assertSucceeds(mine.update({ 'removed.n3': serverTime(), updatedAt: serverTime() }));
  // Mark as unread: off the read map, onto unread (over a shared readAt).
  await assertSucceeds(mine.update({ 'read.n2': FieldValue.delete(), 'unread.n2': true, updatedAt: serverTime() }));
  // A bulk removal of 50, one write.
  const fifty = ids(50, 'b');
  const before = (await mine.get()).data().removed;
  await assertSucceeds(mine.set({ removed: mapOf(fifty, serverTime()), updatedAt: serverTime() }, { merge: true }));
  // Undo: those 50 come off, the earlier removal stays as it was.
  const undo = { updatedAt: serverTime() };
  for (const id of fifty) undo[`removed.${id}`] = FieldValue.delete();
  await assertSucceeds(mine.update(undo));
  assert.deepStrictEqual(Object.keys((await mine.get()).data().removed), Object.keys(before));
  // The stage a persistent notice was read at.
  await assertSucceeds(mine.update({ 'seenStage.subscription_expiring': 'grace', updatedAt: serverTime() }));
});

test('NOTIF-2a: notifications themselves are unchanged - no delete from the app; any member still marks readAt (old app versions)', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.firestore().doc('facilities/F1/notifications/n1').set({ type: 'newClient', title: 'x', message: 'y', createdAt: new Date() }));
  for (const uid of ['owner', 'coadmin', 'assistant', 'pa']) {
    await assertFails(f1(as(uid), 'notifications/n1').delete());
  }
  for (const uid of ['owner', 'assistant']) {
    await assertSucceeds(f1(as(uid), 'notifications/n1').update({ readAt: serverTime() }));
  }
  await assertFails(f1(as('assistant'), 'notifications/n1').update({ title: 'changed' }));
});

test('NOTIF-2b: the service\'s own write - set with merge, entries nested in their map, a delete among them - passes', async () => {
  const mine = stateOf(as('owner'), 'owner');
  await assertSucceeds(mine.set({ removed: { n1: new Date(), n2: new Date() }, updatedAt: serverTime() }, { merge: true }));
  // markRead: one entry in, one off unread; Undo: an entry off removed.
  await assertSucceeds(mine.set({ read: { n1: new Date() }, unread: { n1: FieldValue.delete() }, updatedAt: serverTime() }, { merge: true }));
  await assertSucceeds(mine.set({ removed: { n2: FieldValue.delete() }, updatedAt: serverTime() }, { merge: true }));
  assert.deepStrictEqual(Object.keys((await mine.get()).data().removed), ['n1']);
  await assertSucceeds(mine.set({ seenStage: { subscription_expiring: 'grace' }, updatedAt: serverTime() }, { merge: true }));
});
