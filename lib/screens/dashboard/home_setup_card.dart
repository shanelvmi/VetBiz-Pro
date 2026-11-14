import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_sheet.dart';
import 'home_setup.dart';
import 'needs_attention.dart' show AttentionCountBadge;

/// A step's text.
String homeSetupStepLabel(AppLocalizations l10n, HomeSetupStep step) => switch (step) {
      HomeSetupStep.addProduct => l10n.home_setupAddProduct,
      HomeSetupStep.addClient => l10n.home_setupAddClient,
      HomeSetupStep.recordSale => l10n.home_setupRecordSale,
    };

/// HUB4b: the phone Home's first-time "Set up your facility" card, in the
/// attention strip's place (never with it). A header with Hide, at most two
/// steps (done or not), then an "n more" line opening a sheet of every step.
/// Its height depends only on the number of steps ([heightFor]), so it never
/// moves what is under it when a step is done. A step's tap goes to [onStep]
/// (the panel tile's guard and form).
class HomeSetupCard extends StatelessWidget {
  final List<HomeSetupItem> items;
  final ValueChanged<HomeSetupStep> onStep;
  final VoidCallback onHide;

  /// A short screen ([PhoneHomeMetrics.setupFullMinScreenHeight]): the
  /// strip's shape and height, one line opening the sheet (steps and Hide).
  final bool compact;

  const HomeSetupCard({
    super.key,
    required this.items,
    required this.onStep,
    required this.onHide,
    this.compact = false,
  });

  static double heightFor(int count, {bool compact = false}) {
    if (compact) return PhoneHomeMetrics.attentionStripHeight;
    const visible = PhoneHomeMetrics.setupVisibleRows;
    return PhoneHomeMetrics.setupHeader +
        math.min(count, visible) * PhoneHomeMetrics.setupRow +
        (count > visible ? PhoneHomeMetrics.setupRow : 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    const visible = PhoneHomeMetrics.setupVisibleRows;
    final more = items.length - visible;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PhoneHomeMetrics.cardRadius),
      side: BorderSide(color: colors.border),
    );
    if (compact) {
      final toDo = items.where((i) => !i.done).length;
      return Semantics(
        button: true,
        label: '${l10n.home_setupTitle}. ${l10n.home_setupMore(toDo)}',
        excludeSemantics: true,
        child: Material(
          key: const ValueKey('phone-home-setup'),
          color: colors.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('phone-home-setup-more'),
            onTap: () => showHomeSetupSheet(context, items: items, onStep: onStep, onHide: onHide),
            child: SizedBox(
              height: heightFor(items.length, compact: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding),
                child: Row(
                  children: [
                    Icon(Icons.checklist, size: PhoneHomeMetrics.rowIcon, color: colors.primary),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        l10n.home_setupTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: PhoneHomeMetrics.cardLine,
                          fontWeight: AppFontWeight.semibold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (toDo > 0) ...[
                      const SizedBox(width: AppSpacing.s8),
                      AttentionCountBadge(count: toDo),
                    ],
                    Icon(Icons.chevron_right, color: colors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      key: const ValueKey('phone-home-setup'),
      color: colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: heightFor(items.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: PhoneHomeMetrics.setupHeader,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: PhoneHomeMetrics.cardPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.home_setupTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: PhoneHomeMetrics.cardLine,
                            fontWeight: AppFontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('phone-home-setup-hide'),
                      onPressed: onHide,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                      ),
                      child: Text(l10n.home_setupHide),
                    ),
                  ],
                ),
              ),
            ),
            for (final item in items.take(visible)) HomeSetupRow(item: item, onTap: () => onStep(item.step)),
            if (more > 0)
              _MoreLine(
                text: l10n.home_setupMore(more),
                onTap: () => showHomeSetupSheet(context, items: items, onStep: onStep),
              ),
          ],
        ),
      ),
    );
  }
}

/// One step: a check (done) or an empty circle, the text, a chevron.
class HomeSetupRow extends StatelessWidget {
  final HomeSetupItem item;
  final VoidCallback onTap;

  const HomeSetupRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final label = homeSetupStepLabel(l10n, item.step);
    return Semantics(
      button: true,
      label: item.done ? l10n.home_setupStepDone(label) : l10n.home_setupStepToDo(label),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('phone-home-setup-${item.step.name}'),
        onTap: onTap,
        child: SizedBox(
          height: PhoneHomeMetrics.setupRow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding),
            child: Row(
              children: [
                Icon(
                  item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: PhoneHomeMetrics.rowIcon,
                  color: item.done ? colors.successStrong : colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: PhoneHomeMetrics.cardLine,
                      color: item.done ? colors.textMuted : colors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreLine extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _MoreLine({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('phone-home-setup-more'),
        onTap: onTap,
        child: SizedBox(
          height: PhoneHomeMetrics.setupRow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.cardPadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: PhoneHomeMetrics.cardLine,
                      fontWeight: AppFontWeight.semibold,
                      color: colors.primary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every step in a sheet; a tap closes it and opens the step's form. With
/// [onHide] (the compact card, which has no Hide of its own) a Hide button
/// at the end.
Future<void> showHomeSetupSheet(
  BuildContext context, {
  required List<HomeSetupItem> items,
  required ValueChanged<HomeSetupStep> onStep,
  VoidCallback? onHide,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.home_setupTitle,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          HomeSetupRow(
            item: item,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onStep(item.step);
            },
          ),
        if (onHide != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('phone-home-setup-sheet-hide'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onHide();
              },
              style: TextButton.styleFrom(minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget)),
              child: Text(sheetContext.l10n.home_setupHide),
            ),
          ),
      ],
    ),
  );
}
