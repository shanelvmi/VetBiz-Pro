"use strict";

/**
 * MEMBERSHIP - everything that decides WHO belongs to WHICH facility, and in
 * what role.
 *
 * Why this lives on the server: the app talks to the database directly, so
 * the security rules are the only thing standing between a hostile client
 * and the data. While a person's profile (role, status, the list of
 * facilities they belong to) could be written by the app, a person could
 * simply write themselves into any facility whose id they knew, mark
 * themselves approved, or hand themselves a longer subscription. So the app
 * no longer writes any of it. It asks one of the functions below, which
 * checks who is asking and what they're entitled to, and does the write with
 * the Admin SDK. The rules then only have to READ membership, never trust a
 * claim about it.
 *
 * Everything is built by create(deps) with its dependencies injected, so the
 * same code that runs in production is unit tested against a fake database
 * (see test/membership.test.js).
 */

const FACILITY_TYPES = ["Agrovet", "Vet Clinic", "Vet Hospital", "Ambulatory Vet", "Other"];

// Invite codes are read aloud over the phone and typed on small keyboards, so
// they leave out look-alike characters (0/O, 1/I/L). Facility codes are just
// identifiers, so they don't need to.
const INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const FACILITY_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const INVITE_CODE_LENGTH = 6;
const FACILITY_CODE_LENGTH = 8;
const INVITE_VALIDITY_MS = 48 * 60 * 60 * 1000;

const DEFAULT_TRIAL_DAYS = 14;
const DEFAULT_MAX_FACILITIES = 6;

// Tanzania has no daylight saving, so a fixed offset is exact. A trial ends
// at the end of a local day, as the app has always computed it.
const EAT_OFFSET_MS = 3 * 60 * 60 * 1000;

const INVALID_INVITE_MESSAGE = "Invalid, expired, or already-used invite code";

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

/** "jk7 2p4", "JK7-2P4" and "jk72p4" are all the same code. */
function normalizeInviteCode(input) {
  if (typeof input !== "string") return null;
  const code = input.replace(/[\s-]/g, "").toUpperCase();
  return code.length === INVITE_CODE_LENGTH ? code : null;
}

/** The end of the day, East Africa Time, [days] from [now]. */
function trialExpiry(now, days) {
  const shifted = new Date(now.getTime() + days * 24 * 60 * 60 * 1000 + EAT_OFFSET_MS);
  return new Date(
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate(), 23, 59, 59) - EAT_OFFSET_MS
  );
}

/** Why an invite can't be used, or null if it can. */
function inviteProblem(invite, now) {
  if (!invite) return "missing";
  if (invite.usedAt != null) return "used";
  const expiresAt = invite.expiresAt && typeof invite.expiresAt.toDate === "function" ? invite.expiresAt.toDate() : null;
  if (!expiresAt || now.getTime() > expiresAt.getTime()) return "expired";
  if (typeof invite.facilityId !== "string" || invite.facilityId.length === 0) return "broken";
  return null;
}

function facilityEntry(facilityId, data) {
  return {
    facilityId,
    name: (data && data.name) || "",
    type: (data && data.type) || "",
    code: (data && data.code) || "",
  };
}

function isActiveAdmin(user) {
  return !!user && user.role === "admin" && (user.status || "active") !== "deactivated";
}

function idsOf(user) {
  return Array.isArray(user && user.facilityIds) ? user.facilityIds : [];
}

// APPROVE / REJECT / DEACTIVATE / REACTIVATE: what state each needs, where it
// leads, and what to call it in the person's history.
const STATUS_ACTIONS = {
  approve: { from: "pending", to: "active", history: "approved" },
  reject: { from: "pending", to: "rejected", history: "rejected" },
  deactivate: { from: "active", to: "deactivated", history: "deactivated" },
  reactivate: { from: "deactivated", to: "active", history: "reactivated" },
};
const HISTORY_LIMIT = 30;

