const functions = require("firebase-functions/v1");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
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
 * payments, and all the archived/daily-summary collections that go with
 * them). Deliberately does NOT touch the facility document itself (name,
 * logo, settings) or the `users` collection (login credentials), matching
 * exactly what the confirmation dialog promises.
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
const TRASH_COLLECTIONS = ["trash_products", "trash_clients", "trash_services", "trash_sales"];

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
 * Delete Facility - a Platform Admin action, not a facility-admin one.
 * Wipes every business record for the facility (same subcollections as
 * wipeFacilityData), removes the facility's reference from every user
 * who has it (not just the caller - any admin or assistant assigned to
 * this facility), then deletes the facility document itself.
 *
 * This is what a manual Firestore deletion can't safely do on its own:
 * a client can delete the facility document, but it can't reach into
 * every other user's document to clean up their reference to it, and it
 * can't recursively delete subcollections without reading and deleting
 * every document one by one. Restricted to Platform Admins - this is
 * irreversible and affects accounts beyond the caller's own, so it's a
 * platform-level action, not something a facility admin should be able
 * to trigger themselves.
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
    // Same subcollection list as wipeFacilityData - kept identical
    // deliberately, so this never quietly diverges from what that
    // function already knows how to clean up.
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
    ];

    for (const sub of subcollections) {
      try {
        await db.recursiveDelete(facilityRef.collection(sub));
      } catch (error) {
        console.error(`Error deleting ${sub} for facility ${facilityId}:`, error);
        // Continue deleting the rest rather than leaving everything else
        // half-cleaned because one subcollection had trouble.
      }
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

    await facilityRef.delete();

    return { success: true, usersUpdated: affectedUsers.size };
  } catch (error) {
    console.error(`deleteFacility failed for ${facilityId}:`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Could not delete this facility: ${error.message || error}`
    );
  }
});
