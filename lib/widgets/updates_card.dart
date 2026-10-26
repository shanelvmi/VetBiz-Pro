import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'auth_panel.dart';
import 'updates_parts.dart';

/// AN4 (the owner's design): the login page's Updates as a card of their own,
/// with the login card's surface, radius, border and shadow ([AuthPanel]) but
/// not its accent line. On wide windows it sits beside the login card at the
/// same height: the welcome note (its heading on the line of "Welcome back"),
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

  /// What UpdatesCarousel hands the page: the slides or the skeleton.
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
        // heading sits on the line of the login card's "Welcome back".
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

/// The paw in its soft circle, "Welcome to {appName}", and one plain line
/// about what the app does (it used to be the footer's).
class _WelcomeNote extends StatelessWidget {
  const _WelcomeNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthPanelHeading(
          key: UpdatesCard.welcomeHeadingKey,
          icon: Icons.pets_outlined,
          title: context.l10n.updates_welcomeTitle(AppInfo.name),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          context.l10n.updates_welcomeLine,
          style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
