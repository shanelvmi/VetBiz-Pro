import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The question a step asks: a large title and a short grey line under it
/// (register_wizard.md section 3). No maxLines: Kiswahili wraps.
class WizardStepIntro extends StatelessWidget {
  final String title;
  final String? subtitle;

  const WizardStepIntro({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: WizardFontSize.introTitle,
            fontWeight: AppFontWeight.bold,
            color: colors.textStrong,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: WizardMetrics.introGap),
          Text(subtitle!, style: TextStyle(fontSize: WizardFontSize.introSubtitle, color: colors.textMuted)),
        ],
      ],
    );
  }
}
