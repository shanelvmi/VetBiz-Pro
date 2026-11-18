import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../data/home_chart_range.dart';
import '../../l10n/l10n.dart';
import '../../services/service_breakdown.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/polish/chart_palette.dart';
import '../../widgets/reveal/reveal.dart';
import 'home_chart_page.dart';

/// Counts in tabular figures, so digits do not shift as they change.
const _tabular = [FontFeature.tabularFigures()];

/// POL7: a slice's colour: the ONE chart palette's primary ramp by place
/// (the slices are drawn largest first, so the largest is the deepest),
/// Other grey; each at least 3:1 on the card in every theme, Light and
/// Dark. Colour is never the only signal: every slice has its legend row
/// in words with its value.
Color homeSliceColor(AppColors colors, ServiceSlice slice, int index) =>
    slice.tail ? ChartPalette(colors).other : ChartPalette(colors).step(index);

/// POL7: the slices as drawn: the top three types by visits (the donut is
/// sized by visits), largest first, then one Other with the rest (owner:
/// three ramp steps, then Other). Display only; the breakdown is unchanged.
List<ServiceSlice> homeDrawnSlices(List<ServiceSlice> slices) => chartSlicesByValue<ServiceSlice>(
      slices,
      value: (s) => s.count,
      isOther: (s) => s.tail || s.key == ServiceSlice.otherKey,
      keep: ChartPalette.maxSteps,
      fold: (rest) => ServiceSlice(
        ServiceSlice.otherKey,
        rest.fold(0, (n, s) => n + s.count),
        rest.fold(0.0, (n, s) => n + s.revenue),
        tail: true,
      ),
    );

/// HUB4 (1): the Visit activity page (it was Vet services): the services
/// provided in the period by type as a donut (serviceBreakdownOf, the ONE
/// breakdown Insights' donut uses too), drawn as the top three types and
/// Other (POL7, homeDrawnSlices), sized
/// by visits, the total visits in its centre; a legend row per type with
/// its visits and share. A tap on a slice or a legend row shows its visits
/// and revenue (no revenue while [hidden]); the centre then shows its
/// visits. No visits: a faint empty ring, one muted line and, when given,
/// Record a visit.
class HomeChartVisitsPage extends StatefulWidget {
  final Future<List<ServiceSlice>> future;
  final HomeChartRange range;
  final bool hidden;
  final VoidCallback? onRecordVisit;

  const HomeChartVisitsPage({
    super.key,
    required this.future,
    required this.range,
    required this.hidden,
    this.onRecordVisit,
  });

  @override
  State<HomeChartVisitsPage> createState() => _HomeChartVisitsPageState();
}

class _HomeChartVisitsPageState extends State<HomeChartVisitsPage> {
  List<ServiceSlice> _slices = const [];
  bool _answered = false;
  int? _chosen;

  @override
  void initState() {
    super.initState();
    widget.future.then(
      (s) {
        if (mounted) {
          setState(() {
            _slices = homeDrawnSlices(s);
            _answered = true;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _answered = true);
      },
    );
  }

  String _name(BuildContext context, ServiceSlice s) =>
      s.key == ServiceSlice.otherKey ? context.l10n.serviceCategory_other : s.key;

  void _choose(int i) => setState(() => _chosen = _chosen == i ? null : i);

  /// The slice under [local] in a donut of [size] drawn from the top,
  /// clockwise; none outside the ring's outer edge.
  int? _sliceAt(Offset local, double size, int total) {
    final d = local - Offset(size / 2, size / 2);
    if (d.distance > size / 2 || total == 0) return null;
    final turn = ((math.atan2(d.dy, d.dx) + math.pi / 2) / (2 * math.pi)) % 1;
    var start = 0.0;
    for (var i = 0; i < _slices.length; i++) {
      start += _slices[i].count / total;
      if (turn < start) return i;
    }
    return _slices.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final span = widget.range.days;
    final total = _slices.fold<int>(0, (n, s) => n + s.count);
    final top = _slices.isEmpty ? null : ([..._slices]..sort((a, b) => b.count.compareTo(a.count))).first;
    final summary = top == null ? l10n.home_chartNoVisits(span) : l10n.home_chartVisitsSummary(total, _name(context, top));
    final body = LayoutBuilder(
      builder: (context, box) {
        final size = math.max(0.0, math.min(box.maxHeight, box.maxWidth * HomeChartMetrics.donutShare));
        return LateSlot(
          ready: _answered,
          child: total == 0
              ? HomeChartEmpty(
                  message: l10n.home_chartNoVisits(span),
                  action: widget.onRecordVisit == null ? null : l10n.home_chartRecordVisit,
                  onAction: widget.onRecordVisit,
                  behind: Align(alignment: Alignment.centerLeft, child: _ring(context, size, const [], 0)),
                )
              : Row(
                  children: [
                    ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final i = _sliceAt(d.localPosition, size, total);
                          if (i != null) _choose(i);
                        },
                        child: _ring(context, size, _slices, total),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: _legend(context, total)),
                  ],
                ),
        );
      },
    );
    return HomeChartPage(
      title: l10n.home_chartVisitActivity,
      period: span == HomeChartRange.month.days ? l10n.services_last30 : l10n.services_last7,
      summary: summary,
      body: body,
    );
  }

