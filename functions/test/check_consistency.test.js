"use strict";

// E1-check: the consistency script must be READ-ONLY. Every check runs here
// through readOnly(db), which throws on any write, batch or transaction at
// any level (database, collection, query, document, snapshot ref), and each
// check is tested on small fake data.

const { test } = require("node:test");
const assert = require("node:assert");
const os = require("node:os");
const path = require("node:path");
const { FakeDb, FakeTimestamp } = require("./fake_firestore");
const { runChecks, formatReport, parseArgs, isInside, REPO_ROOT } = require("../scripts/check_consistency");

const FORBIDDEN = new Set(["set", "update", "delete", "create", "add", "batch", "runTransaction", "bulkWriter", "recursiveDelete"]);

// Wraps every object reachable from db, so a write reached through
// db.collection().doc(), a query, or a snapshot's ref is refused too.
function readOnly(target) {
  if (target === null || typeof target !== "object" || target instanceof Date) return target;
  if (typeof target.then === "function") return target.then(readOnly);
  return new Proxy(target, {
    get(obj, prop, receiver) {
      if (FORBIDDEN.has(prop)) {
        return () => {
          throw new Error(`read-only guard: ${String(prop)}() called`);
        };
      }
      const value = obj[prop];
      if (typeof value === "function") // Array methods run on the proxy, so map/filter callbacks get guarded elements.
        return (...args) => readOnly(value.apply(Array.isArray(obj) ? receiver : obj, args));
      return readOnly(value);
    },
  });
}

const at = (iso) => FakeTimestamp.fromDate(new Date(iso));
const F = "facilities/F1";

// One facility in which every check finds exactly one problem, next to
// records that are fine.
function seeded() {
  const db = new FakeDb();
  db.seed("facilities", "F1", { name: "Ukuli" });
  db.seed(`${F}/clients`, "cOk", { name: "Asha", balance: 3000 });
  db.seed(`${F}/clients`, "cWrong", { name: "Juma", balance: 9000 });

  // (1) s1: credit sale with debts/sale_s1 (fine); s2: old-style debt by saleId
  // (fine); s3: owes 500, no debt (problem); s4: walk-in owing (note only).
  db.seed(`${F}/sales`, "s1", { clientId: "cOk", totalAmount: 2000, totalPaid: 0, receiptNumber: 1, timestamp: at("2026-10-01T10:00:00Z"), items: [{ productId: "P1", quantity: 1, unitPrice: 2000 }] });
  db.seed(`${F}/sales`, "s2", { clientId: "cOk", totalAmount: 1000, totalPaid: 0, receiptNumber: 2, timestamp: at("2026-10-01T11:00:00Z"), items: [{ productId: "P1", quantity: 1, unitPrice: 1000 }] });
  db.seed(`${F}/sales`, "s3", { clientId: "cWrong", totalAmount: 1500, totalPaid: 1000, receiptNumber: 3, timestamp: at("2026-10-01T12:00:00Z"), items: [{ productId: "P1", quantity: 3, unitPrice: 500 }] });
  db.seed(`${F}/sales`, "s4", { totalAmount: 800, totalPaid: 0, receiptNumber: 4, timestamp: at("2026-10-01T13:00:00Z"), items: [] });
  // (6) s5 and s6: same client, items and total, 90 seconds apart.
  db.seed(`${F}/sales`, "s5", { clientId: "cOk", totalAmount: 700, totalPaid: 700, receiptNumber: 5, timestamp: at("2026-10-02T09:00:00Z"), items: [{ productId: "P2", quantity: 1, unitPrice: 700 }] });
  db.seed(`${F}/sales`, "s6", { clientId: "cOk", totalAmount: 700, totalPaid: 700, receiptNumber: 5, timestamp: at("2026-10-02T09:01:30Z"), items: [{ productId: "P2", quantity: 1, unitPrice: 700 }] });
  // (7) receipt #5 used twice (s5, s6), #6 missing, counter 7 (#7 is a service).
  db.seed(`${F}/counters`, "receiptNumber", { value: 7 });

  db.seed(`${F}/debts`, "sale_s1", { clientId: "cOk", saleId: "s1", amountOwed: 2000 });
  db.seed(`${F}/debts`, "d2", { clientId: "cOk", saleId: "s2", amountOwed: 1000 });
  // (2) a debt whose sale is gone; (3) it also gives cWrong 9000 vs 4000.
  db.seed(`${F}/debts`, "sale_gone", { clientId: "cWrong", saleId: "gone", amountOwed: 4000 });

  // (8) sv1: credit + external item, debt and expense present (fine);
  // sv2: owes, no debt; external item, no expense (one problem each).
  db.seed(`${F}/services`, "sv1", { clientId: "cOk", name: "Vaccination", totalAmount: 5000, totalPaid: 5000, receiptNumber: 7, createdAt: at("2026-10-03T08:00:00Z"), itemsUsed: [{ itemName: "Syringe", price: 300 }] });
  db.seed(`${F}/services`, "sv2", { clientId: "cOk", name: "Deworming", totalAmount: 4000, totalPaid: 1000, createdAt: at("2026-10-03T09:00:00Z"), itemsUsed: [{ itemName: "Gloves", price: 200 }, { productId: "P1", itemName: "Dawa", price: 900 }] });
  db.seed(`${F}/transactions`, "service_sv1", { type: "expense", serviceId: "sv1", amount: 300 });
  db.seed(`${F}/debts`, "service_svOld", { clientId: "cWrong", serviceId: "svOld", amountOwed: 0 });
  db.seed(`${F}/trash_services`, "svOld", { name: "Old" });

  // (8) payments: one to a live sale (fine), one to a sale in Trash.
  db.seed(`${F}/payments`, "sale_s5", { saleId: "s5", amount: 700 });
  db.seed(`${F}/payments`, "pT", { saleId: "sT", amount: 100 });
  db.seed(`${F}/trash_sales`, "sT", { totalAmount: 100, totalPaid: 100 });

  // (4) and (5): P1 matches its batches; P2 is negative and differs from
  // its batch; P3 is legacy (no batch).
  db.seed(`${F}/products`, "P1", { name: "Dawa", sellableQty: 5, stockQty: 2 });
  db.seed(`${F}/products/P1/batches`, "b1", { sellableQty: 3, stockQty: 2 });
  db.seed(`${F}/products/P1/batches`, "b2", { sellableQty: 2, stockQty: 0 });
  db.seed(`${F}/products`, "P2", { name: "Chanjo", sellableQty: -3, stockQty: 0 });
  db.seed(`${F}/products/P2/batches`, "b3", { sellableQty: 1, stockQty: 0 });
  db.seed(`${F}/products`, "P3", { name: "Legacy", sellableQty: 4, stockQty: 0 });
  return db;
}

