import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

// The small parts of the login page's Updates (AN2), shared by the slide and
// the carousel: the chip, the label row and the dots. Roles and tokens only.

/// A small text chip of the login page's Updates (AN2): Important or New.
/// On a text slide it sits inside the frame; on a poster, in the label row
/// above it, never on the image.
class UpdateChip extends StatelessWidget {
  const UpdateChip.important({super.key}) : important = true;
  const UpdateChip.fresh({super.key}) : important = false;

  final bool important;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: important ? context.colors.danger : context.colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Text(
        important ? context.l10n.updates_important : context.l10n.updates_new,
        style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f10, fontWeight: AppFontWeight.bold),
      ),
    );
  }
}

/// The Updates' dots, with 48 px hit areas (the selected one clear), and
/// arrows when [arrows] (wide windows). [onSelect] gets the slide to show,
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
                    width: i == index ? AppSpacing.s10 : AppSpacing.s8,
                    height: i == index ? AppSpacing.s10 : AppSpacing.s8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index ? context.colors.primary : context.colors.textDisabled,
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

/// "Updates", quiet, above the frame; a poster's Important and New beside it
/// (never on the image). Always the same height, so nothing moves between
/// slides. No icon, no chevron.
class UpdatesLabel extends StatelessWidget {
  const UpdatesLabel({super.key, required this.showChips, required this.urgent, required this.isNew});

  static const rowKey = Key('updatesLabelRow');

  final bool showChips;
  final bool urgent;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: rowKey,
      height: AppSpacing.s24,
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.updates_label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted),
            ),
          ),
          if (showChips && urgent) ...[const SizedBox(width: AppSpacing.s8), const UpdateChip.important()],
          if (showChips && isNew) ...[const SizedBox(width: AppSpacing.s6), const UpdateChip.fresh()],
        ],
      ),
    );
  }
}
