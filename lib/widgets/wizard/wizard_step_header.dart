import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The top of a step-by-step form (register_wizard.md section 3): "Step n
/// of total" at the left, the step's title at the right (wrapping under it
/// when the line is too narrow, as Kiswahili titles often are), and a thin
/// progress bar that slides to the new step. [centered] (FIN1, the flat phone
/// page): the count and the title centred, the title under the count.
class WizardStepHeader extends StatelessWidget {
  final int current;
  final int total;
  final String title;
  final bool centered;

  /// UI8, the phone register page's tinted strip: "Step n of total" at the
  /// left with [trailing] (the page's controls) at the right, then the bar
  /// in [total] parts, the done ones filled; no title (the step's own
  /// heading is under the strip).
  final bool strip;
  final Widget? trailing;

  /// For tests: the strip's part [i] of the bar.
  static ValueKey<String> segmentKey(int i) => ValueKey<String>('wizard-step-segment-$i');

  const WizardStepHeader({
    super.key,
    required this.current,
    required this.total,
    required this.title,
    this.centered = false,
    this.strip = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (strip) return _buildStrip(context);
    final count = Text(
      context.l10n.wizard_stepOf(current, total),
      textAlign: centered ? TextAlign.center : null,
      style: TextStyle(fontSize: WizardFontSize.step, color: colors.textMuted),
    );
    final name = Text(
      title,
      textAlign: centered ? TextAlign.center : null,
      style: TextStyle(
        fontSize: WizardFontSize.stepTitle,
        fontWeight: AppFontWeight.semibold,
        color: colors.textPrimary,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (centered)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [count, const SizedBox(height: WizardMetrics.headerRunSpacing), name],
          )
        else
          // A Wrap, not a Row: a long title moves to its own line instead of
          // squeezing the step count. Full width, so spaceBetween pushes the
          // title to the right edge when both fit.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: WizardMetrics.headerSpacing,
              runSpacing: WizardMetrics.headerRunSpacing,
              children: [count, name],
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

extension on WizardStepHeader {
  Widget _buildStrip(BuildContext context) {
    final colors = context.colors;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.wizard_stepOf(current, total),
                style: TextStyle(fontSize: WizardFontSize.step, fontWeight: AppFontWeight.semibold, color: colors.textPrimary),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AuthPhoneMetrics.stripBarGap),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: AuthPhoneMetrics.progressGap),
              Expanded(
                child: AnimatedContainer(
                  key: WizardStepHeader.segmentKey(i),
                  duration: duration,
                  height: AuthPhoneMetrics.progressHeight,
                  decoration: BoxDecoration(
                    color: i < current ? colors.primary : colors.divider,
                    borderRadius: BorderRadius.circular(AuthPhoneMetrics.progressRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
