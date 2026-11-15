import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// Back and Continue at the bottom of a step-by-step form
/// (register_wizard.md section 3): Back outlined at the left (not on the
/// first step), Continue filled primary at the right, [finishLabel] in its
/// place on the last step. While [submitting], both are off and Continue
/// shows a spinner, so a second tap cannot send twice.
///
/// Inline (the default) it is the card's bottom row. [pinned] is for a
/// phone's `Scaffold.bottomNavigationBar`: a surface strip lifted by the
/// keyboard's height, so the keyboard never hides Continue (RW1 answer 10).
class WizardNavBar extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool submitting;
  final bool pinned;

  /// UI8, the phone register page: Back is a square icon button (the same
  /// outline, its name as the tooltip) beside a full-width Continue, both
  /// AuthPhoneMetrics.buttonHeight high. Back keeps every answer, as before.
  final bool squareBack;

  /// For tests: the square Back.
  static const squareBackKey = ValueKey<String>('wizard-square-back');
  final String finishLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const WizardNavBar({
    super.key,
    required this.isFirst,
    required this.isLast,
    this.submitting = false,
    this.pinned = false,
    this.squareBack = false,
    required this.finishLabel,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(WizardMetrics.buttonRadius)));
    const padding = EdgeInsets.symmetric(horizontal: WizardMetrics.buttonPaddingH);
    final minimumSize = Size(0, squareBack ? AuthPhoneMetrics.buttonHeight : WizardMetrics.buttonHeight);
    const label = TextStyle(fontSize: WizardFontSize.button, fontWeight: AppFontWeight.semibold);

    final back = squareBack
        ? OutlinedButton(
            key: squareBackKey,
            onPressed: submitting ? null : onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              fixedSize: const Size.square(AuthPhoneMetrics.buttonHeight),
              minimumSize: const Size.square(AuthPhoneMetrics.buttonHeight),
              padding: EdgeInsets.zero,
              shape: shape,
            ),
            child: Tooltip(
              message: context.l10n.wizard_back,
              child: Icon(Icons.arrow_back, size: AppIconSize.i24, semanticLabel: context.l10n.wizard_back),
            ),
          )
        : OutlinedButton(
      onPressed: submitting ? null : onBack,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary),
        minimumSize: minimumSize,
        padding: padding,
        shape: shape,
        textStyle: label,
      ),
      child: Text(context.l10n.wizard_back),
    );

    final next = FilledButton(
      onPressed: submitting ? null : onContinue,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: AppAlpha.a70),
        disabledForegroundColor: colors.onPrimary,
        minimumSize: minimumSize,
        padding: padding,
        shape: shape,
        textStyle: label,
      ),
      child: submitting
          ? SizedBox(
              width: WizardMetrics.spinnerSize,
              height: WizardMetrics.spinnerSize,
              child: CircularProgressIndicator(strokeWidth: WizardMetrics.spinnerStroke, color: colors.onPrimary),
            )
          : Text(isLast ? finishLabel : context.l10n.products_continue, textAlign: TextAlign.center),
    );

    // Continue stays at the right on the first step too, where Back is
    // missing, so it does not jump when the person moves on.
    final row = squareBack
        // UI8: Continue takes the rest of the row (the whole row on step 1).
        ? Row(
            children: [
              if (!isFirst) ...[back, const SizedBox(width: WizardMetrics.navGap)],
              Expanded(child: next),
            ],
          )
        : Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isFirst) const SizedBox.shrink() else back,
        Flexible(
          child: Padding(padding: const EdgeInsetsDirectional.only(start: WizardMetrics.navGap), child: next),
        ),
      ],
    );
    if (!pinned) return row;

    return Material(
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider, width: WizardMetrics.pinnedDivider)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WizardMetrics.pinnedPaddingH,
              vertical: WizardMetrics.pinnedPaddingV,
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}
