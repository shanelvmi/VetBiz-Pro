const functions = require("firebase-functions/v1");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten, onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// Email credentials: NEVER hardcode these. Set them as Cloud Functions
// secrets (Secret Manager-backed, not committed to git) once, from your
// machine:
//
//   firebase functions:secrets:set GMAIL_USER
//   firebase functions:secrets:set GMAIL_PASS   (a Gmail *App Password*, not your login password)
//
// They're then available to the function below as process.env.GMAIL_USER /
// process.env.GMAIL_PASS at runtime - they are never present in source code
// or in the git history.
// ---------------------------------------------------------------------------

exports.sendAssistantCredentials = functions
  .runWith({ secrets: ["GMAIL_USER", "GMAIL_PASS"] })
  .https.onCall(async (data, context) => {
    const { email, name, phone, password } = data;

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_PASS,
      },
    });

    const mailOptions = {
      from: `VetBiz Admin <${process.env.GMAIL_USER}>`,
      to: email,
      subject: "VetBiz Assistant Login Credentials",
      text: `Hello ${name},

You have been registered as an assistant on the VetBiz system.

📧 Email: ${email}
📱 Phone: ${phone}
🔐 Password: ${password}

Please log in using these credentials and change your password after logging in.

Thank you,
VetBiz Admin Team`,
    };

    try {
      await transporter.sendMail(mailOptions);
      return { success: true };
    } catch (error) {
      console.error("Email send error:", error);
      throw new functions.https.HttpsError("internal", "Email sending failed");
    }
  });

// ---------------------------------------------------------------------------
// Archiving: keeps the live `sales` subcollection small so day-to-day queries
// (and their Firestore read costs) don't grow forever as years of history
// pile up across facilities. Runs daily, moves *fully paid* sales that have
// had no activity for ARCHIVE_AFTER_DAYS into `archived_sales` (already used
// by the Sales Archive screen), and deletes them from the live collection.
//
// Deliberately keyed on `updatedAt` (last activity), not `timestamp`
// (original sale date): a sale created long ago but only just settled today
// has an `updatedAt` of today, so it stays in the active list a while longer
// instead of vanishing into the archive the day after it was finally paid.
//
// Sales that still carry an outstanding balance are left in place regardless
// of age, so open debts stay visible in the normal sales/debtors views.
// ---------------------------------------------------------------------------

const ARCHIVE_AFTER_DAYS = 180;
const ARCHIVE_BATCH_SIZE = 300;
const MAX_BATCHES_PER_FACILITY_PER_RUN = 10; // bounds run time/cost per day

exports.archiveOldSales = onSchedule("every 24 hours", async () => {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - ARCHIVE_AFTER_DAYS * 24 * 60 * 60 * 1000)
  );

  const facilitiesSnap = await db.collection("facilities").get();

  for (const facilityDoc of facilitiesSnap.docs) {
    const facilityId = facilityDoc.id;
    const salesRef = db
      .collection("facilities")
      .doc(facilityId)
      .collection("sales");

    for (let batchNum = 0; batchNum < MAX_BATCHES_PER_FACILITY_PER_RUN; batchNum++) {
      const oldSalesSnap = await salesRef
        .where("updatedAt", "<", cutoff)
        .orderBy("updatedAt", "asc")
        .limit(ARCHIVE_BATCH_SIZE)
        .get();

      if (oldSalesSnap.empty) break;

      const batch = db.batch();
      let archivedCount = 0;

      oldSalesSnap.docs.forEach((doc) => {
        const sale = doc.data();
        const totalAmount = sale.totalAmount || 0;
        const totalPaid = sale.totalPaid || 0;

        // Leave sales with an outstanding balance alone - they still need
        // to show up in day-to-day debtor tracking regardless of age.
        if (totalPaid < totalAmount) return;

        const archiveRef = db
          .collection("facilities")
          .doc(facilityId)
          .collection("archived_sales")
          .doc(doc.id);

        batch.set(archiveRef, sale);
        batch.delete(doc.ref);
        archivedCount++;
      });

      if (archivedCount > 0) {
        await batch.commit();
      }

      // If this batch wasn't full, there's nothing older left to check.
      if (oldSalesSnap.size < ARCHIVE_BATCH_SIZE) break;

      // If nothing in a full batch was eligible (all still owe money),
      // don't keep re-fetching the exact same batch forever this run.
      if (archivedCount === 0) break;
    }
  }

  console.log("Sales archive sweep complete.");
});

// ---------------------------------------------------------------------------
// Precomputed daily summaries: keeps one small aggregate doc per
// facility/day (facilities/{facilityId}/dailySummaries/{YYYY-MM-DD}) updated
// incrementally on every sale write. Dashboards/reports can then read a
// handful of summary docs for a date range instead of scanning every raw
// sale - see lib/services/sales_summary_service.dart on the app side.
// ---------------------------------------------------------------------------

function dayKeyFor(saleData) {
  if (!saleData || !saleData.timestamp) return null;
  const date = saleData.timestamp.toDate();
  return date.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
}

