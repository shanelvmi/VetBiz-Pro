import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// PH6 S6 (docs/design/phone_foundations.md): a money form's buttons on a
/// phone, in place of its footer. A surface strip pinned at the bottom, out
/// of the home indicator's way and lifted by the keyboard's height as
/// WizardNavBar's pinned bar is, so the keyboard never hides the primary
/// button. The primary button takes the width the secondary one leaves; both
/// are at least 48 high. While [busy], both are off and the primary one
/// shows a spinner, so a second tap cannot save twice. [summary] is a line
/// pinned above the buttons (Add Sale's items and total).
class FormActionBar extends StatelessWidget {
  final String primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final bool busy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? summary;

  const FormActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PhoneFormMetrics.buttonRadius)));
    const minimumSize = Size(0, PhoneFormMetrics.buttonHeight);
    const label = TextStyle(fontSize: PhoneFormMetrics.body, fontWeight: AppFontWeight.semibold);

    final primary = FilledButton(
      key: const ValueKey('formActionBar-primary'),
      onPressed: busy ? null : onPrimary,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: AppAlpha.a50),
        disabledForegroundColor: colors.onPrimary,
        minimumSize: minimumSize,
        shape: shape,
        textStyle: label,
      ),
      child: busy
          ? SizedBox(
              width: PhoneFormMetrics.spinnerSize,
              height: PhoneFormMetrics.spinnerSize,
              child: CircularProgressIndicator(strokeWidth: PhoneFormMetrics.spinnerStroke, color: colors.onPrimary),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (primaryIcon != null) ...[
                  Icon(primaryIcon, size: AppIconSize.i18),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Flexible(child: Text(primaryLabel, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    return Material(
      color: colors.surface,
      child: Container(
        key: const ValueKey('formActionBar'),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider, width: PhoneFormMetrics.barDivider)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PhoneFormMetrics.barPaddingH,
              vertical: PhoneFormMetrics.barPaddingV,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary != null) ...[
                  DefaultTextStyle.merge(
                    style: TextStyle(fontSize: PhoneFormMetrics.summary, color: colors.textPrimary),
                    child: summary!,
                  ),
                  const SizedBox(height: PhoneFormMetrics.summaryGap),
                ],
                Row(
                  children: [
                    if (secondaryLabel != null) ...[
                      OutlinedButton(
                        key: const ValueKey('formActionBar-secondary'),
                        onPressed: busy ? null : onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: colors.border),
                          minimumSize: minimumSize,
                          shape: shape,
                          textStyle: label,
                        ),
                        child: Text(secondaryLabel!),
                      ),
                      const SizedBox(width: PhoneFormMetrics.buttonGap),
                    ],
                    Expanded(child: primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
