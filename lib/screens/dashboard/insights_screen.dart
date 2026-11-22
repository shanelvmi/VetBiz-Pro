import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/insights_data_loader.dart';
import '../../services/service_breakdown.dart';
import '../../widgets/summary_card.dart' show KpiTrend;
import '../../widgets/shell/app_shell.dart';
import '../../widgets/shell/page_header.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_layout.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/polish_metrics.dart';
import '../../ui/feedback/friendly_error.dart';
import '../../ui/polish/chart_palette.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/reveal/skeleton_box.dart';
import '../../utils/app_clock.dart';

/// A simple insights view - a 14-day sales trend and your top 5
/// products by revenue over the last 30 days. Deliberately kept to two
/// clear, genuinely useful charts rather than a dozen shallow ones.
class InsightsScreen extends StatefulWidget {
  final bool isModal;

  /// Tests only (POL2's fingerprints): a fake Firestore in place of the
  /// app's own. The same reads either way.
  final FirebaseFirestore? firestore;
  const InsightsScreen({super.key, this.isModal = false, this.firestore});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();

  /// UX8: forgets the Business Pulse kept in memory (tests start cold).
  @visibleForTesting
  static void forgetLastPulse() => _InsightsScreenState._lastPulse.clear();
}

/// UX8: what one Business Pulse read gave (see _lastPulse).
typedef _PulseValues = ({
  KpiTrend sales,
  KpiTrend services,
  KpiTrend outstanding,
  double todayActivity,
  double todaySalesShare,
  double recentAvg,
  double weeklyRatio,
  bool enoughWeek,
});

class _InsightsScreenState extends State<InsightsScreen> {
  /// POL2: the cards' hairline border, drawn outside the edge so each card
  /// keeps its size and place (it replaced a shadow).
  Border get _hairline =>
      Border.all(color: context.colors.border, width: PolishMetrics.hairline, strokeAlign: BorderSide.strokeAlignOutside);

  bool _isLoading = true;
  Object? _error;
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

  // UX8: the last Business Pulse read, per facility, kept for the session
  // (memory only). A return visit shows it at once while the same reads
  // refresh it, instead of a skeleton.
  static final _lastPulse = <String, _PulseValues>{};

