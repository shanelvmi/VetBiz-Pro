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
  await assertSucceeds(logsOf('assistant').add({ userId: 'assistant', userName: 'Neema', actionType: 'Sale', description: 'Sale recorded', timestamp: new Date() }));
});

