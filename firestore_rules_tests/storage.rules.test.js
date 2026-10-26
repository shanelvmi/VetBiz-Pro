// Allowed / denied tests for ../storage.rules, run against the Storage and
// Firestore emulators (the Storage rules look up users/{uid} and
// platform_admins/{uid} in Firestore) - never against the real project.
//
//   firebase emulators:exec --only firestore,storage --project demo-vetbiz-rules "npm --prefix firestore_rules_tests run test:storage"
//
// The paths and file names below are the ones the app uploads to (E4a
// audit): avatars/{uid}.jpg (registration), user_avatars/{uid}.png (the
// dashboard's avatar editor), facility_logos/{facilityId}.png,
// payment_proofs/{facilityId}/{millis}.jpg, product_images/{facilityId}/{uuid}.jpg,
// announcement_posters/{docId}-{millis}.{ext} (AN1). login_poster/ and
// login_logo/ lost their rules in AN1 (unused since G1).

const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-vetbiz-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
    storage: { rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

const MB = 1024 * 1024;
const bytes = (n = 16) => new Uint8Array(n);
const jpeg = { contentType: 'image/jpeg' };
const png = { contentType: 'image/png' };

// The same people as the Firestore suite: F1 has an owner and an assistant,
// F2 belongs to the "outsider", and "pa" is a Platform Admin in no facility.
beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (uid, data) => db.collection('users').doc(uid).set({ uid, status: 'active', ...data });
    await user('owner', { role: 'admin', facilityIds: ['F1'] });
    await user('assistant', { role: 'assistant', facilityIds: ['F1'] });
    await user('outsider', { role: 'admin', facilityIds: ['F2'] });
    await user('pa', { role: 'admin', facilityIds: [] });
    await db.collection('platform_admins').doc('pa').set({ email: 'pa@example.com' });

    const st = ctx.storage();
    await st.ref('payment_proofs/F1/1700000000000.jpg').put(bytes(), jpeg);
    await st.ref('facility_logos/F1.png').put(bytes(), png);
    await st.ref('avatars/owner.jpg').put(bytes(), jpeg);
    await st.ref('product_images/F1/p1.jpg').put(bytes(), jpeg);
    await st.ref('login_poster/poster.jpg').put(bytes(), jpeg);
  });
});

const ref = (uid, p) => env.authenticatedContext(uid).storage().ref(p);
const signedOutRef = (p) => env.unauthenticatedContext().storage().ref(p);
const upload = (uid, p, meta = jpeg, size = 16) => ref(uid, p).put(bytes(size), meta);

// ---------------------------------------------------------------------------
// Avatars: only the person whose uid is the file name (before the extension).
// ---------------------------------------------------------------------------

test('avatars: a person uploads their own avatar under both prefixes', async () => {
  await assertSucceeds(upload('owner', 'avatars/owner.jpg'));
  await assertSucceeds(upload('assistant', 'user_avatars/assistant.png', png));
});

test('avatars [E4a]: nobody can overwrite someone else\'s avatar, or one whose name only STARTS with their uid', async () => {
  await assertFails(upload('outsider', 'avatars/owner.jpg'));
  await assertFails(upload('outsider', 'user_avatars/owner.png', png));
  // "owner" must not be able to write "ownerX"'s file.
  await assertFails(upload('owner', 'avatars/ownerX.jpg'));
  await assertFails(upload('owner', 'user_avatars/ownerX.png', png));
});

test('avatars: anyone can read one (shown before sign-in); a signed-out visitor can not upload', async () => {
  await assertSucceeds(signedOutRef('avatars/owner.jpg').getDownloadURL());
  await assertFails(signedOutRef('avatars/x.jpg').put(bytes(), jpeg));
});

// G2: Remove photo deletes the person's photo under both prefixes (the
// legacy user_avatars/{uid}.png too). A delete sends no file, so it is a
// rule of its own, like facility logos.
const seedAvatars = () => env.withSecurityRulesDisabled(async (ctx) => {
  const st = ctx.storage();
  await st.ref('user_avatars/owner.png').put(bytes(), png);
  await st.ref('avatars/ownerX.jpg').put(bytes(), jpeg);
  await st.ref('user_avatars/ownerX.png').put(bytes(), png);
});

