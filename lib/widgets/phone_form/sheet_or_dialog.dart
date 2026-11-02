import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_safe_area.dart';

/// PH6: a small form that asks before acting (the expired-stock and release
/// dialogs). On a phone a full-width bottom sheet: [title], [body] scrolling,
/// and [actions] pinned at the bottom side by side, clear of the home
/// indicator and lifted above the keyboard. Elsewhere today's AlertDialog,
/// [body] at [dialogWidth] when given. Both rebuild through the StateSetter
/// they are given. Returns what an action pops with.
Future<T?> showSheetOrDialog<T>(
  BuildContext context, {
  required Widget title,
  required Widget Function(BuildContext context, StateSetter setState) body,
  required List<Widget> Function(BuildContext context, StateSetter setState) actions,
  double? dialogWidth,
  ShapeBorder? dialogShape,
}) {
  if (!AppLayout.isPhone(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: dialogShape,
          title: title,
          content: dialogWidth == null ? body(ctx, setState) : SizedBox(width: dialogWidth, child: body(ctx, setState)),
          actions: actions(ctx, setState),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * AppSheetMetrics.sheetMaxHeightFactor),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PhoneFormMetrics.barPaddingH),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.semibold, color: ctx.colors.textPrimary),
                child: title,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(PhoneFormMetrics.barPaddingH),
                child: body(ctx, setState),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ctx.colors.divider, width: PhoneFormMetrics.barDivider)),
              ),
              padding: EdgeInsets.fromLTRB(
                PhoneFormMetrics.barPaddingH,
                PhoneFormMetrics.barPaddingV,
                PhoneFormMetrics.barPaddingH,
                PhoneFormMetrics.barPaddingV + AppSafeArea.bottomOf(ctx),
              ),
              child: Row(
                children: [
                  for (final (i, action) in actions(ctx, setState).indexed) ...[
                    if (i > 0) const SizedBox(width: PhoneFormMetrics.buttonGap),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: PhoneFormMetrics.buttonHeight),
                        child: action,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
