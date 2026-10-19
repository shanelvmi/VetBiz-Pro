"use strict";

// E1-check: a READ-ONLY consistency report for the live data (RUNBOOK2 E1-check).
//
// It never writes to Firestore: it only calls get() on collections and
// documents. functions/test/check_consistency.test.js runs every check through
// a guard that throws on any write, batch or transaction.
//
// Not exported from index.js and not deployed as a function: run it by hand.
//
// The report contains business data (client ids, amounts), so it is written
// OUTSIDE the repo and must never be committed. The script refuses an --out
// folder inside the repo.
//
// Running it against production (the owner does this, never Claude Code):
//
//   gcloud auth application-default login
//   gcloud auth application-default set-quota-project vetbiz-pro
//   cd functions
//   node scripts/check_consistency.js --project vetbiz-pro
//   node scripts/check_consistency.js --project vetbiz-pro --facility <facilityId>
//
// The Google account used must be able to read Firestore in vetbiz-pro (an
// Owner or Viewer of the project). Instead of gcloud, a service-account key
// works too: set GOOGLE_APPLICATION_CREDENTIALS to the key file's path (keep
// the key outside the repo).
//
// The report lands in <home>/VetBiz-Pro-reports/ as
// consistency-<project>-<date>.md, or in the folder given with --out.

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const EXAMPLES = 10;
// Amounts are TSh stored as doubles; anything smaller than this is rounding.
const MONEY_TOLERANCE = 0.01;
const DUPLICATE_WINDOW_MS = 2 * 60 * 1000;

// ---------------------------------------------------------------- reading

async function readAll(collectionRef) {
  const snap = await collectionRef.get();
  return snap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
}

function byId(docs) {
  return new Map(docs.map((d) => [d.id, d.data]));
}

async function loadFacility(db, facilityId) {
  const f = db.collection("facilities").doc(facilityId);
  const [sales, services, trashSales, trashServices, debts, clients, payments, products, transactions] =
    await Promise.all(
      ["sales", "services", "trash_sales", "trash_services", "debts", "clients", "payments", "products", "transactions"].map(
        (c) => readAll(f.collection(c)),
      ),
    );
  const batchesByProduct = new Map();
  for (const p of products) {
    batchesByProduct.set(p.id, await readAll(f.collection("products").doc(p.id).collection("batches")));
  }
  const counterSnap = await f.collection("counters").doc("receiptNumber").get();
  const counter = counterSnap.exists ? Number((counterSnap.data() || {}).value) || 0 : null;
  return { sales, services, trashSales, trashServices, debts, clients, payments, products, transactions, batchesByProduct, counter };
}

// ---------------------------------------------------------------- helpers

const num = (v) => (typeof v === "number" && Number.isFinite(v) ? v : Number(v) || 0);
const hasClient = (data) => typeof data.clientId === "string" && data.clientId !== "";

function millis(v) {
  if (!v) return null;
  if (v instanceof Date) return v.getTime();
  if (typeof v.toDate === "function") return v.toDate().getTime();
  if (typeof v === "string") {
    const t = Date.parse(v);
    return Number.isNaN(t) ? null : t;
  }
  return null;
}

function result(items) {
  return { count: items.length, examples: items.slice(0, EXAMPLES) };
}

// The service's own external-expense rule (Service.externalExpenseTotal):
// items with no productId are bought for this service and become an expense.
function externalExpenseTotal(service) {
  return (Array.isArray(service.itemsUsed) ? service.itemsUsed : [])
    .filter((i) => i && i.productId == null)
    .reduce((t, i) => t + num(i.price), 0);
}

// ---------------------------------------------------------------- checks