  void _restorePulse() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final last = facilityId == null ? null : _lastPulse[facilityId];
    if (last == null) return;
    _salesPulseTrend = last.sales;
    _serviceRevenuePulseTrend = last.services;
    _outstandingPulseTrend = last.outstanding;
    _todayActivity = last.todayActivity;
    _todaySalesShare = last.todaySalesShare;
    _recentAvgDailyActivity = last.recentAvg;
    _weeklySalesRatio = last.weeklyRatio;
    _hasEnoughWeekData = last.enoughWeek;
    _isPulseLoading = false;
  }

  @override
  void initState() {
    super.initState();
    _restorePulse();
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

    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    _trendStart = today.subtract(AppRanges.insightsTrendBack);
    // UX1b: the trend chart shows 14 days, but Top 5 products and the
    // services donut are titled "Last 30 Days" and read only 14 before (a
    // service 15 to 30 days old was missing). Both reads are now the 30-day
    // window, the same one Home's 30d Product movement and Visit activity
    // pages read (shared, kept for the session); the trend still counts only
    // its 14 days from _trendStart.

    try {
      // HUB2: the same two reads, through the loader Home's Product movement
      // page shares: kept for the session, so a second visit (or Home
      // first) costs nothing.
      Future<List<List<Map<String, dynamic>>>> read(InsightsDataLoader loader) =>
          Future.wait([
            loader.sales(facilityId, now: now, days: AppRanges.month.inDays),
            loader.services(facilityId, now: now, days: AppRanges.month.inDays),
          ]);
      final loader = InsightsDataLoader.shared;
      // POL2: a test's fake Firestore gets its own loader; the app always
      // reads through the shared one.
      final results = await read(widget.firestore == null ? loader : InsightsDataLoader(firestore: widget.firestore));
      final salesDocs = results[0];
      final servicesDocs = results[1];

      final dailyTotals = List<double>.filled(14, 0.0);
      final productRevenue = <String, double>{};

      for (final data in salesDocs) {
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

      // HUB4: the one breakdown Home's Visit activity donut shares (top 5
      // by revenue, then the rest as "Other"); the donut here draws revenue
      // and, as before, leaves out a rest that earned nothing.
      final serviceBreakdown = [
        for (final s in serviceBreakdownOf(servicesDocs))
          if (!s.tail || s.revenue > 0) MapEntry(s.key, s.revenue),
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
      if (mounted) setState(() { _error = e; _isLoading = false; });
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

    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(AppRanges.day);
    // "Normal" is judged against the preceding 7 days, not a single
    // noisy yesterday - one unusually quiet or busy day shouldn't set
    // the bar for what counts as typical.
    final recentStart = today.subtract(AppRanges.week);
    final recentEnd = yesterday;
    // Comparable-period week-over-week: this week's Monday through
    // today, against last week's Monday through the same weekday - so
    // a partial week is never compared against a full one.
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(AppRanges.week);
    final lastWeekComparableEnd = startOfLastWeek.add(Duration(days: today.weekday - 1));

    try {
      final summaryService = DashboardSummaryService(firestore: widget.firestore);
      // UX8: yesterday's snapshot is read alongside the totals (it waited for
      // all twenty of their queries before). The same reads, no new ones.
      final snapshotRead = (widget.firestore ?? FirebaseFirestore.instance)
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.dailySnapshots)
          .doc(_dateKey(yesterday))
          .get();
      final (results, yesterdaySnapshotDoc) = await (
        Future.wait([
          summaryService.getDashboardTotals(facilityId: facilityId, start: today, end: now),
          summaryService.getDashboardTotals(facilityId: facilityId, start: yesterday, end: yesterday),
          summaryService.getDashboardTotals(facilityId: facilityId, start: recentStart, end: recentEnd),
          summaryService.getDashboardTotals(facilityId: facilityId, start: startOfThisWeek, end: now),
          summaryService.getDashboardTotals(
              facilityId: facilityId, start: startOfLastWeek, end: lastWeekComparableEnd),
        ]),
        snapshotRead,
      ).wait;
      final todayTotals = results[0];
      final yesterdayTotals = results[1];
      final recentTotals = results[2];
      final thisWeekTotals = results[3];
      final lastWeekComparableTotals = results[4];
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

      final vsYesterday = L10n.current.dashboard_vsYesterday;
      setState(() {
        _salesPulseTrend = KpiTrend(
          currentValue: todayTotals.totalSales,
          previousValue: yesterdayTotals.totalSales,
          higherIsBetter: true,
          comparisonLabel: vsYesterday,
          formatChange: (v) => Money.format(v),
        );
        _serviceRevenuePulseTrend = KpiTrend(
          currentValue: todayTotals.totalServiceRevenue,
          previousValue: yesterdayTotals.totalServiceRevenue,
          higherIsBetter: true,
          comparisonLabel: vsYesterday,
          formatChange: (v) => Money.format(v),
        );
        _outstandingPulseTrend = KpiTrend(
          currentValue: debtProvider.totalOutstanding(),
          previousValue: (yesterdaySnapshot?['totalOutstanding'] as num?)?.toDouble() ?? 0,
          // Rising outstanding debt is the bad outcome here, same
          // business-meaning rule as the dashboard's own Outstanding
          // Payment card.
          higherIsBetter: false,
          comparisonLabel: vsYesterday,
          formatChange: (v) => Money.format(v),
        );
        _todayActivity = todayActivity;
        _todaySalesShare = todaySalesShare;
        _recentAvgDailyActivity = recentAvgDailyActivity;
        _weeklySalesRatio = weeklySalesRatio;
        _hasEnoughWeekData = hasEnoughWeekData;
        _isPulseLoading = false;
        _lastPulse[facilityId] = (
          sales: _salesPulseTrend!,
          services: _serviceRevenuePulseTrend!,
          outstanding: _outstandingPulseTrend!,
          todayActivity: todayActivity,
          todaySalesShare: todaySalesShare,
          recentAvg: recentAvgDailyActivity,
          weeklyRatio: weeklySalesRatio,
          enoughWeek: hasEnoughWeekData,
        );
      });
    } catch (e) {
      debugPrint('Error loading Business Pulse: $e');
      if (mounted) setState(() => _isPulseLoading = false);
    }
  }

  List<(String, KpiTrend)> _pulseMetrics() {
    final metrics = <(String, KpiTrend)>[];
    final l = context.l10n;
    if (_salesPulseTrend != null) metrics.add((l.dashboard_sales, _salesPulseTrend!));
    if (_serviceRevenuePulseTrend != null) metrics.add((l.insights_serviceRevenue, _serviceRevenuePulseTrend!));
    if (_outstandingPulseTrend != null) metrics.add((l.insights_outstandingPayments, _outstandingPulseTrend!));
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
    final l = context.l10n;
    if (_hasEnoughWeekData && _weeklySalesRatio < 0.7) {
      return l.insights_watchSales;
    }

    final baseline = _recentAvgDailyActivity;
    // Both the 7-day baseline and today are genuinely zero - there's
    // no activity to read a trend from at all, so say that plainly
    // rather than falling into the ratio's fallback (which would
    // otherwise read as a misleadingly "steady" 1.0).
    if (baseline == 0 && _todayActivity == 0) {
      return l.insights_noActivity;
    }
    // No baseline to compare against yet (a brand-new facility) - fall
    // back to a plain read of whether anything happened today at all,
    // rather than a ratio against zero.
    final ratio = baseline > 0 ? (_todayActivity / baseline) : 1.6;

    if (ratio >= 1.6) {
      if (_todaySalesShare >= 0.65) return l.insights_salesTrendingUp;
      if (_todaySalesShare <= 0.35) return l.insights_servicesGaining;
      return l.insights_strongActivity;
    }
    if (ratio >= 1.2) return l.insights_pickingUp;
    if (ratio >= 0.8) return l.insights_steady;
    if (ratio >= 0.5) return l.insights_quieter;
    return l.insights_slowing;
  }

  // The supporting line - a separate, always-present read on the
  // outstanding-payments trend, since it's a distinct concern from
  // today's sales/service activity and deserves its own sentence
  // rather than being folded into the headline.
  String _pulseSentence() {
    final l = context.l10n;
    final trend = _outstandingPulseTrend;
    // Both today's and yesterday's outstanding total were literally
    // zero - there's no debt to call "stable", so say that plainly
    // instead of implying steady debt at some nonzero amount.
    if (trend == null || trend.hasNoChange) return l.insights_noOutstanding;
    if (trend.isNewActivity) return l.insights_outstandingRising;
    // A zero or negligible move isn't a real trend in either
    // direction - only call it rising/improving once the change is
    // large enough to actually mean something.
    if (trend.percent.abs() < 1) return l.insights_outstandingStable;
    if (trend.absoluteChange > 0) return l.insights_outstandingRising;
    return l.insights_outstandingImproving;
  }

  // UX8: one card shape whether loading or not, so nothing moves when the
  // figures land: while loading, the real title and skeleton bars over the
  // headline and the sentence, each laid out from what the card says before
  // any figure (the quiet day's words, same style), never a spinner. A day
  // whose words wrap differently can still change the height by a line.
  Widget _buildBusinessPulseCard() {
    if (_isPulseLoading) return _buildBusinessPulseContent(loading: true);
    return _buildBusinessPulseContent();
  }

  Widget _buildBusinessPulseContent({bool loading = false}) {
    if (!loading && _pulseMetrics().isEmpty) return const SizedBox.shrink(key: ValueKey('pulse-empty'));
    final l = context.l10n;
    final headlineStyle = TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold);
    final sentenceStyle = TextStyle(color: context.colors.textSecondary, fontSize: AppFontSize.f13, height: 1.4);
    final headline = loading
        ? SkeletonOf(child: Text(_pulseHeadline(), style: headlineStyle))
        : Text(_pulseHeadline(), key: const ValueKey('pulse-headline'), style: headlineStyle);
    final sentence = loading
        ? SkeletonOf(child: Text(_pulseSentence(), style: sentenceStyle))
        : Text(_pulseSentence(), style: sentenceStyle);
    final card = Container(
      key: ValueKey(loading ? 'pulse-loading' : 'pulse-content'),
      padding: const EdgeInsets.all(AppSpacing.s20),
      // POL2 (owner rule 4): a flat surface with a hairline border, no
      // gradient or glow. The pulse shows no live state: its read is the
      // headline's words, so no dot is added.
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: _hairline,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The icon's slot as before, without its tinted tile (neutral).
          SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.monitor_heart_outlined, color: context.colors.textSecondary, size: AppIconSize.i22),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.insights_businessPulse,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
                const SizedBox(height: AppSpacing.s4),
                headline,
                const SizedBox(height: AppSpacing.s6),
                sentence,
              ],
            ),
          ),
        ],
      ),
    );
    return loading ? SkeletonPulse(child: card) : card;
  }

  @override
  Widget build(BuildContext context) {
    if (!AppLayout.isPhone(context)) return _buildWide();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.insights_title),
        centerTitle: true,
        backgroundColor: context.colors.brandSurface,
        foregroundColor: context.colors.onBrandSurface,
        // LAY4b: opened from the sidebar it is a top-level place (no back arrow).
        automaticallyImplyLeading: !widget.isModal && !ShellScope.isTopLevel(context),
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.common_close,
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.s24), child: Text(context.l10n.insights_loadFailed(FriendlyError.messageFor(_error!)))))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      children: [
                        _buildBusinessPulseCard(),
                        for (final card in _chartCards()) ...[
                          const SizedBox(height: AppSpacing.s20),
                          card,
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  /// The three chart cards in order (sales trend, top products, services),
  /// for both layouts.
  List<Widget> _chartCards() => [
        _buildChartCard(
          title: context.l10n.insights_salesLast14,
          summary: _trendSummary(),
          chartHeight: 220,
          chart: _buildTrendChart(),
        ),
        _buildChartCard(
          title: context.l10n.insights_topProductsLast30,
          summary: _topProductSummary(),
          chartHeight: 260,
          chart: _buildTopProductsChart(),
        ),
        _buildChartCard(
          title: context.l10n.insights_servicesByTypeLast30,
          summary: _serviceBreakdownSummary(),
          chartHeight: 220,
          chart: _buildServicesDonutChart(),
        ),
      ];

  // UX1b (owner, 2026-11-21): PC and tablet. The shared PageHeader (title on
  // the left; the close button when opened as a modal, the back arrow only
  // when pushed above another page) and the full content width instead of
  // the 800 px centred column: Business Pulse full width, then the three
  // chart cards two to a row from a content width of 900 (one below), and
  // the page scrolls as one. The phone keeps the build above.
  Widget _buildWide() {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: PageHeader(
        title: l10n.insights_title,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_close,
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.s24), child: Text(l10n.insights_loadFailed(FriendlyError.messageFor(_error!)))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = _chartCards();
                      final columns = constraints.maxWidth >= AppBreakpoints.medium ? 2 : 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBusinessPulseCard(),
                          for (var i = 0; i < cards.length; i += columns) ...[
                            const SizedBox(height: AppSpacing.s20),
                            if (columns == 1)
                              cards[i]
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cards[i]),
                                  const SizedBox(width: AppSpacing.s20),
                                  Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
                                ],
                              ),
                          ],
                        ],
                      );
                    },
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        // POL2: a hairline border in place of the shadow (owner rule 4).
        border: _hairline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.s4),
            // POL2 (owner rule 1): the summary is a read, not something
            // chosen or new, so secondary text, not the accent.
            Text(summary, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSecondary, fontWeight: AppFontWeight.semibold)),
          ],
          const SizedBox(height: AppSpacing.s16),
          SizedBox(height: chartHeight, child: chart),
        ],
      ),
    );
  }

  String? _trendSummary() {
    if (_dailyTotals.every((v) => v == 0)) return null;
    final total = _dailyTotals.reduce((a, b) => a + b);
    return context.l10n.insights_totalOver14(Money.format(total));
  }

  // The grouping keys stay the English 'Unknown' (a sale item with no name)
  // and 'Other' (a service with no name, or everything past the top 5);
  // only what is shown is localised. A real name is shown as it is.
  String _productName(String key) => key == 'Unknown' ? context.l10n.common_unknown : key;

  String _serviceName(String key) => key == 'Other' ? context.l10n.serviceCategory_other : key;

  String? _topProductSummary() {
    if (_topProducts.isEmpty) return null;
    final top = _topProducts.first;
    return context.l10n.insights_topSeller(_productName(top.key), Money.format(top.value));
  }

  String? _serviceBreakdownSummary() {
    if (_serviceBreakdown.isEmpty) return null;
    final top = _serviceBreakdown.first;
    return context.l10n.insights_mostRequested(_serviceName(top.key), Money.format(top.value));
  }

  Widget _buildTrendChart() {
    if (_dailyTotals.every((v) => v == 0)) {
      return Center(child: Text(context.l10n.insights_noSales14, style: TextStyle(color: context.colors.textMuted)));
    }

    return LineChart(
      LineChartData(
        // Revenue is never negative - an explicit floor so the
        // curve/shaded area can't visually dip below the zero line,
        // on top of preventCurveOverShooting below.
        minY: 0,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: context.colors.border)),
        // Hover/tap a point to see its exact date and amount - was
        // entirely absent before, a genuinely expected desktop touch
        // for a chart like this.
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = _trendStart.add(Duration(days: spot.x.toInt()));
                return LineTooltipItem(
                  '${AppDateFormat.dateShort.format(day)}\n${Money.format(spot.y)}',
                  TextStyle(color: context.colors.onChartTooltip, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12),
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
                  Text(Money.plain(value), style: const TextStyle(fontSize: AppFontSize.f9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final day = _trendStart.add(Duration(days: value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                  child: Text(AppDateFormat.dayMonthNumeric.format(day), style: const TextStyle(fontSize: AppFontSize.f9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < 14; i++) FlSpot(i.toDouble(), _dailyTotals[i])],
            isCurved: true,
            // Revenue is never negative - stops the curve smoothing
            // from overshooting past a point and visually dipping
            // below zero when a high day is immediately followed by a
            // much lower one.
            preventCurveOverShooting: true,
            color: ChartPalette.of(context).series,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: ChartPalette.of(context).series.withValues(alpha: AppAlpha.a10)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart() {
    if (_topProducts.isEmpty) {
      return Center(child: Text(context.l10n.insights_noSales30, style: TextStyle(color: context.colors.textMuted)));
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
              final name = _productName(_topProducts[group.x.toInt()].key);
              return BarTooltipItem(
                '$name\n${Money.format(rod.toY)}',
                TextStyle(color: context.colors.onChartTooltip, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Text(
                    Money.plain(_topProducts[idx].value),
                    style: TextStyle(fontSize: AppFontSize.f9, fontWeight: AppFontWeight.semibold, color: context.colors.primary),
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
                  Text(Money.plain(value), style: const TextStyle(fontSize: AppFontSize.f9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _topProducts.length) return const SizedBox.shrink();
                final name = _productName(_topProducts[idx].key);
                final shortName = name.length > 9 ? '${name.substring(0, 9)}...' : name;
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                  child: Text(shortName, style: const TextStyle(fontSize: AppFontSize.f9), textAlign: TextAlign.center),
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
                color: ChartPalette.of(context).series,
                width: 22,
                borderRadius: BorderRadius.circular(AppRadius.r4),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildServicesDonutChart() {
    if (_serviceBreakdown.isEmpty) {
      return Center(child: Text(context.l10n.insights_noServices30, style: TextStyle(color: context.colors.textMuted)));
    }
    // UX1b: services given but all free (every total 0): the pie had nothing
    // to share out and drew a blank ring; a line says so instead.
    if (_serviceBreakdown.every((e) => e.value <= 0)) {
      return Center(child: Text(context.l10n.insights_noServiceRevenue30, style: TextStyle(color: context.colors.textMuted)));
    }

    // POL7: drawn as the top three by revenue, largest first (the deepest
    // tone), then one Other (owner: three ramp steps, then Other).
    final slices = insightsDrawnSlices(_serviceBreakdown);
    final palette = ChartPalette.of(context);
    final total = slices.fold<double>(0.0, (runningTotal, e) => runningTotal + e.value);
    final touched = _touchedServiceIndex;
    final centerLabel = (touched != null && touched >= 0 && touched < slices.length)
        ? slices[touched]
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
                    for (int i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].value,
                        color: _sliceColor(palette, slices[i], i),
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
                    Text(_serviceName(centerLabel.key),
                        style: const TextStyle(fontSize: AppFontSize.f11, fontWeight: AppFontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis),
                    Text(Money.format(centerLabel.value),
                        style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.textMuted)),
                    if (centerPercent != null)
                      Text('${centerPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.textMuted)),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.common_total, style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.textMuted)),
                    Text(Money.format(total),
                        style: const TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.bold)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < slices.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _sliceColor(palette, slices[i], i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s6),
                      Expanded(
                        child: Text(
                          _serviceName(slices[i].key),
                          style: const TextStyle(fontSize: AppFontSize.f11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // POL7: every slice shows its value, so colour is
                      // never the only link between a slice and its share.
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        Money.format(slices[i].value),
                        style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
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
  await showAdaptiveForm(
    context,
    barrierLabel: context.l10n.insights_title,
    builder: (isModal) => InsightsScreen(isModal: isModal),
  );
}

/// POL7: the services donut as drawn: the top three types by revenue,
/// largest first, then one Other with the rest and any Other given.
/// Display only; the breakdown (serviceBreakdownOf) is unchanged.
List<MapEntry<String, double>> insightsDrawnSlices(List<MapEntry<String, double>> slices) =>
    chartSlicesByValue<MapEntry<String, double>>(
      slices,
      value: (e) => e.value,
      isOther: (e) => e.key == ServiceSlice.otherKey,
      keep: ChartPalette.maxSteps,
      fold: (rest) => MapEntry(ServiceSlice.otherKey, rest.fold(0.0, (n, e) => n + e.value)),
    );

/// POL7: a slice's colour: the primary ramp by place, Other grey.
Color _sliceColor(ChartPalette palette, MapEntry<String, double> slice, int index) =>
    slice.key == ServiceSlice.otherKey ? palette.other : palette.step(index);