  Widget _ring(BuildContext context, double size, List<ServiceSlice> slices, int total) {
    final colors = context.colors;
    final chosen = _chosen;
    final inner = math.max(0.0, size / 2 - HomeChartMetrics.ringWidth - HomeChartMetrics.ringTouched);
    final centre = chosen != null && chosen < slices.length ? slices[chosen].count : total;
    return SizedBox.square(
      key: const ValueKey('home-chart-donut'),
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: HomeChartMetrics.donutStart,
              sectionsSpace: slices.length > 1 ? HomeChartMetrics.sliceGap : 0,
              centerSpaceRadius: inner,
              pieTouchData: PieTouchData(enabled: false),
              sections: slices.isEmpty
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: colors.border,
                        radius: HomeChartMetrics.ringWidth,
                        showTitle: false,
                      ),
                    ]
                  : [
                      for (var i = 0; i < slices.length; i++)
                        PieChartSectionData(
                          value: slices[i].count.toDouble(),
                          color: homeSliceColor(colors, slices[i], i),
                          radius: HomeChartMetrics.ringWidth + (i == chosen ? HomeChartMetrics.ringTouched : 0),
                          showTitle: false,
                        ),
                    ],
            ),
            swapAnimationDuration: Duration.zero,
          ),
          if (slices.isNotEmpty && size >= HomeChartMetrics.donutTextMin)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$centre',
                  key: const ValueKey('home-chart-donut-count'),
                  style: TextStyle(
                    fontSize: HomeChartMetrics.centreCount,
                    fontWeight: AppFontWeight.bold,
                    fontFeatures: _tabular,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.home_visits,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, int total) {
    final colors = context.colors;
    final l10n = context.l10n;
    final chosen = _chosen;
    final style = TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textPrimary);
    String? detail;
    if (chosen != null && chosen < _slices.length) {
      final s = _slices[chosen];
      detail = widget.hidden
          ? l10n.home_chartSliceDetailHidden(_name(context, s), s.count)
          : l10n.home_chartSliceDetail(_name(context, s), s.count, Money.format(s.revenue));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              for (var i = 0; i < _slices.length; i++)
                // Finger only (20 px rows cannot be 48): a screen reader hears the
                // page summary, the legend in words.
                ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('home-chart-slice-$i'),
                    onTap: () => _choose(i),
                    child: SizedBox(
                      height: HomeChartMetrics.legendLine,
                      child: Row(
                        children: [
                          Container(
                            width: HomeChartMetrics.legendSwatch,
                            height: HomeChartMetrics.legendSwatch,
                            decoration: BoxDecoration(
                              color: homeSliceColor(colors, _slices[i], i),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          Expanded(
                            child: Text(
                              _name(context, _slices[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: i == chosen ? style.copyWith(fontWeight: AppFontWeight.semibold) : style,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            l10n.home_chartSliceShare(_slices[i].count, (_slices[i].count / total * 100).round()),
                            style: style.copyWith(fontFeatures: _tabular, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: HomeChartMetrics.legendLine,
          child: detail == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    detail,
                    key: const ValueKey('home-chart-slice-detail'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(fontWeight: AppFontWeight.semibold),
                  ),
                ),
        ),
      ],
    );
  }
}
