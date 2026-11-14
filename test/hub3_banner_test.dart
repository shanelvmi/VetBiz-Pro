// HUB3 (4): the subscription banner keeps its place (floating under Home's
// app bar), its close and every rule (ph8a_banner_test and
// ph8a_fix_banner_test stay green), but looks calm: a soft tint of the status
// role over the surface (PhoneBannerMetrics.tintAlpha, 14 to 18 percent)
// with a 1 px border of the role at about 40 percent, still slightly
// see-through (PhoneBannerMetrics.overlayAlpha on the tint); the icon and the
// text in the role's deep ink, 4.5:1 over the tint in every theme, Light and
// Dark, over a light and a dark backdrop; Renew (or Details) a small filled
// pill in the solid role with its on-colour ink at 4.5:1; the close a 48 px
// target.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/subscription_banner.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';

const _skip = false;

const _banner = ValueKey('phone-subscription-banner');
const _fill = ValueKey('phone-subscription-banner-fill');
const _action = ValueKey('phone-subscription-banner-action');

const _states = [
  SubscriptionBannerState(SubscriptionBannerKind.locked),
  SubscriptionBannerState(SubscriptionBannerKind.grace),
  SubscriptionBannerState(SubscriptionBannerKind.calmTrial, 20),
  SubscriptionBannerState(SubscriptionBannerKind.trialEnding, 5),
  SubscriptionBannerState(SubscriptionBannerKind.paidEnding, 1),
];

Future<void> _pump(WidgetTester tester, SubscriptionBannerState state,
    {AppColorTheme theme = AppColorTheme.pasture, bool dark = false, bool admin = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.build(theme, dark ? Brightness.dark : Brightness.light),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: PhoneSubscriptionBanner(key: _banner, state: state, isAdmin: admin, onOpenSubscription: () {}, onSnooze: () {}),
      ),
    ),
  ));
}

void main() {
  test('the tint and its border are named constants in range', () {
    expect(PhoneBannerMetrics.tintAlpha, inInclusiveRange(0.14, 0.18));
    expect(PhoneBannerMetrics.borderAlpha, closeTo(0.40, 0.05));
    expect(PhoneBannerMetrics.overlayAlpha, 0.92, reason: 'the see-through alpha is kept, applied to the tint');
  }, skip: _skip);

  testWidgets('a soft tint of the role over the surface, a 1 px role border, no solid fill', (tester) async {
    for (final state in _states) {
      await _pump(tester, state);
      final colors = tester.element(find.byKey(_banner)).colors;
      final role = phoneBannerRole(colors, state.kind);
      final box = tester.widget<DecoratedBox>(find.byKey(_fill)).decoration as BoxDecoration;
      final tint = Color.alphaBlend(role.withValues(alpha: PhoneBannerMetrics.tintAlpha), colors.surface);
      expect(box.color, tint.withValues(alpha: PhoneBannerMetrics.overlayAlpha), reason: '$state');
      final border = box.border! as Border;
      expect(border.top.width, 1);
      expect(border.top.color, role.withValues(alpha: PhoneBannerMetrics.borderAlpha));
    }
  }, skip: _skip);

  for (final theme in AppColorTheme.all) {
    for (final dark in [false, true]) {
      testWidgets('${theme.id} ${dark ? 'Dark' : 'Light'}: the line and icons 4.5:1 on the tint over light and dark content; '
          'the pill\'s ink 4.5:1 on the solid role', (tester) async {
        for (final state in _states) {
          for (final admin in [true, false]) {
            await _pump(tester, state, theme: theme, dark: dark, admin: admin);
            final colors = tester.element(find.byKey(_banner)).colors;
            final fill = (tester.widget<DecoratedBox>(find.byKey(_fill)).decoration as BoxDecoration).color!;
            final action = find.byKey(_action);
            final inks = <Color>[
              for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(
                  of: find.byKey(_banner),
                  matching: find.byWidgetPredicate((w) =>
                      w is RichText && find.descendant(of: action, matching: find.byWidget(w)).evaluate().isEmpty))))
                p.text.style!.color!,
              for (final i in tester.widgetList<Icon>(find.descendant(of: find.byKey(_banner), matching: find.byType(Icon))))
                i.color!,
            ];
            expect(inks.length, greaterThanOrEqualTo(3), reason: 'the line, the icon and the close');
            for (final backdrop in [colors.background, const Color(0xFF000000), const Color(0xFFFFFFFF)]) {
              final over = ColorMath.composite(fill, backdrop);
              for (final ink in inks) {
                expect(ColorMath.contrast(ink, over), greaterThanOrEqualTo(4.5), reason: '$state over $backdrop: $ink on $over');
              }
            }
            final pill = tester.widget<DecoratedBox>(
                find.descendant(of: action, matching: find.byKey(const ValueKey('phone-subscription-banner-pill'))));
            final pillFill = (pill.decoration as BoxDecoration).color!;
            expect(pillFill, phoneBannerRole(colors, state.kind), reason: 'the solid role');
            final pillInk = tester.renderObject<RenderParagraph>(
                find.descendant(of: action, matching: find.byType(RichText)).first).text.style!.color!;
            expect(ColorMath.contrast(pillInk, pillFill), greaterThanOrEqualTo(4.5), reason: '$state pill');
          }
        }
      }, skip: _skip);
    }
  }

  testWidgets('the close is a 48 px target; Renew is a small pill', (tester) async {
    await _pump(tester, _states[1]);
    final close = find.descendant(of: find.byKey(_banner), matching: find.byType(IconButton));
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    expect(find.descendant(of: find.byKey(_action), matching: find.text('Renew')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('phone-subscription-banner-pill'))).height, lessThanOrEqualTo(32));
  }, skip: _skip);
}
