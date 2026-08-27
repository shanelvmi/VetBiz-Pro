import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../constants/subscription_plans.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/hover_elevate_card.dart';

/// Embeddable version of the pending-submissions review list - same
/// logic as the original standalone Subscription Review screen, just
/// without its own Scaffold/AppBar so it can live as one tab inside the
/// Platform Admin home instead of a separate menu entry.
class SubscriptionRequestsTab extends StatelessWidget {
  const SubscriptionRequestsTab({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);

  // How long a request has been waiting, at a glance - "2 days ago"
  // reads faster than a full date/time when scanning a list of
  // several pending requests to see which is oldest.
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  // Same reasoning as the relative-time label, but as a color on the
  // card's own icon - a request pending for days is visually distinct
  // from one submitted minutes ago, without needing to read the text
  // to notice it.
  Color _urgencyColor(DateTime? submittedAt) {
    if (submittedAt == null) return Colors.grey;
    final days = DateTime.now().difference(submittedAt).inDays;
    if (days >= 3) return Colors.redAccent;
    if (days >= 1) return Colors.orange;
    return Colors.green;
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

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
            final submittedAt = data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : null;
            final proofUrl = data['proofImageUrl'] as String?;

            final urgencyColor = _urgencyColor(submittedAt);

            return HoverElevateCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: urgencyColor.withValues(alpha: 0.15),
                          child: Icon(Icons.storefront_outlined, color: urgencyColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['facilityName'] ?? 'Unknown facility',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (submittedAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: urgencyColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _relativeTime(submittedAt),
                              style: TextStyle(fontSize: 11, color: urgencyColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.sell_outlined, size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          '${data['planLabel'] ?? ''} · Tsh ${data['amount'] ?? 0}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                      ],
                    ),
                    if (data['promotionLabel'] != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${data['promotionLabel']} · ${(data['discountPercent'] as num?)?.toStringAsFixed(0) ?? ''}% off applied',
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${data['method'] ?? ''} · Ref: ${data['reference'] ?? ''}',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (submittedAt != null) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(submittedAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                    if (proofUrl != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
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
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                                child: Image.network(
                                  proofUrl,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    color: Colors.grey[200],
                                    child: const Text('Proof image could not be loaded'),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
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
            ),
          ),
        );
      },
    );
  }
}
