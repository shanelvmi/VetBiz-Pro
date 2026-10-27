import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import 'auth_panel.dart';
import 'updates_parts.dart';

/// AN4 (the owner's design): the login page's Updates as a card of their own,
/// with the login card's surface, radius, border and shadow ([AuthPanel]) but
/// not its accent line. On wide windows it sits beside the login card at the
/// same height: the welcome note (its heading on the line of "Sign in to your account"),
/// then the Updates, whose controls are pinned to the card's bottom. On phones
/// only the Updates, at their natural height, below the login card.
class UpdatesCard extends StatelessWidget {
  const UpdatesCard({super.key, required this.wide, required this.child});

  /// For tests: the card itself, its welcome note and the note's heading row.
  static const surfaceKey = ValueKey<String>('updates-card-surface');
  static const welcomeKey = ValueKey<String>('updates-card-welcome');
  static const welcomeHeadingKey = ValueKey<String>('updates-card-welcome-heading');

  /// The login page's two-column layout (AuthCardLayout.isWide).
  final bool wide;

  /// What UpdatesCarousel hands the page: the slides, the skeleton or (AN6)
  /// the calm panel.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final updates = UpdatesPlacement(wide: wide, child: child);
    return Container(
      key: surfaceKey,
      decoration: AuthPanel.decoration(context),
      padding: EdgeInsets.fromLTRB(
        AuthPanelMetrics.padding,
        // No accent line here: its height is added instead, so the welcome
        // heading sits on the line of the login card's "Sign in to your account".
        AuthPanelMetrics.padding + (wide ? AuthPanelMetrics.accentHeight : 0),
        AuthPanelMetrics.padding,
        AuthPanelMetrics.paddingBottom,
      ),
      child:
          wide
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WelcomeNote(key: welcomeKey),
                  const SizedBox(height: UpdatesMetrics.welcomeGap),
                  // The rest of the card's height: the controls go to its bottom.
                  Expanded(child: updates),
                ],
              )
              : updates,
    );
  }
}

/// The vaccine in its soft circle (AN5; it was a paw, which suggests pets,
/// and the customers are agrovets), "Welcome to {appName}", and one plain
/// line about the Updates below it (AN5; in AN4 it was the footer's old line
/// about what the app does).
class _WelcomeNote extends StatelessWidget {
  const _WelcomeNote({super.key});

  @override
  Widget build(BuildContext context) {
    // AN5: the sentence is the heading's subtitle, as the sign-in card's
    // subtext is, so the two sit on one line.
    return AuthPanelHeading(
      key: UpdatesCard.welcomeHeadingKey,
      icon: Icons.vaccines_outlined,
      title: context.l10n.updates_welcomeTitle(AppInfo.name),
      subtitle: context.l10n.updates_welcomeLine,
    );
  }
}
