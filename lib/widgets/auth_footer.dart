import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/support_contact.dart';

/// Opens an outside link; [launchUrl] in the app, a fake in tests.
typedef AuthFooterLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// The calm footer under the Login and Register cards (G3): brand and a
/// plain line, Support, Legal, then copyright, version and social icons.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key, required this.contact, this.launcher = launchUrl});

  /// app_config/support_contact, read ONCE by the page (in initState) and
  /// handed in, so a rebuild never reads it again.
  final Future<SupportContact> contact;

  final AuthFooterLauncher launcher;

  @override
  Widget build(BuildContext context) {
    // G3 stub: built in the next commit.
    return const SizedBox.shrink();
  }
}