// (1) A sale to a client with something still owed must have a debt: the
// app writes debts/sale_{id} (since E1a) or, before that, a debt with saleId.
function salesWithoutDebt(d) {
  const debtSaleIds = new Set(d.debts.map((x) => x.data.saleId).filter(Boolean));
  const debtIds = new Set(d.debts.map((x) => x.id));
  const missing = [];
  let walkInOwing = 0;
  for (const s of d.sales) {
    const outstanding = num(s.data.totalAmount) - num(s.data.totalPaid);
    if (outstanding <= MONEY_TOLERANCE) continue;
    if (!hasClient(s.data)) {
      walkInOwing++;
      continue;
    }
    if (!debtIds.has(`sale_${s.id}`) && !debtSaleIds.has(s.id)) missing.push(`${s.id} (owes ${outstanding})`);
  }
  return { ...result(missing), note: `walk-in sales with an amount outstanding (no client, so no debt possible): ${walkInOwing}` };
}

// (2) A debt's sale or service must exist.
function debtsWithoutRecord(d) {
  const sales = byId(d.sales);
  const services = byId(d.services);
  const trashSales = byId(d.trashSales);
  const trashServices = byId(d.trashServices);
  const missing = [];
  let noReference = 0;
  for (const x of d.debts) {
    const { saleId, serviceId } = x.data;
    if (saleId) {
      if (!sales.has(saleId)) missing.push(`${x.id} -> sale ${saleId}${trashSales.has(saleId) ? " (in Trash)" : ""}`);
    } else if (serviceId) {
      if (!services.has(serviceId)) {
        missing.push(`${x.id} -> service ${serviceId}${trashServices.has(serviceId) ? " (in Trash)" : ""}`);
      }
    } else {
      noReference++;
    }
  }
  return { ...result(missing), note: `debts with neither saleId nor serviceId (not checked): ${noReference}` };
}

// (3) client.balance == sum of amountOwed of the client's debt documents.
function clientBalanceMismatch(d) {
  const owed = new Map();
  for (const x of d.debts) {
    if (!x.data.clientId) continue;
    owed.set(x.data.clientId, (owed.get(x.data.clientId) || 0) + num(x.data.amountOwed));
  }
  const wrong = [];
  const clientIds = new Set(d.clients.map((c) => c.id));
  for (const c of d.clients) {
    const balance = num(c.data.balance);
    const sum = owed.get(c.id) || 0;
    if (Math.abs(balance - sum) > MONEY_TOLERANCE) wrong.push(`${c.id} (balance ${balance}, unpaid debts ${sum})`);
  }
  const orphanClients = [...owed.keys()].filter((id) => !clientIds.has(id));
  return { ...result(wrong), note: `client ids that have debts but no client document: ${orphanClients.length}${orphanClients.length ? ` (${orphanClients.slice(0, EXAMPLES).join(", ")})` : ""}` };
}

// (4) No product or batch quantity below zero.
function negativeQuantities(d) {
  const found = [];
  const check = (label, data) => {
    for (const field of ["sellableQty", "stockQty"]) {
      if (field in data && num(data[field]) < 0) found.push(`${label} ${field}=${data[field]}`);
    }
  };
  for (const p of d.products) {
    check(`product ${p.id}`, p.data);
    for (const b of d.batchesByProduct.get(p.id) || []) check(`batch ${p.id}/${b.id}`, b.data);
  }
  return result(found);
}

// (5) A product with batches holds the sum of its batches (the app's
// _recalculateProductAggregates; the FIFO deducts both by the same amount).
// A product with no batch is a legacy product and is skipped.
function productVsBatches(d) {
  const wrong = [];
  let legacy = 0;
  for (const p of d.products) {
    const batches = d.batchesByProduct.get(p.id) || [];
    if (batches.length === 0) {
      legacy++;
      continue;
    }
    for (const field of ["sellableQty", "stockQty"]) {
      const sum = batches.reduce((t, b) => t + num(b.data[field]), 0);
      if (num(p.data[field]) !== sum) wrong.push(`${p.id} ${field} product ${num(p.data[field])}, batches ${sum}`);
    }
  }
  return { ...result(wrong), note: `products with no batch (legacy, not checked): ${legacy}` };
}

