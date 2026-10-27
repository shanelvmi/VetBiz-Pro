import 'package:flutter/material.dart';

import '../config/app_limits.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

// The small parts of the login page's Updates (AN2), shared by the slide and
// the carousel: the chip, the label row and the dots. Roles and tokens only.

/// AN4: where the Updates sit. [wide]: in the left card beside the login
/// card (UpdatesCard), at that card's height: the label larger, the controls
/// pinned to the bottom. Otherwise (phones, and alone): natural height.
class UpdatesPlacement extends InheritedWidget {
  const UpdatesPlacement({super.key, required this.wide, required super.child});

  final bool wide;

  static bool wideOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UpdatesPlacement>()?.wide ?? false;

  @override
  bool updateShouldNotify(UpdatesPlacement oldWidget) => wide != oldWidget.wide;
}

/// A small text chip of the login page's Updates (AN2): Important or New.
/// On a text slide it sits inside the frame; on a poster, in the label row
/// above it, never on the image.
class UpdateChip extends StatelessWidget {
  const UpdateChip.important({super.key}) : important = true;
  const UpdateChip.fresh({super.key}) : important = false;

  final bool important;

  @override
  Widget build(BuildContext context) {
    // AN4: scaled with the label (12 px beside 16, 14 beside 18).
    final size = UpdatesPlacement.wideOf(context) ? AppFontSize.f14 : AppFontSize.f12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: important ? context.colors.danger : context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Text(
        important ? context.l10n.updates_important : context.l10n.updates_new,
        style: TextStyle(color: context.colors.onPrimary, fontSize: size, fontWeight: AppFontWeight.bold),
      ),
    );
  }
}

/// The Updates' dots, with 48 px hit areas, and arrows when [arrows] (wide
/// windows). AN4: arrows and dots in textMuted (3:1 or more on the card in
/// every theme, Light and Dark; textDisabled was 1.9:1), the selected dot
/// larger as well as primary, so the state is not colour alone. [onSelect] gets the slide to show,
/// possibly past either end; the caller wraps it.
class UpdatesDots extends StatelessWidget {
  const UpdatesDots({
    super.key,
    required this.count,
    required this.index,
    required this.arrows,
    required this.reduceMotion,
    required this.onSelect,
  });

  final int count;
  final int index;
  final bool arrows;
  final bool reduceMotion;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (arrows)
          IconButton(
            tooltip: l10n.updates_previous,
            onPressed: () => onSelect(index - 1 + count),
            icon: Icon(Icons.arrow_back, size: AppIconSize.i18, color: context.colors.textMuted),
          ),
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            selected: i == index,
            label: l10n.updates_slideOf(i + 1, count),
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onSelect(i),
              radius: kMinInteractiveDimension / 2,
              child: SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: Center(
                  child: AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : AppMotion.fast,
                    width: i == index ? UpdatesMetrics.dotSelected : UpdatesMetrics.dot,
                    height: i == index ? UpdatesMetrics.dotSelected : UpdatesMetrics.dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index ? context.colors.primary : context.colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (arrows)
          IconButton(
            tooltip: l10n.updates_next,
            onPressed: () => onSelect(index + 1),
            icon: Icon(Icons.arrow_forward, size: AppIconSize.i18, color: context.colors.textMuted),
          ),
      ],
    );
  }
}

/// "Updates" above the frame; a poster's Important and New beside it (never
/// on the image). Always the same height, so nothing moves between slides;
/// a long label shortens with an ellipsis and the chips keep their place.
/// AN4: 16 px on phones, 18 px on wide windows, semibold. No icon, no chevron.
/// AN5: bold, in textPrimary (textMuted read faded in Light).
class UpdatesLabel extends StatelessWidget {
  const UpdatesLabel({super.key, required this.showChips, required this.urgent, required this.isNew});

  static const rowKey = Key('updatesLabelRow');

  final bool showChips;
  final bool urgent;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final wide = UpdatesPlacement.wideOf(context);
    return SizedBox(
      key: rowKey,
      height: wide ? UpdatesMetrics.labelRowWide : UpdatesMetrics.labelRowPhone,
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.updates_label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: wide ? AppFontSize.f18 : AppFontSize.f16,
                fontWeight: AppFontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (showChips && urgent) ...[const SizedBox(width: AppSpacing.s8), const UpdateChip.important()],
          if (showChips && isNew) ...[const SizedBox(width: AppSpacing.s6), const UpdateChip.fresh()],
        ],
      ),
    );
  }
}

/// G6: the Updates area while their first answer is pending, when the last
/// read on this device had some (UpdatesLastKnown): the label row and the
/// empty 16:9 frame, as tall as one slide, so the page does not jump when
/// they arrive. Nothing to read in it. AN4: in the wide card it also keeps
/// the controls' line at the bottom, as the slides do.
class UpdatesSkeleton extends StatelessWidget {
  const UpdatesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = UpdatesPlacement.wideOf(context);
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UpdatesLabel(showChips: false, urgent: false, isNew: false),
          const SizedBox(height: AppSpacing.s6),
          AspectRatio(
            aspectRatio: AppLimits.posterAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r16),
              child: ColoredBox(color: context.colors.surfaceMuted),
            ),
          ),
          if (wide) ...[const Spacer(), const SizedBox(height: kMinInteractiveDimension)],
        ],
      ),
    );
  }
}
