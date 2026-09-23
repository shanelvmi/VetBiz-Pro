import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import '../../services/dashboard_summary_service.dart';
import '../../widgets/summary_card.dart' show KpiTrend;

/// A simple insights view - a 14-day sales trend and your top 5
/// products by revenue over the last 30 days. Deliberately kept to two
/// clear, genuinely useful charts rather than a dozen shallow ones.
class InsightsScreen extends StatefulWidget {
  final bool isModal;
  const InsightsScreen({super.key, this.isModal = false});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  static const List<Color> _servicePalette = [
    Color(0xFF2F5D62), // same deep teal as primaryColor
    Color(0xFF5C7C99), // same muted steel blue used for Services on the main dashboard chart
    Color(0xFFFFB200), // same warm amber
    Color(0xFF8FA998), // muted sage green
    Color(0xFFB98B6F), // muted terracotta
    Color(0xFF9B8AA6), // muted lavender - reserved for the "Other" slice
  ];
  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  bool _isLoading = true;
  String? _error;
  List<double> _dailyTotals = List.filled(14, 0.0);
  late DateTime _trendStart;
  List<MapEntry<String, double>> _topProducts = [];
  List<MapEntry<String, double>> _serviceBreakdown = [];
  int? _touchedServiceIndex;

  // Today vs Yesterday, reusing the exact same comparison service and
  // KpiTrend model already built for the dashboard's own KPI cards.
  bool _isPulseLoading = true;
  KpiTrend? _salesPulseTrend;
  KpiTrend? _serviceRevenuePulseTrend;
  KpiTrend? _outstandingPulseTrend;
  // Signals for the interpretive engine - today's activity is judged
  // against a rolling recent baseline (not just yesterday, which is too
  // noisy a single day to call "normal"), plus a comparable-period
  // week-over-week comparison for the sales trend warning.
  double _todayActivity = 0;
  double _todaySalesShare = 0.5;
  double _recentAvgDailyActivity = 0;
  double _weeklySalesRatio = 1.0;
  bool _hasEnoughWeekData = false;

  @override
  void initState() {
    super.initState();
    _loadInsights();
    _loadBusinessPulse();
  }