exports.updateDailySalesSummary = onDocumentWritten(
  "facilities/{facilityId}/sales/{saleId}",
  async (event) => {
    const { facilityId, saleId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;

    // A sale disappearing from `sales` happens for two different reasons:
    // a genuine delete, or archiveOldSales relocating it to
    // `archived_sales`. Only the first should reverse its contribution to
    // dailySummaries - an archived sale still fully exists, just
    // elsewhere, and its revenue should stay counted. Because
    // archiveOldSales writes both the archive copy and the delete in one
    // atomic batch, by the time this trigger runs for the delete, the
    // archived_sales doc (same ID) is reliably already there if this was
    // an archive rather than a real deletion.
    if (before && !after) {
      const archivedDoc = await db
        .collection("facilities")
        .doc(facilityId)
        .collection("archived_sales")
        .doc(saleId)
        .get();
      if (archivedDoc.exists) {
        return; // archived, not deleted - leave dailySummaries untouched
      }
    }

    const beforeDay = dayKeyFor(before);
    const afterDay = dayKeyFor(after);

    const summaryRef = (day) =>
      db
        .collection("facilities")
        .doc(facilityId)
        .collection("dailySummaries")
        .doc(day);

    // Reverse the old contribution (covers both update and delete).
    if (before && beforeDay) {
      await summaryRef(beforeDay).set(
        {
          totalAmount: admin.firestore.FieldValue.increment(-(before.totalAmount || 0)),
          totalPaid: admin.firestore.FieldValue.increment(-(before.totalPaid || 0)),
          totalProfit: admin.firestore.FieldValue.increment(-(before.totalProfit || 0)),
          saleCount: admin.firestore.FieldValue.increment(-1),
        },
        { merge: true }
      );
    }

    // Apply the new contribution (covers both create and update).
    if (after && afterDay) {
      await summaryRef(afterDay).set(
        {
          totalAmount: admin.firestore.FieldValue.increment(after.totalAmount || 0),
          totalPaid: admin.firestore.FieldValue.increment(after.totalPaid || 0),
          totalProfit: admin.firestore.FieldValue.increment(after.totalProfit || 0),
          saleCount: admin.firestore.FieldValue.increment(1),
          facilityId,
          date: afterDay,
        },
        { merge: true }
      );
    }
  }
);

// ---------------------------------------------------------------------------
// Daily cash collections: `dailySummaries` above tracks revenue by the DATE
// A SALE WAS MADE - it deliberately doesn't move an old sale's numbers just
// because it got paid later. That's correct for "how much did we sell on
// day X", but it means it can't answer a different, equally real question:
// "how much actual cash did we collect on day X" - because a payment on an
// old credit sale gets filed under the sale's original date, not the day
// the money actually arrived.
//
// `dailyCollections` answers that second question. It's fed by every
// document created in `payments` - which now covers BOTH the upfront
// amount collected at sale time (see SaleProvider.addSale) AND later debt
// repayments (see AddPaymentScreen) - so every payments doc, whichever of
// those wrote it, adds to the bucket for the day it was actually written.
// ---------------------------------------------------------------------------

exports.updateDailyCollections = onDocumentCreated(
  "facilities/{facilityId}/payments/{paymentId}",
  async (event) => {
    const { facilityId } = event.params;
    const payment = event.data?.data();

    if (!payment || !payment.timestamp || typeof payment.amount !== "number") {
      return;
    }

    const dayKey = payment.timestamp.toDate().toISOString().slice(0, 10);

    const collectionRef = db
      .collection("facilities")
      .doc(facilityId)
      .collection("dailyCollections")
      .doc(dayKey);

    await collectionRef.set(
      {
        totalCollected: admin.firestore.FieldValue.increment(payment.amount),
        paymentCount: admin.firestore.FieldValue.increment(1),
        facilityId,
        date: dayKey,
      },
      { merge: true }
    );
  }
);

// ---------------------------------------------------------------------------
// Daily service summaries: same pattern as updateDailySalesSummary, but for
// the `services` collection. Bucketed by `serviceDate` (when the service
// was actually performed) rather than `updatedAt`, for the same reason
// sales use `timestamp`: a service performed months ago that only just got
// paid off today shouldn't have its revenue silently move into today's
// bucket. serviceDate is set by the app's service form (defaults to "now"
// if the user doesn't pick one), so it should always be present - if it's
// ever missing on an older/legacy record, that record is simply skipped
// here rather than guessed at.
// ---------------------------------------------------------------------------

function serviceDayKeyFor(serviceData) {
  if (!serviceData || !serviceData.serviceDate) return null;
  return serviceData.serviceDate.toDate().toISOString().slice(0, 10);
}

exports.updateDailyServiceSummary = onDocumentWritten(
  "facilities/{facilityId}/services/{serviceId}",
  async (event) => {
    const { facilityId, serviceId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;

    // Same fix already needed for sales: a service disappearing from
    // `services` could be a genuine delete, or archiveOldServices
    // relocating it to `archived_services`. Only a real delete should
    // reverse its contribution to dailyServiceSummaries.
    if (before && !after) {
      const archivedDoc = await db
        .collection("facilities")
        .doc(facilityId)
        .collection("archived_services")
        .doc(serviceId)
        .get();
      if (archivedDoc.exists) {
        return; // archived, not deleted - leave dailyServiceSummaries untouched
      }
    }

    const beforeDay = serviceDayKeyFor(before);
    const afterDay = serviceDayKeyFor(after);

    const summaryRef = (day) =>
      db
        .collection("facilities")
        .doc(facilityId)
        .collection("dailyServiceSummaries")
        .doc(day);

    if (before && beforeDay) {
      await summaryRef(beforeDay).set(
        {
          totalAmount: admin.firestore.FieldValue.increment(-(before.totalAmount || 0)),
          totalServiceProfit: admin.firestore.FieldValue.increment(-(before.totalServiceProfit || 0)),
          serviceCount: admin.firestore.FieldValue.increment(-1),
        },
        { merge: true }
      );
    }

    if (after && afterDay) {
      await summaryRef(afterDay).set(
        {
          totalAmount: admin.firestore.FieldValue.increment(after.totalAmount || 0),
          totalServiceProfit: admin.firestore.FieldValue.increment(after.totalServiceProfit || 0),
          serviceCount: admin.firestore.FieldValue.increment(1),
          facilityId,
          date: afterDay,
        },
        { merge: true }
      );
    }
  }
);

// ---------------------------------------------------------------------------
// Daily transaction summaries: same pattern again, for the `transactions`
// collection. `date` is always present (non-nullable in the app's
// TransactionModel), so no null-skipping needed here. Buckets separately by
// type (expense / profit / other income) since the dashboard needs each of
// those as its own figure, matching TransactionProvider's own
// totalExpenses/subProfit/totalOtherIncome getters (same case-insensitive
// type matching).
// ---------------------------------------------------------------------------

function transactionDayKeyFor(txData) {
  if (!txData || !txData.date) return null;
  return txData.date.toDate().toISOString().slice(0, 10);
}

exports.updateDailyTransactionSummary = onDocumentWritten(
  "facilities/{facilityId}/transactions/{transactionId}",
  async (event) => {
    const { facilityId } = event.params;
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;

    const beforeDay = transactionDayKeyFor(before);
    const afterDay = transactionDayKeyFor(after);

    const summaryRef = (day) =>
      db
        .collection("facilities")
        .doc(facilityId)
        .collection("dailyTransactionSummaries")
        .doc(day);

    const fieldFor = (type) => {
      const t = (type || "").toLowerCase();
      if (t === "expense") return "totalExpense";
      if (t === "profit") return "totalProfit";
      if (t === "other income") return "totalOtherIncome";
      return null;
    };

    if (before && beforeDay) {
      const field = fieldFor(before.type);
      if (field) {
        await summaryRef(beforeDay).set(
          { [field]: admin.firestore.FieldValue.increment(-(before.amount || 0)) },
          { merge: true }
        );
      }
    }

    if (after && afterDay) {
      const field = fieldFor(after.type);
      if (field) {
        await summaryRef(afterDay).set(
          {
            [field]: admin.firestore.FieldValue.increment(after.amount || 0),
            facilityId,
            date: afterDay,
          },
          { merge: true }
        );
      }
    }
  }
);

// ---------------------------------------------------------------------------
// Archiving for Services: same pattern as archiveOldSales - keeps the live
// `services` subcollection small as it grows (especially with multiple
// vets recording services daily). Keyed on `updatedAt` (last activity),
// not `serviceDate`, for the same reason as sales: a service performed
// long ago but only just settled today shouldn't vanish into the archive
// the day after being paid off. Only fully-paid services are archived;
// anything still owed stays in the live list regardless of age.
// ---------------------------------------------------------------------------

exports.archiveOldServices = onSchedule("every 24 hours", async () => {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - ARCHIVE_AFTER_DAYS * 24 * 60 * 60 * 1000)
  );

  const facilitiesSnap = await db.collection("facilities").get();

  for (const facilityDoc of facilitiesSnap.docs) {
    const facilityId = facilityDoc.id;
    const servicesRef = db
      .collection("facilities")
      .doc(facilityId)
      .collection("services");

    for (let batchNum = 0; batchNum < MAX_BATCHES_PER_FACILITY_PER_RUN; batchNum++) {
      const oldServicesSnap = await servicesRef
        .where("updatedAt", "<", cutoff)
        .orderBy("updatedAt", "asc")
        .limit(ARCHIVE_BATCH_SIZE)
        .get();

      if (oldServicesSnap.empty) break;

      const batch = db.batch();
      let archivedCount = 0;

      oldServicesSnap.docs.forEach((doc) => {
        const service = doc.data();
        const totalAmount = service.totalAmount || 0;
        const totalPaid = service.totalPaid || 0;

        // Leave services with an outstanding balance alone.
        if (totalPaid < totalAmount) return;

        const archiveRef = db
          .collection("facilities")
          .doc(facilityId)
          .collection("archived_services")
          .doc(doc.id);

        batch.set(archiveRef, service);
        batch.delete(doc.ref);
        archivedCount++;
      });

      if (archivedCount > 0) {
        await batch.commit();
      }

      if (oldServicesSnap.size < ARCHIVE_BATCH_SIZE) break;
      if (archivedCount === 0) break;
    }
  }

  console.log("Services archive sweep complete.");
});

