"use strict";

// A small in-memory stand-in for Firestore - just enough of its behaviour for
// the membership functions: documents, equality / array-contains queries,
// batches, create() that refuses to overwrite, FieldValue sentinels, and
// TRANSACTIONS WITH CONFLICT DETECTION (a transaction whose reads were
// changed by someone else before it commits is run again, as in production).
// That last part is what lets the tests prove an invite can't be redeemed twice
// by two people at the same moment.

class FakeTimestamp {
  constructor(date) {
    this._date = date;
  }
  static fromDate(date) {
    return new FakeTimestamp(date);
  }
  toDate() {
    return this._date;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ __sentinel: "serverTimestamp" }),
  arrayUnion: (...items) => ({ __sentinel: "arrayUnion", items }),
};

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

function resolve(existing, patch, now) {
  const out = { ...existing };
  for (const [key, value] of Object.entries(patch)) {
    if (value && value.__sentinel === "serverTimestamp") {
      out[key] = new FakeTimestamp(now());
    } else if (value && value.__sentinel === "arrayUnion") {
      const list = Array.isArray(out[key]) ? [...out[key]] : [];
      for (const item of value.items) if (!list.some((x) => same(x, item))) list.push(item);
      out[key] = list;
    } else {
      out[key] = value;
    }
  }
  return out;
}

class FakeDb {
  constructor() {
    this.docs = new Map(); // "collection/id" -> { data, version }
    this.nextId = 1;
    this.clock = () => new Date();
    this.failWrites = null; // (path) => boolean
  }

  seed(collection, id, data) {
    this.docs.set(`${collection}/${id}`, { data: clone(data), version: 1 });
  }

  read(collection, id) {
    const entry = this.docs.get(`${collection}/${id}`);
    return entry ? entry.data : undefined;
  }

  // Direct children only: "facilities" must not list the documents inside
  // "facilities/F1/notifications".
  all(collection) {
    const prefix = `${collection}/`;
    return [...this.docs.keys()]
      .filter((k) => k.startsWith(prefix) && !k.slice(prefix.length).includes("/"))
      .map((k) => k.slice(prefix.length));
  }

  collection(name) {
    return new FakeCollection(this, name);
  }

  batch() {
    const ops = [];
    return {
      set: (ref, data) => ops.push(() => ref.set(data)),
      update: (ref, patch) => ops.push(() => ref.update(patch)),
      delete: (ref) => ops.push(() => ref.delete()),
      commit: async () => {
        for (const op of ops) await op();
      },
    };
  }

  // Optimistic concurrency, like the real thing: remember the version of every
  // document read; at commit, if any has changed, throw the work away and run
  // the function again.
  async runTransaction(fn) {
    for (let attempt = 0; attempt < 5; attempt++) {
      const reads = new Map();
      const writes = [];
      const tx = {
        get: async (ref) => {
          const snap = await ref.get();
          reads.set(ref.path, this.docs.has(ref.path) ? this.docs.get(ref.path).version : 0);
          return snap;
        },
        set: (ref, data) => writes.push(() => ref.set(data)),
        update: (ref, patch) => writes.push(() => ref.update(patch)),
        delete: (ref) => writes.push(() => ref.delete()),
      };
      const result = await fn(tx);
      const stale = [...reads].some(([path, v]) => (this.docs.has(path) ? this.docs.get(path).version : 0) !== v);
      if (stale) continue;
      // The check above and ALL the writes below happen in one go, with
      // nothing able to run in between - a real commit is atomic. (An earlier
      // version awaited between writes, which let a second transaction slip in
      // after the first had written some of its changes but not all.)
      const applied = writes.map((w) => w());
      await Promise.all(applied);
      return result;
    }
    throw new Error("transaction kept conflicting");
  }
}

class FakeCollection {
  constructor(db, name) {
    this.db = db;
    this.name = name;
    this.filters = [];
  }
  doc(id) {
    return new FakeDocRef(this.db, this.name, id || `auto${this.db.nextId++}`);
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
  where(field, op, value) {
    const q = new FakeCollection(this.db, this.name);
    q.filters = [...this.filters, { field, op, value }];
    return q;
  }
  async get() {
    const docs = this.db
      .all(this.name)
      .map((id) => new FakeDocRef(this.db, this.name, id))
      .filter((ref) => {
        const data = this.db.read(this.name, ref.id);
        return this.filters.every(({ field, op, value }) => {
          const v = data[field];
          if (op === "==") return value === null ? v === null : v === value;
          if (op === "array-contains") return Array.isArray(v) && v.includes(value);
          throw new Error(`fake: unsupported operator ${op}`);
        });
      })
      .map((ref) => ref.snapshot());
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}

class FakeDocRef {
  constructor(db, collection, id) {
    this.db = db;
    this.parent = collection;
    this.id = id;
    this.path = `${collection}/${id}`;
  }
  // A document's own subcollection, e.g. facilities/F1/notifications.
  collection(name) {
    return new FakeCollection(this.db, `${this.path}/${name}`);
  }
  snapshot() {
    const data = this.db.read(this.parent, this.id);
    const ref = this;
    return { id: this.id, ref, exists: data !== undefined, data: () => (data === undefined ? undefined : clone(data)) };
  }
  async get() {
    return this.snapshot();
  }
  _write(data) {
    // Lets a test make particular writes fail, to prove something that must
    // be best-effort really is.
    if (this.db.failWrites && this.db.failWrites(this.path)) throw new Error("fake: write refused");
    const prev = this.db.docs.get(this.path);
    this.db.docs.set(this.path, { data, version: (prev ? prev.version : 0) + 1 });
  }
  async set(data) {
    this._write(resolve({}, data, this.db.clock));
  }
  async create(data) {
    if (this.db.docs.has(this.path)) {
      throw Object.assign(new Error("ALREADY_EXISTS"), { code: 6 });
    }
    this._write(resolve({}, data, this.db.clock));
  }
  async update(patch) {
    const prev = this.db.docs.get(this.path);
    if (!prev) throw Object.assign(new Error("NOT_FOUND"), { code: 5 });
    this._write(resolve(prev.data, patch, this.db.clock));
  }
  async delete() {
    if (this.db.failWrites && this.db.failWrites(this.path)) throw new Error("fake: write refused");
    this.db.docs.delete(this.path);
  }
}

// Deep copy that keeps FakeTimestamp instances usable (JSON would flatten them).
function clone(value) {
  if (value instanceof FakeTimestamp) return new FakeTimestamp(new Date(value._date.getTime()));
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = clone(v);
    return out;
  }
  return value;
}

module.exports = { FakeDb, FakeTimestamp, FieldValue, HttpsError };