// (6) POSSIBLE duplicates: same client, same items and total, within two
// minutes of each other. Only a hint: two real identical sales are possible.
function possibleDuplicates(records, timeOf, itemsKeyOf) {
  const groups = new Map();
  for (const r of records) {
    const t = timeOf(r.data);
    if (t == null) continue;
    const key = JSON.stringify([r.data.clientId || "", num(r.data.totalAmount), itemsKeyOf(r.data)]);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ id: r.id, t });
  }
  const pairs = [];
  for (const list of groups.values()) {
    list.sort((a, b) => a.t - b.t);
    for (let i = 1; i < list.length; i++) {
      if (list[i].t - list[i - 1].t <= DUPLICATE_WINDOW_MS) pairs.push(`${list[i - 1].id} + ${list[i].id}`);
    }
  }
  return result(pairs);
}

const saleItemsKey = (s) =>
  (Array.isArray(s.items) ? s.items : [])
    .map((i) => [i.productId || i.name || "", num(i.quantity), num(i.unitPrice)])
    .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
const serviceItemsKey = (s) => [
  s.name || "",
  (Array.isArray(s.itemsUsed) ? s.itemsUsed : [])
    .map((i) => [i.productId || i.itemName || "", num(i.price)])
    .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))),
];

// (7) Receipt numbers: one shared sequence for sales and services
// (counters/receiptNumber.value is the last number given out). Records in
// Trash still hold their number. A record deleted for good leaves a gap.
function receiptNumbers(d) {
  const holders = new Map();
  const add = (kind, docs) => {
    for (const x of docs) {
      const n = x.data.receiptNumber;
      if (typeof n !== "number") continue;
      if (!holders.has(n)) holders.set(n, []);
      holders.get(n).push(`${kind} ${x.id}`);
    }
  };
  add("sale", d.sales);
  add("service", d.services);
  add("trash sale", d.trashSales);
  add("trash service", d.trashServices);
  const duplicated = [...holders].filter(([, h]) => h.length > 1).map(([n, h]) => `#${n}: ${h.join(", ")}`);
  const highest = Math.max(0, ...holders.keys());
  const top = d.counter == null ? highest : d.counter;
  const gaps = [];
  for (let n = 1; n <= top; n++) if (!holders.has(n)) gaps.push(`#${n}`);
  const aboveCounter = d.counter == null ? [] : [...holders.keys()].filter((n) => n > d.counter).map((n) => `#${n}`);
  return {
    duplicated: result(duplicated),
    gaps: result(gaps),
    aboveCounter: result(aboveCounter),
    note: `counter: ${d.counter == null ? "missing" : d.counter}; highest number found: ${highest}`,
  };
}

// (8) Services without their debt or expense, and payments pointing at a
// missing sale or service.
function servicesAndPayments(d) {
  const debtIds = new Set(d.debts.map((x) => x.id));
  const debtServiceIds = new Set(d.debts.map((x) => x.data.serviceId).filter(Boolean));
  const txIds = new Set(d.transactions.map((x) => x.id));
  const txServiceIds = new Set(d.transactions.map((x) => x.data.serviceId).filter(Boolean));
  const noDebt = [];
  const noExpense = [];
  for (const s of d.services) {
    const owed = num(s.data.totalAmount) - num(s.data.totalPaid);
    if (hasClient(s.data) && owed > MONEY_TOLERANCE && !debtIds.has(`service_${s.id}`) && !debtServiceIds.has(s.id)) {
      noDebt.push(`${s.id} (owes ${owed})`);
    }
    const expense = externalExpenseTotal(s.data);
    const linked = txIds.has(`service_${s.id}`) || txServiceIds.has(s.id) || (s.data.transactionId && txIds.has(s.data.transactionId));
    if (expense > 0 && !linked) noExpense.push(`${s.id} (external items ${expense})`);
  }
  const sales = byId(d.sales);
  const services = byId(d.services);
  const trashSales = byId(d.trashSales);
  const trashServices = byId(d.trashServices);
  const badPayments = [];
  for (const p of d.payments) {
    const { saleId, serviceId } = p.data;
    if (saleId && !sales.has(saleId)) badPayments.push(`${p.id} -> sale ${saleId}${trashSales.has(saleId) ? " (in Trash)" : ""}`);
    if (serviceId && !services.has(serviceId)) {
      badPayments.push(`${p.id} -> service ${serviceId}${trashServices.has(serviceId) ? " (in Trash)" : ""}`);
    }
  }
  return { servicesWithoutDebt: result(noDebt), servicesWithoutExpense: result(noExpense), paymentsWithoutRecord: result(badPayments) };
}

