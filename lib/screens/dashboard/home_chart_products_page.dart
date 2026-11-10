import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../services/insights_data_loader.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/reveal/reveal.dart';
import 'home_chart_page.dart';

/// Amounts in tabular figures, so digits do not shift as they change.
const _tabular = [FontFeature.tabularFigures()];

/// The top 5 products by quantity in the last 7 days, as horizontal bars
/// with their names (one line, ellipsis) and quantities: as many rows as the
/// box holds.
class HomeChartProductsPage extends StatefulWidget {
  final Future<List<ProductMovement>> future;
  final VoidCallback onOpen;

  const HomeChartProductsPage({super.key, required this.future, required this.onOpen});

  @override
  State<HomeChartProductsPage> createState() => _HomeChartProductsPageState();
}

class _HomeChartProductsPageState extends State<HomeChartProductsPage> {
  List<ProductMovement>? _top;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    widget.future.then(
      (t) {
        if (mounted) {
          setState(() {
            _top = t;
            _answered = true;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _answered = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = _top ?? const <ProductMovement>[];
    final style = TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textPrimary);
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final row = math.max(
          HomeChartMetrics.productRow,
          MediaQuery.textScalerOf(context).scale(HomeChartMetrics.axisLabel) * HomeChartMetrics.lineHeight,
        );
        final fit =
            ((constraints.maxHeight + HomeChartMetrics.productGap) / (row + HomeChartMetrics.productGap)).floor();
        final shown = top.take(math.max(1, fit)).toList();
        final most = top.isEmpty ? 1.0 : top.first.quantity;
        return LateSlot(
          ready: _answered,
          child:
              top.isEmpty
                  ? const HomeChartEmpty()
                  : Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(height: HomeChartMetrics.productGap),
                        SizedBox(
                          height: row,
                          child: Row(
                            children: [
                              Expanded(
                                flex: HomeChartMetrics.productNameFlex,
                                child: Text(
                                  shown[i].name == ProductMovement.unknownName
                                      ? context.l10n.common_unknown
                                      : shown[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                flex: HomeChartMetrics.productBarFlex,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: math.max(HomeChartMetrics.productBarMin, shown[i].quantity / most),
                                    child: Container(
                                      height: HomeChartMetrics.productBar,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        borderRadius: BorderRadius.circular(HomeChartMetrics.productBar),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Text(Money.decimal(shown[i].quantity), style: style.copyWith(fontFeatures: _tabular)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
        );
      },
    );
    return HomeChartPage(title: context.l10n.home_chartProducts, body: body, onOpen: widget.onOpen);
  }
}
