import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/subscription_status_utils.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/hover_elevate_card.dart';
import 'overview_details_screen.dart';

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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Spacer(),
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
            const SizedBox(height: 16),

            // Responsive grid - 4 across on a wide desktop monitor, 2
            // across on a tablet-width window, a single stacked column
            // on a phone, rather than a fixed two-per-row pairing that
            // never adapted to the screen it happened to be on.
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 700 ? 4 : (width >= 420 ? 2 : 1);
                final spacing = 12.0;
                final cardWidth = (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

                final cards = [
                  _StatCard(
                    label: 'Total Facilities',
                    value: '${stats['total']}',
                    color: primaryColor,
                    icon: Icons.store,
                  ),
                  _StatCard(
                    label: 'Revenue This Month',
                    value: 'Tsh ${_moneyFormat.format(stats['monthRevenue'])}',
                    color: Colors.green,
                    icon: Icons.payments,
                  ),
                  _StatCard(
                    label: 'Pending Requests',
                    value: '${stats['pendingCount']}',
                    color: Colors.blue,
                    icon: Icons.pending_actions,
                  ),
                  _StatCard(
                    label: 'Payments This Month',
                    value: '${stats['monthPayments']}',
                    color: primaryColor,
                    icon: Icons.receipt_long,
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
                );
              },
            ),

            const SizedBox(height: 28),
            const Text('Facilities by Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _StatusBar(
              primaryColor: primaryColor,
              active: stats['active'] as int,
              trial: stats['trial'] as int,
              grace: stats['grace'] as int,
              locked: stats['locked'] as int,
            ),

            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => showOverviewDetailsScreen(context),
                icon: const Icon(Icons.bar_chart_outlined, size: 18),
                label: const Text('View More'),
                style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
              ),
            ),
          ],
        ),
      ),
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
      baseElevation: 1,
      child: Container(
        decoration: BoxDecoration(
          // A subtle colored left accent, matching the icon - gives
          // each card its own quiet identity at a glance, rather than
          // four otherwise-identical plain white cards distinguished
          // only by their text.
          border: Border(left: BorderSide(color: color, width: 3)),
          // Matches HoverElevateCard's own default border radius exactly -
          // Card doesn't clip its child by default, so a mismatched
          // radius here would show as a faint square corner peeking out
          // from under the card's rounded one.
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

/// A horizontal stacked bar, proportional to each status's share of the
/// whole facility base, plus a legend with the exact counts and
/// percentages below it - a single glance at the shape of the business
/// (mostly active? a worrying amount locked?) that four separate
/// numbers in a plain list never gave as immediately.
class _StatusBar extends StatelessWidget {
  final Color primaryColor;
  final int active;
  final int trial;
  final int grace;
  final int locked;

  const _StatusBar({
    required this.primaryColor,
    required this.active,
    required this.trial,
    required this.grace,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final total = active + trial + grace + locked;

    final segments = [
      (label: 'Active', count: active, color: Colors.green),
      (label: 'Trial', count: trial, color: primaryColor),
      (label: 'Grace Period', count: grace, color: Colors.orange),
      (label: 'Locked', count: locked, color: Colors.redAccent),
    ];

    if (total == 0) {
      return Text('No facilities yet.', style: TextStyle(color: Colors.grey[600]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: segments
                  .where((s) => s.count > 0)
                  .map((s) => Expanded(flex: s.count, child: Container(color: s.color)))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 10,
          children: segments.map((s) {
            final pct = total > 0 ? (s.count / total * 100).round() : 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  '${s.label}: ${s.count} ($pct%)',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
