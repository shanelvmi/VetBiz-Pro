import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// The look of the cards inside the signed-out frame (AN4): the login card
/// and the Updates card beside it. One surface, radius and border, from
/// [AuthPanelMetrics] and the theme's roles, so one place restyles both.
/// POL3 (owner rule: flat cards): the hairline border alone; the tinted lift
/// and the edge shadow are gone.
class AuthPanel {
  AuthPanel._();

  static BoxDecoration decoration(BuildContext context) => BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AuthPanelMetrics.radius),
    border: Border.all(color: context.colors.border),
  );
}

/// A card's heading row: the soft circle with [icon], then [title] on one
/// line, and an optional [subtitle] under it. The login card's "Sign in to
/// your account" and the Updates card's welcome note use it, so the two rows
/// are the same height and line up, and (AN5) the welcome sentence and the
/// sign-in subtext are one widget, on one horizontal line. With no [icon]
/// (LG1, the flat phone login) the same title and subtitle without the
/// circle, the title free to wrap (a long Kiswahili title is not cut); with
/// [centered] (UI1, the phone) both lines centred across the column.
class AuthPanelHeading extends StatelessWidget {
  const AuthPanelHeading({super.key, this.icon, required this.title, this.subtitle, this.centered = false});

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final glow = context.colors.brandTealGlow;
    final icon = this.icon;
    final titleStyle = TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.extraBold, color: context.colors.textPrimary);
    final align = centered ? TextAlign.center : null;
    final row = icon == null ? Text(title, textAlign: align, style: titleStyle) : Row(
      children: [
        Container(
          width: AuthPanelMetrics.iconCircle,
          height: AuthPanelMetrics.iconCircle,
          // POL3: the soft fill and outline only; the glow around it is gone.
          decoration: BoxDecoration(
            color: glow.withValues(alpha: AppAlpha.a20),
            shape: BoxShape.circle,
            border: Border.all(color: glow.withValues(alpha: AppAlpha.a70), width: AuthPanelMetrics.iconCircleBorder),
          ),
          child: Icon(icon, color: context.colors.authPanelIcon, size: AppIconSize.i20),
        ),
        const SizedBox(width: AuthPanelMetrics.headingGap),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
      ],
    );
    final sub = subtitle;
    final heading = sub == null
        ? row
        : Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              row,
              const SizedBox(height: AuthPanelMetrics.subtitleGap),
              Text(sub, textAlign: align, style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textSecondary)),
            ],
          );
    // The full width of the column it sits in, so its centre is the column's.
    return centered ? SizedBox(width: double.infinity, child: heading) : heading;
  }
}