// ---------------------------------------------------------------------------
// Manage Account: two real, callable actions replacing what were
// previously fake buttons that showed a success message without doing
// anything.
// ---------------------------------------------------------------------------

/**
 * Log Out of All Devices - revokes every existing refresh token for the
 * calling user, forcing every signed-in device (including this one) to
 * re-authenticate. This is the standard Firebase Auth way to implement
 * "sign out everywhere" - there is no per-device session list to
 * selectively clear, so this is the correct real equivalent.
 */
exports.revokeAllSessions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  try {
    await admin.auth().revokeRefreshTokens(context.auth.uid);
    return { success: true };
  } catch (error) {
    console.error("revokeAllSessions error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Could not revoke sessions."
    );
  }
});

/**
 * Wipe All Business Data - permanently deletes every business record for
 * one facility (sales, products, clients, services, transactions, debts,
 * payments, trash, pending payment submissions, and all the
 * archived/daily-summary collections that go with them). Deliberately
 * does NOT touch the facility document itself (name, logo, settings) or
 * the `users` collection (login credentials), matching exactly what the
 * confirmation dialog promises.
 *
 * The subcollection list below was previously missing trash_products,
 * trash_clients, trash_services, trash_sales, and payment_submissions -
 * all real subcollections (confirmed against firestore.rules) that would
 * have silently survived a "wipe everything" action untouched. Fixed
 * here by adding them explicitly, since this function - unlike
 * deleteFacility below - deliberately keeps the facility document alive,
 * so it can't simply recursiveDelete the whole document the way
 * deleteFacility now does.
 *
 * Restricted to admins of that facility - this is irreversible, so it
 * should never be reachable by a regular staff account.
 */
