import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/subscription_status_utils.dart';
import '../../widgets/firestore_error_view.dart';

/// A snapshot of the whole business - how many facilities, in what state, and
/// how much has actually been collected this month. Reads every facility
/// directly, which is fine while you have a manageable number of facilities;
/// worth revisiting (e.g. precomputed via a Cloud Function, same pattern
/// as dailySummaries) if this ever grows into the hundreds.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  Future<Map<String, dynamic>> _loadStats() async {
    final facilitiesSnap = await FirebaseFirestore.instance.collection('facilities').get();

    int trial = 0, active = 0, grace = 0, locked = 0;
    for (final doc in facilitiesSnap.docs) {
      final expiresAtField = doc.data()['subscriptionExpiresAt'];
      final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
      switch (computeSubscriptionStatus(expiresAt)) {
        case SubscriptionStatusKind.trial:
          trial++;
          break;
        case SubscriptionStatusKind.active:
          active++;
          break;
        case SubscriptionStatusKind.grace:
          grace++;
          break;
        case SubscriptionStatusKind.locked:
          locked++;
          break;
      }
    }

    // Revenue actually collected this month - summed from approved
    // subscription payments across every facility (a collection-group read,
    // same access already granted for the Requests tab).
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final approvedSnap = await FirebaseFirestore.instance
        .collectionGroup('payment_submissions')
        .where('status', isEqualTo: 'approved')
        .get();

    double monthRevenue = 0;
    int monthPayments = 0;
    for (final doc in approvedSnap.docs) {
      final data = doc.data();
      final reviewedAt = data['reviewedAt'];
      final reviewedDate = reviewedAt is Timestamp ? reviewedAt.toDate() : null;
      if (reviewedDate != null && !reviewedDate.isBefore(monthStart)) {
        monthRevenue += (data['amount'] as num?)?.toDouble() ?? 0.0;
        monthPayments++;
      }
    }

    final pendingSnap = await FirebaseFirestore.instance
        .collectionGroup('payment_submissions')
        .where('status', isEqualTo: 'pending')
        .get();

    return {
      'total': facilitiesSnap.docs.length,
      'trial': trial,
      'active': active,
      'grace': grace,
      'locked': locked,
      'monthRevenue': monthRevenue,
      'monthPayments': monthPayments,
      'pendingCount': pendingSnap.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final moneyFormat = NumberFormat('#,##0', 'en_US');

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return FirestoreErrorView(error: snapshot.error);
        }

        final stats = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Facilities',
                    value: '${stats['total']}',
                    color: primaryColor,
                    icon: Icons.store,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Revenue This Month',
                    value: 'Tsh ${moneyFormat.format(stats['monthRevenue'])}',
                    color: warmAmber,
                    icon: Icons.payments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Pending Requests',
                    value: '${stats['pendingCount']}',
                    color: Colors.orange,
                    icon: Icons.pending_actions,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Payments This Month',
                    value: '${stats['monthPayments']}',
                    color: primaryColor,
                    icon: Icons.receipt_long,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Facilities by Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _StatusRow(label: 'Active', count: stats['active'], color: Colors.green),
            _StatusRow(label: 'Trial', count: stats['trial'], color: primaryColor),
            _StatusRow(label: 'Grace Period', count: stats['grace'], color: Colors.orange),
            _StatusRow(label: 'Locked', count: stats['locked'], color: Colors.redAccent),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
