import 'package:flutter/material.dart';

import '../../data/home_card_mode.dart';
import '../../data/home_chart_range.dart';
import '../../l10n/l10n.dart';
import '../../models/product.dart';
import '../../services/home_chart_data.dart';
import '../../services/home_movement.dart';
import '../../services/service_breakdown.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'home_chart_days_page.dart';
import 'home_chart_products_page.dart';
import 'home_chart_visits_page.dart';

export 'home_chart_page.dart' show homeChartNiceMax, homeChartGuides, homeChartDayLabelled;

/// HUB2 (3), HUB4: Home's chart carousel: a header row (the dots at the
/// left, the small 7d | 30d switch at the right) over three pages that are
/// always swipeable, in this order: Sales (a line), Product movement (top
/// sellers and slow movers) and Visit activity (a donut by service type).
/// The pages share one height and top, so a swipe never moves anything.
///
/// Reads: none of its own. Each page asks its data the first time it is
/// shown, once per range: [days] is the shared summary read (14 days, or 60
/// for 30d), [movement] the shared sales window with the held products,
/// [visits] the shared services window.
///
/// TWO-WAY SYNC with the card's switch ([mode]): a new [mode] from the card
/// scrolls to Sales (page 1) or Visit activity (page 3), animated (at once
/// under reduced motion); a swipe reports its page's mode through
/// [onModeChanged] (Product movement belongs to Sales). A change made here
/// is never sent back (no loops), and the pages it scrolls past report
/// nothing.
class HomeChartCarousel extends StatefulWidget {
  final Future<HomeChartDays> Function(HomeChartRange range) days;
  final Future<HomeMovement> Function(HomeChartRange range) movement;
  final Future<List<ServiceSlice>> Function(HomeChartRange range) visits;

  final HomeChartRange range;
  final ValueChanged<HomeChartRange> onRangeChanged;

  final HomeCardMode mode;
  final ValueChanged<HomeCardMode>? onModeChanged;

  /// Today's live sales (the card's Today total); null keeps the read's.
  final double? todaySales;
  final bool amountsHidden;

  /// The facility has no products (Product movement's empty state).
  final bool noProducts;

  /// The empty pages' actions, through the record guard (null: not offered).
  final VoidCallback? onRecordSale;
  final VoidCallback? onRecordVisit;
  final VoidCallback? onAddProduct;
  final ValueChanged<Product> onOpenProduct;

  const HomeChartCarousel({
    super.key,
    required this.days,
    required this.movement,
    required this.visits,
    required this.range,
    required this.onRangeChanged,
    required this.amountsHidden,
    required this.onOpenProduct,
    this.mode = HomeCardMode.sales,
    this.onModeChanged,
    this.todaySales,
    this.noProducts = false,
    this.onRecordSale,
    this.onRecordVisit,
    this.onAddProduct,
  });

  /// The pages, in order.
  static const int pageCount = 3;
  static const int salesPage = 0;
  static const int visitsPage = 2;

  /// The card's mode a page belongs to.
  static HomeCardMode modeOf(int page) => page == visitsPage ? HomeCardMode.services : HomeCardMode.sales;

  /// The page a card's mode scrolls to.
  static int pageOf(HomeCardMode mode) => mode == HomeCardMode.services ? visitsPage : salesPage;

  @override
  State<HomeChartCarousel> createState() => _HomeChartCarouselState();
}

class _HomeChartCarouselState extends State<HomeChartCarousel> {
  late final PageController _controller;
  late int _page;

  // True while this widget scrolls to follow the card: the pages passed on
  // the way report nothing.
  bool _following = false;

  final _days = <HomeChartRange, Future<HomeChartDays>>{};
  final _movement = <HomeChartRange, Future<HomeMovement>>{};
  final _visits = <HomeChartRange, Future<List<ServiceSlice>>>{};

  @override
  void initState() {
    super.initState();
    _page = HomeChartCarousel.pageOf(widget.mode);
    _controller = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(HomeChartCarousel old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode && HomeChartCarousel.modeOf(_page) != widget.mode) {
      _follow(HomeChartCarousel.pageOf(widget.mode));
    }
  }