exports.wipeFacilityData = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  const facilityId = data && data.facilityId;
  if (!facilityId || typeof facilityId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "facilityId is required."
    );
  }

  // Confirm the caller is an admin and actually belongs to this facility -
  // mirrors the same check used in Firestore security rules, done here
  // explicitly since this bypasses those rules entirely (Admin SDK).
  const userDoc = await db.collection("users").doc(context.auth.uid).get();
  const userData = userDoc.data();

  if (!userData || userData.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only an admin can wipe business data."
    );
  }

  const facilityIds = userData.facilityIds || [];
  if (!facilityIds.includes(facilityId)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You do not belong to this facility."
    );
  }

  const facilityRef = db.collection("facilities").doc(facilityId);

  const subcollections = [
    "sales",
    "archived_sales",
    "products",
    "clients",
    "services",
    "archived_services",
    "transactions",
    "debts",
    "payments",
    "dailySummaries",
    "dailyCollections",
    "dailyServiceSummaries",
    "dailyTransactionSummaries",
    "activity_logs",
    "trash_products",
    "trash_clients",
    "trash_services",
    "trash_sales",
    "trash_transactions",
    "payment_submissions",
  ];

  for (const sub of subcollections) {
    try {
      await db.recursiveDelete(facilityRef.collection(sub));
    } catch (error) {
      console.error(`Error wiping ${sub} for facility ${facilityId}:`, error);
      // Continue wiping the rest even if one subcollection fails, rather
      // than leaving everything else half-deleted.
    }
  }

  return { success: true };
});

// ---------------------------------------------------------------------------
// Trash auto-purge: deleted Products, Clients, and Services get moved to
// trash_products/trash_clients/trash_services (see the app's provider
// delete methods) instead of being erased immediately, so an accidental
// delete can be restored. This keeps trash from growing forever by
// permanently removing anything sitting there for more than 30 days.
// ---------------------------------------------------------------------------

const TRASH_RETENTION_DAYS = 30;
const TRASH_COLLECTIONS = ["trash_products", "trash_clients", "trash_services", "trash_sales", "trash_transactions"];

exports.purgeOldTrash = onSchedule("every 24 hours", async () => {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - TRASH_RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );

  const facilitiesSnap = await db.collection("facilities").get();

  for (const facilityDoc of facilitiesSnap.docs) {
    const facilityId = facilityDoc.id;

    for (const trashCollection of TRASH_COLLECTIONS) {
      try {
        const oldItemsSnap = await db
          .collection("facilities")
          .doc(facilityId)
          .collection(trashCollection)
          .where("deletedAt", "<", cutoff)
          .limit(300)
          .get();

        if (oldItemsSnap.empty) continue;

        // Trashed products leave their batches subcollection dangling
        // (Firestore doesn't cascade-delete subcollections) - clean that
        // up too when a product is actually purged for good, or it's
        // orphaned data in Firestore forever with nothing pointing to it.
        if (trashCollection === "trash_products") {
          for (const doc of oldItemsSnap.docs) {
            const batchesRef = db
              .collection("facilities")
              .doc(facilityId)
              .collection("products")
              .doc(doc.id)
              .collection("batches");
            await db.recursiveDelete(batchesRef);
          }
        }

        const batch = db.batch();
        oldItemsSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      } catch (error) {
        console.error(`Error purging ${trashCollection} for facility ${facilityId}:`, error);
      }
    }
  }

  console.log("Trash purge sweep complete.");
});

/**
 * Records a once-daily snapshot of each facility's current balances -
 * total product stock value, total outstanding debt, and total client
 * count. Unlike the flow-metric aggregates above (sales, services,
 * transactions - each already has its own daily summary, built from
 * records that get created once and never change), these three are
 * point-in-time balances that get updated in place as debts are paid
 * down or stock moves, not appended as new records the way a sale is -
 * there's no way to reconstruct "what was the outstanding debt last
 * Tuesday" after the fact from the raw collections alone. This is what
 * makes a dashboard trend indicator for these three cards possible at
 * all: without a daily record of what the value actually was, there's
 * nothing to compare today's figure against.
 *
 * Formulas mirror the client-side computations exactly - ProductProvider.
 * totalProductValue ((stockQty + sellableQty) * buyPrice, summed),
 * DebtProvider.totalOutstanding (amountOwed, summed), ClientProvider.
 * clients.length (a plain count) - kept in sync deliberately, since a
 * snapshot computed with a different formula than what's shown live
 * would make the two numbers subtly, silently disagree.
 */
