import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// The question a step asks: a large title and a short grey line under it
/// (register_wizard.md section 3). No maxLines: Kiswahili wraps.
/// [centered] (FIN1, the flat phone page): both lines centred. [icon] (UI8,
/// the phone page): a tinted round icon above the title: authFooterFill, the
/// header's tint, with authPanelIcon, the signed-out headings' icon role.
class WizardStepIntro extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool centered;
  final IconData? icon;

  /// For tests: the round icon.
  static const iconKey = ValueKey<String>('wizard-step-icon');

  const WizardStepIntro({super.key, required this.title, this.subtitle, this.centered = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            key: iconKey,
            width: AuthPhoneMetrics.stepIcon,
            height: AuthPhoneMetrics.stepIcon,
            decoration: BoxDecoration(color: colors.authFooterFill, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: AuthPhoneMetrics.stepIconGlyph, color: colors.authPanelIcon),
          ),
          const SizedBox(height: AuthPhoneMetrics.stepIconGap),
        ],
        Text(
          title,
          textAlign: centered ? TextAlign.center : null,
          style: TextStyle(
            fontSize: WizardFontSize.introTitle,
            fontWeight: AppFontWeight.bold,
            color: colors.textStrong,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: WizardMetrics.introGap),
          Text(subtitle!, textAlign: centered ? TextAlign.center : null, style: TextStyle(fontSize: WizardFontSize.introSubtitle, color: colors.textMuted)),
        ],
      ],
    );
  }
}
