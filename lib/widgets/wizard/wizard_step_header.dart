import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The top of a step-by-step form (register_wizard.md section 3): "Step n
/// of total" at the left, the step's title at the right (wrapping under it
/// when the line is too narrow, as Kiswahili titles often are), and a thin
/// progress bar that slides to the new step.
class WizardStepHeader extends StatelessWidget {
  final int current;
  final int total;
  final String title;

  const WizardStepHeader({super.key, required this.current, required this.total, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A Wrap, not a Row: a long title moves to its own line instead of
        // squeezing the step count. Full width, so spaceBetween pushes the
        // title to the right edge when both fit.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: WizardMetrics.headerSpacing,
            runSpacing: WizardMetrics.headerRunSpacing,
            children: [
              Text(
                context.l10n.wizard_stepOf(current, total),
                style: TextStyle(fontSize: WizardFontSize.step, color: colors.textMuted),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: WizardFontSize.stepTitle,
                  fontWeight: AppFontWeight.semibold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: WizardMetrics.headerBarGap),
        // Begin is left empty, so the first build shows the value at once
        // and a later step animates from where the bar was.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: total == 0 ? 0 : current / total),
          duration: AppMotion.fast,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: WizardMetrics.progressHeight,
            color: colors.primary,
            backgroundColor: colors.divider,
            borderRadius: BorderRadius.circular(WizardMetrics.progressRadius),
          ),
        ),
      ],
    );
  }
}