exports.recordDailySnapshots = onSchedule("every 24 hours", async () => {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  const facilitiesSnap = await db.collection("facilities").get();

  for (const facilityDoc of facilitiesSnap.docs) {
    const facilityId = facilityDoc.id;

    try {
      const [productsSnap, debtsSnap, clientsCountSnap] = await Promise.all([
        db.collection("facilities").doc(facilityId).collection("products").get(),
        db.collection("facilities").doc(facilityId).collection("debts").get(),
        db.collection("facilities").doc(facilityId).collection("clients").count().get(),
      ]);

      let totalProductValue = 0;
      productsSnap.docs.forEach((doc) => {
        const d = doc.data();
        const stockQty = Number(d.stockQty) || 0;
        const sellableQty = Number(d.sellableQty) || 0;
        const buyPrice = Number(d.buyPrice) || 0;
        totalProductValue += (stockQty + sellableQty) * buyPrice;
      });

      let totalOutstanding = 0;
      debtsSnap.docs.forEach((doc) => {
        const d = doc.data();
        totalOutstanding += Number(d.amountOwed) || 0;
      });

      const totalClients = clientsCountSnap.data().count;

      await db
        .collection("facilities")
        .doc(facilityId)
        .collection("dailySnapshots")
        .doc(today)
        .set({
          totalProductValue,
          totalOutstanding,
          totalClients,
          recordedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.error(`Error recording daily snapshot for facility ${facilityId}:`, error);
    }
  }

  console.log("Daily snapshot sweep complete.");
});

/**
 * Delete Facility - a Platform Admin action, not a facility-admin one.
 * Deletes every business record for the facility AND the facility
 * document itself, removes the facility's reference from every user who
 * has it (not just the caller - any admin or assistant assigned to this
 * facility), and deletes the facility's logo from Storage if it has one.
 *
 * Now uses a single recursiveDelete on the facility document itself
 * rather than looping through a manually maintained subcollection list -
 * that list previously missed trash_products, trash_clients,
 * trash_services, trash_sales, and payment_submissions (all real
 * subcollections, confirmed against firestore.rules), which would have
 * silently survived this function untouched. recursiveDelete on the
 * whole document closes that gap completely, and stays complete even if
 * a new subcollection is added later and nobody remembers to update a
 * list for it.
 *
 * This is what a manual Firestore deletion can't safely do on its own:
 * a client can delete the facility document, but it can't reach into
 * every other user's document to clean up their reference to it, and it
 * can't recursively delete subcollections without reading and deleting
 * every document one by one. Restricted to Platform Admins - this is
 * irreversible and affects accounts beyond the caller's own, so it's a
 * platform-level action, not something a facility admin should be able
 * to trigger themselves. See deleteOwnFacility below for the
 * facility-admin equivalent, which additionally blocks on assigned
 * assistants - a restriction that doesn't apply here, since a Platform
 * Admin cleaning up a facility isn't blocked by staff still being
 * assigned to it.
 */
exports.deleteFacility = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  const facilityId = data && data.facilityId;
  if (!facilityId || typeof facilityId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "facilityId is required."
    );
  }

  // Only a Platform Admin can do this - checked directly here since
  // this bypasses Firestore rules entirely (Admin SDK), same reasoning
  // as wipeFacilityData's own check above.
  const platformAdminDoc = await db.collection("platform_admins").doc(context.auth.uid).get();
  if (!platformAdminDoc.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only a Platform Admin can delete a facility."
    );
  }

  const facilityRef = db.collection("facilities").doc(facilityId);
  const facilityDoc = await facilityRef.get();
  if (!facilityDoc.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "This facility no longer exists."
    );
  }

  // Everything past this point is wrapped in one try/catch - any
  // unexpected error (a permissions issue, a malformed record, anything
  // not already an HttpsError above) now surfaces its real message to
  // the client instead of falling through to Firebase's generic
  // "internal" error, which hides the actual cause entirely. The real
  // message is also always in the Cloud Functions logs regardless -
  // Firebase Console -> Functions -> Logs, or `firebase functions:log`
  // - but this makes the common case visible without needing to go
  // looking for it.
  try {
    // The facility's logo isn't touched by deleting the Firestore
    // document - cleaned up here explicitly so it doesn't become an
    // orphaned file in Storage. Not every facility has one, so a
    // missing-file error here is expected and fine, not a real failure.
    try {
      await admin.storage().bucket().file(`facility_logos/${facilityId}.png`).delete();
    } catch (storageError) {
      // No logo existed for this facility - nothing to clean up.
    }

    // Remove this facility from every user who has it - not just the
    // caller. An assistant (or another admin) left with a reference to
    // a now-deleted facility is exactly the dangling-reference problem
    // a manual Firestore deletion can't fix on its own.
    const affectedUsers = await db
      .collection("users")
      .where("facilityIds", "array-contains", facilityId)
      .get();

    if (!affectedUsers.empty) {
      const batch = db.batch();
      affectedUsers.forEach((userDoc) => {
        const userData = userDoc.data();
        const remainingFacilities = (userData.facilities || []).filter(
          (f) => f && f.facilityId !== facilityId
        );
        const remainingFacilityIds = (userData.facilityIds || []).filter(
          (id) => id !== facilityId
        );
        batch.update(userDoc.ref, {
          facilities: remainingFacilities,
          facilityIds: remainingFacilityIds,
        });
      });
      await batch.commit();
    }

    // Recursively deletes the facility document AND every subcollection
    // beneath it in one call - replaces the previous manual loop through
    // a hardcoded subcollection list (which missed several real
    // subcollections - see the comment above this function) with
    // something that's inherently complete, not dependent on a list
    // staying accurate over time.
    await admin.firestore().recursiveDelete(facilityRef);

    return { success: true, usersUpdated: affectedUsers.size };
  } catch (error) {
    console.error(`deleteFacility failed for ${facilityId}:`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Could not delete this facility: ${error.message || error}`
    );
  }
});

/**
 * Delete Own Facility - a facility Admin deleting a facility they
 * themselves created, from the View Facilities screen. Distinct from
 * deleteFacility above (which is a Platform Admin action with no
 * assistant restriction) in two ways: restricted to the facility's own
 * creator rather than a Platform Admin, and blocks entirely if any
 * assistant is still assigned - removing someone's access out from under
 * them as a side effect of an unrelated delete isn't something a regular
 * facility Admin should be able to do silently, the way a Platform Admin
 * cleanup action reasonably can.
 *
 * Uses recursiveDelete on the whole facility document, same reasoning as
 * deleteFacility above - inherently complete, not dependent on a
 * manually maintained subcollection list ever falling out of date.
 */
exports.deleteOwnFacility = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  const facilityId = data && data.facilityId;
  if (!facilityId || typeof facilityId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "facilityId is required."
    );
  }

  const callerUid = context.auth.uid;
  const facilityRef = db.collection("facilities").doc(facilityId);
  const facilityDoc = await facilityRef.get();

  if (!facilityDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Facility not found.");
  }

  // Only this facility's own creator can delete it this way - checked
  // here server-side, not just assumed from whatever the client claims.
  const facilityData = facilityDoc.data();
  if (facilityData.createdBy !== callerUid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only this facility's admin can delete it."
    );
  }

  // Re-checked here too, not just in the client's UI - a client-side
  // check alone can always be bypassed by calling this function
  // directly.
  const assistantsSnap = await db
    .collection("users")
    .where("role", "==", "assistant")
    .where("facilityIds", "array-contains", facilityId)
    .limit(1)
    .get();

  if (!assistantsSnap.empty) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Remove or reassign all assistants before deleting this facility."
    );
  }

  try {
    // The logo file in Storage isn't touched by deleting the Firestore
    // document - cleaned up here explicitly so it doesn't become an
    // orphaned file. Not every facility has one, so a missing-file
    // error here is expected and fine, not a real failure.
    try {
      await admin.storage().bucket().file(`facility_logos/${facilityId}.png`).delete();
    } catch (storageError) {
      // No logo existed for this facility - nothing to clean up.
    }

    // Remove this facility from every user who has it - not just the
    // caller. Mirrors deleteFacility above: an assistant left with a
    // reference to a now-deleted facility is exactly the
    // dangling-reference problem a manual client-side update can't
    // reliably fix (assistants aren't in the caller's own account, so
    // the caller updating only themselves would leave every assistant's
    // account still pointing at a facility that's gone).
    const affectedUsers = await db
      .collection("users")
      .where("facilityIds", "array-contains", facilityId)
      .get();

    if (!affectedUsers.empty) {
      const batch = db.batch();
      affectedUsers.forEach((userDoc) => {
        const userData = userDoc.data();
        const remainingFacilities = (userData.facilities || []).filter(
          (f) => f && f.facilityId !== facilityId
        );
        const remainingFacilityIds = (userData.facilityIds || []).filter(
          (id) => id !== facilityId
        );
        batch.update(userDoc.ref, {
          facilities: remainingFacilities,
          facilityIds: remainingFacilityIds,
        });
      });
      await batch.commit();
    }

    // Recursively deletes the facility document and every subcollection
    // beneath it - products (and each product's own batches
    // sub-subcollection), sales, clients, debts, payments, activity
    // logs, every precomputed summary collection, trash, pending
    // payment submissions, all of it - in one call, inherently
    // complete rather than dependent on a hardcoded list.
    await admin.firestore().recursiveDelete(facilityRef);

    return { success: true, usersUpdated: affectedUsers.size };
  } catch (error) {
    console.error(`deleteOwnFacility failed for ${facilityId}:`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Could not delete this facility: ${error.message || error}`
    );
  }
});

