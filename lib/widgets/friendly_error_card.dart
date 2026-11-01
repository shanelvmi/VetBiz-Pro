import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// FX1: what a release build shows in place of a widget that failed to build
/// (ErrorWidget.builder), instead of Flutter's grey box: a small card with
/// error_screenFailed, sized to what it holds (it never stretches a Row or a
/// list), no technical text. It may be drawn above the app's theme and
/// localisations, so it needs neither.
class FriendlyErrorCard extends StatelessWidget {
  const FriendlyErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    // The app's roles when its theme is above; the default theme's otherwise.
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.fromTheme(AppColorTheme.pasture);
    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      // Center shrinks to the card where the room is unbounded (a Row, a
      // list) and centres it where it is not (a page body).
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.dialogXs),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.s8),
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(color: colors.borderStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colors.dangerAccent, size: AppIconSize.i24),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  L10n.current.error_screenFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFontSize.f14,
                    color: colors.textPrimary,
                    // No Material above it here: no fallback underline.
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