test('avatars [G2]: the owner deletes their own photo under both prefixes', async () => {
  await seedAvatars();
  await assertSucceeds(ref('owner', 'avatars/owner.jpg').delete());
  await assertSucceeds(ref('owner', 'user_avatars/owner.png').delete());
});

test('avatars [G2]: another signed-in person and a signed-out visitor can not delete it', async () => {
  await seedAvatars();
  for (const p of ['avatars/owner.jpg', 'user_avatars/owner.png']) {
    await assertFails(ref('outsider', p).delete());
    await assertFails(ref('assistant', p).delete());
    await assertFails(signedOutRef(p).delete());
  }
});

test('avatars [G2]: a file whose name only STARTS with the uid can not be deleted by that uid', async () => {
  await seedAvatars();
  await assertFails(ref('owner', 'avatars/ownerX.jpg').delete());
  await assertFails(ref('owner', 'user_avatars/ownerX.png').delete());
});

test('avatars [G2]: creating still needs an image, at most 5 MB, and the right uid', async () => {
  for (const p of ['avatars/owner.jpg', 'user_avatars/owner.png']) {
    await assertFails(upload('owner', p, { contentType: 'text/html' }));
    await assertFails(ref('owner', p).put(bytes()));
    await assertFails(upload('owner', p, jpeg, 5 * MB + 1));
    await assertFails(upload('outsider', p));
    await assertSucceeds(upload('owner', p, jpeg, 5 * MB));
  }
});

// ---------------------------------------------------------------------------
// Facility logos: only a member of the facility named in the file name.
// ---------------------------------------------------------------------------

test('facility logos: a member uploads and removes their facility\'s logo; anyone can read it', async () => {
  await assertSucceeds(signedOutRef('facility_logos/F1.png').getDownloadURL());
  await assertSucceeds(upload('owner', 'facility_logos/F1.png', png));
  await assertSucceeds(upload('assistant', 'facility_logos/F1.png', png));
  await assertSucceeds(ref('owner', 'facility_logos/F1.png').delete());
});

test('facility logos [E4a]: an admin of another facility can NOT replace or remove it', async () => {
  await assertFails(upload('outsider', 'facility_logos/F1.png', png));
  await assertFails(ref('outsider', 'facility_logos/F1.png').delete());
  await assertSucceeds(upload('outsider', 'facility_logos/F2.png', png)); // their own, yes
});

// ---------------------------------------------------------------------------
// Payment proofs: private to the facility and the Platform Admins.
// ---------------------------------------------------------------------------

test('payment proofs: the facility\'s members and a Platform Admin can read one', async () => {
  await assertSucceeds(ref('owner', 'payment_proofs/F1/1700000000000.jpg').getDownloadURL());
  await assertSucceeds(ref('assistant', 'payment_proofs/F1/1700000000000.jpg').getDownloadURL());
  await assertSucceeds(ref('pa', 'payment_proofs/F1/1700000000000.jpg').getDownloadURL());
});

test('payment proofs [E4a]: an admin of another facility and a signed-out visitor can NOT read one', async () => {
  await assertFails(ref('outsider', 'payment_proofs/F1/1700000000000.jpg').getDownloadURL());
  await assertFails(ref('outsider', 'payment_proofs/F1/1700000000000.jpg').getMetadata());
  await assertFails(signedOutRef('payment_proofs/F1/1700000000000.jpg').getDownloadURL());
});

test('payment proofs: a member uploads one for their facility; an outsider can not', async () => {
  await assertSucceeds(upload('owner', 'payment_proofs/F1/1700000000001.jpg'));
  await assertFails(upload('outsider', 'payment_proofs/F1/1700000000001.jpg'));
});

// ---------------------------------------------------------------------------
// Product images: write rules unchanged, plus the
// content checks below.
// ---------------------------------------------------------------------------

test('product images: a member uploads one; an outsider can not; anyone can read', async () => {
  await assertSucceeds(upload('assistant', 'product_images/F1/p2.jpg'));
  await assertFails(upload('outsider', 'product_images/F1/p2.jpg'));
  await assertSucceeds(signedOutRef('product_images/F1/p1.jpg').getDownloadURL());
});

// ---------------------------------------------------------------------------
// Every upload path: an image, and at most 5 MB.
// ---------------------------------------------------------------------------

