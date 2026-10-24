import 'package:flutter/material.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../constants/subscription_plans.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/hover_elevate_card.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/payment_submission_status.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

/// Embeddable version of the subscription submissions review list -
/// same logic as the original standalone Subscription Review screen,
/// just without its own Scaffold/AppBar so it can live as one tab
/// inside the Platform Admin home instead of a separate menu entry.
///
/// Two views, toggled at the top: Pending (the original, unchanged
/// review queue) and Attended (already-approved/rejected submissions,
/// scoped to a recent period) - previously, once a submission was
/// approved or rejected it simply vanished with no way to look back
/// at it, including losing sight of whatever rejection reason had
/// been written for it.
class SubscriptionRequestsTab extends StatefulWidget {
  /// Null: the app's own Firestore. Tests pass an in-memory one (SUBS-1).
  final FirebaseFirestore? firestore;

  const SubscriptionRequestsTab({super.key, this.firestore});

  @override
  State<SubscriptionRequestsTab> createState() => _SubscriptionRequestsTabState();
}

class _SubscriptionRequestsTabState extends State<SubscriptionRequestsTab> {
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  bool _showAttended = false;
  int _attendedDays = 30;

  // How long a request has been waiting, at a glance - "2 days ago"
  // reads faster than a full date/time when scanning a list of
  // several pending requests to see which is oldest.
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppDateFormat.dateShort.format(dt);
  }

  // Same reasoning as the relative-time label, but as a color on the
  // card's own icon - a request pending for days is visually distinct
  // from one submitted minutes ago, without needing to read the text
  // to notice it.
  Color _urgencyColor(DateTime? submittedAt) {
    if (submittedAt == null) return context.colors.textHint;
    final days = DateTime.now().difference(submittedAt).inDays;
    if (days >= 3) return context.colors.dangerAccent;
    if (days >= 1) return context.colors.warning;
    return context.colors.success;
  }

  Future<void> _approve(BuildContext context, QueryDocumentSnapshot submissionDoc) async {
    final data = submissionDoc.data() as Map<String, dynamic>;
    final facilityId = data[Fields.facilityId] as String?;
    final planId = data['planId'] as String?;
    final plan = planId != null ? await loadPlanById(planId) : null;

    if (facilityId == null || plan == null) return;

    final facilityRef = _db.collection(Collections.facilities).doc(facilityId);
    final facilitySnap = await facilityRef.get();
    final currentExpires = facilitySnap.data()?['subscriptionExpiresAt'];
    final currentExpiresDate = currentExpires is Timestamp ? currentExpires.toDate() : null;

    final now = DateTime.now();
    final base = (currentExpiresDate != null && currentExpiresDate.isAfter(now)) ? currentExpiresDate : now;
    final newExpiryDate = base.add(Duration(days: plan.durationDays));
    // Always the end of that day, not the exact time-of-day the
    // payment happened to be approved at - gives the full last day of
    // access rather than cutting off mid-day at an arbitrary moment.
    final newExpiry =
        DateTime(newExpiryDate.year, newExpiryDate.month, newExpiryDate.day, 23, 59, 59);

    final admin = FirebaseAuth.instance.currentUser;
    final batch = _db.batch();

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
      Fields.status: PaymentSubmissionStatus.approved.key,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.email ?? admin?.uid ?? 'Unknown',
    });

    await batch.commit();

    AppFeedback.success('Approved - subscription now runs until ${AppDateFormat.date.format(newExpiry)}');
  }

  Future<void> _reject(BuildContext context, QueryDocumentSnapshot submissionDoc) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Submission'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: reasonController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final admin = FirebaseAuth.instance.currentUser;
    final data = submissionDoc.data() as Map<String, dynamic>;
    final facilityId = data[Fields.facilityId] as String?;
    final reason = reasonController.text.trim();

    await submissionDoc.reference.update({
      Fields.status: PaymentSubmissionStatus.rejected.key,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.email ?? admin?.uid ?? 'Unknown',
      'reviewNote': reason,
    });

    if (facilityId != null) {
      await _db
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.notifications)
          .add({
        'type': 'subscription_rejected',
        'title': 'Subscription Payment Rejected',
        'message': reason.isNotEmpty
            ? reason
            : 'Your recent subscription payment submission was rejected. Contact support for details.',
        Fields.createdAt: FieldValue.serverTimestamp(),
      });
    }

    // Was a red bar, but the reject succeeded: a success message (the
    // action the admin chose happened), not an error.
    AppFeedback.success('Submission rejected');
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, AppSpacing.s4),
      child: Row(
        children: [
          _ViewToggleChip(
            label: 'Pending',
            selected: !_showAttended,
            onTap: () => setState(() => _showAttended = false),
          ),
          const SizedBox(width: AppSpacing.s8),
          _ViewToggleChip(
            label: 'Attended',
            selected: _showAttended,
            onTap: () => setState(() => _showAttended = true),
          ),
          if (_showAttended) ...[
            const Spacer(),
            DropdownButton<int>(
              value: _attendedDays,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                DropdownMenuItem(value: 90, child: Text('Last 90 days')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _attendedDays = value);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToggleRow(),
        Expanded(
          child: _showAttended ? _buildAttendedList() : _buildPendingList(),
        ),
      ],
    );
  }

  Widget _buildPendingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collectionGroup(Collections.paymentSubmissions)
          .where(Fields.status, isEqualTo: PaymentSubmissionStatus.pending.key)
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
                Icon(Icons.check_circle_outline, size: AppIconSize.i56, color: context.colors.textDisabled),
                const SizedBox(height: AppSpacing.s12),
                Text('No pending submissions', style: TextStyle(color: context.colors.textMuted)),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.s12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final submittedAt =
                    data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : null;
                final proofUrl = data['proofImageUrl'] as String?;

                final urgencyColor = _urgencyColor(submittedAt);

                return HoverElevateCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: urgencyColor.withValues(alpha: AppAlpha.a15),
                              child: Icon(Icons.storefront_outlined, color: urgencyColor, size: AppIconSize.i20),
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                              child: Text(
                                data['facilityName'] ?? 'Unknown facility',
                                style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (submittedAt != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withValues(alpha: AppAlpha.a10),
                                  borderRadius: BorderRadius.circular(AppRadius.r10),
                                ),
                                child: Text(
                                  _relativeTime(submittedAt),
                                  style: TextStyle(fontSize: AppFontSize.f11, color: urgencyColor, fontWeight: AppFontWeight.semibold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        Row(
                          children: [
                            Icon(Icons.sell_outlined, size: AppIconSize.i16, color: context.colors.primary),
                            const SizedBox(width: AppSpacing.s6),
                            Text(
                              '${data['planLabel'] ?? ''} · ${Money.formatStored(data['amount'] ?? 0)}',
                              style: TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold, color: context.colors.primary),
                            ),
                          ],
                        ),
                        if (data['promotionLabel'] != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: context.colors.success.withValues(alpha: AppAlpha.a10),
                              borderRadius: BorderRadius.circular(AppRadius.r8),
                            ),
                            child: Text(
                              '${data['promotionLabel']} · ${(data['discountPercent'] as num?)?.toStringAsFixed(0) ?? ''}% off applied',
                              style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.success, fontWeight: AppFontWeight.semibold),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: AppIconSize.i16, color: context.colors.textMuted),
                            const SizedBox(width: AppSpacing.s6),
                            Expanded(
                              child: Text(
                                '${data['method'] ?? ''} · Ref: ${data['reference'] ?? ''}',
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (submittedAt != null) ...[
                          const SizedBox(height: AppSpacing.s2),
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.s22),
                            child: Text(
                              AppDateFormat.dateTime24.format(submittedAt),
                              style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint),
                            ),
                          ),
                        ],
                        if (proofUrl != null) ...[
                          const SizedBox(height: AppSpacing.s10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: Image.network(
                                        proofUrl,
                                        errorBuilder: (context, error, stackTrace) => const Padding(
                                          padding: EdgeInsets.all(AppSpacing.s24),
                                          child: Text('Could not load image.'),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
                                    child: Image.network(
                                      proofUrl,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 120,
                                        alignment: Alignment.center,
                                        color: context.colors.divider,
                                        child: const Text('Proof image could not be loaded'),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.s4),
                                    decoration: BoxDecoration(
                                      color: context.colors.scrim.withValues(alpha: AppAlpha.a50),
                                      borderRadius: BorderRadius.circular(AppRadius.r6),
                                    ),
                                    child: Icon(Icons.zoom_in, size: AppIconSize.i16, color: context.colors.onPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _reject(context, doc),
                              style: TextButton.styleFrom(foregroundColor: context.colors.dangerAccent),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            ElevatedButton(
                              onPressed: () => _approve(context, doc),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                                  return context.colors.primary;
                                }),
                                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
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

  /// Already-approved/rejected submissions, scoped to a recent window
  /// (7/30/90 days, picked above) rather than every one ever made -
  /// this is a look-back/audit view, not a growing archive someone
  /// needs to page through.
  Widget _buildAttendedList() {
    final since = DateTime.now().subtract(Duration(days: _attendedDays));

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collectionGroup(Collections.paymentSubmissions)
          .where(Fields.status, whereIn: [PaymentSubmissionStatus.approved.key, PaymentSubmissionStatus.rejected.key])
          .where('reviewedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('reviewedAt', descending: true)
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
                Icon(Icons.inbox_outlined, size: AppIconSize.i56, color: context.colors.textDisabled),
                const SizedBox(height: AppSpacing.s12),
                Text('No attended submissions in this period.', style: TextStyle(color: context.colors.textMuted)),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.s12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isApproved = data[Fields.status] == PaymentSubmissionStatus.approved.key;
                final statusColor = isApproved ? context.colors.success : context.colors.dangerAccent;
                final reviewedAt =
                    data['reviewedAt'] is Timestamp ? (data['reviewedAt'] as Timestamp).toDate() : null;
                final reviewNote = (data['reviewNote'] as String?)?.trim();

                return HoverElevateCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withValues(alpha: AppAlpha.a15),
                              child: Icon(
                                isApproved ? Icons.check : Icons.close,
                                color: statusColor,
                                size: AppIconSize.i20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                              child: Text(
                                data['facilityName'] ?? 'Unknown facility',
                                style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: AppAlpha.a10),
                                borderRadius: BorderRadius.circular(AppRadius.r10),
                              ),
                              child: Text(
                                isApproved ? 'Approved' : 'Rejected',
                                style: TextStyle(fontSize: AppFontSize.f11, color: statusColor, fontWeight: AppFontWeight.semibold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s10),
                        Row(
                          children: [
                            Icon(Icons.sell_outlined, size: AppIconSize.i16, color: context.colors.primary),
                            const SizedBox(width: AppSpacing.s6),
                            Text(
                              '${data['planLabel'] ?? ''} · ${Money.formatStored(data['amount'] ?? 0)}',
                              style: TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold, color: context.colors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: AppIconSize.i16, color: context.colors.textMuted),
                            const SizedBox(width: AppSpacing.s6),
                            Expanded(
                              child: Text(
                                'By ${data['reviewedBy'] ?? 'Unknown'}'
                                '${reviewedAt != null ? ' · ${AppDateFormat.dateTime24.format(reviewedAt)}' : ''}',
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isApproved && reviewNote != null && reviewNote.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.s10),
                            decoration: BoxDecoration(
                              color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a05),
                              borderRadius: BorderRadius.circular(AppRadius.r8),
                              border: Border.all(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason for rejection',
                                  style: TextStyle(fontSize: AppFontSize.f11, fontWeight: AppFontWeight.bold, color: context.colors.dangerLabel),
                                ),
                                const SizedBox(height: AppSpacing.s3),
                                Text(reviewNote, style: const TextStyle(fontSize: AppFontSize.f13)),
                              ],
                            ),
                          ),
                        ],
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

class _ViewToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s6),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: AppAlpha.a10) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r20),
          border: Border.all(color: selected ? context.colors.primary : context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.colors.primary : context.colors.textSoft,
            fontSize: AppFontSize.f12_5,
            fontWeight: selected ? AppFontWeight.semibold : AppFontWeight.medium,
          ),
        ),
      ),
    );
  }
}
