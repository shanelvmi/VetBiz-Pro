import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../services/support_contact_store.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'app_sheet.dart';
import 'auth_links.dart';
import 'hover_link.dart';

/// UI8: opens the phone help sheet from the Help button of the signed-out
/// pages' header (sign-in and register on a phone, where the footer is not
/// shown). Tablets and computers keep the AuthFooter.
Future<void> showAuthHelpSheet(
  BuildContext context, {
  SupportContactStore? store,
  AuthLinkLauncher launcher = launchUrl,
}) =>
    showAppSheet<void>(
      context,
      title: context.l10n.dashboard_help,
      builder: (_) => AuthHelpSheet(store: store, launcher: launcher),
    );

/// What the footer holds, in a bottom sheet: Help and FAQ, About, Contact
/// support, Terms of service and Privacy policy (the footer's own links and
/// routes, AuthLink), then the copyright and the version, and the social
/// icons the Platform Admin saved (only when some are saved).
class AuthHelpSheet extends StatelessWidget {
  const AuthHelpSheet({super.key, this.store, this.launcher = launchUrl});

  /// The app's one copy of the support contact (G6), as the footer reads it.
  final SupportContactStore? store;
  final AuthLinkLauncher launcher;

  SupportContactStore get _store => store ?? SupportContactStore.instance;

  /// For tests: the social icons' row (absent while none are saved).
  static const socialRowKey = ValueKey<String>('auth-help-social');

  static final links = [
    AuthLink.faq,
    AuthLink.howToUse,
    AuthLink.about,
    AuthLink.helpContact,
    AuthLink.terms,
    AuthLink.privacy,
  ];

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final link in links)
          // Touch: Material's 48 px row, as the footer's links on a phone.
          HoverLink(
            label: link.label(context.l10n),
            button: link.button,
            onTap: () => link.open(context, _store),
            style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14),
          ),
        const SizedBox(height: AppSpacing.s8),
        Divider(height: AuthFooterMetrics.hairline, thickness: AuthFooterMetrics.hairline, color: context.colors.divider),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s4,
          children: [
            Text(context.l10n.login_copyright(AppInfo.name), style: muted),
            Text(context.l10n.common_versionWithBuild(AppInfo.versionLabel, AppInfo.buildStamp), style: muted),
          ],
        ),
        ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final saved = _store.current?.socialLinks ?? const [];
            if (saved.isEmpty) return const SizedBox.shrink();
            return Padding(
              key: socialRowKey,
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Wrap(
                children: [
                  for (final link in saved)
                    AuthSocial.button(context, link.key, link.value, color: context.colors.textSecondary, launcher: launcher),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
