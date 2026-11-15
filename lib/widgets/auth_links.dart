import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../data/support_contact_fields.dart';
import '../l10n/l10n.dart';
import '../screens/info/about_screen.dart';
import '../screens/info/faq_screen.dart';
import '../screens/info/how_to_use_screen.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../services/support_contact_store.dart';
import '../theme/app_dimens.dart';
import '../ui/feedback/app_feedback.dart';
import '../utils/social_link.dart';
import 'hover_link.dart';
import 'support_contact_dialog.dart';

/// Opens an outside link; [launchUrl] in the app, a fake in tests.
typedef AuthLinkLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// One help or legal link of the signed-out pages: its text and what it
/// opens. UI8: the footer (wide) and the phone help sheet (AuthHelpSheet)
/// read the same list, so a route or a label changes in one place.
class AuthLink {
  const AuthLink._(this.label, this._open, {this.button = false});

  final String Function(AppLocalizations l10n) label;
  final void Function(BuildContext context, SupportContactStore store) _open;

  /// Opens a dialog rather than a page (read as a button).
  final bool button;

  void open(BuildContext context, SupportContactStore store) => _open(context, store);

  static void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  static final about = AuthLink._(
    (l10n) => l10n.authFooter_about(AppInfo.name),
    (context, store) => _push(context, AboutScreen(store: store)),
  );
  static final howToUse = AuthLink._((l10n) => l10n.authFooter_howToUse, (context, _) => _push(context, const HowToUseScreen()));

  /// The dashboard's Help dialog, from the same copy as the icons.
  static final helpContact = AuthLink._(
    (l10n) => l10n.authFooter_helpContact,
    (context, store) => showSupportContactDialog(context, store: store),
    button: true,
  );
  static final faq = AuthLink._((l10n) => l10n.authFooter_faq, (context, _) => _push(context, const FaqScreen()));
  static final privacy = AuthLink._((l10n) => l10n.common_privacyPolicy, (context, _) => _push(context, const PrivacyPolicyScreen()));
  static final terms = AuthLink._((l10n) => l10n.common_termsOfService, (context, _) => _push(context, const TermsOfServiceScreen()));
}

/// The social icons the Platform Admin saved, shared by the footer and the
/// help sheet: the glyph and name of each network, and the one way a link
/// leaves the app.
abstract final class AuthSocial {
  static const Map<SocialNetwork, FaIconData> icons = {
    SocialNetwork.facebook: FontAwesomeIcons.facebook,
    SocialNetwork.instagram: FontAwesomeIcons.instagram,
    SocialNetwork.x: FontAwesomeIcons.xTwitter,
    SocialNetwork.linkedin: FontAwesomeIcons.linkedin,
    SocialNetwork.youtube: FontAwesomeIcons.youtube,
    SocialNetwork.tiktok: FontAwesomeIcons.tiktok,
  };

  static String networkName(AppLocalizations l10n, SocialNetwork network) => switch (network) {
        SocialNetwork.facebook => l10n.social_facebook,
        SocialNetwork.instagram => l10n.social_instagram,
        SocialNetwork.x => l10n.social_x,
        SocialNetwork.linkedin => l10n.social_linkedin,
        SocialNetwork.youtube => l10n.social_youtube,
        SocialNetwork.tiktok => l10n.social_tiktok,
      };

  static Future<void> open(AuthLinkLauncher launcher, Uri uri) async {
    // Checked again here: only http and https ever leave the app.
    if (!SocialLink.isLaunchable(uri)) return;
    final opened = await launcher(uri, mode: LaunchMode.externalApplication);
    if (!opened) AppFeedback.info(L10n.current.common_linkFailed);
  }

  /// One network's icon: the shared HoverLink, named for screen readers.
  static Widget button(
    BuildContext context,
    SocialNetwork network,
    Uri uri, {
    required Color color,
    required AuthLinkLauncher launcher,
  }) {
    final name = networkName(context.l10n, network);
    return HoverLink.icon(
      tooltip: name,
      color: color,
      onTap: () => open(launcher, uri),
      icon: (color) => FaIcon(icons[network], size: AuthFooterMetrics.socialIconSize, color: color, semanticLabel: name),
    );
  }
}