  Future<void> _loadInsights() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _trendStart = today.subtract(const Duration(days: 13));
    final windowStart = now.subtract(const Duration(days: 30));

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('sales')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
            .get(),
        FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('services')
            .where('serviceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
            .get(),
      ]);
      final salesSnap = results[0];
      final servicesSnap = results[1];

      final dailyTotals = List<double>.filled(14, 0.0);
      final productRevenue = <String, double>{};

      for (final doc in salesSnap.docs) {
        final data = doc.data();
        final timestampField = data['timestamp'];
        final timestamp = timestampField is Timestamp ? timestampField.toDate() : null;
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        if (timestamp != null) {
          final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
          final dayIndex = day.difference(_trendStart).inDays;
          if (dayIndex >= 0 && dayIndex < 14) {
            dailyTotals[dayIndex] += totalAmount;
          }
        }

        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final name = (item['name'] as String?) ?? 'Unknown';
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
          final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
          final revenue = (qty * unitPrice) - discount;
          productRevenue[name] = (productRevenue[name] ?? 0) + revenue;
        }
      }

      final serviceRevenue = <String, double>{};
      for (final doc in servicesSnap.docs) {
        final data = doc.data();
        final name = (data['name'] as String?);
        final key = (name == null || name.isEmpty) ? 'Other' : name;
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        serviceRevenue[key] = (serviceRevenue[key] ?? 0) + totalAmount;
      }

      final sortedServicesFull = serviceRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topServices = sortedServicesFull.take(5).toList();
      final remainingServicesTotal =
          sortedServicesFull.skip(5).fold<double>(0.0, (sum, e) => sum + e.value);
      final serviceBreakdown = [
        ...topServices,
        if (remainingServicesTotal > 0) MapEntry('Other', remainingServicesTotal),
      ];

      final sortedProducts = productRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _dailyTotals = dailyTotals;
          _topProducts = sortedProducts.take(5).toList();
          _serviceBreakdown = serviceBreakdown;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadBusinessPulse() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isPulseLoading = false);
      return;
    }

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    // "Normal" is judged against the preceding 7 days, not a single
    // noisy yesterday - one unusually quiet or busy day shouldn't set
    // the bar for what counts as typical.
    final recentStart = today.subtract(const Duration(days: 7));
    final recentEnd = yesterday;
    // Comparable-period week-over-week: this week's Monday through
    // today, against last week's Monday through the same weekday - so
    // a partial week is never compared against a full one.
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final lastWeekComparableEnd = startOfLastWeek.add(Duration(days: today.weekday - 1));

    try {
      final summaryService = DashboardSummaryService();
      final results = await Future.wait([
        summaryService.getDashboardTotals(facilityId: facilityId, start: today, end: now),
        summaryService.getDashboardTotals(facilityId: facilityId, start: yesterday, end: yesterday),
        summaryService.getDashboardTotals(facilityId: facilityId, start: recentStart, end: recentEnd),
        summaryService.getDashboardTotals(facilityId: facilityId, start: startOfThisWeek, end: now),
        summaryService.getDashboardTotals(
            facilityId: facilityId, start: startOfLastWeek, end: lastWeekComparableEnd),
      ]);
      final todayTotals = results[0];
      final yesterdayTotals = results[1];
      final recentTotals = results[2];
      final thisWeekTotals = results[3];
      final lastWeekComparableTotals = results[4];

      final yesterdaySnapshotDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('dailySnapshots')
          .doc(_dateKey(yesterday))
          .get();
      final yesterdaySnapshot = yesterdaySnapshotDoc.data();

      if (!mounted) return;

      final todayActivity = todayTotals.totalSales + todayTotals.totalServiceRevenue;
      final recentAvgDailyActivity =
          (recentTotals.totalSales + recentTotals.totalServiceRevenue) / 7;
      final todaySalesShare = todayActivity == 0 ? 0.5 : todayTotals.totalSales / todayActivity;

      final lastWeekComparableSales = lastWeekComparableTotals.totalSales;
      final weeklySalesRatio = lastWeekComparableSales > 0
          ? thisWeekTotals.totalSales / lastWeekComparableSales
          : 1.0;
      // A single day into the week is too little to call a "weekly"
      // trend - Monday alone isn't a week yet.
      final hasEnoughWeekData = today.weekday >= 2;

      setState(() {
        _salesPulseTrend = KpiTrend(
          currentValue: todayTotals.totalSales,
          previousValue: yesterdayTotals.totalSales,
          higherIsBetter: true,
          comparisonLabel: 'vs Yesterday',
          formatChange: (v) => 'Tsh ${_moneyFormat.format(v)}',
        );
        _serviceRevenuePulseTrend = KpiTrend(
          currentValue: todayTotals.totalServiceRevenue,
          previousValue: yesterdayTotals.totalServiceRevenue,
          higherIsBetter: true,
          comparisonLabel: 'vs Yesterday',
          formatChange: (v) => 'Tsh ${_moneyFormat.format(v)}',
        );
        _outstandingPulseTrend = KpiTrend(
          currentValue: debtProvider.totalOutstanding(),
          previousValue: (yesterdaySnapshot?['totalOutstanding'] as num?)?.toDouble() ?? 0,
          // Rising outstanding debt is the bad outcome here, same
          // business-meaning rule as the dashboard's own Outstanding
          // Payment card.
          higherIsBetter: false,
          comparisonLabel: 'vs Yesterday',
          formatChange: (v) => 'Tsh ${_moneyFormat.format(v)}',
        );
        _todayActivity = todayActivity;
        _todaySalesShare = todaySalesShare;
        _recentAvgDailyActivity = recentAvgDailyActivity;
        _weeklySalesRatio = weeklySalesRatio;
        _hasEnoughWeekData = hasEnoughWeekData;
        _isPulseLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading Business Pulse: $e');
      if (mounted) setState(() => _isPulseLoading = false);
    }
  }

  List<(String, KpiTrend)> _pulseMetrics() {
    final metrics = <(String, KpiTrend)>[];
    if (_salesPulseTrend != null) metrics.add(('Sales', _salesPulseTrend!));
    if (_serviceRevenuePulseTrend != null) metrics.add(('Service revenue', _serviceRevenuePulseTrend!));
    if (_outstandingPulseTrend != null) metrics.add(('Outstanding payments', _outstandingPulseTrend!));
    return metrics;
  }

  // The interpretive engine's headline - an insight, not a record
  // counter. Never a figure; always one of a fixed set of qualitative
  // reads on the day.
  //
  // Priority order:
  // 1. A declining weekly sales trend is checked first - it's
  //    forward-looking and actionable, so it takes priority over how
  //    today alone looks (a single strong today doesn't erase a week
  //    that's been sliding).
  // 2. Otherwise, today's activity (sales + service revenue combined)
  //    is judged against the preceding 7 days' daily average - not
  //    yesterday alone, which is too noisy a single point to call
  //    "normal". The top tier is split further by which channel is
  //    actually driving it, so a sales-led surge and a service-led
  //    surge get their own distinct reads rather than one generic
  //    "activity is up".
  String _pulseHeadline() {
    if (_hasEnoughWeekData && _weeklySalesRatio < 0.7) {
      return 'Keep an eye on sales this week.';
    }

    final baseline = _recentAvgDailyActivity;
    // Both the 7-day baseline and today are genuinely zero - there's
    // no activity to read a trend from at all, so say that plainly
    // rather than falling into the ratio's fallback (which would
    // otherwise read as a misleadingly "steady" 1.0).
    if (baseline == 0 && _todayActivity == 0) {
      return 'No activity recorded yet.';
    }
    // No baseline to compare against yet (a brand-new facility) - fall
    // back to a plain read of whether anything happened today at all,
    // rather than a ratio against zero.
    final ratio = baseline > 0 ? (_todayActivity / baseline) : 1.6;

    if (ratio >= 1.6) {
      if (_todaySalesShare >= 0.65) return 'Sales are trending upward.';
      if (_todaySalesShare <= 0.35) return 'Services are gaining momentum.';
      return 'Strong business activity today.';
    }
    if (ratio >= 1.2) return 'Business is picking up.';
    if (ratio >= 0.8) return 'Business is steady.';
    if (ratio >= 0.5) return 'A quieter day so far.';
    return 'Customer activity is slowing.';
  }

  // The supporting line - a separate, always-present read on the
  // outstanding-payments trend, since it's a distinct concern from
  // today's sales/service activity and deserves its own sentence
  // rather than being folded into the headline.
  String _pulseSentence() {
    final trend = _outstandingPulseTrend;
    // Both today's and yesterday's outstanding total were literally
    // zero - there's no debt to call "stable", so say that plainly
    // instead of implying steady debt at some nonzero amount.
    if (trend == null || trend.hasNoChange) return 'No outstanding payments.';
    if (trend.isNewActivity) return 'Outstanding payments are rising - worth following up.';
    // A zero or negligible move isn't a real trend in either
    // direction - only call it rising/improving once the change is
    // large enough to actually mean something.
    if (trend.percent.abs() < 1) return 'Outstanding payments are stable.';
    if (trend.absoluteChange > 0) return 'Outstanding payments are rising - worth following up.';
    return 'Outstanding payments are improving.';
  }

  Widget _buildBusinessPulseCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: _isPulseLoading
          ? Container(
              key: const ValueKey('pulse-loading'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : _buildBusinessPulseContent(),
    );
  }

  Widget _buildBusinessPulseContent() {
    final metrics = _pulseMetrics();
    if (metrics.isEmpty) return const SizedBox.shrink(key: ValueKey('pulse-empty'));

    return Container(
      key: const ValueKey('pulse-content'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, const Color(0xFF3E8E82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business Pulse',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_pulseHeadline(),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_pulseSentence(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        title: const Text('Insights'),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load insights: $_error')))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildBusinessPulseCard(),
                        const SizedBox(height: 20),
                        _buildChartCard(
                          title: 'Sales - Last 14 Days',
                          summary: _trendSummary(),
                          chartHeight: 220,
                          chart: _buildTrendChart(),
                        ),
                        const SizedBox(height: 20),
                        _buildChartCard(
                          title: 'Top 5 Products - Last 30 Days',
                          summary: _topProductSummary(),
                          chartHeight: 260,
                          chart: _buildTopProductsChart(),
                        ),
                        const SizedBox(height: 20),
                        _buildChartCard(
                          title: 'Services by Type - Last 30 Days',
                          summary: _serviceBreakdownSummary(),
                          chartHeight: 220,
                          chart: _buildServicesDonutChart(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // A white, shadowed, rounded container around each chart - previously
  // both charts sat directly on the page background with nothing to
  // visually separate them from it, unlike every other card-based
  // screen in this app.
  Widget _buildChartCard({
    required String title,
    required String? summary,
    required double chartHeight,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (summary != null) ...[
            const SizedBox(height: 4),
            Text(summary, style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SizedBox(height: chartHeight, child: chart),
        ],
      ),
    );
  }

  String? _trendSummary() {
    if (_dailyTotals.every((v) => v == 0)) return null;
    final total = _dailyTotals.reduce((a, b) => a + b);
    return 'Total: Tsh ${_moneyFormat.format(total)} over 14 days';
  }

  String? _topProductSummary() {
    if (_topProducts.isEmpty) return null;
    final top = _topProducts.first;
    return 'Top seller: ${top.key} · Tsh ${_moneyFormat.format(top.value)}';
  }

  String? _serviceBreakdownSummary() {
    if (_serviceBreakdown.isEmpty) return null;
    final top = _serviceBreakdown.first;
    return 'Most requested: ${top.key} - Tsh ${_moneyFormat.format(top.value)}';
  }

  Widget _buildTrendChart() {
    if (_dailyTotals.every((v) => v == 0)) {
      return Center(child: Text('No sales in the last 14 days.', style: TextStyle(color: Colors.grey[600])));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        // Hover/tap a point to see its exact date and amount - was
        // entirely absent before, a genuinely expected desktop touch
        // for a chart like this.
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = _trendStart.add(Duration(days: spot.x.toInt()));
                return LineTooltipItem(
                  '${DateFormat('d MMM').format(day)}\nTsh ${_moneyFormat.format(spot.y)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
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
              interval: 2,
              getTitlesWidget: (value, meta) {
                final day = _trendStart.add(Duration(days: value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d/M').format(day), style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < 14; i++) FlSpot(i.toDouble(), _dailyTotals[i])],
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: primaryColor.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart() {
    if (_topProducts.isEmpty) {
      return Center(child: Text('No sales in the last 30 days.', style: TextStyle(color: Colors.grey[600])));
    }

    final maxValue = _topProducts.first.value;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        // Extra headroom above the tallest bar so its value label
        // (added via topTitles below) has room to actually show,
        // rather than getting clipped at the chart's own top edge.
        maxY: maxValue * 1.35,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        // Hover/tap a bar to see the exact product name and revenue.
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final name = _topProducts[group.x.toInt()].key;
              return BarTooltipItem(
                '$name\nTsh ${_moneyFormat.format(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          // The actual Tsh figure shown above each bar directly,
          // rather than only implied by bar height or only visible on
          // hover - readable at a glance without needing to interact
          // with the chart at all.
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _topProducts.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _moneyFormat.format(_topProducts[idx].value),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: primaryColor),
                  ),
                );
              },
            ),
          ),
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _topProducts.length) return const SizedBox.shrink();
                final name = _topProducts[idx].key;
                final shortName = name.length > 9 ? '${name.substring(0, 9)}...' : name;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(shortName, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < _topProducts.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: _topProducts[i].value,
                color: warmAmber,
                width: 22,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildServicesDonutChart() {
    if (_serviceBreakdown.isEmpty) {
      return Center(child: Text('No services in the last 30 days.', style: TextStyle(color: Colors.grey[600])));
    }

    final total = _serviceBreakdown.fold<double>(0.0, (sum, e) => sum + e.value);
    final touched = _touchedServiceIndex;
    final centerLabel = (touched != null && touched >= 0 && touched < _serviceBreakdown.length)
        ? _serviceBreakdown[touched]
        : null;
    final centerPercent =
        centerLabel != null && total > 0 ? (centerLabel.value / total * 100) : null;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: [
                    for (int i = 0; i < _serviceBreakdown.length; i++)
                      PieChartSectionData(
                        value: _serviceBreakdown[i].value,
                        color: _servicePalette[i % _servicePalette.length],
                        radius: i == touched ? 60 : 54,
                        showTitle: false,
                      ),
                  ],
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        final index = response?.touchedSection?.touchedSectionIndex;
                        if (!event.isInterestedForInteractions || index == null || index < 0) {
                          _touchedServiceIndex = null;
                          return;
                        }
                        _touchedServiceIndex = index;
                      });
                    },
                  ),
                ),
              ),
              if (centerLabel != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerLabel.key,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis),
                    Text('Tsh ${_moneyFormat.format(centerLabel.value)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    if (centerPercent != null)
                      Text('${centerPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text('Tsh ${_moneyFormat.format(total)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < _serviceBreakdown.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _servicePalette[i % _servicePalette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _serviceBreakdown[i].key,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one entry point for opening Insights - same reasoning and
/// threshold as showActivityLog/showSubscriptionScreen: a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. Insights is genuinely lighter content
/// than either of those (three charts, no forms, no filters) - "look
/// at it, then leave" describes it even better than it describes
/// Activity Log, so it belongs in the same modal category rather than
/// staying a full-screen navigation.
Future<void> showInsightsScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InsightsScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Insights',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 860).toDouble();
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: screenSize.height * 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const Material(
              child: InsightsScreen(isModal: true),
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
