import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../../config/app_defaults.dart';
import '../../config/money.dart';
import '../../data/home_card_mode.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/press_scale.dart';
import 'dashboard_figures.dart';

/// Amounts in tabular figures, so digits do not shift as they change.
const _tabular = [FontFeature.tabularFigures()];

/// The one Today card on the brand gradient (NAV1), HUB2's three rows: the
/// Sales | Vet services switch with the exact range under it, and the period
/// chip; the big amount with the eye at the row's right end (it hides every
/// amount on the card, and only here); three figures, then a chevron. Sales:
/// Collected, Owed and (admins only, as the Net Profit card's masking today)
/// Net profit. Vet services: the service revenue, then Visits, Collected and
/// Owed (the brief's FALLBACK: the daily service summaries hold no paid or
/// outstanding amount, so services alone cannot be split without a new
/// read). The whole card is one tap target opening All details, and a
/// horizontal swipe switches; the switch, the chip and the eye are their own
/// buttons. Its loaded size is the same for both choices, hidden or shown,
/// with or without sales, in every period.
class TodayCard extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAllDetails;

  /// UI5: the exact range the figures cover ("Mon 9 Nov", "3–9 Nov"), from
  /// dashboardPeriodRangeLabel over the range the totals are watched over.
  final String periodLabel;

  /// NAV1: the amounts are masked (UI3: soft blurred dots after the
  /// currency). Only what is drawn changes; [figures] are the same either way.
  final bool amountsHidden;

  /// The eye; null draws none.
  final VoidCallback? onToggleAmounts;

  /// HUB2: what the card shows, Sales or Vet services, and the switch's
  /// choice (a tap on an option or a horizontal swipe on the card).
  final HomeCardMode mode;
  final ValueChanged<HomeCardMode>? onModeChanged;

  const TodayCard({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onAllDetails,
    this.periodLabel = '',
    this.amountsHidden = false,
    this.onToggleAmounts,
    this.mode = HomeCardMode.sales,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    String money(double v) => figures.loading ? '—' : Money.format(v);
    final services = mode == HomeCardMode.services;
    // (label, value, is money: the eye hides money only; Visits is a count).
    final stats = services
        ? [
            (l10n.home_visits, figures.loading ? '—' : Money.decimal(figures.visits), false),
            (l10n.sales_collected, money(figures.collected), true),
            (l10n.home_owed, Money.format(figures.owed), true),
          ]
        : [
            (l10n.sales_collected, money(figures.collected), true),
            (l10n.home_owed, Money.format(figures.owed), true),
            if (isAdmin) (l10n.home_netProfit, money(figures.netProfit), true),
          ];
    final amount = services ? figures.serviceRevenue : figures.sales;
    final none = !figures.loading && amount == 0;
    void swipe(DragEndDetails details) {
      final velocity = details.primaryVelocity ?? 0;
      if (onModeChanged == null || velocity.abs() < HomeCardMetrics.swipeVelocity) return;
      // Left brings the second option, right the first.
      final next = velocity < 0 ? HomeCardMode.services : HomeCardMode.sales;
      if (next != mode) onModeChanged!(next);
    }

    return PressScale(
      child: GestureDetector(
        onHorizontalDragEnd: swipe,
        child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.brandGradientStart, colors.brandGradientEnd],
          ),
          borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            // One button for the card; the chip, the eye and the figures keep
            // their own nodes inside it.
            container: true,
            explicitChildNodes: true,
            button: true,
            label: l10n.home_allDetails,
            child: InkWell(
              key: const ValueKey('phone-home-today-card'),
              borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
              onTap: onAllDetails,
              child: Padding(
                // The chip and the eye bring their own 48 px targets, so the
                // card's top and right edges are mostly theirs.
                padding: const EdgeInsets.fromLTRB(
                  PhoneHomeMetrics.cardPadding,
                  AppSpacing.s4,
                  AppSpacing.s4,
                  PhoneHomeMetrics.cardPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _ModeSwitch(mode: mode, onChanged: onModeChanged),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        _PeriodChip(period: period, onChanged: onPeriodChanged),
                      ],
                    ),
                    // UI5's exact range, under the switch.
                    Text(
                      periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: HomeCardMetrics.rangeLabel, color: colors.onBrandSurfaceMuted),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Amount(
                                value: money(amount),
                                hidden: amountsHidden,
                                blur: PhoneHomeMetrics.maskBlurLarge,
                                style: TextStyle(
                                  fontSize: PhoneHomeMetrics.salesValue,
                                  fontWeight: AppFontWeight.semibold,
                                  fontFeatures: _tabular,
                                  color: colors.onBrandSurface,
                                ),
                              ),
                              // Always laid out, shown only when there is nothing, so
                              // the card keeps one height.
                              Visibility(
                                visible: none,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: Text(
                                  services ? l10n.home_noVisitsYet : l10n.home_noSalesYet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurfaceMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onToggleAmounts != null) _EyeButton(hidden: amountsHidden, onPressed: onToggleAmounts!),
                      ],
                    ),
                    const SizedBox(height: PhoneHomeMetrics.cardRowGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: PhoneHomeMetrics.statGap),
                          Expanded(child: _Stat(label: stats[i].$1, value: stats[i].$2, hidden: amountsHidden && stats[i].$3)),
                        ],
                        ExcludeSemantics(
                          child: Icon(Icons.chevron_right, size: PhoneHomeMetrics.rowIcon, color: colors.onBrandSurface),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool hidden;

  const _Stat({required this.label, required this.value, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurfaceMuted),
          ),
          _Amount(
            value: value,
            hidden: hidden,
            blur: PhoneHomeMetrics.maskBlurSmall,
            // UI5 made the values 14: the dots keep UI3's size (0.3 of 15), so
            // the 1.4 blur keeps its centre at 3:1 (at 14 it fell to 2.98).
            dotBase: PhoneHomeMetrics.statValue,
            style: TextStyle(
              fontSize: PhoneHomeMetrics.cardValue,
              fontWeight: AppFontWeight.semibold,
              fontFeatures: _tabular,
              color: colors.onBrandSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// NAV1: an amount, or (UI3) the soft blurred dots in its place, with a short
/// cross-fade between the two; at once under reduced motion. Keyed on the
/// mask alone, so a new figure is not faded in. The slot is one line of
/// [style] high either way, so hiding never changes the card's size, even
/// when a long amount is scaled down to fit.
class _Amount extends StatelessWidget {
  final String value;
  final bool hidden;
  final TextStyle style;

  /// The dots' Gaussian blur (sigma).
  final double blur;

  /// The text size the dots are a fraction of (null: the style's).
  final double? dotBase;

  const _Amount({required this.value, required this.hidden, required this.style, required this.blur, this.dotBase});

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: AppDefaults.currencySymbol, style: DefaultTextStyle.of(context).style.merge(style)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    return SizedBox(
      height: lineHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
          // While hidden the amount's Text is not built at all: the digits
          // are in neither the widget nor the semantics tree.
          child: hidden
              ? _HiddenAmount(key: const ValueKey(true), style: style, blur: blur, dotBase: dotBase)
              : Text(value, key: const ValueKey(false), style: style),
        ),
      ),
    );
  }
}

/// UI3: the currency, then four soft blurred dots: a fixed placeholder that
/// never depends on the amount. The dots are about 0.3 of the text size, in
/// the text's colour at 70 percent.
class _HiddenAmount extends StatelessWidget {
  final TextStyle style;
  final double blur;

  /// The text size the dots are a fraction of (null: the style's).
  final double? dotBase;

  const _HiddenAmount({super.key, required this.style, required this.blur, this.dotBase});

  @override
  Widget build(BuildContext context) {
    final dot = MediaQuery.textScalerOf(context).scale(dotBase ?? style.fontSize!) * PhoneHomeMetrics.maskDot;
    final fill = style.color!.withValues(alpha: PhoneHomeMetrics.maskAlpha);
    return Semantics(
      label: context.l10n.home_amountHidden,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppDefaults.currencySymbol, style: style),
          SizedBox(width: dot),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < PhoneHomeMetrics.maskDots; i++) ...[
                  if (i > 0) SizedBox(width: dot * PhoneHomeMetrics.maskDotGap),
                  SizedBox.square(
                    dimension: dot,
                    child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: fill)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// NAV1: the eye at the end of the card's top row: a 48 target whose tooltip
/// and screen-reader label say what a tap does.
class _EyeButton extends StatelessWidget {
  final bool hidden;
  final VoidCallback onPressed;

  const _EyeButton({required this.hidden, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: hidden ? context.l10n.home_showAmounts : context.l10n.home_hideAmounts,
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: PhoneHomeMetrics.linkHeight,
          minHeight: PhoneHomeMetrics.linkHeight,
        ),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: PhoneHomeMetrics.eyeIcon,
          color: context.colors.onBrandSurface,
        ),
      );
}

/// HUB2: the card's Sales | Vet services switch: a faint outlined track
/// [HomeCardMetrics.segmentHeight] high, the chosen option filled as the period
/// chip is (a soft fill, full ink; the other muted ink: never a bright box,
/// which Dark would not allow), each option a 48 high target;| Vet services switch: a soft track
/// [HomeCardMetrics.segmentHeight] high with the chosen option filled, each
/// option a 48 high target; a label too long for a narrow card ends in an
/// ellipsis rather than pushing the chip out.
class _ModeSwitch extends StatelessWidget {
  final HomeCardMode mode;
  final ValueChanged<HomeCardMode>? onChanged;

  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast;
    const pill = HomeCardMetrics.segmentHeight - 2 * HomeCardMetrics.segmentInset;
    return SizedBox(
      height: PhoneHomeMetrics.linkHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                height: HomeCardMetrics.segmentHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.onBrandSurfaceSubtle),
                  borderRadius: BorderRadius.circular(HomeCardMetrics.segmentHeight),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HomeCardMetrics.segmentInset),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in HomeCardMode.values)
                  Flexible(
                    child: Semantics(
                      key: ValueKey('home-card-mode-${m.key}'),
                      container: true,
                      button: true,
                      selected: m == mode,
                      inMutuallyExclusiveGroup: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onChanged == null || m == mode ? null : () => onChanged!(m),
                        child: SizedBox(
                          height: PhoneHomeMetrics.linkHeight,
                          child: Center(
                            child: AnimatedContainer(
                              duration: duration,
                              height: pill,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: HomeCardMetrics.segmentPadding),
                              decoration: BoxDecoration(
                                color: colors.onBrandSurface.withValues(alpha: m == mode ? PhoneHomeMetrics.circleAlpha : 0),
                                borderRadius: BorderRadius.circular(pill),
                              ),
                              child: Text(
                                m == HomeCardMode.sales ? l10n.dashboard_sales : l10n.home_vetServices,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: HomeCardMetrics.segmentLabel,
                                  fontWeight: AppFontWeight.semibold,
                                  color: m == mode ? colors.onBrandSurface : colors.onBrandSurfaceMuted,
                                ),
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
        ],
      ),
    );
  }
}

/// The date chip: today's period picker (Today, This Week, This Month, This
/// Year), 36 high in a 48 target.
class _PeriodChip extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const _PeriodChip({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return PopupMenuButton<String>(
      tooltip: l10n.dashboard_changePeriod,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final p in dashboardPeriods) PopupMenuItem(value: p, child: Text(dashboardPeriodLabel(l10n, p))),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.linkHeight),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: PhoneHomeMetrics.chipHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            decoration: BoxDecoration(
              color: colors.onBrandSurface.withValues(alpha: PhoneHomeMetrics.circleAlpha),
              borderRadius: BorderRadius.circular(PhoneHomeMetrics.chipHeight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: PhoneHomeMetrics.chipIcon, color: colors.onBrandSurface),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  dashboardPeriodLabel(l10n, period),
                  style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurface),
                ),
                Icon(Icons.arrow_drop_down, size: PhoneHomeMetrics.rowIcon, color: colors.onBrandSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

