import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/home_chart_data.dart';
import '../../services/insights_data_loader.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/theme_context.dart';
import 'home_chart_days_page.dart';
import 'home_chart_products_page.dart';

export 'home_chart_page.dart' show homeChartNiceMax;

/// HUB2 (3): Home's chart carousel, three pages in a PageView with dots
/// under it: Sales (the last 7 days as a line with a soft area, the 7 before
/// as a dashed line), Product movement (the top 5 products by quantity in
/// the last 7 days) and Vet services (service revenue per day, the total at
/// the top). It fills the box Home gives it (PhoneHome's chart region).
///
/// Reads: none of its own. [days] is the shared 14-day read (one range get
/// of each daily summary, kept for the session) and is asked when a page
/// that needs it is first built; [products] is asked only when the Product
/// movement page is first shown. Each page's chart is a LateSlot in its
/// reserved box, so a page filling never moves anything.
///
/// A tap anywhere on a page opens Insights; a long press on the Sales or Vet
/// services chart shows that day's exact amount. While [amountsHidden], those
/// two charts keep their shape only: no guide labels, no total, no amounts
/// (Product movement shows quantities, which are not money).
class HomeChartCarousel extends StatefulWidget {
  final Future<HomeChartDays> Function() days;
  final Future<List<ProductMovement>> Function() products;

  /// Today's live sales and service revenue (the card's period totals while
  /// the period is Today); null keeps the read's value for today.
  final double? todaySales;
  final double? todayServices;

  final bool amountsHidden;
  final VoidCallback onOpen;

  const HomeChartCarousel({
    super.key,
    required this.days,
    required this.products,
    required this.amountsHidden,
    required this.onOpen,
    this.todaySales,
    this.todayServices,
  });

  /// The pages, in order.
  static const int pageCount = 3;

  @override
  State<HomeChartCarousel> createState() => _HomeChartCarouselState();
}

class _HomeChartCarouselState extends State<HomeChartCarousel> {
  final _controller = PageController();
  int _page = 0;
  Future<HomeChartDays>? _days;
  Future<List<ProductMovement>>? _products;

  Future<HomeChartDays> get _daysFuture => _days ??= widget.days();
  Future<List<ProductMovement>> get _productsFuture => _products ??= widget.products();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _page0(BuildContext context) => HomeChartDaysPage(
    key: const ValueKey('home-chart-sales'),
    future: _daysFuture,
    title: context.l10n.dashboard_sales,
    legend: true,
    today: widget.todaySales,
    pick: (d) => d.salesThisWeek,
    previous: (d) => d.salesLastWeek,
    hidden: widget.amountsHidden,
    onOpen: widget.onOpen,
  );

  Widget _page1(BuildContext context) =>
      HomeChartProductsPage(key: const ValueKey('home-chart-products'), future: _productsFuture, onOpen: widget.onOpen);

  Widget _page2(BuildContext context) => HomeChartDaysPage(
    key: const ValueKey('home-chart-services'),
    future: _daysFuture,
    title: context.l10n.home_vetServices,
    bars: true,
    today: widget.todayServices,
    pick: (d) => d.servicesThisWeek,
    hidden: widget.amountsHidden,
    onOpen: widget.onOpen,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final still = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        Expanded(
          // Each page is inset on both sides, and the pages are that much
          // wider than the region, so a page lines up with the card above
          // and two pages show a gap while swiping.
          child: LayoutBuilder(
            builder:
                (context, constraints) => OverflowBox(
                  minWidth: constraints.maxWidth + 2 * HomeChartMetrics.pageInset,
                  maxWidth: constraints.maxWidth + 2 * HomeChartMetrics.pageInset,
                  child: PageView.builder(
                    key: const ValueKey('home-chart-pages'),
                    controller: _controller,
                    itemCount: HomeChartCarousel.pageCount,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder:
                        (context, i) => switch (i) {
                          0 => _page0(context),
                          1 => _page1(context),
                          _ => _page2(context),
                        },
                  ),
                ),
          ),
        ),
        ExcludeSemantics(
          child: SizedBox(
            height: HomeChartMetrics.dotsHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ],
    );
  }
}
