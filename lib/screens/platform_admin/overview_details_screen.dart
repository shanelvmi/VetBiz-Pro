import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../widgets/hover_elevate_card.dart';
import '../../widgets/firestore_error_view.dart';

/// The detail behind Overview's own summary cards - day-to-day earnings,
/// individual recent payments, revenue by plan, and the
/// approved/rejected rate - none of which fit on the summary screen
/// itself without crowding it. Reached via "View More" at the bottom
/// of Overview, not a tab of its own, since this is a drill-down from
/// that screen specifically, not a separate section to browse to
/// directly.
class OverviewDetailsScreen extends StatefulWidget {
  final bool isModal;
  const OverviewDetailsScreen({super.key, this.isModal = false});

  @override
  State<OverviewDetailsScreen> createState() => _OverviewDetailsScreenState();
}

class _OverviewDetailsScreenState extends State<OverviewDetailsScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  bool _isLoading = true;
  Object? _error;

  // Day -> total revenue that day, for the last 30 days.
  List<MapEntry<DateTime, double>> _dailyEarnings = [];
  // Most recent approved payments, newest first.
  List<Map<String, dynamic>> _recentPayments = [];
  // Plan label -> total revenue from that plan, across the same
  // 90-day window as the rest of this screen.
  Map<String, double> _revenueByPlan = {};
  int _approvedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      // A wider window than Overview's own "this month" figure, so
      // this screen actually adds context rather than repeating it -
      // bounded to 90 days rather than every payment ever made, since
      // this is a look-back view, not a growing archive.
      final windowStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));

      // Same query shape (single where(), no orderBy()) already proven
      // working by Overview's own revenue figure - no new composite
      // index needed.
      final approvedSnap = await FirebaseFirestore.instance
          .collectionGroup('payment_submissions')
          .where('status', isEqualTo: 'approved')
          .get();
      final rejectedSnap = await FirebaseFirestore.instance
          .collectionGroup('payment_submissions')
          .where('status', isEqualTo: 'rejected')
          .get();

      final dailyTotals = <DateTime, double>{};
      final planTotals = <String, double>{};
      final recentApproved = <Map<String, dynamic>>[];
      var approvedInWindow = 0;
      var rejectedInWindow = 0;

      for (final doc in approvedSnap.docs) {
        final data = doc.data();
        final reviewedAtField = data['reviewedAt'];
        final reviewedAt = reviewedAtField is Timestamp ? reviewedAtField.toDate() : null;
        if (reviewedAt == null || reviewedAt.isBefore(windowStart)) continue;

        approvedInWindow++;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final planLabel = (data['planLabel'] as String?) ?? 'Unknown';

        final day = DateTime(reviewedAt.year, reviewedAt.month, reviewedAt.day);
        dailyTotals[day] = (dailyTotals[day] ?? 0) + amount;
        planTotals[planLabel] = (planTotals[planLabel] ?? 0) + amount;

        recentApproved.add({
          'facilityName': data['facilityName'],
          'planLabel': planLabel,
          'amount': amount,
          'reviewedAt': reviewedAt,
        });
      }

      for (final doc in rejectedSnap.docs) {
        final data = doc.data();
        final reviewedAtField = data['reviewedAt'];
        final reviewedAt = reviewedAtField is Timestamp ? reviewedAtField.toDate() : null;
        if (reviewedAt == null || reviewedAt.isBefore(windowStart)) continue;
        rejectedInWindow++;
      }

      recentApproved.sort((a, b) => (b['reviewedAt'] as DateTime).compareTo(a['reviewedAt'] as DateTime));

      // Last 30 days, every day represented even if it earned nothing -
      // a chart with gaps is harder to read than one with real zeros.
      final today = DateTime(now.year, now.month, now.day);
      final dailyEarnings = <MapEntry<DateTime, double>>[];
      for (var i = 29; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        dailyEarnings.add(MapEntry(day, dailyTotals[day] ?? 0));
      }

      if (!mounted) return;
      setState(() {
        _dailyEarnings = dailyEarnings;
        _recentPayments = recentApproved.take(20).toList();
        _revenueByPlan = planTotals;
        _approvedCount = approvedInWindow;
        _rejectedCount = rejectedInWindow;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        title: const Text('Overview Details'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading && _dailyEarnings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _dailyEarnings.isEmpty
              ? FirestoreErrorView(error: _error)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Last 90 Days', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 16),

                        const Text('Day-to-Day Earnings (Last 30 Days)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        SizedBox(height: 220, child: _buildDailyEarningsChart()),

                        const SizedBox(height: 28),
                        const Text('Revenue by Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildRevenueByPlan(),

                        const SizedBox(height: 28),
                        const Text('Payment Outcomes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildOutcomesRow(),

                        const SizedBox(height: 28),
                        const Text('Recent Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildRecentPayments(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyEarningsChart() {
    if (_dailyEarnings.every((e) => e.value == 0)) {
      return Center(child: Text('No revenue in the last 30 days.', style: TextStyle(color: Colors.grey[600])));
    }

    final maxValue = _dailyEarnings.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue == 0 ? 1 : maxValue * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = _dailyEarnings[group.x.toInt()].key;
              return BarTooltipItem(
                '${DateFormat('d MMM').format(day)}\nTsh ${_moneyFormat.format(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) =>
                  Text(_moneyFormat.format(value), style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _dailyEarnings.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(_dailyEarnings[idx].key),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < _dailyEarnings.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: _dailyEarnings[i].value,
                color: primaryColor,
                width: 8,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildRevenueByPlan() {
    if (_revenueByPlan.isEmpty) {
      return Text('No approved payments in this period.', style: TextStyle(color: Colors.grey[600]));
    }

    final entries = _revenueByPlan.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((entry) {
            final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Tsh ${_moneyFormat.format(entry.value)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(warmAmber),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOutcomesRow() {
    final total = _approvedCount + _rejectedCount;
    final approvalRate = total == 0 ? 0 : (_approvedCount / total * 100).round();

    return Row(
      children: [
        Expanded(
          child: _OutcomeCard(
            label: 'Approved',
            value: '$_approvedCount',
            color: Colors.green,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OutcomeCard(
            label: 'Rejected',
            value: '$_rejectedCount',
            color: Colors.redAccent,
            icon: Icons.cancel_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OutcomeCard(
            label: 'Approval Rate',
            value: '$approvalRate%',
            color: primaryColor,
            icon: Icons.percent,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPayments() {
    if (_recentPayments.isEmpty) {
      return Text('No approved payments in this period.', style: TextStyle(color: Colors.grey[600]));
    }

    return Column(
      children: _recentPayments.map((payment) {
        final reviewedAt = payment['reviewedAt'] as DateTime;
        return HoverElevateCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (payment['facilityName'] as String?) ?? 'Unknown facility',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${payment['planLabel']} · ${DateFormat('dd MMM yyyy, HH:mm').format(reviewedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Tsh ${_moneyFormat.format(payment['amount'])}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _OutcomeCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      baseElevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

/// The one entry point for opening Overview Details - same modal-on-
/// desktop pattern as Insights/Activity Log: a full-screen push on
/// mobile, a large, centered, dismissable modal on desktop/tablet-
/// width screens.
Future<void> showOverviewDetailsScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OverviewDetailsScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Overview Details',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      return Center(
        child: SizedBox(
          width: screenSize.width * 0.8,
          height: screenSize.height * 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const Material(
              child: OverviewDetailsScreen(isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