// (9) E2: a service with external items must have its expense at
// transactions/service_{id}, the id addService (E1b) and the Trash restore
// (E2) write. A service recorded before E1b whose expense has a random id
// shows here too; 8b says whether it has an expense at all.
function servicesWithoutServiceExpense(d) {
  const txIds = new Set(d.transactions.map((x) => x.id));
  const missing = [];
  for (const s of d.services) {
    const expense = externalExpenseTotal(s.data);
    if (expense > 0 && !txIds.has(`service_${s.id}`)) missing.push(`${s.id} (external items ${expense})`);
  }
  return result(missing);
}

function checkFacility(d) {
  return {
    salesWithoutDebt: salesWithoutDebt(d),
    debtsWithoutRecord: debtsWithoutRecord(d),
    clientBalanceMismatch: clientBalanceMismatch(d),
    negativeQuantities: negativeQuantities(d),
    productVsBatches: productVsBatches(d),
    possibleDuplicateSales: possibleDuplicates(d.sales, (s) => millis(s.timestamp), saleItemsKey),
    possibleDuplicateServices: possibleDuplicates(d.services, (s) => millis(s.createdAt) ?? millis(s.serviceDate), serviceItemsKey),
    receiptNumbers: receiptNumbers(d),
    ...servicesAndPayments(d),
    servicesWithoutServiceExpense: servicesWithoutServiceExpense(d),
  };
}

/** Reads (never writes) and returns { facilityId: results }. */
async function runChecks(db, { facilityId } = {}) {
  const ids = facilityId ? [facilityId] : (await db.collection("facilities").get()).docs.map((d) => d.id);
  const out = {};
  for (const id of ids) out[id] = checkFacility(await loadFacility(db, id));
  return out;
}

// ---------------------------------------------------------------- report

const DEFINITIONS = `## Definitions (from the app's code)

- **Unpaid debt:** every document in \`debts\` is unpaid; \`amountOwed\` is what is still owed. Recording a payment against a debt (add_payment_screen) lowers \`amountOwed\` by the payment and DELETES the debt when nothing is left; it also lowers \`client.balance\` by the same amount (\`increment(-amount)\`) and raises the sale's or service's \`totalPaid\`. A payment recorded against a client without choosing a debt lowers the balance only, so it shows up below as a balance mismatch.
- **Client balance (check 3):** \`client.balance\` should equal the sum of \`amountOwed\` of that client's debts (tolerance ${MONEY_TOLERANCE} TSh).
- **Outstanding (checks 1, 8):** \`totalAmount - totalPaid\` > ${MONEY_TOLERANCE}. Only a record with a client gets a debt (walk-in sales cannot).
- **Product vs batches (check 5):** an invariant in the app: \`_recalculateProductAggregates\` sets a product's \`sellableQty\` and \`stockQty\` to the sums of its batches, and every sale deducts both by the same amount. Products with no batch (legacy) are skipped.
- **Possible duplicates (check 6):** same client (or both walk-in), same total, same items (sales: product, quantity, unit price; services: name, item, price), saved within 2 minutes. A hint only.
- **Receipt numbers (check 7):** one shared sequence for sales and services; \`counters/receiptNumber.value\` is the last number given out. Records in Trash keep their number; a record deleted for good, or a failed save before E1a/E1b, leaves a gap.
- **Service expense (check 8):** a service whose external items (no productId) cost more than 0 needs \`transactions/service_{id}\`, or (older) a transaction with that \`serviceId\` or the service's \`transactionId\`.
- **Service expense id (check 9):** the same services, but only \`transactions/service_{id}\` counts (written by addService since E1b and by a Trash restore since E2). Run it before a delete and after the restore: the count must not change.`;