// Said plainly, because the usual cause is a stale screen: someone else (or
// this same person, a moment ago) already did it.
function wrongStateMessage(action, current) {
  if (action === "approve" || action === "reject") {
    if (current === "active") return "This assistant has already been approved.";
    if (current === "deactivated") return "This assistant is deactivated - reactivate them instead.";
    return "This assistant isn't waiting for approval.";
  }
  if (action === "deactivate") {
    if (current === "deactivated") return "This assistant is already deactivated.";
    return "This assistant hasn't been approved yet.";
  }
  if (current === "active") return "This assistant is already active.";
  return "This assistant hasn't been approved yet - approve them instead.";
}

// What the Notifications screen shows. These are for the facility's ADMINS only
// (audience "admins"): an assistant has no use for "someone is waiting for
// approval", and one who joins later shouldn't find the owner's old notices.
//
// (There is deliberately NO stored "your trial has started" notice any more.
// The trial is announced by a live row the app builds itself from the
// facility's subscription - see SubscriptionProvider.trialInfoNotice - because
// a stored notice was written once, only for admins, only for new accounts, so
// every existing account and every assistant still got a blinking bell with no
// message, and a stored one would only duplicate the live row.)
function pendingAssistantNotification(assistantUid, assistantName, facilityName, alreadyRegistered) {
  return {
    type: "assistantPending",
    title: "New assistant waiting for approval",
    message: alreadyRegistered
      ? `${assistantName} has asked to join ${facilityName} with your invite code and is waiting for your approval. Open Team Members to approve them.`
      : `${assistantName} has registered with your invite code and is waiting for your approval. Open Team Members to approve them.`,
    audience: "admins",
    relatedEntityType: "assistant",
    relatedEntityId: assistantUid,
  };
}

// ---------------------------------------------------------------------------

