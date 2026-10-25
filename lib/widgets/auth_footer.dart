import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../data/support_contact_fields.dart';
import '../l10n/l10n.dart';
import '../models/support_contact.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import '../ui/feedback/app_feedback.dart';
import '../utils/social_link.dart';
import 'support_contact_dialog.dart';

/// Opens an outside link; [launchUrl] in the app, a fake in tests.
typedef AuthFooterLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// The calm footer under the Login and Register cards (G3): brand and a
/// plain line, Support, Legal, then copyright, version and social icons.
/// Three columns above AppBreakpoints.medium of its own width; on phones
/// the columns stack and the bottom row wraps. Roles and named sizes only.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key, required this.contact, this.launcher = launchUrl});

  /// app_config/support_contact, read ONCE by the page (in initState) and
  /// handed in, so a rebuild never reads it again.
  final Future<SupportContact> contact;

  final AuthFooterLauncher launcher;

  static const Map<SocialNetwork, FaIconData> _icons = {
    SocialNetwork.facebook: FontAwesomeIcons.facebook,
    SocialNetwork.instagram: FontAwesomeIcons.instagram,
    SocialNetwork.x: FontAwesomeIcons.xTwitter,
    SocialNetwork.linkedin: FontAwesomeIcons.linkedin,
    SocialNetwork.youtube: FontAwesomeIcons.youtube,
    SocialNetwork.tiktok: FontAwesomeIcons.tiktok,
  };

  static String _networkName(AppLocalizations l10n, SocialNetwork network) => switch (network) {
        SocialNetwork.facebook => l10n.social_facebook,
        SocialNetwork.instagram => l10n.social_instagram,
        SocialNetwork.x => l10n.social_x,
        SocialNetwork.linkedin => l10n.social_linkedin,
        SocialNetwork.youtube => l10n.social_youtube,
        SocialNetwork.tiktok => l10n.social_tiktok,
      };

  Future<void> _open(Uri uri) async {
    // Checked again here: only http and https ever leave the app.
    if (!SocialLink.isLaunchable(uri)) return;
    final opened = await launcher(uri, mode: LaunchMode.externalApplication);
    if (!opened) AppFeedback.info(L10n.current.common_linkFailed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuthCardMetrics.pageMargin,
        vertical: AuthFooterMetrics.paddingVertical,
      ),
      child: Center(
        child: ConstrainedBox(
          // Lines up with the card above it.
          constraints: const BoxConstraints(maxWidth: AuthCardMetrics.maxWidthWide),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > AppBreakpoints.medium;
              const gap = SizedBox(width: AuthFooterMetrics.columnGap, height: AuthFooterMetrics.sectionGap);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: AuthFooterMetrics.brandFlex, child: _brand(context)),
                        gap,
                        Expanded(child: _supportColumn(context)),
                        gap,
                        Expanded(child: _legalColumn(context)),
                      ],
                    )
                  else ...[
                    _brand(context),
                    gap,
                    _supportColumn(context),
                    gap,
                    _legalColumn(context),
                  ],
                  gap,
                  Divider(
                    height: AuthFooterMetrics.hairline,
                    thickness: AuthFooterMetrics.hairline,
                    color: context.colors.divider,
                  ),
                  _bottomRow(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brand(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AuthFooterMetrics.markSize,
              height: AuthFooterMetrics.markSize,
              decoration: BoxDecoration(color: context.colors.brandSurface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(AppInfo.logoMark,
                  style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12)),
            ),
            const SizedBox(width: AppSpacing.s10),
            Flexible(
              child: Text(AppInfo.name,
                  style: TextStyle(color: context.colors.textPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(context.l10n.authFooter_tagline, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13)),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Text(text,
      style: TextStyle(color: context.colors.textPrimary, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13));

  Widget _supportColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, context.l10n.authFooter_support),
        _FooterLink(
          label: context.l10n.authFooter_helpContact,
          // The dashboard's Help dialog, given this page's single read.
          onTap: () => showSupportContactDialog(context, contact: contact),
        ),
      ],
    );
  }

  Widget _legalColumn(BuildContext context) {
    void open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, context.l10n.authFooter_legal),
        _FooterLink(label: context.l10n.common_privacyPolicy, onTap: () => open(const PrivacyPolicyScreen())),
        _FooterLink(label: context.l10n.common_termsOfService, onTap: () => open(const TermsOfServiceScreen())),
      ],
    );
  }

  Widget _bottomRow(BuildContext context) {
    final muted = TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f12);
    return Wrap(
      // Copyright and version at the left, the icons at the right while
      // they fit on one line; on a phone the icons wrap under them.
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AuthFooterMetrics.tapTarget),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: [
              Text(context.l10n.login_copyright(AppInfo.name), style: muted),
              Text(AppInfo.versionLabel, style: muted),
            ],
          ),
        ),
        FutureBuilder<SupportContact>(
          future: contact,
          builder: (context, snapshot) {
            final links = snapshot.data?.socialLinks ?? const [];
            if (links.isEmpty) return const SizedBox.shrink();
            return Wrap(
              children: [
                for (final link in links) _socialButton(context, link.key, link.value),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _socialButton(BuildContext context, SocialNetwork network, Uri uri) {
    final name = _networkName(context.l10n, network);
    return IconButton(
      tooltip: name,
      constraints: const BoxConstraints(
        minWidth: AuthFooterMetrics.tapTarget,
        minHeight: AuthFooterMetrics.tapTarget,
      ),
      onPressed: () => _open(uri),
      icon: FaIcon(_icons[network], size: AuthFooterMetrics.socialIconSize, color: context.colors.textMuted, semanticLabel: name),
    );
  }
}

/// A text link in the footer: the whole 48 px row is the target.
class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AuthFooterMetrics.tapTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(label,
                style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
          ),
        ),
      ),
    );
  }
}
