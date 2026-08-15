import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../constants/subscription_plans.dart';
import '../../widgets/firestore_error_view.dart';

/// Embeddable version of the pending-submissions review list - same
/// logic as the original standalone Subscription Review screen, just
/// without its own Scaffold/AppBar so it can live as one tab inside the
/// Platform Admin home instead of a separate menu entry.
class SubscriptionRequestsTab extends StatelessWidget {
  const SubscriptionRequestsTab({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);

  Future<void> _approve(BuildContext context, QueryDocumentSnapshot submissionDoc) async {
    final data = submissionDoc.data() as Map<String, dynamic>;
    final facilityId = data['facilityId'] as String?;
    final planId = data['planId'] as String?;
    final plan = planId != null ? planById(planId) : null;

    if (facilityId == null || plan == null) return;

    final facilityRef = FirebaseFirestore.instance.collection('facilities').doc(facilityId);
    final facilitySnap = await facilityRef.get();
    final currentExpires = facilitySnap.data()?['subscriptionExpiresAt'];
    final currentExpiresDate = currentExpires is Timestamp ? currentExpires.toDate() : null;

    final now = DateTime.now();
    final base = (currentExpiresDate != null && currentExpiresDate.isAfter(now)) ? currentExpiresDate : now;
    final newExpiry = base.add(Duration(days: plan.durationDays));

    final admin = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      facilityRef,
      {
        'subscriptionPlan': plan.id,
        'subscriptionExpiresAt': Timestamp.fromDate(newExpiry),
        'lastPaymentAt': FieldValue.serverTimestamp(),
        'lastPaymentAmount': plan.priceTsh,
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

        if (snapshot.hasError) {
          return FirestoreErrorView(error: snapshot.error);
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
            final submittedAt = data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : null;
            final proofUrl = data['proofImageUrl'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['facilityName'] ?? 'Unknown facility',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${data['planLabel'] ?? ''} - Tsh ${data['amount'] ?? 0}'),
                    Text('${data['method'] ?? ''} • Ref: ${data['reference'] ?? ''}'),
                    if (submittedAt != null)
                      Text('Submitted ${DateFormat('dd MMM yyyy, HH:mm').format(submittedAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                              if (states.contains(WidgetState.hovered)) return const Color(0xFFFFB200);
                              return primaryColor;
                            }),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
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
  }
}