/**
 * Remove Assistant - a facility Admin removing an assistant from their
 * facility. Deletes both the Firestore users/{uid} document AND the
 * actual Firebase Auth account - a client can only ever delete its own
 * signed-in Auth account, never someone else's, so without this
 * server-side step the assistant's email/password stayed valid in Auth
 * forever even after their Firestore profile was gone. That silently
 * broke two things: logging in succeeded at the Auth layer but found no
 * profile to route from, and the same email couldn't be used to
 * register anywhere else either, since Firebase Auth enforces unique
 * emails project-wide, not per-facility.
 */
exports.removeAssistant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  const assistantUid = data && data.assistantUid;
  if (!assistantUid || typeof assistantUid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "assistantUid is required."
    );
  }

  const callerUid = context.auth.uid;

  const assistantDoc = await db.collection("users").doc(assistantUid).get();

  if (!assistantDoc.exists) {
    // Firestore doc already gone - still attempt the Auth cleanup in
    // case that's the part that's actually left dangling (e.g. a
    // previous removal that used the old, direct-delete client path,
    // from before this function existed). Nothing left to check
    // permissions against at that point, so this is deliberately
    // best-effort rather than blocking.
    try {
      await admin.auth().deleteUser(assistantUid);
    } catch (error) {
      // Already gone from Auth too, or never existed - either way,
      // there's genuinely nothing left to remove.
    }
    return { success: true };
  }

  const assistantData = assistantDoc.data();
  if (assistantData.role !== "assistant") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This account is not an assistant."
    );
  }

  // Caller must be an admin of a facility this assistant actually
  // belongs to - checked here server-side, not just assumed from the
  // client, since deleting a Firebase Auth account is irreversible.
  const callerDoc = await db.collection("users").doc(callerUid).get();
  const callerData = callerDoc.data();
  if (!callerData || callerData.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only an admin can remove an assistant."
    );
  }

  const callerFacilityIds = callerData.facilityIds || [];
  const assistantFacilityIds = assistantData.facilityIds || [];
  const sharesAFacility = assistantFacilityIds.some((id) =>
    callerFacilityIds.includes(id)
  );
  if (!sharesAFacility) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "This assistant is not assigned to any facility you administer."
    );
  }

  try {
    await db.collection("users").doc(assistantUid).delete();
  } catch (error) {
    console.error(
      `removeAssistant: failed to delete Firestore doc for ${assistantUid}:`,
      error
    );
    throw new functions.https.HttpsError(
      "internal",
      `Could not remove this assistant's profile: ${error.message || error}`
    );
  }

  try {
    await admin.auth().deleteUser(assistantUid);
  } catch (error) {
    // The Firestore profile is already gone at this point - the part
    // that actually caused the silent-login-failure and
    // can't-re-register symptoms. A failure here is logged but doesn't
    // roll back or fail the whole operation, since the assistant's
    // access to this facility is already fully revoked either way.
    console.error(
      `removeAssistant: failed to delete Auth account for ${assistantUid}:`,
      error
    );
  }

  return { success: true };
});

