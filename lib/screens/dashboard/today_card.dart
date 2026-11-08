import 'package:flutter/material.dart';

import '../../config/app_defaults.dart';
import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'dashboard_figures.dart';

/// The one Today card: Sales large, the period chip, then Collected, Owed and
/// (admins only, as the Net Profit card's masking today) Net profit, on the
/// brand gradient (NAV1). The eye at the end of the top row masks every
/// amount on the card (and only here); the labels stay.
class TodayCard extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAllDetails;

  /// NAV1: the amounts are masked ([AppDefaults.amountMask]). Only what is
  /// drawn changes; [figures] are the same either way.
  final bool amountsHidden;

  /// The eye; null draws none.
  final VoidCallback? onToggleAmounts;

  const TodayCard({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onAllDetails,
    this.amountsHidden = false,
    this.onToggleAmounts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    String money(double v) => figures.loading ? '—' : Money.format(v);
    final stats = [
      (l10n.sales_collected, money(figures.collected)),
      (l10n.home_owed, Money.format(figures.owed)),
      if (isAdmin) (l10n.home_netProfit, money(figures.netProfit)),
    ];
    return Container(
      padding: const EdgeInsets.all(PhoneHomeMetrics.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brandGradientStart, colors.brandGradientEnd],
        ),
        borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.nav_sales,
                  style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.onBrandSurfaceMuted),
                ),
              ),
              _PeriodChip(period: period, onChanged: onPeriodChanged),
              if (onToggleAmounts != null) _EyeButton(hidden: amountsHidden, onPressed: onToggleAmounts!),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _Amount(
              value: money(figures.sales),
              hidden: amountsHidden,
              style: TextStyle(
                fontSize: PhoneHomeMetrics.salesValue,
                fontWeight: AppFontWeight.bold,
                color: colors.onBrandSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: PhoneHomeMetrics.statGap),
                Expanded(child: _Stat(label: stats[i].$1, value: stats[i].$2, hidden: amountsHidden)),
              ],
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAllDetails,
              style: TextButton.styleFrom(
                foregroundColor: colors.onBrandSurface,
                minimumSize: const Size(PhoneHomeMetrics.linkHeight, PhoneHomeMetrics.linkHeight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.home_allDetails, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                  const Icon(Icons.chevron_right, size: PhoneHomeMetrics.rowIcon),
                ],
              ),
            ),
          ),
        ],
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
            maxLines: 2,
            style: TextStyle(fontSize: PhoneHomeMetrics.label, color: colors.onBrandSurfaceMuted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _Amount(
              value: value,
              hidden: hidden,
              style: TextStyle(
                fontSize: PhoneHomeMetrics.statValue,
                fontWeight: AppFontWeight.bold,
                color: colors.onBrandSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// NAV1: an amount, or the soft mask in its place, with a short cross-fade
/// between the two (not a blur); at once under reduced motion. Keyed on the
/// mask alone, so a new figure is not faded in.
class _Amount extends StatelessWidget {
  final String value;
  final bool hidden;
  final TextStyle style;

  const _Amount({required this.value, required this.hidden, required this.style});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast,
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
        child: Text(
          hidden ? AppDefaults.amountMask : value,
          key: ValueKey(hidden),
          style: style,
        ),
      );
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
                  style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.onBrandSurface),
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

