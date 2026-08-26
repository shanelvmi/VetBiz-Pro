import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../constants/subscription_plans.dart';

/// Platform-admin-only screen (you, the SaaS operator) - reviews payment
/// submissions from every shop across the whole system and approves or
/// rejects them, extending each facility's subscription on approval.
///
/// This is the manual review step. When automated push-payment support
/// is added later (via an aggregator), it should write the same
/// `subscriptionPlan`/`subscriptionExpiresAt` fields on the facility
/// document that approval does here - this screen (and everything that
/// reads subscription status) doesn't need to change at all.
class SubscriptionAdminReviewScreen extends StatelessWidget {
  const SubscriptionAdminReviewScreen({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);

  Future<bool> _isPlatformAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('platform_admins')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  Future<void> _approve(BuildContext context, QueryDocumentSnapshot submissionDoc) async {
    final data = submissionDoc.data() as Map<String, dynamic>;
    final facilityId = data['facilityId'] as String?;
    final planId = data['planId'] as String?;
    final plan = planId != null ? await loadPlanById(planId) : null;

    if (facilityId == null || plan == null) return;

    final facilityRef = FirebaseFirestore.instance.collection('facilities').doc(facilityId);
    final facilitySnap = await facilityRef.get();
    final currentExpires = facilitySnap.data()?['subscriptionExpiresAt'];
    final currentExpiresDate = currentExpires is Timestamp ? currentExpires.toDate() : null;

    final now = DateTime.now();
    // Renewing before expiry extends from the existing expiry date (no
    // paid time lost); renewing after expiry (or for the first time)
    // starts the new period from today.
    final base = (currentExpiresDate != null && currentExpiresDate.isAfter(now))
        ? currentExpiresDate
        : now;
    final newExpiry = base.add(Duration(days: plan.durationDays));

    final admin = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      facilityRef,
      {
        'subscriptionPlan': plan.id,
        'subscriptionExpiresAt': Timestamp.fromDate(newExpiry),
        'lastPaymentAt': FieldValue.serverTimestamp(),
        'lastPaymentAmount': (data['amount'] as num?)?.toDouble() ?? plan.priceTsh,
      },
      SetOptions(merge: true),
    );

    batch.update(submissionDoc.reference, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.email ?? admin?.uid ?? 'Unknown',
    });

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved - subscription now runs until ${DateFormat('dd MMM yyyy').format(newExpiry)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _reject(BuildContext context, QueryDocumentSnapshot submissionDoc) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Submission'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final admin = FirebaseAuth.instance.currentUser;
    await submissionDoc.reference.update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.email ?? admin?.uid ?? 'Unknown',
      'reviewNote': reasonController.text.trim(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission rejected'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Review'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<bool>(
        future: _isPlatformAdmin(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (adminSnapshot.data != true) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You do not have access to this screen.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('payment_submissions')
                .where('status', isEqualTo: 'pending')
                .orderBy('submittedAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // A real query failure (e.g. a missing Firestore index for
              // this collection-group query) used to look identical to
              // "no submissions" - now it shows the actual error instead.
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load submissions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        '${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No pending submissions', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final submittedAt = data['submittedAt'] is Timestamp
                      ? (data['submittedAt'] as Timestamp).toDate()
                      : null;
                  final proofUrl = data['proofImageUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['facilityName'] ?? 'Unknown facility',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text('${data['planLabel'] ?? ''} - Tsh ${data['amount'] ?? 0}'),
                          Text('${data['method'] ?? ''} • Ref: ${data['reference'] ?? ''}'),
                          if (submittedAt != null)
                            Text(
                              'Submitted ${DateFormat('dd MMM yyyy, HH:mm').format(submittedAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          if (proofUrl != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: Image.network(
                                    proofUrl,
                                    errorBuilder: (context, error, stackTrace) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('Could not load image.'),
                                    ),
                                  ),
                                ),
                              ),
                              child: Image.network(
                                proofUrl,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 120,
                                  alignment: Alignment.center,
                                  color: Colors.grey[200],
                                  child: const Text('Proof image could not be loaded'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _reject(context, doc),
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _approve(context, doc),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
