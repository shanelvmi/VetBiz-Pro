import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/subscription_status_utils.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/hover_elevate_card.dart';

/// A snapshot of the whole business - how many facilities, in what state, and
/// how much has actually been collected this month. Reads every facility
/// directly, which is fine while you have a manageable number of facilities;
/// worth revisiting (e.g. precomputed via a Cloud Function, same pattern
/// as dailySummaries) if this ever grows into the hundreds.
///
/// A one-time fetch on open, not a live listener - same reasoning as
/// Facilities Directory's summary row: this needs the full picture to
/// mean what it claims, and a live listener would re-read everything
/// on any change anywhere. Refreshed via the button next to the
/// heading, or automatically whenever this tab is opened.
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  Object? _error;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _loadStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _lastRefreshed = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final facilitiesSnap = await FirebaseFirestore.instance.collection('facilities').get();

    int trial = 0, active = 0, grace = 0, locked = 0;
    for (final doc in facilitiesSnap.docs) {
      final expiresAtField = doc.data()['subscriptionExpiresAt'];
      final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
      final trialExpiresAtField = doc.data()['trialExpiresAt'];
      final trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;
      switch (computeSubscriptionStatus(expiresAt, trialExpiresAt)) {
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
    if (_isLoading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return FirestoreErrorView(error: _error);
    }

    final stats = _stats!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            if (_lastRefreshed != null)
              Text(
                'Updated ${DateFormat('HH:mm').format(_lastRefreshed!)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
              ),
            IconButton(
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _refresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                value: 'Tsh ${_moneyFormat.format(stats['monthRevenue'])}',
                color: Colors.green,
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
                color: Colors.blue,
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
    return HoverElevateCard(
      baseElevation: 2,
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