/**
 * Remove User (Platform Admin) - permanently deletes a deactivated
 * user's account (Firestore profile + Firebase Auth), platform-wide -
 * not scoped to sharing a facility with the caller, since a Platform
 * Admin oversees every facility, not just some of them. Deliberately
 * restricted to accounts already status === 'deactivated', mirroring
 * the same safety gate already used in the client UI for facility
 * Admins removing their own assistants - even a fully trusted Platform
 * Admin shouldn't be able to permanently delete a currently-active
 * account in one click without deactivating it first. A Platform
 * Admin's own account can never be removed this way, regardless of
 * status, for the same reason it can never be deactivated at all.
 */
exports.platformRemoveUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to do this."
    );
  }

  const targetUid = data && data.userId;
  if (!targetUid || typeof targetUid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId is required."
    );
  }

  const callerUid = context.auth.uid;
  const callerPlatformAdminDoc = await db
    .collection("platform_admins")
    .doc(callerUid)
    .get();
  if (!callerPlatformAdminDoc.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only a Platform Admin can remove a user this way."
    );
  }

  const targetDoc = await db.collection("users").doc(targetUid).get();

  if (!targetDoc.exists) {
    // Firestore doc already gone - still attempt the Auth cleanup in
    // case that's the part left dangling, same reasoning as
    // removeAssistant above.
    try {
      await admin.auth().deleteUser(targetUid);
    } catch (error) {
      // Already gone from Auth too, or never existed.
    }
    return { success: true };
  }

  const targetIsPlatformAdmin = await db
    .collection("platform_admins")
    .doc(targetUid)
    .get();
  if (targetIsPlatformAdmin.exists) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "A Platform Admin's own account can't be removed this way."
    );
  }

  const targetData = targetDoc.data();
  const targetStatus = (targetData.status || "active").toString();
  if (targetStatus !== "deactivated") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Deactivate this account first before removing it."
    );
  }

  try {
    await db.collection("users").doc(targetUid).delete();
  } catch (error) {
    console.error(
      `platformRemoveUser: failed to delete Firestore doc for ${targetUid}:`,
      error
    );
    throw new functions.https.HttpsError(
      "internal",
      `Could not remove this user's profile: ${error.message || error}`
    );
  }

  try {
    await admin.auth().deleteUser(targetUid);
  } catch (error) {
    // The Firestore profile is already gone at this point - a failure
    // here is logged but doesn't roll back or fail the whole
    // operation, since the account's access is already fully revoked
    // either way.
    console.error(
      `platformRemoveUser: failed to delete Auth account for ${targetUid}:`,
      error
    );
  }

  return { success: true };
});

// ---------------------------------------------------------------------------
// Notification triggers: each of these fires the moment a specific kind of
// record is created, and writes a single, real `notifications` document -
// the piece the Dashboard bell dropdown and the full Notifications screen
// both read from. Every one of these is ephemeral (no expiresAt) rather
// than persistent, since each represents a one-time event that happened
// once, not an ongoing condition like a promotion - it should simply
// disappear once someone's actually seen it, matching how
// FacilityNotification.isCurrentlyVisible already treats ephemeral entries.
// ---------------------------------------------------------------------------

function formatTsh(amount) {
  return Math.round(amount).toLocaleString("en-US");
}