function create({ db, FieldValue, Timestamp, HttpsError, randomInt, now = () => new Date() }) {
  const invalid = (message) => new HttpsError("invalid-argument", message);

  function requireAuth(context) {
    if (!context || !context.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to do this.");
    }
    return context.auth.uid;
  }

  function emailOf(context) {
    return (context.auth.token && context.auth.token.email) || "";
  }

  function cleanText(value, label, min, max) {
    if (typeof value !== "string") throw invalid(`${label} is required.`);
    const text = value.trim();
    if (text.length < min) throw invalid(`${label} is required.`);
    if (text.length > max) throw invalid(`${label} is too long.`);
    return text;
  }

  // Digits with the usual separators, 9 to 15 digits in all - the same rule
  // the registration form applies, so a number the form accepts is accepted.
  function cleanPhone(value) {
    const phone = cleanText(value, "Phone number", 1, 32);
    const digits = phone.replace(/\D/g, "").length;
    if (!/^[0-9+\-\s().]+$/.test(phone) || digits < 9 || digits > 15) {
      throw invalid("Enter a valid phone number.");
    }
    return phone;
  }

  function cleanFacilityType(value) {
    if (typeof value !== "string" || !FACILITY_TYPES.includes(value)) {
      throw invalid("Choose a valid facility type.");
    }
    return value;
  }

  function cleanId(value, label) {
    if (typeof value !== "string" || value.length === 0 || value.length > 128 || value.includes("/")) {
      throw invalid(`${label} is required.`);
    }
    return value;
  }

  // Optional. Anything that isn't an https link is dropped rather than stored.
  function cleanAvatarUrl(value) {
    if (typeof value !== "string") return "";
    const url = value.trim();
    return url.startsWith("https://") && url.length <= 1500 ? url : "";
  }

  function randomCode(alphabet, length) {
    let out = "";
    for (let i = 0; i < length; i++) out += alphabet[randomInt(alphabet.length)];
    return out;
  }

  async function loadConfig() {
    const snap = await db.collection("platform_config").doc("settings").get();
    const data = snap.exists ? snap.data() || {} : {};
    const trialDays = Number(data.trialDays);
    const maxFacilities = Number(data.maxFacilitiesPerAdmin);
    return {
      trialDays: trialDays > 0 ? Math.floor(trialDays) : DEFAULT_TRIAL_DAYS,
      maxFacilities: maxFacilities > 0 ? Math.floor(maxFacilities) : DEFAULT_MAX_FACILITIES,
    };
  }

  // The caller must be an active Admin of this facility, or a Platform Admin.
  async function assertCanManageFacility(uid, facilityId, what) {
    const snap = await db.collection("users").doc(uid).get();
    const user = snap.exists ? snap.data() : null;
    if (isActiveAdmin(user) && idsOf(user).includes(facilityId)) return user;
    const pa = await db.collection("platform_admins").doc(uid).get();
    if (pa.exists) return user;
    throw new HttpsError("permission-denied", `You can only ${what} for a facility you administer.`);
  }

  // ======================================================================
  // CHECK AN INVITE CODE - callable by anyone, signed in or not
  // ======================================================================
  //
  // The registration screen has to check a code BEFORE the person has an
  // account, so this can't require sign-in. It used to be a public read of
  // the invite document itself, which also let anyone LIST every invite and
  // collect every business's facility id. Here the answer is only whether the
  // code works, and the facility's name and type to show "you're joining X" -
  // never the facility id.
  // NOTIFICATIONS. Written here, by the server, for two reasons: the app can't
  // create them (the security rules refuse it), and written at the moment the
  // thing happens they exist exactly once. The bell used to blink for a new
  // pending assistant from a live watcher of its own while the Notifications
  // list stayed empty, because nothing ever wrote one.
  //
  // Best-effort: a notification that can't be written must never undo the
  // registration it's about.
  async function notify(facilityId, notification) {
    try {
      await db
        .collection("facilities")
        .doc(facilityId)
        .collection("notifications")
        .add({ ...notification, createdAt: FieldValue.serverTimestamp() });
    } catch (e) {
      console.warn(`Could not write a ${notification.type} notification for ${facilityId}: ${e && e.message}`);
    }
  }

  // The "waiting for approval" notice is about a DECISION - so once the decision
  // has been made (approved or rejected), or the person has left, it goes. It
  // used to sit there saying "waiting" about someone already dealt with,
  // because nothing ever connected the decision back to the notice.
  //
  // Removes only THAT person's notice in THAT facility: another assistant's
  // notice, other kinds of notice and other facilities are left alone. The
  // record of what was decided isn't lost - it's in the Activity Log and in
  // the person's own history.
  //
  // Best-effort, like writing one: failing to tidy a notice must never undo (or
  // fail) the decision it follows.
  async function clearPendingNotices(facilityId, assistantUid) {
    if (!facilityId) return;
    try {
      const found = await db
        .collection("facilities")
        .doc(facilityId)
        .collection("notifications")
        .where("type", "==", "assistantPending")
        .where("relatedEntityId", "==", assistantUid)
        .get();
      await Promise.all(found.docs.map((d) => d.ref.delete()));
    } catch (e) {
      console.warn(`Could not clear the approval notice for ${assistantUid} in ${facilityId}: ${e && e.message}`);
    }
  }

  async function checkInviteCode(data) {
    const code = normalizeInviteCode(data && data.code);
    if (!code) return { valid: false };
    const snap = await db.collection("inviteCodes").doc(code).get();
    const invite = snap.exists ? snap.data() : null;
    if (inviteProblem(invite, now())) return { valid: false };
    return { valid: true, facilityName: invite.facilityName || "", facilityType: invite.facilityType || "" };
  }

  // ======================================================================
  // REGISTER AN OWNER
  // ======================================================================
  //
  // Creates the person's profile and their first facility(ies) in one
  // transaction: all of it, or none. The trial end and the facility limit
  // are worked out HERE, so the app can't pick its own.
  async function registerOwner(data, context) {
    const uid = requireAuth(context);
    const email = emailOf(context);
    const fullName = cleanText(data && data.fullName, "Your name", 2, 120);
    const phone = cleanPhone(data && data.phone);
    const avatarUrl = cleanAvatarUrl(data && data.avatarUrl);

    const incoming = Array.isArray(data && data.facilities) ? data.facilities : [];
    if (incoming.length === 0) throw invalid("Add at least one facility.");

    const config = await loadConfig();
    if (incoming.length > config.maxFacilities) {
      throw new HttpsError("failed-precondition", `You can register up to ${config.maxFacilities} facilities.`);
    }
    const parsed = incoming.map((f, i) => ({
      name: cleanText(f && f.name, `Facility ${i + 1} name`, 1, 120),
      type: cleanFacilityType(f && f.type),
    }));
    const trialEnds = Timestamp.fromDate(trialExpiry(now(), config.trialDays));

    return db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const existing = await tx.get(userRef);
      // A profile is created once. Without this, calling again would create
      // more facilities each time.
      if (existing.exists) throw new HttpsError("already-exists", "This account already has a profile.");

      const entries = [];
      for (const f of parsed) {
        const ref = db.collection("facilities").doc();
        const code = randomCode(FACILITY_ALPHABET, FACILITY_CODE_LENGTH);
        tx.set(ref, {
          name: f.name,
          type: f.type,
          code,
          createdBy: uid,
          createdAt: FieldValue.serverTimestamp(),
          trialExpiresAt: trialEnds,
        });
        entries.push({ facilityId: ref.id, name: f.name, type: f.type, code });
      }

      tx.set(userRef, {
        uid,
        fullName,
        email,
        phone,
        role: "admin",
        status: "active",
        facilities: entries,
        facilityIds: entries.map((e) => e.facilityId),
        avatarUrl,
        createdAt: FieldValue.serverTimestamp(),
      });
      return { facilities: entries };
    });
  }

  // ======================================================================
  // JOIN WITH AN INVITE
  // ======================================================================
  //
  // Creates an Assistant's profile - always "pending", always in the
  // facility the invite was made for - and uses up the invite, in ONE
  // transaction. So a code really is single-use (two people redeeming it at
  // the same moment can't both succeed), and the person never chooses their
  // own role, status or facility.
  async function joinWithInvite(data, context) {
    const uid = requireAuth(context);
    const email = emailOf(context);
    const code = normalizeInviteCode(data && data.code);
    if (!code) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);
    const fullName = cleanText(data && data.fullName, "Your name", 2, 120);
    const phone = cleanPhone(data && data.phone);
    const avatarUrl = cleanAvatarUrl(data && data.avatarUrl);

    let facilityId;
    const result = await db.runTransaction(async (tx) => {
      const inviteRef = db.collection("inviteCodes").doc(code);
      const userRef = db.collection("users").doc(uid);
      const inviteSnap = await tx.get(inviteRef);
      const existing = await tx.get(userRef);

      if (existing.exists) throw new HttpsError("already-exists", "This account already has a profile.");
      const invite = inviteSnap.exists ? inviteSnap.data() : null;
      if (inviteProblem(invite, now())) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);

      const facilitySnap = await tx.get(db.collection("facilities").doc(invite.facilityId));
      if (!facilitySnap.exists) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);
      const entry = facilityEntry(invite.facilityId, facilitySnap.data());

      tx.set(userRef, {
        uid,
        fullName,
        email,
        phone,
        role: "assistant",
        status: "pending",
        facilities: [entry],
        facilityIds: [entry.facilityId],
        avatarUrl,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(inviteRef, {
        usedAt: FieldValue.serverTimestamp(),
        usedByEmail: email,
        usedByUid: uid,
      });
      facilityId = entry.facilityId;
      return { facilityName: entry.name, facilityType: entry.type };
    });

    // The facility's admins are told, so the new assistant doesn't sit unseen
    // until someone happens to open Team Members.
    await notify(facilityId, pendingAssistantNotification(uid, fullName, result.facilityName, false));
    return result;
  }

  // ======================================================================
  // JOIN ANOTHER FACILITY, WHEN YOU HAVE NONE
  // ======================================================================
  //
  // For someone who is already registered but no longer in any facility - they
  // were removed from theirs. They keep their account, name, phone and photo
  // and ask to join another with a fresh invite code.
  //
  // This used to be a dead end. Removing someone from a facility leaves their
  // status alone (and the app only offers removal for deactivated
  // assistants), so they came back as "deactivated" - and their old admin
  // couldn't reactivate them, because they're no longer in any facility that
  // admin can see. Nothing was left for them to do but register all over again
  // under a new email.
  //
  // Only an ASSISTANT with NO facility can use this - never someone who is
  // still in one (that's reassignAssistant, an admin's decision), and never
  // an admin. They come back "pending": the new facility's admin decides,
  // exactly as for anyone joining with an invite.
  async function joinFacilityWithInvite(data, context) {
    const uid = requireAuth(context);
    const email = emailOf(context);
    const code = normalizeInviteCode(data && data.code);
    if (!code) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);

    let facilityId;
    let assistantName = "";
    const result = await db.runTransaction(async (tx) => {
      const inviteRef = db.collection("inviteCodes").doc(code);
      const userRef = db.collection("users").doc(uid);
      const inviteSnap = await tx.get(inviteRef);
      const userSnap = await tx.get(userRef);

      const user = userSnap.exists ? userSnap.data() : null;
      if (!user) throw new HttpsError("failed-precondition", "We couldn't find your profile. Please register again.");
      if (user.role !== "assistant") {
        throw new HttpsError("permission-denied", "Only an assistant can join a facility with an invite code.");
      }
      if (idsOf(user).length > 0) throw new HttpsError("failed-precondition", "You are already assigned to a facility.");

      const invite = inviteSnap.exists ? inviteSnap.data() : null;
      if (inviteProblem(invite, now())) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);
      const facilitySnap = await tx.get(db.collection("facilities").doc(invite.facilityId));
      if (!facilitySnap.exists) throw new HttpsError("failed-precondition", INVALID_INVITE_MESSAGE);
      const entry = facilityEntry(invite.facilityId, facilitySnap.data());

      tx.update(userRef, {
        facilityIds: [entry.facilityId],
        facilities: [entry],
        status: "pending",
        rejoinedAt: FieldValue.serverTimestamp(),
        // Whatever they were told before no longer applies.
        lastRejection: null,
      });
      tx.update(inviteRef, {
        usedAt: FieldValue.serverTimestamp(),
        usedByEmail: email,
        usedByUid: uid,
      });
      facilityId = entry.facilityId;
      assistantName = user.fullName || email;
      return { facilityName: entry.name, facilityType: entry.type };
    });

    await notify(facilityId, pendingAssistantNotification(uid, assistantName, result.facilityName, true));
    return result;
  }

  // ======================================================================
  // ADD A FACILITY
  // ======================================================================
  //
  // The limit is checked against the person's real, current list inside the
  // transaction, so two quick taps can't both slip under it - and the app
  // can't skip it by talking to the database directly.
  async function addFacility(data, context) {
    const uid = requireAuth(context);
    const name = cleanText(data && data.name, "Facility name", 1, 120);
    const type = cleanFacilityType(data && data.type);
    const config = await loadConfig();
    const trialEnds = Timestamp.fromDate(trialExpiry(now(), config.trialDays));

    return db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const snap = await tx.get(userRef);
      const user = snap.exists ? snap.data() : null;
      if (!isActiveAdmin(user)) throw new HttpsError("permission-denied", "Only an admin can add a facility.");
      if (idsOf(user).length >= config.maxFacilities) {
        throw new HttpsError(
          "resource-exhausted",
          `You've reached the facility limit for your account (${config.maxFacilities}).`
        );
      }

      const ref = db.collection("facilities").doc();
      const code = randomCode(FACILITY_ALPHABET, FACILITY_CODE_LENGTH);
      tx.set(ref, {
        name,
        type,
        code,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        trialExpiresAt: trialEnds,
      });
      const entry = { facilityId: ref.id, name, type, code };
      // Both lists, together: "facilities" is what the screens show,
      // "facilityIds" is what every access rule checks.
      tx.update(userRef, {
        facilities: FieldValue.arrayUnion(entry),
        facilityIds: FieldValue.arrayUnion(ref.id),
      });
      return entry;
    });
  }

  // ======================================================================
  // CREATE AN INVITE CODE
  // ======================================================================
  async function createInviteCode(data, context) {
    const uid = requireAuth(context);
    const facilityId = cleanId(data && data.facilityId, "facilityId");
    await assertCanManageFacility(uid, facilityId, "invite people");

    const facilitySnap = await db.collection("facilities").doc(facilityId).get();
    if (!facilitySnap.exists) throw new HttpsError("not-found", "Facility not found.");
    const facility = facilitySnap.data();

    const nowDate = now();
    const expiresAt = new Date(nowDate.getTime() + INVITE_VALIDITY_MS);

    // create() refuses to overwrite, so a collision with an existing code
    // (extremely unlikely: 32^6 combinations) simply tries another one,
    // atomically - no separate "does it exist?" read to race against.
    let code = null;
    for (let attempt = 0; attempt < 10 && !code; attempt++) {
      const candidate = randomCode(INVITE_ALPHABET, INVITE_CODE_LENGTH);
      try {
        await db.collection("inviteCodes").doc(candidate).create({
          facilityId,
          facilityName: facility.name || "",
          facilityType: facility.type || "",
          createdByUserId: uid,
          createdAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromDate(expiresAt),
          usedAt: null,
          usedByEmail: null,
        });
        code = candidate;
      } catch (e) {
        const exists = e && (e.code === 6 || e.code === "already-exists");
        if (!exists) throw e;
      }
    }
    if (!code) throw new HttpsError("internal", "Could not generate an invite code - please try again.");

    // Only one active invite per facility: the new one replaces any earlier
    // unused one. Done after the new code exists, so a failure can't leave
    // the facility with none.
    const earlier = await db
      .collection("inviteCodes")
      .where("facilityId", "==", facilityId)
      .where("usedAt", "==", null)
      .get();
    const stale = earlier.docs.filter((d) => d.id !== code);
    if (stale.length > 0) {
      const batch = db.batch();
      stale.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

    return { code, expiresAt: expiresAt.toISOString() };
  }

  // ======================================================================
  // REASSIGN / REMOVE AN ASSISTANT
  // ======================================================================
  async function loadCallerAdmin(tx, uid) {
    const snap = await tx.get(db.collection("users").doc(uid));
    const user = snap.exists ? snap.data() : null;
    if (!isActiveAdmin(user)) throw new HttpsError("permission-denied", "Only an admin can do this.");
    return user;
  }

  function assertAssistantInYourFacilities(assistant, caller) {
    if (!assistant || assistant.role !== "assistant") {
      throw new HttpsError("failed-precondition", "This account is not an assistant.");
    }
    const callerIds = idsOf(caller);
    if (!idsOf(assistant).some((id) => callerIds.includes(id))) {
      throw new HttpsError("permission-denied", "This assistant is not assigned to any facility you administer.");
    }
  }

  async function reassignAssistant(data, context) {
    const callerUid = requireAuth(context);
    const assistantUid = cleanId(data && data.assistantUid, "assistantUid");
    const newFacilityId = cleanId(data && data.newFacilityId, "newFacilityId");

    let leftIds = [];
    const result = await db.runTransaction(async (tx) => {
      const caller = await loadCallerAdmin(tx, callerUid);
      const assistantRef = db.collection("users").doc(assistantUid);
      const assistantSnap = await tx.get(assistantRef);
      const facilitySnap = await tx.get(db.collection("facilities").doc(newFacilityId));

      const assistant = assistantSnap.exists ? assistantSnap.data() : null;
      assertAssistantInYourFacilities(assistant, caller);
      leftIds = idsOf(assistant).filter((id) => id !== newFacilityId);
      // You can only move someone into a facility you administer yourself.
      if (!idsOf(caller).includes(newFacilityId)) {
        throw new HttpsError("permission-denied", "You can only move an assistant into a facility you administer.");
      }
      if (!facilitySnap.exists) throw new HttpsError("not-found", "Facility not found.");

      const entry = facilityEntry(newFacilityId, facilitySnap.data());
      tx.update(assistantRef, { facilityIds: [newFacilityId], facilities: [entry] });
      return { success: true };
    });

    for (const id of leftIds) await clearPendingNotices(id, assistantUid);
    return result;
  }

  async function removeAssistantFromFacility(data, context) {
    const callerUid = requireAuth(context);
    const assistantUid = cleanId(data && data.assistantUid, "assistantUid");
    const facilityId = cleanId(data && data.facilityId, "facilityId");

    const result = await db.runTransaction(async (tx) => {
      const caller = await loadCallerAdmin(tx, callerUid);
      const assistantRef = db.collection("users").doc(assistantUid);
      const assistantSnap = await tx.get(assistantRef);
      const assistant = assistantSnap.exists ? assistantSnap.data() : null;

      assertAssistantInYourFacilities(assistant, caller);
      if (!idsOf(caller).includes(facilityId) || !idsOf(assistant).includes(facilityId)) {
        throw new HttpsError("permission-denied", "That assistant is not in a facility you administer.");
      }

      tx.update(assistantRef, {
        facilityIds: idsOf(assistant).filter((id) => id !== facilityId),
        facilities: (Array.isArray(assistant.facilities) ? assistant.facilities : []).filter(
          (f) => !(f && f.facilityId === facilityId)
        ),
      });
      return { success: true };
    });

    await clearPendingNotices(facilityId, assistantUid);
    return result;
  }

  // ======================================================================
  // APPROVE / REJECT / DEACTIVATE / REACTIVATE AN ASSISTANT
  // ======================================================================
  //
  // These used to be plain writes from the app, which kept only the LAST
  // change - so nothing could say when someone was approved, or by whom, once
  // anything else had happened to them. Done here, each change is stamped with
  // the server's clock and added to a short history, and a change that no
  // longer makes sense (an approval that's already happened, from a stale
  // screen) is refused with a plain explanation instead of overwriting.
  //
  // REJECT is the one that removes someone: they are taken out of the facility
  // - not left "waiting for approval" - and a note records which facility and
  // who turned them down. When they next sign in they land on the screen that
  // asks for an invite code (joinFacilityWithInvite), so they can join
  // somewhere else, or here again with a new code, with the account they
  // already have.
  async function setAssistantStatus(data, context) {
    const callerUid = requireAuth(context);
    const assistantUid = cleanId(data && data.assistantUid, "assistantUid");
    const action = data && data.action;
    const rule = Object.prototype.hasOwnProperty.call(STATUS_ACTIONS, action) ? STATUS_ACTIONS[action] : null;
    if (!rule) throw invalid("Unknown action.");

    let theirFacilityId = "";
    const result = await db.runTransaction(async (tx) => {
      const caller = await loadCallerAdmin(tx, callerUid);
      const assistantRef = db.collection("users").doc(assistantUid);
      const assistantSnap = await tx.get(assistantRef);
      const assistant = assistantSnap.exists ? assistantSnap.data() : null;
      assertAssistantInYourFacilities(assistant, caller);

      const current = assistant.status || "pending";
      if (current !== rule.from) throw new HttpsError("failed-precondition", wrongStateMessage(action, current));

      const callerIds = idsOf(caller);
      const theirFacility = (Array.isArray(assistant.facilities) ? assistant.facilities : []).find(
        (f) => f && callerIds.includes(f.facilityId)
      );
      const facilityName = (theirFacility && theirFacility.name) || "";
      theirFacilityId = (theirFacility && theirFacility.facilityId) || "";
      const byName = caller.fullName || emailOf(context) || "An admin";

      const historyEntry = { action: rule.history, at: Timestamp.fromDate(now()), by: byName, facility: facilityName };
      const history = [...(Array.isArray(assistant.statusHistory) ? assistant.statusHistory : []), historyEntry].slice(
        -HISTORY_LIMIT
      );

      // statusChanged* are the fields the Platform Admin's screen already reads.
      const patch = {
        status: rule.to,
        statusChangedBy: emailOf(context) || byName,
        statusChangedByRole: "Facility Admin",
        statusChangedAt: FieldValue.serverTimestamp(),
        statusHistory: history,
      };
      if (action === "approve") {
        Object.assign(patch, {
          approvedAt: FieldValue.serverTimestamp(),
          approvedBy: byName,
          approvedByUid: callerUid,
          lastRejection: null,
        });
      } else if (action === "deactivate") {
        Object.assign(patch, { deactivatedAt: FieldValue.serverTimestamp(), deactivatedBy: byName });
      } else if (action === "reactivate") {
        Object.assign(patch, { reactivatedAt: FieldValue.serverTimestamp(), reactivatedBy: byName });
      } else {
        // reject: out of the facility(ies) this admin runs - an assistant is in
        // one, so that's all of it.
        Object.assign(patch, {
          facilityIds: idsOf(assistant).filter((id) => !callerIds.includes(id)),
          facilities: (Array.isArray(assistant.facilities) ? assistant.facilities : []).filter(
            (f) => !(f && callerIds.includes(f.facilityId))
          ),
          rejectedAt: FieldValue.serverTimestamp(),
          rejectedBy: byName,
          lastRejection: {
            facilityId: (theirFacility && theirFacility.facilityId) || "",
            facilityName,
            by: byName,
            at: Timestamp.fromDate(now()),
          },
        });
      }
      tx.update(assistantRef, patch);
      return { success: true, status: rule.to };
    });

    // The question "should this person be let in?" has been answered.
    if (action === "approve" || action === "reject") await clearPendingNotices(theirFacilityId, assistantUid);
    return result;
  }

  // ======================================================================
  // KEEP EACH MEMBER'S COPY OF A FACILITY'S NAME AND TYPE IN STEP
  // ======================================================================
  //
  // Every member's profile carries a copy of their facilities' name and type
  // (the screens read it without a second lookup). Editing a facility used
  // to rewrite those copies from the app - including OTHER people's profiles,
  // which the app can no longer touch. So the server does it: called by the
  // editing screen so the change shows at once, and by a trigger on the
  // facility document as the safety net for any other path.
  async function propagateFacilityDetails(facilityId) {
    const facilitySnap = await db.collection("facilities").doc(facilityId).get();
    if (!facilitySnap.exists) return { updated: 0 };
    const facility = facilitySnap.data();

    const members = await db.collection("users").where("facilityIds", "array-contains", facilityId).get();
    let updated = 0;
    let batch = db.batch();
    let pending = 0;

    for (const doc of members.docs) {
      const list = Array.isArray(doc.data().facilities) ? doc.data().facilities : [];
      let changed = false;
      const next = list.map((entry) => {
        if (entry && entry.facilityId === facilityId && (entry.name !== facility.name || entry.type !== facility.type)) {
          changed = true;
          return { ...entry, name: facility.name || "", type: facility.type || "" };
        }
        return entry;
      });
      if (!changed) continue;
      batch.update(doc.ref, { facilities: next });
      updated++;
      pending++;
      if (pending === 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    return { updated };
  }

  async function syncFacilityDetails(data, context) {
    const uid = requireAuth(context);
    const facilityId = cleanId(data && data.facilityId, "facilityId");
    await assertCanManageFacility(uid, facilityId, "do this");
    return propagateFacilityDetails(facilityId);
  }

  return {
    checkInviteCode,
    registerOwner,
    joinWithInvite,
    joinFacilityWithInvite,
    addFacility,
    createInviteCode,
    reassignAssistant,
    removeAssistantFromFacility,
    setAssistantStatus,
    syncFacilityDetails,
    propagateFacilityDetails,
  };
}

module.exports = {
  create,
  // Exposed for tests.
  helpers: { normalizeInviteCode, trialExpiry, inviteProblem, FACILITY_TYPES, INVITE_ALPHABET },
};
