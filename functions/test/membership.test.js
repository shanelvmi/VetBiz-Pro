"use strict";

// Unit tests for membership.js against a fake database (see fake_firestore.js).
// Run:  cd functions && npm test

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { FakeDb, FakeTimestamp, FieldValue, HttpsError } = require("./fake_firestore");
const membership = require("../membership");

const NOW = new Date("2026-10-05T10:00:00Z");
const hoursFromNow = (h) => new Date(NOW.getTime() + h * 60 * 60 * 1000);

// [sequence]: forces the random numbers, to provoke a code collision.
function setup(sequence) {
  const db = new FakeDb();
  db.clock = () => NOW;
  let counter = 0;
  let i = 0;
  const randomInt = sequence
    ? (n) => (i < sequence.length ? sequence[i++] % n : 2)
    : (n) => (counter++ * 7 + 3) % n;
  const fns = membership.create({
    db,
    FieldValue,
    Timestamp: FakeTimestamp,
    HttpsError,
    randomInt,
    now: () => NOW,
  });
  return { db, fns };
}

const as = (uid, email) => ({ auth: { uid, token: { email: email || `${uid}@example.com` } } });

const entry = (id, name, type, code) => ({ facilityId: id, name, type, code });
const F1 = entry("F1", "Ukuli", "Agrovet", "AAAA1111");
const F2 = entry("F2", "Other Vet", "Vet Clinic", "BBBB2222");

// Two separate businesses: F1 (owner, a Co-admin, an Assistant) and F2 (its
// own owner), plus a Platform Admin.
function seedWorld(db) {
  db.seed("facilities", "F1", { name: "Ukuli", type: "Agrovet", code: "AAAA1111", createdBy: "owner" });
  db.seed("facilities", "F2", { name: "Other Vet", type: "Vet Clinic", code: "BBBB2222", createdBy: "outsider" });
  db.seed("users", "owner", { role: "admin", status: "active", facilityIds: ["F1"], facilities: [F1] });
  db.seed("users", "coadmin", {
    role: "admin",
    previousRole: "assistant",
    status: "active",
    facilityIds: ["F1"],
    facilities: [F1],
  });
  db.seed("users", "assistant", { role: "assistant", status: "active", facilityIds: ["F1"], facilities: [F1] });
  db.seed("users", "outsider", { role: "admin", status: "active", facilityIds: ["F2"], facilities: [F2] });
  db.seed("users", "pa", { role: "admin", status: "active", facilityIds: [], facilities: [] });
  db.seed("platform_admins", "pa", {});
}

function seedInvite(db, code, overrides = {}) {
  db.seed("inviteCodes", code, {
    facilityId: "F1",
    facilityName: "Ukuli",
    facilityType: "Agrovet",
    createdByUserId: "owner",
    expiresAt: new FakeTimestamp(hoursFromNow(24)),
    usedAt: null,
    usedByEmail: null,
    ...overrides,
  });
}

