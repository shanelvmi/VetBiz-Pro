import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/money.dart';
import '../../data/home_chart_range.dart';
import '../../l10n/l10n.dart';
import '../../models/product.dart';
import '../../services/home_movement.dart';
import '../../services/insights_data_loader.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/reveal/reveal.dart';
import '../products/product_phone_parts.dart';
import 'home_chart_page.dart';

/// Amounts in tabular figures, so digits do not shift as they change.
const _tabular = [FontFeature.tabularFigures()];

/// HUB4 (1): the Product movement page: "Top sellers" (up to 5 ranked rows:
/// the rank, the product's image in the shared RevealImage slot with its
/// initials, the name, a bar in proportion and the quantity) and "Slow
/// movers" (up to 3 products in stock that sold nothing: the name and
/// "n in stock"). Rows are 48 high so a few still look intentional; when
/// they need more room than the page has, the list scrolls inside the page
/// and Home itself never does. A row opens its product's details page.
/// Nothing sold: one line in place of the top sellers, the slow movers
/// still. No products at all: one muted line and, for admins, Add a product.
class HomeChartProductsPage extends StatefulWidget {
  final Future<HomeMovement> future;
  final HomeChartRange range;

  /// The facility has no products (held: ProductProvider).
  final bool noProducts;
  final VoidCallback? onAddProduct;
  final ValueChanged<Product> onOpenProduct;

  const HomeChartProductsPage({
    super.key,
    required this.future,
    required this.range,
    required this.noProducts,
    required this.onOpenProduct,
    this.onAddProduct,
  });

  @override
  State<HomeChartProductsPage> createState() => _HomeChartProductsPageState();
}

class _HomeChartProductsPageState extends State<HomeChartProductsPage> {
  HomeMovement? _movement;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    widget.future.then(
      (m) {
        if (mounted) {
          setState(() {
            _movement = m;
            _answered = true;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _answered = true);
      },
    );
  }

  String _name(BuildContext context, String name) =>
      name == ProductMovement.unknownName ? context.l10n.common_unknown : name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final span = widget.range.days;
    final movement = _movement ?? const HomeMovement(top: [], slow: []);
    final summary = movement.soldNothing
        ? l10n.home_chartNothingSold(span)
        : l10n.home_chartProductsSummary(span, _name(context, movement.top.first.name));
    final Widget content;
    if (widget.noProducts) {
      content = HomeChartEmpty(
        message: l10n.sales_noProductsYet,
        action: widget.onAddProduct == null ? null : l10n.home_chartAddProduct,
        onAction: widget.onAddProduct,
      );
    } else {
      final most = movement.top.isEmpty ? 1.0 : movement.top.first.quantity;
      content = ListView(
        key: const ValueKey('home-chart-movement'),
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [
          _Section(l10n.home_chartTopSellers),
          if (movement.soldNothing)
            _Muted(l10n.home_chartNothingSold(span))
          else
            for (var i = 0; i < movement.top.length; i++)
              _Row(
                key: ValueKey('home-top-$i'),
                rank: i + 1,
                name: _name(context, movement.top[i].name),
                product: movement.top[i].product,
                share: movement.top[i].quantity / most,
                trailing: Money.decimal(movement.top[i].quantity),
                onTap: movement.top[i].product == null ? null : () => widget.onOpenProduct(movement.top[i].product!),
              ),
          if (movement.slow.isNotEmpty) ...[
            _Section(l10n.home_chartSlowMovers),
            for (final p in movement.slow)
              _Row(
                key: ValueKey('home-slow-${p.id}'),
                name: p.name,
                product: p,
                trailing: l10n.home_chartInStock(p.totalStock),
                onTap: () => widget.onOpenProduct(p),
              ),
          ],
        ],
      );
    }
    return HomeChartPage(
      title: l10n.home_chartProducts,
      period: span == HomeChartRange.month.days ? l10n.services_last30 : l10n.services_last7,
      summary: summary,
      body: LateSlot(ready: _answered || widget.noProducts, child: content),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;

  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: HomeChartMetrics.axisLabel,
      fontWeight: AppFontWeight.semibold,
      color: context.colors.textMuted,
    ),
  );
}

class _Muted extends StatelessWidget {
  final String text;

  const _Muted(this.text);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: HomeChartMetrics.movementRow,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        key: const ValueKey('home-chart-nothing-sold'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: HomeChartMetrics.axisLabel, color: context.colors.textMuted),
      ),
    ),
  );
}

/// One 48 px row: [rank] (top sellers only), the image or initials, the
/// name (one line, ellipsis) over a bar of [share] (top sellers only), then
/// [trailing] (the quantity, or "n in stock").
class _Row extends StatelessWidget {
  final int? rank;
  final String name;
  final Product? product;
  final double? share;
  final String trailing;
  final VoidCallback? onTap;

  const _Row({super.key, required this.name, required this.trailing, this.rank, this.product, this.share, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(fontSize: HomeChartMetrics.axisLabel, color: colors.textPrimary);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: HomeChartMetrics.movementRow,
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: HomeChartMetrics.rankWidth,
                child: Text('$rank', style: style.copyWith(fontFeatures: _tabular, color: colors.textMuted)),
              ),
            product == null
                ? _Initials(name)
                : SizedBox.square(
                    dimension: HomeChartMetrics.movementImage,
                    child: FittedBox(child: ProductLeading(product: product!)),
                  ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                  if (share != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    FractionallySizedBox(
                      widthFactor: math.max(HomeChartMetrics.productBarMin, share!),
                      child: Container(
                        height: HomeChartMetrics.productBar,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(HomeChartMetrics.productBar),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(trailing, style: style.copyWith(fontFeatures: _tabular)),
          ],
        ),
      ),
    );
  }
}

/// A sold item no held product matches: its name's initials.
class _Initials extends StatelessWidget {
  final String name;

  const _Initials(this.name);

  @override
  Widget build(BuildContext context) => Container(
    width: HomeChartMetrics.movementImage,
    height: HomeChartMetrics.movementImage,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(HomeChartMetrics.barRadius),
    ),
    child: Text(
      InitialsAvatar.initialsFor(name),
      style: TextStyle(
        fontSize: HomeChartMetrics.axisLabel,
        fontWeight: AppFontWeight.bold,
        color: context.colors.textPrimary,
      ),
    ),
  );
}
