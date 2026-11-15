import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../data/support_contact_fields.dart';
import '../l10n/l10n.dart';
import '../services/support_contact_store.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'auth_links.dart';
import 'hover_link.dart';

/// Opens an outside link; [launchUrl] in the app, a fake in tests (UI8:
/// the same type as the phone help sheet's).
typedef AuthFooterLauncher = AuthLinkLauncher;

/// The calm footer under the Login and Register cards (G3, v2 in G4): on a
/// full-width soft band (authFooterFill) with a hairline on top, the brand
/// (the mark and the name; AN4: no plain line; AN5: the description line), then Platform, Support and Legal, then copyright,
/// version and the social icons the Platform Admin saved. Four columns
/// above AppBreakpoints.medium of its own width; on phones the brand, then
/// the columns two by two, and the bottom row wraps. Every link and icon is
/// the shared HoverLink. G5: on wide windows (a mouse) link rows of 32 px
/// and less padding, about a third shorter; touch widths keep 48 px
/// targets. Roles and named sizes only.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key, this.store, this.launcher = launchUrl});

  /// Where the support contact comes from: the app's one copy (G6), which
  /// the page asks to revalidate. Each page used to read it itself and the
  /// footer showed no icons until that read answered.
  final SupportContactStore? store;

  SupportContactStore get _store => store ?? SupportContactStore.instance;

  final AuthFooterLauncher launcher;

  /// For tests: the full-width band the footer sits on.
  static const bandKey = ValueKey<String>('auth-footer-band');

  /// For tests: the bottom row (copyright, version, social icons).
  static const bottomRowKey = ValueKey<String>('auth-footer-bottom-row');

  /// For tests: the brand column (the mark, the app name and, AN5, the description line).
  static const brandKey = ValueKey<String>('auth-footer-brand');


  @override
  Widget build(BuildContext context) {
    // The band: edge to edge, whatever the page puts around the footer.
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        key: bandKey,
        decoration: BoxDecoration(
          color: context.colors.authFooterFill,
          border: Border(top: BorderSide(color: context.colors.divider, width: AuthFooterMetrics.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuthCardMetrics.pageMargin),
          child: Center(
            child: ConstrainedBox(
              // Lines up with the card above it.
              constraints: const BoxConstraints(maxWidth: AuthCardMetrics.maxWidthWide),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Wide is a mouse (G5): 32 px link rows, less padding and
                  // a small gap above the line. Phones and narrow windows
                  // are touch: 48 px targets, whose own space is the gap
                  // under a row of links.
                  final isWide = constraints.maxWidth > AppBreakpoints.medium;
                  const gap = SizedBox(width: AuthFooterMetrics.columnGap, height: AuthFooterMetrics.sectionGap);
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isWide ? AuthFooterMetrics.paddingVerticalWide : AuthFooterMetrics.paddingVertical,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: AuthFooterMetrics.brandFlex, child: _brand(context, isWide)),
                              gap,
                              Expanded(child: _platformColumn(context, isWide)),
                              gap,
                              Expanded(child: _supportColumn(context, isWide)),
                              gap,
                              Expanded(child: _legalColumn(context, isWide)),
                            ],
                          )
                        else ...[
                          // Phones: the brand, then the columns two by two.
                          _brand(context, isWide),
                          gap,
                          _pair(_platformColumn(context, isWide), _supportColumn(context, isWide)),
                          const SizedBox(height: AuthFooterMetrics.linksGapNarrow),
                          _pair(_legalColumn(context, isWide), const SizedBox.shrink()),
                        ],
                        if (isWide) const SizedBox(height: AuthFooterMetrics.lineGapWide),
                        Divider(
                          height: AuthFooterMetrics.hairline,
                          thickness: AuthFooterMetrics.hairline,
                          color: context.colors.divider,
                        ),
                        _bottomRow(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pair(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: AuthFooterMetrics.columnGap),
          Expanded(child: right),
        ],
      );

  Widget _brand(BuildContext context, bool isWide) {
    return Column(
      key: brandKey,
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
        // AN4: the welcome note's sentence is not repeated here (once, not
        // twice). AN5: the owner's sentence about the app in its place; static
        // text, at most four lines (three in the wide brand column: the English
        // takes two there, under the links, and the Kiswahili is never cut), so
        // nothing shifts.
        const SizedBox(height: AppSpacing.s8),
        Text(
          context.l10n.authFooter_description,
          maxLines: isWide ? AuthFooterMetrics.descriptionMaxLinesWide : AuthFooterMetrics.descriptionMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.authFooterMutedText, fontSize: AppFontSize.f13),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Text(text,
      style: TextStyle(color: context.colors.textPrimary, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13));

  Widget _column(BuildContext context, String heading, List<Widget> links) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_heading(context, heading), ...links],
      );

  // UI8: each link's text and target come from AuthLink, which the phone
  // help sheet reads too.
  Widget _link(BuildContext context, AuthLink link, bool isWide) =>
      _FooterLink(compact: isWide, label: link.label(context.l10n), button: link.button, onTap: () => link.open(context, _store));

  Widget _platformColumn(BuildContext context, bool isWide) => _column(context, context.l10n.authFooter_platform, [
        _link(context, AuthLink.about, isWide),
        _link(context, AuthLink.howToUse, isWide),
      ]);

  Widget _supportColumn(BuildContext context, bool isWide) => _column(context, context.l10n.authFooter_support, [
        _link(context, AuthLink.helpContact, isWide),
        _link(context, AuthLink.faq, isWide),
      ]);

  Widget _legalColumn(BuildContext context, bool isWide) => _column(context, context.l10n.authFooter_legal, [
        _link(context, AuthLink.privacy, isWide),
        _link(context, AuthLink.terms, isWide),
      ]);

  /// Copyright and version, and the social icons. G6: its height never
  /// depends on the icons (the owner saw the footer jump when they arrived):
  /// the icons' line is always kept at the icon target, and they fade in
  /// with opacity only. Wide enough: one line, the icons in a slot at the
  /// right as wide as every network; narrower: their own line under the text.
  Widget _bottomRow(BuildContext context) {
    final muted = TextStyle(color: context.colors.authFooterMutedText, fontSize: AppFontSize.f12);
    final text = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s4,
      children: [
        Text(context.l10n.login_copyright(AppInfo.name), style: muted),
        // FIN1: the build stamp after the version, so the owner can tell which
        // build a phone has open.
        Text(context.l10n.common_versionWithBuild(AppInfo.versionLabel, AppInfo.buildStamp), style: muted),
      ],
    );
    final icons = ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final links = _store.current?.socialLinks ?? const [];
        return AnimatedOpacity(
          opacity: links.isEmpty ? 0 : 1,
          duration: AppMotion.normal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final link in links) _socialButton(context, link.key, link.value)],
          ),
        );
      },
    );
    return LayoutBuilder(
      key: bottomRowKey,
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.compact) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AuthFooterMetrics.bottomRowHeight),
            child: Row(
              children: [
                Expanded(child: text),
                // Always as wide as every network, so the text beside it
                // never reflows when the icons arrive.
                SizedBox(
                  width: AuthFooterMetrics.tapTarget * SocialNetwork.values.length,
                  child: Align(alignment: AlignmentDirectional.centerEnd, child: icons),
                ),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AuthFooterMetrics.tapTarget),
              child: Align(alignment: AlignmentDirectional.centerStart, child: text),
            ),
            SizedBox(
              height: AuthFooterMetrics.bottomRowHeight,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                // Six targets fit from 288 px; a narrower line scales them down.
                child: FittedBox(fit: BoxFit.scaleDown, child: icons),
              ),
            ),
          ],
        );
      },
    );
  }

  // UI8: the help sheet shows the same icons (AuthSocial).
  Widget _socialButton(BuildContext context, SocialNetwork network, Uri uri) =>
      AuthSocial.button(context, network, uri, color: context.colors.authFooterMutedText, launcher: launcher);
}

/// A text link in the footer: the shared HoverLink (G4) in the footer's
/// size, primary at rest.
class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap, this.button = false, this.compact = false});

  final String label;
  final VoidCallback onTap;
  final bool button;

  /// Wide windows (a mouse): a 32 px row instead of the 48 px touch target.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return HoverLink(
      label: label,
      onTap: onTap,
      button: button,
      minHeight: compact ? AuthFooterMetrics.linkRowHeightWide : AuthFooterMetrics.tapTarget,
      style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13),
    );
  }
}