exports.notifyOnPaymentReceived = onDocumentCreated(
  "facilities/{facilityId}/payments/{paymentId}",
  async (event) => {
    const { facilityId, paymentId } = event.params;
    const payment = event.data?.data();

    if (!payment || typeof payment.amount !== "number") return;

    // clientName isn't stored on the payment document itself (see
    // Payment.fromFirestore in the Flutter app, which looks it up
    // separately at read time) - so it's looked up here too, rather
    // than assumed. A payment can also exist with no clientId at all
    // (e.g. a walk-in sale paid on the spot), which is a valid case,
    // not an error - falls back to a generic label instead of skipping
    // the notification entirely.
    let clientName = "a client";
    if (payment.clientId) {
      const clientSnap = await db
        .collection("facilities")
        .doc(facilityId)
        .collection("clients")
        .doc(payment.clientId)
        .get();
      if (clientSnap.exists && clientSnap.data().name) {
        clientName = clientSnap.data().name;
      }
    }

    await db
      .collection("facilities")
      .doc(facilityId)
      .collection("notifications")
      .add({
        type: "paymentReceived",
        title: "Payment Received",
        message: `From ${clientName} · Tsh ${formatTsh(payment.amount)}`,
        relatedEntityType: "payment",
        relatedEntityId: paymentId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
);

exports.notifyOnServiceRecorded = onDocumentCreated(
  "facilities/{facilityId}/services/{serviceId}",
  async (event) => {
    const { facilityId, serviceId } = event.params;
    const service = event.data?.data();

    if (!service) return;

    const clientName = service.clientName || "a client";
    const serviceName = service.name || "Service";

    await db
      .collection("facilities")
      .doc(facilityId)
      .collection("notifications")
      .add({
        type: "serviceRecorded",
        title: "Service Recorded",
        message: `Client: ${clientName} · ${serviceName}`,
        relatedEntityType: "service",
        relatedEntityId: serviceId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
);

exports.notifyOnNewClient = onDocumentCreated(
  "facilities/{facilityId}/clients/{clientId}",
  async (event) => {
    const { facilityId, clientId } = event.params;
    const client = event.data?.data();

    if (!client || !client.name) return;

    const phonePart = client.phone ? ` · ${client.phone}` : "";

    await db
      .collection("facilities")
      .doc(facilityId)
      .collection("notifications")
      .add({
        type: "newClient",
        title: "New Client Added",
        message: `${client.name}${phonePart}`,
        relatedEntityType: "client",
        relatedEntityId: clientId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
);

// ---------------------------------------------------------------------------
// Product stock-status change notifications: mirrors
// Product.primaryStatus / Product.hasRestockShelfAlert from the Flutter app
// (lib/models/product.dart) in JavaScript, since Cloud Functions can't call
// Dart code directly. IMPORTANT: if the threshold logic in product.dart
// ever changes, this must be updated to match, or the two will silently
// drift apart - there is no shared source of truth between the two
// languages here.
//
// Fires only on a genuine transition into a worse status (or newly needing
// a shelf restock), never on every product write - editing a product's
// name or price, for instance, leaves its status unchanged and produces
// no notification. Also never fires on improvement (e.g. restocked back
// to "in stock" isn't an alert).
// ---------------------------------------------------------------------------

const DEFAULT_SHELF_MIN_LEVEL = 3;
const DEFAULT_LOW_STOCK_THRESHOLD = 5;
const DEFAULT_REORDER_POINT = 10;

function pickEffectiveThreshold(explicitVal, computedVal, defaultVal) {
  if (typeof explicitVal === "number") return explicitVal;
  if (typeof computedVal === "number") return computedVal;
  return defaultVal;
}

function computeProductStatus(product) {
  const stockQty = product.stockQty || 0;
  const sellableQty = product.sellableQty || 0;
  const totalStock = stockQty + sellableQty;

  if (totalStock === 0) {
    return product.hasEverHadStock ? "criticalStock" : "neverStocked";
  }

  const lowStockThreshold = pickEffectiveThreshold(
    product.lowStockThreshold,
    product.computedLowStockThreshold,
    DEFAULT_LOW_STOCK_THRESHOLD
  );
  if (totalStock <= lowStockThreshold) return "lowStock";

  const reorderPoint = pickEffectiveThreshold(
    product.reorderPoint,
    product.computedReorderPoint,
    DEFAULT_REORDER_POINT
  );
  if (totalStock <= reorderPoint) return "reorderSoon";

  return "inStock";
}

function computeHasRestockShelfAlert(product) {
  const shelfMinLevel = pickEffectiveThreshold(
    product.shelfMinLevel,
    product.computedShelfMinLevel,
    DEFAULT_SHELF_MIN_LEVEL
  );
  const sellableQty = product.sellableQty || 0;
  const stockQty = product.stockQty || 0;
  const deficit = shelfMinLevel - sellableQty;
  if (deficit <= 0) return false;
  return stockQty >= deficit;
}

const STATUS_NOTIFICATION_INFO = {
  criticalStock: { type: "criticalStock", title: "Critical - Out of Stock Everywhere" },
  lowStock: { type: "lowStock", title: "Low Stock" },
  reorderSoon: { type: "reorderSoon", title: "Reorder Soon" },
};

exports.notifyOnProductStatusChange = onDocumentUpdated(
  "facilities/{facilityId}/products/{productId}",
  async (event) => {
    const { facilityId, productId } = event.params;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const beforeStatus = computeProductStatus(before);
    const afterStatus = computeProductStatus(after);
    const beforeRestockAlert = computeHasRestockShelfAlert(before);
    const afterRestockAlert = computeHasRestockShelfAlert(after);

    const productName = after.name || "A product";
    const writes = [];

    if (afterStatus !== beforeStatus && STATUS_NOTIFICATION_INFO[afterStatus]) {
      const info = STATUS_NOTIFICATION_INFO[afterStatus];
      writes.push({
        type: info.type,
        title: info.title,
        message: `${productName} - Shelf: ${after.sellableQty || 0} · Warehouse: ${after.stockQty || 0}`,
        relatedEntityType: "product",
        relatedEntityId: productId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // A separate, non-exclusive signal from the primary status above - a
    // product can newly need shelf restocking without its overall status
    // changing at all (e.g. staying "in stock" the whole time).
    if (!beforeRestockAlert && afterRestockAlert) {
      writes.push({
        type: "restockShelf",
        title: "Restock Shelf",
        message: `${productName} - ${after.sellableQty || 0} on shelf · ${after.stockQty || 0} in warehouse`,
        relatedEntityType: "product",
        relatedEntityId: productId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (writes.length === 0) return;

    const notificationsRef = db
      .collection("facilities")
      .doc(facilityId)
      .collection("notifications");

    await Promise.all(writes.map((n) => notificationsRef.add(n)));
  }
);
