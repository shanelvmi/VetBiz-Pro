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
  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  bool _isLoading = true;
  String? _error;
  List<double> _dailyTotals = List.filled(14, 0.0);
  late DateTime _trendStart;
  List<MapEntry<String, double>> _topProducts = [];

  // Today vs Yesterday, reusing the exact same comparison service and
  // KpiTrend model already built for the dashboard's own KPI cards -
  // "Business Pulse" is a narrative summary of the same underlying
  // comparison, not a separate calculation.
  bool _isPulseLoading = true;
  KpiTrend? _salesPulseTrend;
  KpiTrend? _serviceRevenuePulseTrend;
  KpiTrend? _outstandingPulseTrend;

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
      final salesSnap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart))
          .get();

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

      final sortedProducts = productRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _dailyTotals = dailyTotals;
          _topProducts = sortedProducts.take(5).toList();
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

    try {
      final summaryService = DashboardSummaryService();
      final todayTotals =
          await summaryService.getDashboardTotals(facilityId: facilityId, start: today, end: now);
      final yesterdayTotals = await summaryService.getDashboardTotals(
          facilityId: facilityId, start: yesterday, end: yesterday);
      final yesterdaySnapshotDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('dailySnapshots')
          .doc(_dateKey(yesterday))
          .get();
      final yesterdaySnapshot = yesterdaySnapshotDoc.data();

      if (!mounted) return;
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

  // True when there's been no sales or service revenue recorded today
  // at all - used to stop a passive metric like Outstanding payments
  // (which can shift for reasons that have nothing to do with today,
  // e.g. a debt settled earlier, or a delayed snapshot) from
  // single-handedly declaring the day "performing well" when nothing
  // was actually sold or serviced today.
  bool get _hasNoRevenueActivityToday =>
      (_salesPulseTrend == null || _salesPulseTrend!.currentValue == 0) &&
      (_serviceRevenuePulseTrend == null || _serviceRevenuePulseTrend!.currentValue == 0);

  // An overall sentiment from what fraction of the metrics that
  // actually changed are positive - deliberately not just "did sales
  // go up", since a genuinely mixed day (sales up, debt also up)
  // shouldn't be flatly reported as either "great" or "bad".
  String _pulseHeadline(List<(String, KpiTrend)> metrics) {
    if (_hasNoRevenueActivityToday) return 'No sales or service activity recorded today yet.';
    final withChange = metrics.where((m) => !m.$2.hasNoChange).toList();
    if (withChange.isEmpty) return "Nothing much has changed since yesterday.";
    final positiveCount = withChange.where((m) => m.$2.isNewActivity || m.$2.isPositive).length;
    final ratio = positiveCount / withChange.length;
    if (ratio >= 0.66) return 'Your business is performing well today.';
    if (ratio <= 0.33) return 'Today has been a bit slower than usual.';
    return 'A mixed day for your business so far.';
  }

  // A clean "X up N%, Y down M%, and Z up P%" list - works for any
  // combination of directions without needing a hand-crafted sentence
  // structure per case, unlike trying to weave in a word like "while"
  // only when the signs are mixed.
  String _pulseSentence(List<(String, KpiTrend)> metrics) {
    if (_hasNoRevenueActivityToday) return 'Record a sale or service to see how today compares.';
    final phrases = <String>[];
    for (final (label, trend) in metrics) {
      if (trend.hasNoChange) continue;
      if (trend.isNewActivity) {
        phrases.add('$label picking up');
        continue;
      }
      final direction = trend.absoluteChange >= 0 ? 'up' : 'down';
      phrases.add('$label $direction ${trend.percent.abs().toStringAsFixed(0)}%');
    }
    if (phrases.isEmpty) return "Check back once today's activity picks up.";
    if (phrases.length == 1) return '${phrases[0]}.';
    return '${phrases.sublist(0, phrases.length - 1).join(', ')}, and ${phrases.last}.';
  }

  Widget _buildBusinessPulseCard() {
    if (_isPulseLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final metrics = _pulseMetrics();
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Container(
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
                Text(_pulseHeadline(metrics),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_pulseSentence(metrics),
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
}

/// The one entry point for opening Insights - same reasoning and
/// threshold as showActivityLog/showSubscriptionScreen: a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. Insights is genuinely lighter content
/// than either of those (two charts, no forms, no filters) - "look at
/// it, then leave" describes it even better than it describes Activity
/// Log, so it belongs in the same modal category rather than staying a
/// full-screen navigation.
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
      return Center(
        child: SizedBox(
          width: screenSize.width * 0.8,
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