const snapshot = (db) => JSON.stringify([...db.docs.entries()]);

test("the read-only guard refuses every kind of write, at every level", async () => {
  const db = readOnly(seeded());
  const doc = db.collection("facilities").doc("F1");
  assert.throws(() => doc.set({}), /read-only guard: set/);
  assert.throws(() => doc.update({}), /read-only guard: update/);
  assert.throws(() => doc.delete(), /read-only guard: delete/);
  assert.throws(() => doc.create({}), /read-only guard: create/);
  assert.throws(() => doc.collection("sales").add({}), /read-only guard: add/);
  assert.throws(() => db.batch(), /read-only guard: batch/);
  assert.throws(() => db.runTransaction(async () => {}), /read-only guard: runTransaction/);
  const snap = await doc.collection("sales").where("clientId", "==", "cOk").get();
  assert.throws(() => snap.docs[0].ref.update({ totalPaid: 1 }), /read-only guard: update/);
});

test("every check runs through the read-only guard and changes nothing", async () => {
  const raw = seeded();
  const before = snapshot(raw);
  const results = await runChecks(readOnly(raw));
  assert.deepStrictEqual(Object.keys(results), ["F1"]);
  assert.strictEqual(snapshot(raw), before);
  // --facility reads only that one
  const one = await runChecks(readOnly(raw), { facilityId: "F1" });
  assert.deepStrictEqual(Object.keys(one), ["F1"]);
});

