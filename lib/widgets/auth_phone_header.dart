import 'package:flutter/material.dart';

import '../config/app_info.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_icons.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'auth_language_switch.dart';
import 'auth_theme_toggle.dart';

/// UI8: the tinted top of the signed-out pages on a phone (sign-in and the
/// register wizard): authFooterFill, the footer band's soft tint of the
/// primary (surface in Dark), edge to edge and under the status bar, with
/// rounded bottom corners. Tablets and computers keep the AuthCard header.
class AuthPhoneTint extends StatelessWidget {
  const AuthPhoneTint({super.key, required this.padding, required this.child});

  /// Inside the tint, below the status bar.
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.authFooterFill,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AuthPhoneMetrics.headerRadius)),
      ),
      child: Padding(padding: padding.copyWith(top: padding.top + MediaQuery.paddingOf(context).top), child: child),
    );
  }
}

/// The sign-in page's header on a phone: the controls at the right, then
/// the VB mark in its rounded tile, the app name and [tagline]. [collapsed]
/// (the keyboard is open): one line, a smaller mark and the name with the
/// controls, so the Sign in button stays on a small screen.
class AuthPhoneHeader extends StatelessWidget {
  const AuthPhoneHeader({super.key, required this.tagline, required this.onHelp, this.collapsed = false});

  final String tagline;
  final VoidCallback onHelp;
  final bool collapsed;

  /// For tests: the mark's tile, and the tagline.
  static const markKey = ValueKey<String>('auth-phone-mark');
  static const taglineKey = ValueKey<String>('auth-phone-tagline');

  @override
  Widget build(BuildContext context) {
    final controls = AuthPhoneControls(onHelp: onHelp);
    if (collapsed) {
      return AuthPhoneTint(
        padding: const EdgeInsets.symmetric(horizontal: AuthPhoneMetrics.headerPaddingH, vertical: AuthPhoneMetrics.collapsedPaddingV),
        child: Row(
          children: [
            const AuthMarkTile(size: AuthPhoneMetrics.collapsedMark, radius: AuthPhoneMetrics.collapsedMarkRadius, fontSize: AppFontSize.f12),
            const SizedBox(width: AppSpacing.s10),
            Expanded(child: _name(context, AppFontSize.f16)),
            controls,
          ],
        ),
      );
    }
    return AuthPhoneTint(
      padding: const EdgeInsets.fromLTRB(
        AuthPhoneMetrics.headerPaddingH,
        AuthPhoneMetrics.headerPaddingTop,
        AuthPhoneMetrics.headerPaddingH,
        AuthPhoneMetrics.headerPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: AlignmentDirectional.centerEnd, child: controls),
          const SizedBox(height: AuthPhoneMetrics.controlsToBrand),
          Row(
            children: [
              const AuthMarkTile(size: AuthPhoneMetrics.markTile, radius: AuthPhoneMetrics.markTileRadius, fontSize: AppFontSize.f18),
              const SizedBox(width: AuthPhoneMetrics.markGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _name(context, AppFontSize.f20),
                    const SizedBox(height: AuthPhoneMetrics.taglineGap),
                    Text(tagline, key: taglineKey, style: TextStyle(color: context.colors.authFooterMutedText, fontSize: AppFontSize.f13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _name(BuildContext context, double size) => Text(
    AppInfo.name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: context.colors.textPrimary, fontWeight: AppFontWeight.bold, fontSize: size),
  );
}

/// The VB mark in a rounded tile (brandSurface, onBrandSurface ink).
class AuthMarkTile extends StatelessWidget {
  const AuthMarkTile({super.key, required this.size, required this.radius, required this.fontSize});

  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AuthPhoneHeader.markKey,
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.colors.brandSurface, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: Text(AppInfo.logoMark, style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: fontSize)),
    );
  }
}

/// EN | SW, the Light/Dark switch and Help, in that order (the header's
/// right on the sign-in page, the step strip's right in the wizard).
class AuthPhoneControls extends StatelessWidget {
  const AuthPhoneControls({super.key, required this.onHelp});

  final VoidCallback onHelp;

  /// For tests: the Help button.
  static const helpKey = ValueKey<String>('auth-phone-help');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AuthLanguageSwitch(),
        const SizedBox(width: AuthPhoneMetrics.controlsGap),
        const AuthThemeToggle(onPage: true),
        IconButton(
          key: helpKey,
          tooltip: context.l10n.dashboard_help,
          onPressed: onHelp,
          icon: Icon(AppIcons.help.outlined, size: AppIconSize.i18),
          // The same circle as the Light/Dark switch beside it.
          style: IconButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            backgroundColor: context.colors.surfaceMuted,
            fixedSize: const Size.square(AppSizes.authHeaderButton),
            minimumSize: const Size.square(AppSizes.authHeaderButton),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ],
    );
  }
}
