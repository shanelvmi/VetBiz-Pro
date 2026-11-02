import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// PH6: a picker's field on a phone: the chosen label (or the placeholder,
/// in the hint colour), at least 48 high, an optional icon; a tap opens the
/// picker's sheet (showPickerSheet).
class PhoneChoiceField extends StatelessWidget {
  final String text;
  final bool chosen;
  final IconData? icon;
  final VoidCallback onTap;

  const PhoneChoiceField({super.key, required this.text, required this.chosen, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: PhoneFormMetrics.fieldMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: PhoneFormMetrics.fieldPaddingH),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: Border.all(color: colors.textHint.withValues(alpha: AppAlpha.a40)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppIconSize.i18, color: colors.primary),
              const SizedBox(width: AppSpacing.s10),
            ],
            Expanded(
              child: Text(text, style: TextStyle(fontSize: PhoneFormMetrics.body, color: chosen ? colors.textPrimary : colors.textHint)),
            ),
            Icon(Icons.expand_more, size: AppIconSize.i18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