const LABELS = [
  ["salesWithoutDebt", "1. Sales with an outstanding amount but no debt"],
  ["debtsWithoutRecord", "2. Debts whose sale or service does not exist"],
  ["clientBalanceMismatch", "3. Clients whose balance differs from their unpaid debts"],
  ["negativeQuantities", "4. Products and batches with a negative quantity"],
  ["productVsBatches", "5. Products whose quantities differ from the sum of their batches"],
  ["possibleDuplicateSales", "6a. POSSIBLE duplicate sales"],
  ["possibleDuplicateServices", "6b. POSSIBLE duplicate services"],
  ["servicesWithoutDebt", "8a. Services with an amount outstanding but no debt"],
  ["servicesWithoutExpense", "8b. Services with external items but no expense transaction"],
  ["paymentsWithoutRecord", "8c. Payments pointing at a missing sale or service"],
  ["servicesWithoutServiceExpense", "9. Services with external items but no transactions/service_{id}"],
];

function section(title, r) {
  const lines = [`### ${title}: ${r.count}`];
  for (const e of r.examples) lines.push(`- ${e}`);
  if (r.count > r.examples.length) lines.push(`- ... and ${r.count - r.examples.length} more`);
  if (r.note) lines.push(`- _${r.note}_`);
  return lines.join("\n");
}

function formatReport(results, { project, generatedAt }) {
  const parts = [`# VetBiz Pro consistency report`, ``, `Project: ${project}. Generated: ${generatedAt}. Read-only: nothing was written.`, ``, `CONTAINS BUSINESS DATA: do not commit or share.`, ``, DEFINITIONS];
  for (const [facilityId, r] of Object.entries(results)) {
    parts.push(``, `## Facility ${facilityId}`, ``);
    const sections = LABELS.slice(0, 7).map(([k, t]) => section(t, r[k]));
    sections.push(section("7a. Receipt numbers used more than once", r.receiptNumbers.duplicated));
    sections.push(section("7b. Receipt numbers missing (gaps up to the counter)", { ...r.receiptNumbers.gaps, note: r.receiptNumbers.note }));
    sections.push(section("7c. Receipt numbers above the counter", r.receiptNumbers.aboveCounter));
    for (const [k, t] of LABELS.slice(7)) sections.push(section(t, r[k]));
    parts.push(sections.join("\n\n"));
  }
  return parts.join("\n") + "\n";
}

// ---------------------------------------------------------------- CLI

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const m = /^--(project|facility|out)$/.exec(argv[i]);
    if (!m || argv[i + 1] == null) throw new Error(`unknown or incomplete argument: ${argv[i]}`);
    args[m[1]] = argv[++i];
  }
  if (!args.project) throw new Error("--project is required, e.g. --project vetbiz-pro");
  return args;
}

const REPO_ROOT = path.resolve(__dirname, "..", "..");

function isInside(child, parent) {
  const rel = path.relative(parent, child);
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const outDir = path.resolve(args.out || path.join(os.homedir(), "VetBiz-Pro-reports"));
  if (isInside(outDir, REPO_ROOT)) throw new Error(`--out must be outside the repo (${REPO_ROOT}): the report holds business data`);

  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: args.project });
  const results = await runChecks(admin.firestore(), { facilityId: args.facility });

  const generatedAt = new Date().toISOString();
  fs.mkdirSync(outDir, { recursive: true });
  const file = path.join(outDir, `consistency-${args.project}-${generatedAt.replace(/[:.]/g, "-")}.md`);
  fs.writeFileSync(file, formatReport(results, { project: args.project, generatedAt }));
  console.log(`Report written to ${file}`);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
}

module.exports = { runChecks, formatReport, parseArgs, isInside, REPO_ROOT };
