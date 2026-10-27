import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// The look of the cards inside the signed-out frame (AN4): the login card
/// and the Updates card beside it. One surface, radius, border and shadow,
/// from [AuthPanelMetrics] and the theme's roles, so one place restyles both.
class AuthPanel {
  AuthPanel._();

  static BoxDecoration decoration(BuildContext context) => BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AuthPanelMetrics.radius),
    border: Border.all(color: context.colors.border),
    // Two layers: a wide, teal-tinted one that lifts the card off the frame
    // around it, and a tight one for a crisp edge.
    boxShadow: [
      BoxShadow(
        color: context.colors.primary.withValues(alpha: AppAlpha.a15),
        blurRadius: AuthPanelMetrics.liftBlur,
        offset: const Offset(0, AuthPanelMetrics.liftOffsetY),
      ),
      BoxShadow(
        color: context.colors.shadow.withValues(alpha: AppAlpha.a05),
        blurRadius: AuthPanelMetrics.edgeBlur,
        offset: const Offset(0, AuthPanelMetrics.edgeOffsetY),
      ),
    ],
  );
}

/// A card's heading row: the soft circle with [icon], then [title] on one
/// line, and an optional [subtitle] under it. The login card's "Sign in to
/// your account" and the Updates card's welcome note use it, so the two rows
/// are the same height and line up, and (AN5) the welcome sentence and the
/// sign-in subtext are one widget, on one horizontal line.
class AuthPanelHeading extends StatelessWidget {
  const AuthPanelHeading({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final glow = context.colors.brandTealGlow;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final row = Row(
      children: [
        Container(
          width: AuthPanelMetrics.iconCircle,
          height: AuthPanelMetrics.iconCircle,
          decoration: BoxDecoration(
            color: glow.withValues(alpha: AppAlpha.a20),
            shape: BoxShape.circle,
            border: Border.all(color: glow.withValues(alpha: AppAlpha.a70), width: AuthPanelMetrics.iconCircleBorder),
            boxShadow: [
              dark
                  ? BoxShadow(color: glow.withValues(alpha: AuthPanelMetrics.iconCircleGlowAlphaDark), blurRadius: AuthPanelMetrics.iconCircleGlowDark)
                  : BoxShadow(color: glow.withValues(alpha: AuthPanelMetrics.iconCircleGlowAlpha), blurRadius: AuthPanelMetrics.iconCircleGlow),
            ],
          ),
          child: Icon(icon, color: context.colors.authPanelIcon, size: AppIconSize.i20),
        ),
        const SizedBox(width: AuthPanelMetrics.headingGap),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.extraBold, color: context.colors.textPrimary),
          ),
        ),
      ],
    );
    final sub = subtitle;
    if (sub == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(height: AuthPanelMetrics.subtitleGap),
        Text(sub, style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textSecondary)),
      ],
    );
  }
}
