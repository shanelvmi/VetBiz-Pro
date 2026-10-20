import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import '../utils/force_logout.dart';
import 'vetbiz_loading_indicator.dart' show VetBizLoadingTheme;

/// The full-screen block for a running version lower than
/// `platform_config/settings.minimumVersion` (P1, shown by [MaintenanceGate]).
/// Light in every mode, like the loading screen: it may show to someone whose
/// old app predates any later look. Only Sign out is offered.
class UpdateRequiredScreen extends StatelessWidget {
  final String currentVersion;
  final String minimumVersion;

  const UpdateRequiredScreen({super.key, required this.currentVersion, required this.minimumVersion});

  @override
  Widget build(BuildContext context) {
    return VetBizLoadingTheme(
      builder: (context) => Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.dialogSm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.system_update_rounded, size: AppIconSize.i48, color: context.colors.primary),
                    ),
                    const SizedBox(height: AppSpacing.s28),
                    Text(
                      context.l10n.update_title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppFontSize.f22, fontWeight: AppFontWeight.bold, color: context.colors.primary),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      context.l10n.update_body(AppInfo.name, currentVersion, minimumVersion),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppFontSize.f14_5, color: context.colors.textSoft),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      context.l10n.update_howTo(AppInfo.name),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppFontSize.f14_5, color: context.colors.textSoft),
                    ),
                    const SizedBox(height: AppSpacing.s32),
                    TextButton.icon(
                      onPressed: () => forceLogoutAndShowLogin(),
                      icon: const Icon(Icons.logout, size: AppIconSize.i18),
                      label: Text(context.l10n.common_signOut),
                      style: TextButton.styleFrom(foregroundColor: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
