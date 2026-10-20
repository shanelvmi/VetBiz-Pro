import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../widgets/hover_elevate_card.dart';
import '../../widgets/firestore_error_view.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/payment_submission_status.dart';
import '../../config/money.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_breakpoints.dart';

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
  // Height of the daily earnings chart. A size (above the spacing
  // ladder), kept exact.
  static const double _chartHeight = 220;

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
      final windowStart = DateTime(now.year, now.month, now.day).subtract(AppRanges.adminOverviewWindow);

      // Same query shape (single where(), no orderBy()) already proven
      // working by Overview's own revenue figure - no new composite
      // index needed.
      final approvedSnap = await FirebaseFirestore.instance
          .collectionGroup(Collections.paymentSubmissions)
          .where(Fields.status, isEqualTo: PaymentSubmissionStatus.approved.key)
          .get();
      final rejectedSnap = await FirebaseFirestore.instance
          .collectionGroup(Collections.paymentSubmissions)
          .where(Fields.status, isEqualTo: PaymentSubmissionStatus.rejected.key)
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Overview Details'),
        centerTitle: true,
        backgroundColor: context.colors.brandSurface,
        foregroundColor: context.colors.onBrandSurface,
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
                ? SizedBox(width: AppSpacing.s18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
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
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      children: [
                        Text('Last 90 Days', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                        const SizedBox(height: AppSpacing.s16),

                        const Text('Day-to-Day Earnings (Last 30 Days)',
                            style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                        const SizedBox(height: AppSpacing.s12),
                        SizedBox(height: _chartHeight, child: _buildDailyEarningsChart()),

                        const SizedBox(height: AppSpacing.s28),
                        const Text('Revenue by Plan', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                        const SizedBox(height: AppSpacing.s12),
                        _buildRevenueByPlan(),

                        const SizedBox(height: AppSpacing.s28),
                        const Text('Payment Outcomes', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                        const SizedBox(height: AppSpacing.s12),
                        _buildOutcomesRow(),

                        const SizedBox(height: AppSpacing.s28),
                        const Text('Recent Payments', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                        const SizedBox(height: AppSpacing.s12),
                        _buildRecentPayments(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyEarningsChart() {
    if (_dailyEarnings.every((e) => e.value == 0)) {
      return Center(child: Text('No revenue in the last 30 days.', style: TextStyle(color: context.colors.textMuted)));
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
                '${AppDateFormat.dateShort.format(day)}\n${Money.format(rod.toY)}',
                TextStyle(color: context.colors.onChartTooltip, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12),
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
                  Text(Money.plain(value), style: const TextStyle(fontSize: AppFontSize.f9)),
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
                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                  child: Text(
                    AppDateFormat.dateShort.format(_dailyEarnings[idx].key),
                    style: const TextStyle(fontSize: AppFontSize.f9),
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
                color: context.colors.primary,
                width: 8,
                borderRadius: BorderRadius.circular(AppRadius.r4),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildRevenueByPlan() {
    if (_revenueByPlan.isEmpty) {
      return Text('No approved payments in this period.', style: TextStyle(color: context.colors.textMuted));
    }

    final entries = _revenueByPlan.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((entry) {
            final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
                      Text(Money.format(entry.value),
                          style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13, color: context.colors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: context.colors.divider,
                      valueColor: AlwaysStoppedAnimation(context.colors.accent),
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
            color: context.colors.success,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _OutcomeCard(
            label: 'Rejected',
            value: '$_rejectedCount',
            color: context.colors.dangerAccent,
            icon: Icons.cancel_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _OutcomeCard(
            label: 'Approval Rate',
            value: '$approvalRate%',
            color: context.colors.primary,
            icon: Icons.percent,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPayments() {
    if (_recentPayments.isEmpty) {
      return Text('No approved payments in this period.', style: TextStyle(color: context.colors.textMuted));
    }

    return Column(
      children: _recentPayments.map((payment) {
        final reviewedAt = payment['reviewedAt'] as DateTime;
        return HoverElevateCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: AppAlpha.a10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.payments_outlined, size: AppIconSize.i16, color: context.colors.success),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (payment['facilityName'] as String?) ?? 'Unknown facility',
                        style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${payment['planLabel']} · ${AppDateFormat.dateTime24.format(reviewedAt)}',
                        style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(payment['amount']),
                  style: TextStyle(fontWeight: AppFontWeight.bold, color: context.colors.primary),
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
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: AppIconSize.i20),
            const SizedBox(height: AppSpacing.s8),
            Text(value, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f20, color: color)),
            const SizedBox(height: AppSpacing.s2),
            Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
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
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

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
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      // Never shorter than 480px, fixed - 88% of screen height
      // comfortably exceeds that on most windows, but this guarantees
      // it even on a smaller one.
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
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