  Future<void> _follow(int target) async {
    if (!_controller.hasClients) return;
    _following = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      await _controller.animateToPage(target, duration: AppMotion.pageSlide, curve: AppMotion.pageSlideCurve);
    }
    _following = false;
    if (mounted) setState(() => _page = target);
  }

  void _pageChanged(int i) {
    setState(() => _page = i);
    if (_following) return;
    final mode = HomeChartCarousel.modeOf(i);
    if (mode != widget.mode) widget.onModeChanged?.call(mode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pageAt(int i) {
    final range = widget.range;
    return switch (i) {
      0 => HomeChartSalesPage(
        key: ValueKey('home-chart-sales-${range.key}'),
        future: _days[range] ??= widget.days(range),
        range: range,
        today: widget.todaySales,
        hidden: widget.amountsHidden,
        onRecordSale: widget.onRecordSale,
      ),
      1 => HomeChartProductsPage(
        key: ValueKey('home-chart-products-${range.key}'),
        future: widget.noProducts
            ? Future.value(const HomeMovement(top: [], slow: []))
            : _movement[range] ??= widget.movement(range),
        range: range,
        noProducts: widget.noProducts,
        onAddProduct: widget.onAddProduct,
        onOpenProduct: widget.onOpenProduct,
      ),
      _ => HomeChartVisitsPage(
        key: ValueKey('home-chart-visits-${range.key}'),
        future: _visits[range] ??= widget.visits(range),
        range: range,
        hidden: widget.amountsHidden,
        onRecordVisit: widget.onRecordVisit,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final still = MediaQuery.disableAnimationsOf(context);
    final pages = Column(
      children: [
        SizedBox(
          height: HomeChartMetrics.header,
          child: Row(
            children: [
              const SizedBox(width: HomeChartMetrics.pageInset),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < HomeChartCarousel.pageCount; i++)
                      AnimatedContainer(
                        key: ValueKey('home-chart-dot-$i'),
                        duration: still ? Duration.zero : AppMotion.fast,
                        margin: const EdgeInsets.symmetric(horizontal: HomeChartMetrics.dotMargin),
                        width: i == _page ? HomeChartMetrics.dotActive : HomeChartMetrics.dot,
                        height: HomeChartMetrics.dot,
                        decoration: BoxDecoration(
                          color: i == _page ? colors.primary : colors.textHint,
                          borderRadius: BorderRadius.circular(HomeChartMetrics.dot),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // Each page is inset on both sides, and the pages are that much
          // wider than the region, so a page lines up with the card above
          // and two pages show a gap while swiping.
          child: LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              minWidth: constraints.maxWidth + 2 * HomeChartMetrics.pageInset,
              maxWidth: constraints.maxWidth + 2 * HomeChartMetrics.pageInset,
              child: PageView.builder(
                key: const ValueKey('home-chart-pages'),
                controller: _controller,
                itemCount: HomeChartCarousel.pageCount,
                onPageChanged: _pageChanged,
                itemBuilder: (context, i) => _pageAt(i),
              ),
            ),
          ),
        ),
      ],
    );
    // The switch over the header's right end: drawn in the header, its
    // touch area reaching into the page's top padding (painted last, so it
    // takes those taps first).
    return Stack(
      children: [
        Positioned.fill(child: pages),
        Positioned(
          top: (HomeChartMetrics.header - HomeChartMetrics.rangeHeight) / 2,
          right: HomeChartMetrics.pageInset,
          child: _RangeSwitch(range: widget.range, onChanged: widget.onRangeChanged),
        ),
      ],
    );
  }
}

/// HUB4: the small 7d | 30d switch, [HomeChartMetrics.header] high: the
/// chosen option filled with the primary role, as the card's switch.
class _RangeSwitch extends StatelessWidget {
  final HomeChartRange range;
  final ValueChanged<HomeChartRange> onChanged;

  const _RangeSwitch({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    const radius = Radius.circular(HomeChartMetrics.rangeHeight / 2);
    final options = HomeChartRange.values;
    return Semantics(
      container: true,
      label: l10n.home_chartRangeLabel,
      child: SizedBox(
        key: const ValueKey('home-chart-range'),
        height: HomeChartMetrics.target,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < options.length; i++)
              Semantics(
                button: true,
                selected: options[i] == range,
                child: GestureDetector(
                  key: ValueKey('home-chart-range-${options[i].key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: options[i] == range ? null : () => onChanged(options[i]),
                  child: SizedBox(
                    height: HomeChartMetrics.target,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: HomeChartMetrics.rangeHeight,
                        constraints: const BoxConstraints(minWidth: HomeChartMetrics.rangeSegment),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: options[i] == range ? colors.primary : colors.surface,
                          border: Border.all(color: options[i] == range ? colors.primary : colors.border),
                          borderRadius: BorderRadius.horizontal(
                            left: i == 0 ? radius : Radius.zero,
                            right: i == options.length - 1 ? radius : Radius.zero,
                          ),
                        ),
                        child: Text(
                          options[i] == HomeChartRange.week ? l10n.home_chartRange7d : l10n.home_chartRange30d,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: HomeChartMetrics.axisLabel,
                            fontWeight: AppFontWeight.semibold,
                            color: options[i] == range ? colors.onPrimary : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
