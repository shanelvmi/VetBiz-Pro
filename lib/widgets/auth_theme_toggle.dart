import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ui_theme_mode.dart';
import '../l10n/l10n.dart';
import '../providers/ui_settings_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_context.dart';

/// The Light/Dark switch in the header of the signed-out screens: a moon in
/// Light, a sun in Dark. Tapping it saves an explicit Light or Dark in
/// UiSettingsProvider (on the device, so it holds before sign-in).
///
/// It reads the brightness on screen, not the saved choice, so with System
/// it shows what the person sees and switches to the other one.
class AuthThemeToggle extends StatelessWidget {
  const AuthThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? context.l10n.auth_switchToLightMode : context.l10n.auth_switchToDarkMode,
      // The provider sits above MaterialApp, so the whole app (and with it
      // this screen) rebuilds at once in the new mode.
      onPressed: () => context.read<UiSettingsProvider>().setThemeMode(isDark ? UiThemeMode.light : UiThemeMode.dark),
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: AppIconSize.i18),
      style: IconButton.styleFrom(
        foregroundColor: context.colors.onBrandSurface,
        backgroundColor: context.colors.onBrandSurface.withValues(alpha: AppAlpha.a15),
        // A small circle to look at, Material's 48 px to tap.
        fixedSize: const Size.square(AppSizes.authHeaderButton),
        minimumSize: const Size.square(AppSizes.authHeaderButton),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
