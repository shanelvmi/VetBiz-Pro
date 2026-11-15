import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_defaults.dart';
import '../l10n/l10n.dart';
import '../providers/ui_settings_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// The language switch of the signed-out phone pages: one half per language
/// the app has texts for (EN | SW), the one on screen filled. A tap saves the
/// choice through UiSettingsProvider.setLocale, the same call as Settings,
/// so it holds on the device before sign-in. No language logic of its own.
class AuthLanguageSwitch extends StatelessWidget {
  const AuthLanguageSwitch({super.key});

  /// For tests: the half for [code].
  static ValueKey<String> segmentKey(String code) => ValueKey<String>('auth-language-$code');

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return Semantics(
      label: context.l10n.common_language,
      container: true,
      // The pill is drawn 36 high; each half's target is Material's 48.
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: AuthPhoneMetrics.languagePillHeight,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AuthPhoneMetrics.languagePillRadius),
                    border: Border.all(color: context.colors.border, width: AuthPhoneMetrics.languagePillBorder),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final code in AppDefaults.supportedLanguages) _segment(context, code, code == current)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, String code, bool selected) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: AppDefaults.languageNames[code] ?? code,
      excludeSemantics: true,
      child: Tooltip(
        message: AppDefaults.languageNames[code] ?? code,
        child: InkResponse(
          key: segmentKey(code),
          onTap: selected ? null : () => context.read<UiSettingsProvider>().setLocale(code),
          radius: kMinInteractiveDimension / 2,
          child: SizedBox(
            width: AuthPhoneMetrics.languageSegmentWidth,
            height: kMinInteractiveDimension,
            child: Center(
              child: Container(
                height: AuthPhoneMetrics.languagePillHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? context.colors.brandSurface : null,
                  borderRadius: BorderRadius.circular(AuthPhoneMetrics.languagePillRadius),
                ),
                child: Text(
                  // The code itself (technical text): EN, SW.
                  code.toUpperCase(),
                  style: TextStyle(
                    color: selected ? context.colors.onBrandSurface : context.colors.textPrimary,
                    fontWeight: AppFontWeight.bold,
                    fontSize: AppFontSize.f12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
