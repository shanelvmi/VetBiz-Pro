import 'package:flutter/material.dart';

import '../../config/app_defaults.dart';
import '../../l10n/l10n.dart';
import '../../providers/ui_settings_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// UX6: the language choice on PC and tablet, a centred dialog in the Theme
/// and layout dialog's style (title, options, close; AppSizes.dialogMd at
/// most). The phone keeps its bottom sheet (showLanguagePicker). The same
/// options and the same call: it saves the stored code through
/// [UiSettingsProvider.setLocale], never the label.
class LanguageDialog extends StatelessWidget {
  final UiSettingsProvider uiSettings;

  const LanguageDialog({super.key, required this.uiSettings});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      key: const ValueKey('language-dialog'),
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      // A dialog with no width limit stretches across a whole desktop screen.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.dialogMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s8, AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Icon(Icons.language_outlined, color: colors.primary),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(context.l10n.settings_languageBoth,
                        style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s8),
                itemCount: AppDefaults.supportedLanguages.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider),
                itemBuilder: (context, index) {
                  final code = AppDefaults.supportedLanguages[index];
                  final selected = code == uiSettings.languageCode;
                  return ListTile(
                    key: ValueKey('language-option-$code'),
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: AppSizes.minTapTarget,
                    title: Text(AppDefaults.languageNames[code] ?? code),
                    trailing: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? colors.primary : colors.border,
                    ),
                    onTap: () {
                      uiSettings.setLocale(code);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