async function rejects(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected "${code}" but got "${e.code}": ${e.message}`);
    return true;
  });
}

const validOwner = (extra = {}) => ({
  fullName: "Dr. Asha Mwita",
  phone: "0712 345 678",
  facilities: [{ name: "Ukuli", type: "Agrovet" }],
  ...extra,
});

// ======================================================================
describe("helpers", () => {
  const { normalizeInviteCode, trialExpiry, inviteProblem } = membership.helpers;

  test("an invite code is the same however it's typed", () => {
    assert.equal(normalizeInviteCode("jk7 2p4"), "JK72P4");
    assert.equal(normalizeInviteCode("JK7-2P4"), "JK72P4");
    assert.equal(normalizeInviteCode("jk72p4"), "JK72P4");
    assert.equal(normalizeInviteCode("JK72P"), null);
    assert.equal(normalizeInviteCode("JK72P44"), null);
    assert.equal(normalizeInviteCode(123456), null);
    assert.equal(normalizeInviteCode(undefined), null);
  });

  test("a trial ends at the end of the day, East Africa Time", () => {
    // 10:00 UTC = 13:00 EAT on 5 Oct; 14 days on is 19 Oct; its last second is 20:59:59 UTC.
    assert.equal(trialExpiry(NOW, 14).toISOString(), "2026-10-19T20:59:59.000Z");
    // 22:30 UTC is already 01:30 on 6 Oct in Tanzania - so the day counted from is the 6th.
    assert.equal(trialExpiry(new Date("2026-10-05T22:30:00Z"), 14).toISOString(), "2026-10-20T20:59:59.000Z");
  });

  test("invite problems", () => {
    const ok = { facilityId: "F1", usedAt: null, expiresAt: new FakeTimestamp(hoursFromNow(1)) };
    assert.equal(inviteProblem(ok, NOW), null);
    assert.equal(inviteProblem(undefined, NOW), "missing");
    assert.equal(inviteProblem({ ...ok, usedAt: new FakeTimestamp(NOW) }, NOW), "used");
    assert.equal(inviteProblem({ ...ok, expiresAt: new FakeTimestamp(hoursFromNow(-1)) }, NOW), "expired");
    assert.equal(inviteProblem({ ...ok, facilityId: "" }, NOW), "broken");
    assert.equal(inviteProblem({ ...ok, expiresAt: null }, NOW), "expired");
  });
});

// ======================================================================
describe("checkInviteCode (callable by anyone)", () => {
  test("a good code returns the facility's name and type - and NEVER its id", async () => {
    const { db, fns } = setup();
    seedInvite(db, "JK72P4");
    const result = await fns.checkInviteCode({ code: "jk7-2p4" }); // no sign-in
    assert.deepEqual(result, { valid: true, facilityName: "Ukuli", facilityType: "Agrovet" });
    assert.equal(JSON.stringify(result).includes("F1"), false);
  });

  test("unknown, used, expired and malformed codes all give the same plain answer", async () => {
    const { db, fns } = setup();
    seedInvite(db, "USED22", { usedAt: new FakeTimestamp(NOW) });
    seedInvite(db, "OLD222", { expiresAt: new FakeTimestamp(hoursFromNow(-2)) });
    for (const code of ["NOPE22", "USED22", "OLD222", "abc", "", undefined, 5]) {
      assert.deepEqual(await fns.checkInviteCode({ code }), { valid: false }, `code: ${code}`);
    }
    assert.deepEqual(await fns.checkInviteCode(undefined), { valid: false });
  });
});

// ======================================================================
describe("registerOwner", () => {
  test("creates the profile and the facility together", async () => {
    const { db, fns } = setup();
    const result = await fns.registerOwner(validOwner(), as("newowner", "asha@example.com"));

    assert.equal(result.facilities.length, 1);
    const f = result.facilities[0];
    assert.equal(f.name, "Ukuli");
    assert.equal(f.type, "Agrovet");
    assert.match(f.code, /^[A-Z0-9]{8}$/);

    const user = db.read("users", "newowner");
    assert.equal(user.role, "admin");
    assert.equal(user.status, "active");
    assert.equal(user.email, "asha@example.com");
    assert.equal(user.fullName, "Dr. Asha Mwita");
    assert.deepEqual(user.facilityIds, [f.facilityId]);
    assert.deepEqual(user.facilities, [f]);

    const facility = db.read("facilities", f.facilityId);
    assert.equal(facility.createdBy, "newowner");
    assert.equal(facility.code, f.code);
    // 14 days by default, to the end of that day in Tanzania.
    assert.equal(facility.trialExpiresAt.toDate().toISOString(), "2026-10-19T20:59:59.000Z");
  });

  test("the trial length and facility limit come from the platform settings", async () => {
    const { db, fns } = setup();
    db.seed("platform_config", "settings", { trialDays: 30, maxFacilitiesPerAdmin: 2 });
    const r = await fns.registerOwner(validOwner(), as("o1"));
    assert.equal(db.read("facilities", r.facilities[0].facilityId).trialExpiresAt.toDate().toISOString(), "2026-11-04T20:59:59.000Z");

    const three = validOwner({ facilities: [1, 2, 3].map((n) => ({ name: `F${n}`, type: "Agrovet" })) });
    await rejects(fns.registerOwner(three, as("o2")), "failed-precondition");
    assert.equal(db.read("users", "o2"), undefined);
  });

  test("whatever the app claims about role, status, facilities or trial is ignored", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    const result = await fns.registerOwner(
      validOwner({
        role: "platformAdmin",
        status: "active",
        facilityIds: ["F1"], // someone else's facility
        trialExpiresAt: "2099-01-01",
        createdBy: "owner",
        uid: "owner",
      }),
      as("attacker")
    );
    const user = db.read("users", "attacker");
    assert.equal(user.role, "admin");
    assert.equal(user.uid, "attacker");
    assert.equal(user.facilityIds.includes("F1"), false);
    assert.equal(user.facilityIds.length, 1);
    const facility = db.read("facilities", result.facilities[0].facilityId);
    assert.equal(facility.createdBy, "attacker");
    assert.equal(facility.trialExpiresAt.toDate().toISOString(), "2026-10-19T20:59:59.000Z");
  });

  test("a profile is created ONCE - calling again creates nothing more", async () => {
    const { db, fns } = setup();
    await fns.registerOwner(validOwner(), as("o1"));
    const before = db.all("facilities").length;
    await rejects(fns.registerOwner(validOwner(), as("o1")), "already-exists");
    assert.equal(db.all("facilities").length, before);
  });

  test("several facilities in one registration, up to the limit", async () => {
    const { db, fns } = setup();
    const r = await fns.registerOwner(
      validOwner({ facilities: [{ name: "A", type: "Agrovet" }, { name: "B", type: "Other" }] }),
      as("o1")
    );
    assert.equal(r.facilities.length, 2);
    assert.equal(db.read("users", "o1").facilityIds.length, 2);
    assert.notEqual(r.facilities[0].facilityId, r.facilities[1].facilityId);
  });

  test("must be signed in", async () => {
    const { fns } = setup();
    await rejects(fns.registerOwner(validOwner(), {}), "unauthenticated");
    await rejects(fns.registerOwner(validOwner(), undefined), "unauthenticated");
  });

  test("bad input is refused, and nothing is created", async () => {
    const { db, fns } = setup();
    const bad = [
      validOwner({ fullName: "A" }),
      validOwner({ fullName: "" }),
      validOwner({ phone: "123" }),
      validOwner({ phone: "07x2 abc 999" }),
      validOwner({ facilities: [] }),
      validOwner({ facilities: undefined }),
      validOwner({ facilities: [{ name: "", type: "Agrovet" }] }),
      validOwner({ facilities: [{ name: "Ukuli", type: "Pharmacy" }] }),
      validOwner({ facilities: [{ name: "Ukuli", type: "Agrovet" }, { name: "X", type: "Nope" }] }),
    ];
    for (const data of bad) await rejects(fns.registerOwner(data, as("o1")), "invalid-argument");
    assert.equal(db.all("users").length, 0);
    assert.equal(db.all("facilities").length, 0);
  });

  test("an avatar link is kept only if it's https", async () => {
    const { db, fns } = setup();
    await fns.registerOwner(validOwner({ avatarUrl: "https://firebasestorage.example/a.jpg" }), as("o1"));
    assert.equal(db.read("users", "o1").avatarUrl, "https://firebasestorage.example/a.jpg");
    await fns.registerOwner(validOwner({ avatarUrl: "javascript:alert(1)" }), as("o2"));
    assert.equal(db.read("users", "o2").avatarUrl, "");
  });
});

// ======================================================================
describe("joinWithInvite", () => {
  const join = (extra = {}) => ({ code: "JK7-2P4", fullName: "Neema Joseph", phone: "0755 111 222", ...extra });

  test("creates a PENDING assistant in the invited facility and uses up the code", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    const result = await fns.joinWithInvite(join(), as("newbie", "neema@example.com"));
    assert.deepEqual(result, { facilityName: "Ukuli", facilityType: "Agrovet" });

    const user = db.read("users", "newbie");
    assert.equal(user.role, "assistant");
    assert.equal(user.status, "pending");
    assert.deepEqual(user.facilityIds, ["F1"]);
    assert.deepEqual(user.facilities, [F1]);

    const invite = db.read("inviteCodes", "JK72P4");
    assert.notEqual(invite.usedAt, null);
    assert.equal(invite.usedByEmail, "neema@example.com");
    assert.equal(invite.usedByUid, "newbie");
  });

  test("the person can NOT choose their own role, status or facility", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await fns.joinWithInvite(
      join({ role: "admin", status: "active", facilityIds: ["F2"], facilities: [F2] }),
      as("newbie")
    );
    const user = db.read("users", "newbie");
    assert.equal(user.role, "assistant");
    assert.equal(user.status, "pending");
    assert.deepEqual(user.facilityIds, ["F1"]);
  });

  test("a code can be used ONCE", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await fns.joinWithInvite(join(), as("first"));
    await rejects(fns.joinWithInvite(join(), as("second")), "failed-precondition");
    assert.equal(db.read("users", "second"), undefined);
  });

  test("two people redeeming the same code at the same moment: exactly ONE gets in", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    const results = await Promise.allSettled([
      fns.joinWithInvite(join({ fullName: "Anna Said" }), as("u1")),
      fns.joinWithInvite(join({ fullName: "Brian Ali" }), as("u2")),
    ]);
    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(results.find((r) => r.status === "rejected").reason.code, "failed-precondition");
    assert.equal([db.read("users", "u1"), db.read("users", "u2")].filter(Boolean).length, 1);
  });

  test("unknown, expired and malformed codes are refused with one message", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "OLD222", { expiresAt: new FakeTimestamp(hoursFromNow(-1)) });
    for (const code of ["NOPE22", "OLD222", "abc", "", undefined]) {
      await assert.rejects(fns.joinWithInvite(join({ code }), as("newbie")), (e) => {
        assert.equal(e.code, "failed-precondition");
        assert.equal(e.message, "Invalid, expired, or already-used invite code");
        return true;
      });
    }
    assert.equal(db.read("users", "newbie"), undefined);
  });

  test("an account that already has a profile can't use up a code", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await rejects(fns.joinWithInvite(join(), as("assistant")), "already-exists");
    assert.equal(db.read("inviteCodes", "JK72P4").usedAt, null);
  });

  test("a code for a facility that no longer exists is refused", async () => {
    const { db, fns } = setup();
    seedInvite(db, "JK72P4", { facilityId: "GONE" });
    await rejects(fns.joinWithInvite(join(), as("newbie")), "failed-precondition");
    assert.equal(db.read("users", "newbie"), undefined);
  });

  test("must be signed in; bad name or phone refused", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await rejects(fns.joinWithInvite(join(), {}), "unauthenticated");
    await rejects(fns.joinWithInvite(join({ fullName: "" }), as("newbie")), "invalid-argument");
    await rejects(fns.joinWithInvite(join({ phone: "12" }), as("newbie")), "invalid-argument");
    assert.equal(db.read("inviteCodes", "JK72P4").usedAt, null); // nothing consumed
  });
});

// ======================================================================
describe("addFacility", () => {
  test("an admin adds a facility: created, owned by them, added to BOTH of their lists", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    const e = await fns.addFacility({ name: "Ukuli Clinic", type: "Vet Clinic" }, as("owner"));
    const facility = db.read("facilities", e.facilityId);
    assert.equal(facility.createdBy, "owner");
    assert.equal(facility.trialExpiresAt.toDate().toISOString(), "2026-10-19T20:59:59.000Z");
    const user = db.read("users", "owner");
    assert.deepEqual(user.facilityIds, ["F1", e.facilityId]);
    assert.equal(user.facilities.length, 2);
    assert.deepEqual(user.facilities[1], e);
  });

  test("the facility limit is enforced", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("platform_config", "settings", { maxFacilitiesPerAdmin: 2 });
    await fns.addFacility({ name: "Second", type: "Agrovet" }, as("owner")); // 1 -> 2
    await rejects(fns.addFacility({ name: "Third", type: "Agrovet" }, as("owner")), "resource-exhausted");
    assert.equal(db.read("users", "owner").facilityIds.length, 2);
  });

  test("two quick taps can't both slip under the limit", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("platform_config", "settings", { maxFacilitiesPerAdmin: 2 });
    const results = await Promise.allSettled([
      fns.addFacility({ name: "A", type: "Agrovet" }, as("owner")),
      fns.addFacility({ name: "B", type: "Agrovet" }, as("owner")),
    ]);
    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(db.read("users", "owner").facilityIds.length, 2);
  });

  test("a Co-admin can add one (their membership counts towards the limit)", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    const e = await fns.addFacility({ name: "Mine", type: "Other" }, as("coadmin"));
    assert.deepEqual(db.read("users", "coadmin").facilityIds, ["F1", e.facilityId]);
  });

  test("assistants, deactivated admins and strangers can't", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "gone", { role: "admin", status: "deactivated", facilityIds: ["F1"], facilities: [F1] });
    const call = (uid) => fns.addFacility({ name: "X", type: "Agrovet" }, as(uid));
    await rejects(call("assistant"), "permission-denied");
    await rejects(call("gone"), "permission-denied");
    await rejects(call("nobody"), "permission-denied");
    await rejects(fns.addFacility({ name: "X", type: "Agrovet" }, {}), "unauthenticated");
    assert.equal(db.all("facilities").length, 2);
  });

  test("bad input is refused", async () => {
    const { fns, db } = setup();
    seedWorld(db);
    await rejects(fns.addFacility({ name: "", type: "Agrovet" }, as("owner")), "invalid-argument");
    await rejects(fns.addFacility({ name: "X", type: "Pharmacy" }, as("owner")), "invalid-argument");
  });
});

// ======================================================================
describe("createInviteCode", () => {
  test("an admin creates a code for their own facility", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    const { code, expiresAt } = await fns.createInviteCode({ facilityId: "F1" }, as("owner"));
    assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
    assert.equal(expiresAt, hoursFromNow(48).toISOString());
    const invite = db.read("inviteCodes", code);
    assert.equal(invite.facilityId, "F1");
    assert.equal(invite.facilityName, "Ukuli");
    assert.equal(invite.facilityType, "Agrovet");
    assert.equal(invite.createdByUserId, "owner");
    assert.equal(invite.usedAt, null);
  });

  test("a new code replaces the earlier UNUSED one - but never touches a used one", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "OLDONE", {});
    seedInvite(db, "USEDAL", { usedAt: new FakeTimestamp(NOW), usedByEmail: "x@y.z" });
    seedInvite(db, "OTHERF", { facilityId: "F2" });
    const { code } = await fns.createInviteCode({ facilityId: "F1" }, as("owner"));
    assert.equal(db.read("inviteCodes", "OLDONE"), undefined, "the earlier unused code is revoked");
    assert.notEqual(db.read("inviteCodes", "USEDAL"), undefined, "a used code is kept (it's the record)");
    assert.notEqual(db.read("inviteCodes", "OTHERF"), undefined, "another facility's code is untouched");
    assert.notEqual(db.read("inviteCodes", code), undefined);
  });

  test("if the first random code is already taken, another is tried", async () => {
    // 6 x index 0 = "AAAAAA", then 6 x index 1 = "BBBBBB".
    const { db, fns } = setup([0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]);
    seedWorld(db);
    seedInvite(db, "AAAAAA", { facilityId: "F2" });
    const { code } = await fns.createInviteCode({ facilityId: "F1" }, as("owner"));
    assert.equal(code, "BBBBBB");
    assert.equal(db.read("inviteCodes", "AAAAAA").facilityId, "F2", "the other facility's code is NOT overwritten");
  });

  test("a Co-admin and a Platform Admin can; nobody else can", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await fns.createInviteCode({ facilityId: "F1" }, as("coadmin"));
    await fns.createInviteCode({ facilityId: "F1" }, as("pa"));
    await rejects(fns.createInviteCode({ facilityId: "F1" }, as("assistant")), "permission-denied");
    await rejects(fns.createInviteCode({ facilityId: "F1" }, as("outsider")), "permission-denied"); // another business's admin
    await rejects(fns.createInviteCode({ facilityId: "F2" }, as("owner")), "permission-denied");
    await rejects(fns.createInviteCode({ facilityId: "F1" }, as("nobody")), "permission-denied");
    await rejects(fns.createInviteCode({ facilityId: "F1" }, {}), "unauthenticated");
  });

  test("a facility that doesn't exist, or a bad id", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "owner", { role: "admin", status: "active", facilityIds: ["F1", "GONE"], facilities: [] });
    await rejects(fns.createInviteCode({ facilityId: "GONE" }, as("owner")), "not-found");
    await rejects(fns.createInviteCode({ facilityId: "" }, as("owner")), "invalid-argument");
    await rejects(fns.createInviteCode({ facilityId: "a/b" }, as("owner")), "invalid-argument");
  });
});

// ======================================================================
describe("reassignAssistant / removeAssistantFromFacility", () => {
  test("an admin of both facilities moves an assistant, with fresh facility details", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "owner", { role: "admin", status: "active", facilityIds: ["F1", "F2"], facilities: [F1, F2] });
    await fns.reassignAssistant({ assistantUid: "assistant", newFacilityId: "F2" }, as("owner"));
    const a = db.read("users", "assistant");
    assert.deepEqual(a.facilityIds, ["F2"]);
    assert.deepEqual(a.facilities, [F2]);
  });

  test("can't move someone into a facility you don't administer", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await rejects(fns.reassignAssistant({ assistantUid: "assistant", newFacilityId: "F2" }, as("owner")), "permission-denied");
    assert.deepEqual(db.read("users", "assistant").facilityIds, ["F1"]);
  });

  test("can't touch an assistant who isn't in one of your facilities", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "owner2", { role: "admin", status: "active", facilityIds: ["F2"], facilities: [F2] });
    await rejects(fns.reassignAssistant({ assistantUid: "assistant", newFacilityId: "F2" }, as("owner2")), "permission-denied");
    await rejects(fns.removeAssistantFromFacility({ assistantUid: "assistant", facilityId: "F1" }, as("outsider")), "permission-denied");
  });

  test("only assistants can be reassigned or removed this way - not a Co-admin or the owner", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await rejects(fns.reassignAssistant({ assistantUid: "coadmin", newFacilityId: "F1" }, as("owner")), "failed-precondition");
    await rejects(fns.removeAssistantFromFacility({ assistantUid: "coadmin", facilityId: "F1" }, as("owner")), "failed-precondition");
    await rejects(fns.removeAssistantFromFacility({ assistantUid: "owner", facilityId: "F1" }, as("coadmin")), "failed-precondition");
  });

  test("an assistant can't reassign or remove anyone", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "assistant2", { role: "assistant", status: "active", facilityIds: ["F1"], facilities: [F1] });
    await rejects(fns.removeAssistantFromFacility({ assistantUid: "assistant2", facilityId: "F1" }, as("assistant")), "permission-denied");
    await rejects(fns.reassignAssistant({ assistantUid: "assistant2", newFacilityId: "F1" }, as("assistant")), "permission-denied");
  });

  test("remove takes the facility out of BOTH lists", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await fns.removeAssistantFromFacility({ assistantUid: "assistant", facilityId: "F1" }, as("owner"));
    const a = db.read("users", "assistant");
    assert.deepEqual(a.facilityIds, []);
    assert.deepEqual(a.facilities, []);
  });

  test("remove: the assistant must actually be in that facility", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "owner", { role: "admin", status: "active", facilityIds: ["F1", "F2"], facilities: [F1, F2] });
    await rejects(fns.removeAssistantFromFacility({ assistantUid: "assistant", facilityId: "F2" }, as("owner")), "permission-denied");
  });
});

// ======================================================================
describe("keeping each member's copy of a facility's name in step", () => {
  test("a rename reaches the owner, the Co-admin and the assistants - and nobody else", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("facilities", "F1", { name: "Ukuli Renamed", type: "Vet Clinic", code: "AAAA1111", createdBy: "owner" });
    const r = await fns.syncFacilityDetails({ facilityId: "F1" }, as("owner"));
    assert.equal(r.updated, 3);
    for (const uid of ["owner", "coadmin", "assistant"]) {
      assert.equal(db.read("users", uid).facilities[0].name, "Ukuli Renamed", uid);
      assert.equal(db.read("users", uid).facilities[0].type, "Vet Clinic", uid);
      assert.equal(db.read("users", uid).facilities[0].code, "AAAA1111", "the code is kept");
    }
    assert.equal(db.read("users", "outsider").facilities[0].name, "Other Vet");
  });

  test("nothing to change, nothing written", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    assert.deepEqual(await fns.syncFacilityDetails({ facilityId: "F1" }, as("owner")), { updated: 0 });
  });

  test("a big facility is updated in batches of at most 400", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    for (let i = 0; i < 450; i++) {
      db.seed("users", `staff${i}`, { role: "assistant", status: "active", facilityIds: ["F1"], facilities: [F1] });
    }
    db.seed("facilities", "F1", { name: "Renamed", type: "Agrovet", code: "AAAA1111", createdBy: "owner" });

    const sizes = [];
    const original = db.batch.bind(db);
    db.batch = () => {
      const b = original();
      let n = 0;
      const count = (f) => (...args) => {
        n++;
        return f(...args);
      };
      return { set: count(b.set), update: count(b.update), delete: count(b.delete), commit: async () => (sizes.push(n), b.commit()) };
    };

    const r = await fns.propagateFacilityDetails("F1");
    assert.equal(r.updated, 453); // 450 + owner + coadmin + assistant
    assert.ok(sizes.every((s) => s <= 400), `batch sizes: ${sizes}`);
    assert.equal(db.read("users", "staff449").facilities[0].name, "Renamed");
  });

  test("only an admin of the facility (or a Platform Admin) can ask for it", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await fns.syncFacilityDetails({ facilityId: "F1" }, as("pa"));
    await rejects(fns.syncFacilityDetails({ facilityId: "F1" }, as("assistant")), "permission-denied");
    await rejects(fns.syncFacilityDetails({ facilityId: "F1" }, as("outsider")), "permission-denied");
    await rejects(fns.syncFacilityDetails({ facilityId: "F1" }, {}), "unauthenticated");
  });

  test("a facility that's gone updates nobody", async () => {
    const { fns } = setup();
    assert.deepEqual(await fns.propagateFacilityDetails("GONE"), { updated: 0 });
  });
});

// ======================================================================
// NOTIFICATIONS - written the moment things happen.
//
// The bell used to blink for a newly registered assistant from a live watcher
// of its own, while the Notifications list stayed empty: nothing ever wrote a
// notification. Nor was a new owner told their trial had started.
// ======================================================================

const notificationsOf = (db, facilityId) => {
  const path = `facilities/${facilityId}/notifications`;
  return db.all(path).map((id) => db.read(path, id));
};

describe("notifications", () => {
  test("the free trial is NOT written as a stored notice - the app shows a live row instead", async () => {
    // A stored one was written once, for admins only, for new accounts only: every
    // existing account and every assistant still had a blinking bell with no
    // message, and a stored copy would only duplicate the live row.
    const { db, fns } = setup();
    const r = await fns.registerOwner(
      validOwner({ facilities: [{ name: "Ukuli", type: "Agrovet" }, { name: "Mjini Vet", type: "Vet Clinic" }] }),
      as("o1")
    );
    for (const f of r.facilities) assert.equal(notificationsOf(db, f.facilityId).length, 0, `${f.name} has no stored notice`);

    const w = setup();
    seedWorld(w.db);
    const added = await w.fns.addFacility({ name: "Ukuli Clinic", type: "Vet Clinic" }, as("owner"));
    assert.equal(notificationsOf(w.db, added.facilityId).length, 0);
    // ...but the trial itself is still there, for the app to build the row from.
    assert.ok(w.db.read("facilities", added.facilityId).trialExpiresAt, "the facility carries its trial end date");
  });

  test("a new assistant waiting for approval is announced to the facility's admins", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await fns.joinWithInvite(
      { code: "JK7-2P4", fullName: "Neema Joseph", phone: "0755 111 222" },
      as("newbie", "neema@example.com")
    );
    const list = notificationsOf(db, "F1");
    assert.equal(list.length, 1);
    const n = list[0];
    assert.equal(n.type, "assistantPending");
    assert.equal(n.audience, "admins");
    assert.equal(n.title, "New assistant waiting for approval");
    assert.ok(n.message.includes("Neema Joseph"));
    assert.ok(n.message.includes("Team Members"), "says where to act");
    assert.equal(n.relatedEntityType, "assistant");
    assert.equal(n.relatedEntityId, "newbie");
    // Not in anyone else's facility.
    assert.equal(notificationsOf(db, "F2").length, 0);
  });

  test("a refused registration writes no notice", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    await rejects(fns.joinWithInvite({ code: "ZZZ-999", fullName: "Neema Joseph", phone: "0755 111 222" }, as("newbie")), "failed-precondition");
    assert.equal(notificationsOf(db, "F1").length, 0);
  });

  test("a notice that can't be written never undoes the registration it's about", async () => {
    const b = setup();
    seedWorld(b.db);
    seedInvite(b.db, "JK72P4");
    b.db.failWrites = (path) => path.includes("/notifications/");
    await b.fns.joinWithInvite({ code: "JK7-2P4", fullName: "Neema Joseph", phone: "0755 111 222" }, as("newbie"));
    assert.equal(b.db.read("users", "newbie").status, "pending");
    assert.notEqual(b.db.read("inviteCodes", "JK72P4").usedAt, null);
  });
});

// ======================================================================
// JOIN ANOTHER FACILITY WHEN YOU HAVE NONE
//
// A removed assistant used to be stuck: removal leaves their status alone (and
// is only offered for deactivated assistants), so they came back "deactivated"
// - and their old admin couldn't reactivate them, being no longer able to see
// them. They had to register again under a new email.
// ======================================================================

describe("joinFacilityWithInvite", () => {
  const removed = (extra = {}) => ({
    uid: "removed",
    fullName: "Baraka Ali",
    email: "baraka@example.com",
    phone: "0766 000 111",
    avatarUrl: "https://example.com/b.jpg",
    role: "assistant",
    status: "deactivated",
    facilityIds: [],
    facilities: [],
    ...extra,
  });
  const ask = (code = "JK7-2P4") => ({ code });

  test("a removed assistant joins another facility: pending, in THAT facility, code used up, admins told", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "removed", removed());
    seedInvite(db, "JK72P4", { facilityId: "F2", facilityName: "Other Vet", facilityType: "Vet Clinic" });

    const result = await fns.joinFacilityWithInvite(ask(), as("removed", "baraka@example.com"));
    assert.deepEqual(result, { facilityName: "Other Vet", facilityType: "Vet Clinic" });

    const user = db.read("users", "removed");
    assert.equal(user.role, "assistant");
    assert.equal(user.status, "pending", "the new facility's admin decides - not automatically active, and no longer deactivated");
    assert.deepEqual(user.facilityIds, ["F2"]);
    assert.deepEqual(user.facilities, [F2]);

    const invite = db.read("inviteCodes", "JK72P4");
    assert.notEqual(invite.usedAt, null);
    assert.equal(invite.usedByUid, "removed");
    assert.equal(invite.usedByEmail, "baraka@example.com");

    const [n] = notificationsOf(db, "F2");
    assert.equal(n.type, "assistantPending");
    assert.equal(n.audience, "admins");
    assert.ok(n.message.includes("Baraka Ali"));
    assert.ok(n.message.includes("asked to join"), "says they were already registered");
    assert.equal(notificationsOf(db, "F1").length, 0);
  });

  test("they keep their name, phone, photo and email", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "removed", removed());
    seedInvite(db, "JK72P4");
    await fns.joinFacilityWithInvite(ask(), as("removed", "baraka@example.com"));
    const user = db.read("users", "removed");
    assert.equal(user.fullName, "Baraka Ali");
    assert.equal(user.phone, "0766 000 111");
    assert.equal(user.avatarUrl, "https://example.com/b.jpg");
    assert.equal(user.email, "baraka@example.com");
  });

  test("it works however the removal left their status (deactivated, active or pending)", async () => {
    for (const status of ["deactivated", "active", "pending"]) {
      const { db, fns } = setup();
      seedWorld(db);
      db.seed("users", "removed", removed({ status }));
      seedInvite(db, "JK72P4");
      await fns.joinFacilityWithInvite(ask(), as("removed"));
      assert.equal(db.read("users", "removed").status, "pending", `from ${status}`);
    }
  });

  test("someone still IN a facility can't use it - moving them is an admin's decision (reassign)", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4", { facilityId: "F2" });
    await rejects(fns.joinFacilityWithInvite(ask(), as("assistant")), "failed-precondition");
    assert.deepEqual(db.read("users", "assistant").facilityIds, ["F1"], "unchanged");
    assert.equal(db.read("inviteCodes", "JK72P4").usedAt, null, "and the code is not used up");
  });

  test("only an ASSISTANT can: an admin is refused", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    // The Platform Admin has no facility of their own - the case most likely to slip through.
    await rejects(fns.joinFacilityWithInvite(ask(), as("pa")), "permission-denied");
    assert.deepEqual(db.read("users", "pa").facilityIds, []);
  });

  test("an account with no profile is told to register, and uses up nothing", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    seedInvite(db, "JK72P4");
    await rejects(fns.joinFacilityWithInvite(ask(), as("nobody")), "failed-precondition");
    assert.equal(db.read("inviteCodes", "JK72P4").usedAt, null);
  });

  test("unknown, used, expired and malformed codes all give the same plain answer", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "removed", removed());
    seedInvite(db, "USED11", { usedAt: new FakeTimestamp(hoursFromNow(-1)) });
    seedInvite(db, "OLD222", { expiresAt: new FakeTimestamp(hoursFromNow(-1)) });
    const messages = new Set();
    for (const code of ["NOPE99", "USED11", "OLD222", "", "!!", null]) {
      await assert.rejects(fns.joinFacilityWithInvite({ code }, as("removed")), (e) => {
        assert.equal(e.code, "failed-precondition");
        messages.add(e.message);
        return true;
      });
    }
    assert.equal(messages.size, 1, "one message, so a code can't be probed");
    assert.equal(db.read("users", "removed").status, "deactivated", "nothing changed");
  });

  test("a code for a facility that no longer exists is refused", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "removed", removed());
    seedInvite(db, "JK72P4", { facilityId: "GONE" });
    await rejects(fns.joinFacilityWithInvite(ask(), as("removed")), "failed-precondition");
  });

  test("two removed assistants redeeming the same code at the same moment: exactly ONE gets in", async () => {
    const { db, fns } = setup();
    seedWorld(db);
    db.seed("users", "r1", removed({ uid: "r1" }));
    db.seed("users", "r2", removed({ uid: "r2" }));
    seedInvite(db, "JK72P4");
    const results = await Promise.allSettled([
      fns.joinFacilityWithInvite(ask(), as("r1")),
      fns.joinFacilityWithInvite(ask(), as("r2")),
    ]);
    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(results.filter((r) => r.status === "rejected").length, 1);
    assert.equal(notificationsOf(db, "F1").length, 1, "and the admins are told once");
  });

  test("must be signed in", async () => {
    const { fns } = setup();
    await rejects(fns.joinFacilityWithInvite(ask(), {}), "unauthenticated");
  });
});

// ======================================================================
// APPROVE / REJECT / DEACTIVATE / REACTIVATE
//
// Used to be plain writes from the app that kept only the LAST change - so
// nothing could say when someone was approved, or by whom, once anything else
// had happened to them. Now each change is stamped by the server and added to
// a history; a change that no longer makes sense is refused; and REJECT takes
// the person out of the facility so they can join elsewhere with an invite.
// ======================================================================

describe("setAssistantStatus", () => {
  const act = (assistantUid, action) => ({ assistantUid, action });

  function world() {
    const w = setup();
    seedWorld(w.db);
    w.db.seed("users", "owner", { role: "admin", status: "active", fullName: "Asha Owner", facilityIds: ["F1"], facilities: [F1] });
    w.db.seed("users", "pend", { role: "assistant", status: "pending", fullName: "Pat Pending", facilityIds: ["F1"], facilities: [F1] });
    w.db.seed("users", "deact", { role: "assistant", status: "deactivated", fullName: "Dee Deactivated", facilityIds: ["F1"], facilities: [F1] });
    return w;
  }

  test("approve: pending -> active, stamped with who and when, and recorded in the history", async () => {
    const { db, fns } = world();
    const result = await fns.setAssistantStatus(act("pend", "approve"), as("owner", "asha@example.com"));
    assert.deepEqual(result, { success: true, status: "active" });

    const u = db.read("users", "pend");
    assert.equal(u.status, "active");
    assert.ok(u.approvedAt instanceof FakeTimestamp, "approvedAt is the server's timestamp");
    assert.equal(u.approvedBy, "Asha Owner");
    assert.equal(u.approvedByUid, "owner");
    // what the Platform Admin's screen already reads
    assert.equal(u.statusChangedBy, "asha@example.com");
    assert.equal(u.statusChangedByRole, "Facility Admin");
    assert.ok(u.statusChangedAt instanceof FakeTimestamp);
    assert.equal(u.statusHistory.length, 1);
    assert.equal(u.statusHistory[0].action, "approved");
    assert.equal(u.statusHistory[0].by, "Asha Owner");
    assert.equal(u.statusHistory[0].facility, "Ukuli");
    assert.equal(u.statusHistory[0].at.toDate().toISOString(), NOW.toISOString());
  });

  test("a Co-admin can approve too", async () => {
    const { db, fns } = world();
    await fns.setAssistantStatus(act("pend", "approve"), as("coadmin"));
    assert.equal(db.read("users", "pend").status, "active");
  });

  test("reject: out of the facility, marked rejected, with a note of which facility and who", async () => {
    const { db, fns } = world();
    const result = await fns.setAssistantStatus(act("pend", "reject"), as("owner"));
    assert.deepEqual(result, { success: true, status: "rejected" });

    const u = db.read("users", "pend");
    assert.equal(u.status, "rejected");
    assert.deepEqual(u.facilityIds, [], "no facility - so sign-in sends them to the invite-code screen, not 'waiting for approval'");
    assert.deepEqual(u.facilities, []);
    assert.equal(u.lastRejection.facilityName, "Ukuli");
    assert.equal(u.lastRejection.facilityId, "F1");
    assert.equal(u.lastRejection.by, "Asha Owner");
    assert.ok(u.rejectedAt instanceof FakeTimestamp);
    assert.equal(u.statusHistory[0].action, "rejected");
    // Their identity is untouched - it's their account, and they can use it again.
    assert.equal(u.fullName, "Pat Pending");
    assert.equal(u.role, "assistant");
  });

  test("a rejected person can join again with an invite code - pending, in the new facility, the old note gone", async () => {
    const { db, fns } = world();
    await fns.setAssistantStatus(act("pend", "reject"), as("owner"));
    seedInvite(db, "JK72P4", { facilityId: "F2", facilityName: "Other Vet", facilityType: "Vet Clinic" });

    await fns.joinFacilityWithInvite({ code: "JK7-2P4" }, as("pend", "pat@example.com"));
    const u = db.read("users", "pend");
    assert.equal(u.status, "pending");
    assert.deepEqual(u.facilityIds, ["F2"]);
    assert.equal(u.lastRejection, null, "so a later removal doesn't replay an old rejection");
    assert.equal(u.statusHistory[0].action, "rejected", "the history is kept");
  });

  test("reject and approve only apply to someone WAITING; a stale tap is refused with a plain reason", async () => {
    const { db, fns } = world();
    await fns.setAssistantStatus(act("pend", "approve"), as("owner"));
    await assert.rejects(fns.setAssistantStatus(act("pend", "approve"), as("owner")), (e) => {
      assert.equal(e.code, "failed-precondition");
      assert.match(e.message, /already been approved/);
      return true;
    });
    await assert.rejects(fns.setAssistantStatus(act("pend", "reject"), as("owner")), (e) => {
      assert.equal(e.code, "failed-precondition");
      return true;
    });
    assert.equal(db.read("users", "pend").status, "active", "unchanged by the refused attempts");
    assert.equal(db.read("users", "pend").statusHistory.length, 1, "and no history entry added for them");
    await assert.rejects(fns.setAssistantStatus(act("deact", "approve"), as("owner")), /reactivate them instead/);
  });

  test("deactivate and reactivate, each stamped", async () => {
    const { db, fns } = world();
    await fns.setAssistantStatus(act("assistant", "deactivate"), as("owner"));
    let u = db.read("users", "assistant");
    assert.equal(u.status, "deactivated");
    assert.ok(u.deactivatedAt instanceof FakeTimestamp);
    assert.equal(u.deactivatedBy, "Asha Owner");

    await fns.setAssistantStatus(act("assistant", "reactivate"), as("owner"));
    u = db.read("users", "assistant");
    assert.equal(u.status, "active");
    assert.ok(u.reactivatedAt instanceof FakeTimestamp);
    assert.deepEqual(u.statusHistory.map((h) => h.action), ["deactivated", "reactivated"], "in the order it happened");

    await assert.rejects(fns.setAssistantStatus(act("assistant", "reactivate"), as("owner")), /already active/);
    await assert.rejects(fns.setAssistantStatus(act("pend", "deactivate"), as("owner")), /hasn't been approved yet/);
    await assert.rejects(fns.setAssistantStatus(act("deact", "deactivate"), as("owner")), /already deactivated/);
  });

  test("approving one person's history doesn't touch another's, and the history is kept to the latest 30", async () => {
    const { db, fns } = world();
    const old = Array.from({ length: 40 }, (_, i) => ({ action: "approved", at: new FakeTimestamp(NOW), by: `x${i}`, facility: "Ukuli" }));
    db.seed("users", "busy", { role: "assistant", status: "active", fullName: "Busy", facilityIds: ["F1"], facilities: [F1], statusHistory: old });
    await fns.setAssistantStatus(act("busy", "deactivate"), as("owner"));
    const h = db.read("users", "busy").statusHistory;
    assert.equal(h.length, 30);
    assert.equal(h[h.length - 1].action, "deactivated", "newest last");
    assert.equal(h[0].by, "x11", "oldest dropped");
    assert.equal(db.read("users", "assistant").statusHistory, undefined);
  });

  test("only an ADMIN of the assistant's facility can: not an assistant, not another business's admin", async () => {
    const { db, fns } = world();
    await rejects(fns.setAssistantStatus(act("pend", "approve"), as("assistant")), "permission-denied");
    await rejects(fns.setAssistantStatus(act("pend", "approve"), as("outsider")), "permission-denied");
    await rejects(fns.setAssistantStatus(act("pend", "reject"), as("outsider")), "permission-denied");
    await rejects(fns.setAssistantStatus(act("pend", "approve"), as("pa")), "permission-denied");
    assert.equal(db.read("users", "pend").status, "pending");
    assert.deepEqual(db.read("users", "pend").facilityIds, ["F1"]);
  });

  test("a deactivated admin can't", async () => {
    const { db, fns } = world();
    db.seed("users", "owner", { role: "admin", status: "deactivated", facilityIds: ["F1"], facilities: [F1] });
    await rejects(fns.setAssistantStatus(act("pend", "approve"), as("owner")), "permission-denied");
  });

  test("it only works on ASSISTANTS - not the owner, a Co-admin, or someone who doesn't exist", async () => {
    const { fns } = world();
    await rejects(fns.setAssistantStatus(act("coadmin", "deactivate"), as("owner")), "failed-precondition");
    await rejects(fns.setAssistantStatus(act("owner", "deactivate"), as("coadmin")), "failed-precondition");
    await rejects(fns.setAssistantStatus(act("ghost", "approve"), as("owner")), "failed-precondition");
  });

  test("an unknown action, a missing id, and no sign-in are all refused", async () => {
    const { fns } = world();
    await rejects(fns.setAssistantStatus(act("pend", "promote"), as("owner")), "invalid-argument");
    await rejects(fns.setAssistantStatus(act("pend", "constructor"), as("owner")), "invalid-argument");
    await rejects(fns.setAssistantStatus(act("pend", undefined), as("owner")), "invalid-argument");
    await rejects(fns.setAssistantStatus({ action: "approve" }, as("owner")), "invalid-argument");
    await rejects(fns.setAssistantStatus(act("pend", "approve"), {}), "unauthenticated");
  });
});

// ======================================================================
// THE "WAITING FOR APPROVAL" NOTICE GOES WHEN THE DECISION IS MADE
//
// It used to sit there saying "waiting" about someone already approved or
// rejected: nothing connected the decision back to the notice.
// ======================================================================

describe("the waiting-for-approval notice is cleared by the decision", () => {
  const act = (assistantUid, action) => ({ assistantUid, action });
  const waiting = (db, facilityId, uid) =>
    notificationsOf(db, facilityId).filter((n) => n.type === "assistantPending" && n.relatedEntityId === uid);

  // Everyone arrives the real way - registering with an invite - so the notice
  // is the genuine one the app would show.
  async function register(w, uid, code, name) {
    seedInvite(w.db, code);
    await w.fns.joinWithInvite({ code, fullName: name, phone: "0755 111 222" }, as(uid, `${uid}@example.com`));
  }
  function world() {
    const w = setup();
    seedWorld(w.db);
    w.db.seed("users", "owner", { role: "admin", status: "active", fullName: "Asha Owner", facilityIds: ["F1"], facilities: [F1] });
    return w;
  }

  test("approving someone clears their notice", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    assert.equal(waiting(w.db, "F1", "newbie").length, 1, "the notice exists to begin with");
    await w.fns.setAssistantStatus(act("newbie", "approve"), as("owner"));
    assert.equal(waiting(w.db, "F1", "newbie").length, 0);
    assert.equal(w.db.read("users", "newbie").status, "active");
  });

  test("rejecting someone clears their notice too", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    await w.fns.setAssistantStatus(act("newbie", "reject"), as("owner"));
    assert.equal(waiting(w.db, "F1", "newbie").length, 0);
    assert.equal(w.db.read("users", "newbie").status, "rejected");
  });

  test("it clears only THAT person's notice - not another waiting assistant's, other kinds, or another facility's", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    await register(w, "newbie2", "KM83Q5", "Baraka Ali");
    // an owner's trial notice, and a notice about the same person in a DIFFERENT facility
    w.db.seed("facilities/F1/notifications", "trial1", { type: "trialStarted", audience: "admins", relatedEntityId: "F1" });
    w.db.seed("facilities/F2/notifications", "other1", { type: "assistantPending", audience: "admins", relatedEntityId: "newbie" });
    // a DIFFERENT kind of notice about the very same person: not this one's business
    w.db.seed("facilities/F1/notifications", "about1", { type: "general", audience: "admins", relatedEntityId: "newbie" });

    await w.fns.setAssistantStatus(act("newbie", "approve"), as("owner"));

    assert.equal(waiting(w.db, "F1", "newbie").length, 0, "the decided one is gone");
    assert.equal(waiting(w.db, "F1", "newbie2").length, 1, "the other person is still waiting, and still shown");
    assert.equal(notificationsOf(w.db, "F1").filter((n) => n.type === "trialStarted").length, 1, "other kinds untouched");
    assert.equal(waiting(w.db, "F2", "newbie").length, 1, "another facility's notices untouched");
    assert.equal(notificationsOf(w.db, "F1").filter((n) => n.type === "general").length, 1, "another kind of notice about the same person untouched");
  });

  test("a refused decision clears nothing", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    w.db.seed("users", "deact", { role: "assistant", status: "deactivated", fullName: "Dee", facilityIds: ["F1"], facilities: [F1] });
    await rejects(w.fns.setAssistantStatus(act("deact", "approve"), as("owner")), "failed-precondition");
    await rejects(w.fns.setAssistantStatus(act("newbie", "approve"), as("outsider")), "permission-denied");
    assert.equal(waiting(w.db, "F1", "newbie").length, 1, "still waiting - nothing was decided");
  });

  test("deactivating or reactivating someone else doesn't touch a waiting person's notice", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    await w.fns.setAssistantStatus(act("assistant", "deactivate"), as("owner"));
    await w.fns.setAssistantStatus(act("assistant", "reactivate"), as("owner"));
    assert.equal(waiting(w.db, "F1", "newbie").length, 1);
  });

  test("removing or moving someone clears the notice in the facility they LEFT", async () => {
    const w = world();
    // the owner runs both facilities, so can move people between them
    w.db.seed("users", "owner", { role: "admin", status: "active", fullName: "Asha", facilityIds: ["F1", "F2"], facilities: [F1, F2] });
    w.db.seed("users", "gone", { role: "assistant", status: "deactivated", fullName: "Gone", facilityIds: ["F1"], facilities: [F1] });
    w.db.seed("facilities/F1/notifications", "n1", { type: "assistantPending", audience: "admins", relatedEntityId: "gone" });
    w.db.seed("facilities/F1/notifications", "n2", { type: "assistantPending", audience: "admins", relatedEntityId: "assistant" });

    await w.fns.removeAssistantFromFacility({ assistantUid: "gone", facilityId: "F1" }, as("owner"));
    assert.equal(waiting(w.db, "F1", "gone").length, 0);

    await w.fns.reassignAssistant({ assistantUid: "assistant", newFacilityId: "F2" }, as("owner"));
    assert.equal(waiting(w.db, "F1", "assistant").length, 0, "moved out of F1, so F1 isn't waiting on them");
  });

  test("a notice that can't be cleared never fails the decision", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    w.db.failWrites = (path) => path.includes("/notifications/");
    const result = await w.fns.setAssistantStatus(act("newbie", "approve"), as("owner"));
    assert.deepEqual(result, { success: true, status: "active" });
    assert.equal(w.db.read("users", "newbie").status, "active", "approved regardless");
    assert.equal(waiting(w.db, "F1", "newbie").length, 1, "the notice is simply left, not a reason to refuse");
  });

  test("someone who registers again after a rejection gets a fresh notice, and the old one stayed gone", async () => {
    const w = world();
    await register(w, "newbie", "JK72P4", "Neema Joseph");
    await w.fns.setAssistantStatus(act("newbie", "reject"), as("owner"));
    assert.equal(waiting(w.db, "F1", "newbie").length, 0);

    seedInvite(w.db, "ZX94R6");
    await w.fns.joinFacilityWithInvite({ code: "ZX94R6" }, as("newbie", "newbie@example.com"));
    assert.equal(waiting(w.db, "F1", "newbie").length, 1, "exactly one - for the new request");
  });
});
