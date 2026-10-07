"use strict";

// The membership functions and the app have to agree on THREE things, and a
// mismatch fails quietly - registration just gets slow, or errors with a
// vague "not found":
//
//   1. which functions exist,
//   2. which region they run in (next to the database - africa-south1 - so the
//      several database round trips each makes stay local), and
//   3. that every place the app calls them uses that region.
//
// This is what went wrong before: the functions ran in us-central1, the
// database is in africa-south1, and every call crossed continents.
//
// Reads the real index.js and the real Dart source; needs no emulator.

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-endpoints-test";
const exported = require("../index.js");

const LIB = path.join(__dirname, "..", "..", "lib");
const membershipDart = fs.readFileSync(path.join(LIB, "services", "membership_service.dart"), "utf8");

const calledByApp = [...membershipDart.matchAll(/_call\('(\w+)'/g)].map((m) => m[1]);
const appRegion = (membershipDart.match(/kMembershipFunctionsRegion\s*=\s*'([^']+)'/) || [])[1];

function dartFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? dartFiles(p) : p.endsWith(".dart") ? [p] : [];
  });
}

test("the app asks for functions, and says which region", () => {
  assert.ok(calledByApp.length >= 8, `expected the app to call the 8 membership functions, found ${calledByApp.length}`);
  assert.ok(appRegion, "kMembershipFunctionsRegion is missing from membership_service.dart");
});

test("every function the app calls exists on the server, as a 2nd-gen callable in the SAME region", () => {
  for (const name of calledByApp) {
    const fn = exported[name];
    assert.ok(fn, `the app calls "${name}", but index.js doesn't export it`);
    const endpoint = fn.__endpoint;
    assert.strictEqual(endpoint.platform, "gcfv2", `${name} must be 2nd gen (africa-south1 has no 1st gen)`);
    assert.ok(endpoint.callableTrigger, `${name} must be a callable`);
    assert.deepStrictEqual(endpoint.region, [appRegion], `${name} runs in ${JSON.stringify(endpoint.region)}, the app calls ${appRegion}`);
  }
});

test("nothing in the app calls a membership function without the region", () => {
  const offenders = [];
  for (const file of dartFiles(LIB)) {
    const src = fs.readFileSync(file, "utf8");
    // The default FirebaseFunctions.instance is us-central1.
    for (const name of calledByApp) {
      if (src.includes(`FirebaseFunctions.instance.httpsCallable('${name}')`)) offenders.push(`${path.relative(LIB, file)} -> ${name}`);
    }
    // And any instanceFor(...) that doesn't pass a region.
    for (const m of src.matchAll(/FirebaseFunctions\.instanceFor\(([^)]*)\)/g)) {
      if (!/region\s*:/.test(m[1])) offenders.push(`${path.relative(LIB, file)} -> instanceFor(${m[1].trim()}) has no region`);
    }
  }
  assert.deepStrictEqual(offenders, [], "these would call the wrong region:\n  " + offenders.join("\n  "));
});

test("the older functions are untouched: still 1st gen in us-central1", () => {
  for (const name of ["deleteFacility", "deleteOwnFacility", "removeAssistant", "platformRemoveUser", "wipeFacilityData", "revokeAllSessions"]) {
    assert.strictEqual(exported[name].__endpoint.platform, "gcfv1", `${name} changed generation`);
  }
});

// ---------------------------------------------------------------------------
// Constants the app and the server both know (Phase 2 spec, section 6). Read
// from the real Dart source as text, like the region above.

const { helpers } = require("../membership.js");
const membershipJs = fs.readFileSync(path.join(__dirname, "..", "membership.js"), "utf8");
const readDart = (...parts) => fs.readFileSync(path.join(LIB, ...parts), "utf8");

// The stored keys of a Dart enum written as `name('key'),`.
const enumKeys = (src, enumName) => {
  const body = (src.match(new RegExp(String.raw`enum ${enumName}\s*\{([\s\S]*?);`)) || [])[1] || "";
  return [...body.matchAll(/\w+\('([^']+)'\)/g)].map((m) => m[1]).sort();
};

test("invite code length and alphabet match AppRules", () => {
  const rules = readDart("config", "app_rules.dart");
  const appLength = Number((rules.match(/inviteCodeLength\s*=\s*(\d+)/) || [])[1]);
  const appAlphabet = (rules.match(/inviteAlphabet\s*=\s*'([^']+)'/) || [])[1];
  assert.strictEqual(appLength, helpers.INVITE_CODE_LENGTH, "AppRules.inviteCodeLength differs from INVITE_CODE_LENGTH");
  assert.strictEqual(appAlphabet, helpers.INVITE_ALPHABET, "AppRules.inviteAlphabet differs from INVITE_ALPHABET");
});

test("UserRole keys are the roles the server writes", () => {
  const appRoles = enumKeys(readDart("data", "user_role.dart"), "UserRole");
  const serverRoles = [...new Set([...membershipJs.matchAll(/\brole:\s*"([a-z_]+)"/g)].map((m) => m[1]))].sort();
  assert.ok(serverRoles.length > 0, "found no role writes in membership.js");
  assert.deepStrictEqual(appRoles, serverRoles);
});

test("UserStatus keys are the statuses the server writes or moves between", () => {
  const appStatuses = enumKeys(readDart("data", "user_status.dart"), "UserStatus");
  const written = [...membershipJs.matchAll(/\bstatus:\s*"([a-z_]+)"/g)].map((m) => m[1]);
  const transitions = [...membershipJs.matchAll(/\b(?:from|to):\s*"([a-z_]+)"/g)].map((m) => m[1]);
  const serverStatuses = [...new Set([...written, ...transitions])].sort();
  assert.ok(serverStatuses.length > 0, "found no status writes in membership.js");
  assert.deepStrictEqual(appStatuses, serverStatuses);
});