// Each uploader allowed on its path, with a name the app uses.
const uploads = [
  ['owner', 'avatars/owner.jpg'],
  ['owner', 'user_avatars/owner.png'],
  ['owner', 'facility_logos/F1.png'],
  ['owner', 'payment_proofs/F1/1700000000002.jpg'],
  ['owner', 'product_images/F1/p3.jpg'],
];

test('every upload path [E4a]: a file that is not an image is refused', async () => {
  for (const [uid, p] of uploads) {
    await assertFails(upload(uid, p, { contentType: 'text/html' }));
    // No content type given: the web SDK sends application/octet-stream.
    await assertFails(ref(uid, p).put(bytes()));
  }
});

test('every upload path [E4a]: more than 5 MB is refused; exactly 5 MB is allowed', async () => {
  for (const [uid, p] of uploads) {
    await assertFails(upload(uid, p, jpeg, 5 * MB + 1));
    await assertSucceeds(upload(uid, p, jpeg, 5 * MB));
  }
});

// ---------------------------------------------------------------------------
// AN1: announcement posters. Public read; only a Platform Admin uploads
// (exactly image/jpeg, image/png or image/webp, at most 1 MB) or deletes.
// The app names the file {docId}-{millis}.{ext}.
// ---------------------------------------------------------------------------

const poster = 'announcement_posters/A1-1700000000000.jpg';
const seedPoster = () => env.withSecurityRulesDisabled((ctx) => ctx.storage().ref(poster).put(bytes(), jpeg));

test('announcement posters [AN1]: a Platform Admin uploads a small JPEG, a PNG and a WebP', async () => {
  await assertSucceeds(upload('pa', 'announcement_posters/A1-1.jpg'));
  await assertSucceeds(upload('pa', 'announcement_posters/A1-2.png', png));
  await assertSucceeds(upload('pa', 'announcement_posters/A1-3.webp', { contentType: 'image/webp' }));
  await assertSucceeds(upload('pa', 'announcement_posters/A1-4.jpg', jpeg, MB)); // exactly 1 MB
});

test('announcement posters [AN1]: an SVG, a GIF, other types, no type and more than 1 MB are refused, even for a Platform Admin', async () => {
  await assertFails(upload('pa', 'announcement_posters/A1-1.svg', { contentType: 'image/svg+xml' }));
  await assertFails(upload('pa', 'announcement_posters/A1-1.gif', { contentType: 'image/gif' }));
  await assertFails(upload('pa', 'announcement_posters/A1-1.jpg', { contentType: 'image/jpeg; x=1' }));
  await assertFails(upload('pa', 'announcement_posters/A1-1.html', { contentType: 'text/html' }));
  await assertFails(ref('pa', 'announcement_posters/A1-1.jpg').put(bytes()));
  await assertFails(upload('pa', 'announcement_posters/A1-1.jpg', jpeg, MB + 1));
});

test('announcement posters [AN1]: a signed-in non-admin and a signed-out visitor can not upload', async () => {
  for (const uid of ['owner', 'assistant', 'outsider']) {
    await assertFails(upload(uid, 'announcement_posters/A1-1.jpg'));
  }
  await assertFails(signedOutRef('announcement_posters/A1-1.jpg').put(bytes(), jpeg));
});

test('announcement posters [AN1]: anyone can read one, signed out too', async () => {
  await seedPoster();
  await assertSucceeds(signedOutRef(poster).getDownloadURL());
  await assertSucceeds(ref('assistant', poster).getDownloadURL());
});

test('announcement posters [AN1]: only a Platform Admin deletes one', async () => {
  await seedPoster();
  for (const uid of ['owner', 'assistant', 'outsider']) {
    await assertFails(ref(uid, poster).delete());
  }
  await assertFails(signedOutRef(poster).delete());
  await assertSucceeds(ref('pa', poster).delete());
});

test('login poster and logo [AN1]: the unused paths are gone - nobody uploads, reads or deletes there', async () => {
  for (const p of ['login_poster/poster.jpg', 'login_logo/logo.png']) {
    await assertFails(upload('pa', p));
    await assertFails(signedOutRef(p).getDownloadURL());
    await assertFails(ref('pa', p).delete());
  }
});