test("each check finds exactly the planted problem", async () => {
  const r = (await runChecks(readOnly(seeded()))).F1;
  assert.deepStrictEqual(r.salesWithoutDebt.examples, ["s3 (owes 500)"]);
  assert.match(r.salesWithoutDebt.note, /walk-in .*: 1$/);
  assert.deepStrictEqual(r.debtsWithoutRecord.examples, ["sale_gone -> sale gone", "service_svOld -> service svOld (in Trash)"]);
  assert.deepStrictEqual(r.clientBalanceMismatch.examples, ["cWrong (balance 9000, unpaid debts 4000)"]);
  assert.deepStrictEqual(r.negativeQuantities.examples, ["product P2 sellableQty=-3"]);
  assert.deepStrictEqual(r.productVsBatches.examples, ["P2 sellableQty product -3, batches 1"]);
  assert.match(r.productVsBatches.note, /legacy, not checked\): 1$/);
  assert.deepStrictEqual(r.possibleDuplicateSales.examples, ["s5 + s6"]);
  assert.strictEqual(r.possibleDuplicateServices.count, 0);
  assert.deepStrictEqual(r.receiptNumbers.duplicated.examples, ["#5: sale s5, sale s6"]);
  assert.deepStrictEqual(r.receiptNumbers.gaps.examples, ["#6"]);
  assert.strictEqual(r.receiptNumbers.aboveCounter.count, 0);
  assert.deepStrictEqual(r.servicesWithoutDebt.examples, ["sv2 (owes 3000)"]);
  assert.deepStrictEqual(r.servicesWithoutExpense.examples, ["sv2 (external items 200)"]);
  assert.deepStrictEqual(r.paymentsWithoutRecord.examples, ["pT -> sale sT (in Trash)"]);
});

test("duplicates more than two minutes apart, or with different items, are not flagged", async () => {
  const db = new FakeDb();
  db.seed("facilities", "F1", {});
  const sale = (id, iso, qty) =>
    db.seed(`${F}/sales`, id, { clientId: "c", totalAmount: 100, totalPaid: 100, timestamp: at(iso), items: [{ productId: "P", quantity: qty, unitPrice: 100 / qty }] });
  sale("a", "2026-10-01T10:00:00Z", 1);
  sale("b", "2026-10-01T10:02:01Z", 1);
  sale("c", "2026-10-01T10:02:30Z", 2);
  const r = (await runChecks(readOnly(db))).F1;
  assert.strictEqual(r.possibleDuplicateSales.count, 0);
  // and services through createdAt
  db.seed(`${F}/services`, "x", { clientId: "c", name: "Dip", totalAmount: 50, totalPaid: 50, createdAt: at("2026-10-01T10:00:00Z"), itemsUsed: [] });
  db.seed(`${F}/services`, "y", { clientId: "c", name: "Dip", totalAmount: 50, totalPaid: 50, createdAt: at("2026-10-01T10:01:00Z"), itemsUsed: [] });
  assert.deepStrictEqual((await runChecks(readOnly(db))).F1.possibleDuplicateServices.examples, ["x + y"]);
});

test("at most 10 examples per check, with the full count", async () => {
  const db = new FakeDb();
  db.seed("facilities", "F1", {});
  for (let i = 0; i < 12; i++) db.seed(`${F}/products`, `P${i}`, { sellableQty: -1 });
  const r = (await runChecks(readOnly(db))).F1;
  assert.strictEqual(r.negativeQuantities.count, 12);
  assert.strictEqual(r.negativeQuantities.examples.length, 10);
  assert.match(formatReport({ F1: r }, { project: "demo", generatedAt: "now" }), /\.\.\. and 2 more/);
});

test("the report has every check and the definitions; arguments and the out folder are checked", async () => {
  const text = formatReport(await runChecks(readOnly(seeded())), { project: "demo", generatedAt: "now" });
  for (const n of ["1.", "2.", "3.", "4.", "5.", "6a.", "6b.", "7a.", "7b.", "7c.", "8a.", "8b.", "8c."]) assert.ok(text.includes(`### ${n}`), n);
  assert.match(text, /Unpaid debt/);
  assert.deepStrictEqual(parseArgs(["--project", "p", "--facility", "F1", "--out", "x"]), { project: "p", facility: "F1", out: "x" });
  assert.throws(() => parseArgs(["--facility", "F1"]), /--project is required/);
  assert.throws(() => parseArgs(["--project"]), /incomplete/);
  assert.ok(isInside(path.join(REPO_ROOT, "docs"), REPO_ROOT));
  assert.ok(!isInside(path.join(os.homedir(), "VetBiz-Pro-reports"), REPO_ROOT));
});
