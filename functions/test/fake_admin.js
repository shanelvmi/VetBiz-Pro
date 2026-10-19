"use strict";

// Loads the real index.js with firebase-admin replaced by the fakes, so the
// older callables written there (wipeFacilityData, deleteOwnFacility, ...) are
// tested as deployed, checks and all, with no emulator.
//
// index.js reads admin.firestore() and admin.auth() once, when it loads, so
// there is ONE fake database and ONE fake Auth for the whole file: reset()
// empties both before each test.

const Module = require("node:module");
const { FakeDb, FakeTimestamp, FieldValue } = require("./fake_firestore");

let loaded = null;

function loadIndexWithFakes(FakeAuth) {
  if (loaded) return loaded;
  const db = new FakeDb();
  const auth = new FakeAuth();
  // What each call deleted, in order: "facilities/F1/sales", "facilities/F1".
  const recursivelyDeleted = [];
  db.recursiveDelete = async (ref) => {
    recursivelyDeleted.push(ref.path || ref.name);
  };

  const firestore = Object.assign(() => db, { FieldValue, Timestamp: FakeTimestamp });
  const fakeAdmin = {
    initializeApp() {},
    firestore,
    auth: () => auth,
    storage: () => ({ bucket: () => ({ file: () => ({ delete: async () => {} }) }) }),
  };

  process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-fake-admin-test";
  const originalLoad = Module._load;
  Module._load = function (request, ...rest) {
    if (request === "firebase-admin") return fakeAdmin;
    return originalLoad.call(this, request, ...rest);
  };
  let exported;
  try {
    exported = require("../index.js");
  } finally {
    Module._load = originalLoad;
  }

  loaded = {
    exported,
    db,
    auth,
    recursivelyDeleted,
    reset() {
      db.docs = new Map();
      db.failWrites = null;
      recursivelyDeleted.length = 0;
      Object.assign(auth, new FakeAuth());
    },
  };
  return loaded;
}

module.exports = { loadIndexWithFakes };
