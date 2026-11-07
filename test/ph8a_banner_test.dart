// PH8a (2): the subscription banner on phones. One state from today's rules
// (the pill's): locked, grace, the calm trial, the last 7 days of a trial or
// a paid subscription; today's sentences unchanged. On a phone a slim banner
// at the top of EVERY tab under its app bar, from one place (the PhoneShell),
// never over the app bar, the floating button or the bar; not on pushed deep
// screens; the snooze exactly as today (2 hours, every state, in memory).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/screens/dashboard/subscription_banner.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';

import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

// Was true until the implementation (every call threw UnimplementedError).
const _skip = false;

const _banner = ValueKey('phone-subscription-banner');

const _states = [
  SubscriptionBannerState(SubscriptionBannerKind.locked),
  SubscriptionBannerState(SubscriptionBannerKind.grace),
  SubscriptionBannerState(SubscriptionBannerKind.calmTrial, 20),
  SubscriptionBannerState(SubscriptionBannerKind.calmTrial),
  SubscriptionBannerState(SubscriptionBannerKind.trialEnding, 5),
  SubscriptionBannerState(SubscriptionBannerKind.paidEnding, 1),
];

Future<void> _pump(WidgetTester tester, Widget home,
    {Size size = const Size(390, 844), String locale = 'en', bool dark = false, bool realFont = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    theme: realFont ? _real(AppTheme.build(AppColorTheme.pasture, dark ? Brightness.dark : Brightness.light))
        : AppTheme.build(AppColorTheme.pasture, dark ? Brightness.dark : Brightness.light),
    home: home,
  ));
  await tester.pumpAndSettle();
}

// Where a line wraps needs a real font: the square test font is twice as wide.
ThemeData _real(ThemeData t) => t.copyWith(textTheme: t.textTheme.apply(fontFamily: realFontFamily));

Widget _list(String title, {bool fab = false}) => PhoneListScaffold<String>(
      title: title,
      asTab: true,
      menu: const [],
      searchController: TextEditingController(),
      searchHint: 'Search',
      onSearchChanged: (_) {},
      onSearchClosed: () {},
      quickChips: PhoneQuickChips(values: const ['All'], selected: 'All', label: (v) => v, onSelected: (_) {}),
      filtersActive: false,
      onFilter: null,
      appliedFilters: const [],
      summaryLine: null,
      onSummary: () {},
      items: [for (var i = 0; i < 30; i++) '$title row $i'],
      idOf: (s) => s,
      dateOf: (_) => DateTime(2026),
      amountOf: (_) => 0,
      grouped: false,
      tileBuilder: (context, s, {required grouped}) => SizedBox(height: 64, child: Text(s)),
      loading: false,
      error: null,
      onRetry: () {},
      emptyIcon: Icons.inbox,
      emptyText: 'None',
      fab: fab ? PhoneListAction(label: 'Record', icon: Icons.add, onPressed: () {}) : null,
      hasMore: false,
      loadingMore: false,
      onLoadMore: () {},
      onRefresh: () async {},
    );

Widget _shell({Widget? banner}) => PhoneShell(
      homeAppBar: AppBar(title: const Text('HOME BAR')),
      banner: banner,
      home: (_) => ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('home row $i'))]),
      sales: (_) => _list('Sales'),
      products: (context) => _list('Products', fab: true),
      more: (_) => MoreScreen(isAdmin: true, onOpen: (context, item) async {
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _list('Deep', fab: true)));
      }),
      onRecord: () {},
    );

Widget _phoneBanner(SubscriptionBannerState state, {bool admin = true, VoidCallback? onOpen, VoidCallback? onSnooze}) =>
    PhoneSubscriptionBanner(
      key: _banner,
      state: state,
      isAdmin: admin,
      onOpenSubscription: onOpen ?? () {},
      onSnooze: onSnooze ?? () {},
    );

bool _overlaps(Rect a, Rect b) => a.intersect(b).width > 0 && a.intersect(b).height > 0;

void main() {
  group('the state, from today\'s rules', () {
    test('every status', () {
      SubscriptionBannerState? s(SubscriptionStatus st, int? days, {bool calm = false}) =>
          subscriptionBannerFor(status: st, daysRemaining: days, inCalmTrial: calm);
      expect(s(SubscriptionStatus.locked, -3), const SubscriptionBannerState(SubscriptionBannerKind.locked));
      expect(s(SubscriptionStatus.grace, -1), const SubscriptionBannerState(SubscriptionBannerKind.grace));
      expect(s(SubscriptionStatus.trial, 20, calm: true), const SubscriptionBannerState(SubscriptionBannerKind.calmTrial, 20));
      expect(s(SubscriptionStatus.trial, null, calm: true), const SubscriptionBannerState(SubscriptionBannerKind.calmTrial));
      expect(s(SubscriptionStatus.trial, 7), const SubscriptionBannerState(SubscriptionBannerKind.trialEnding, 7));
      expect(s(SubscriptionStatus.active, 1), const SubscriptionBannerState(SubscriptionBannerKind.paidEnding, 1));
      expect(s(SubscriptionStatus.active, 8), isNull);
      expect(s(SubscriptionStatus.active, null), isNull);
    }, skip: _skip);

    testWidgets('today\'s sentences, unchanged', (tester) async {
      await _pump(tester, Builder(builder: (context) {
        final l = context.l10n;
        String t(SubscriptionBannerKind k, [int? d]) => subscriptionBannerSentence(l, SubscriptionBannerState(k, d));
        expect(t(SubscriptionBannerKind.locked), l.subscription_expiredReadOnly);
        expect(t(SubscriptionBannerKind.grace), l.subscription_expiredGrace);
        expect(t(SubscriptionBannerKind.calmTrial, 20), l.subscription_freeTrialDaysLeft(20));
        expect(t(SubscriptionBannerKind.calmTrial), l.subscription_onFreeTrial);
        expect(t(SubscriptionBannerKind.trialEnding, 5), l.subscription_trialExpiresIn(5));
        expect(t(SubscriptionBannerKind.paidEnding, 1), l.subscription_expiresIn(1));
        return const SizedBox();
      }));
    }, skip: _skip);
  });

  group('the snooze, as today', () {
    test('2 hours from the tap, whatever the state; a new sign-in starts unsnoozed', () {
      final at = DateTime(2026, 11, 3, 9);
      final snooze = SubscriptionBannerSnooze();
      expect(snooze.isSnoozed(at), isFalse);
      snooze.snooze(at);
      expect(snooze.isSnoozed(at.add(const Duration(hours: 1, minutes: 59))), isTrue);
      expect(snooze.isSnoozed(at.add(const Duration(hours: 2))), isFalse);
      expect(SubscriptionBannerSnooze().isSnoozed(at), isFalse);
    }, skip: _skip);
  });

  group('the phone banner', () {
    setUpAll(loadRealFont);
    for (final state in _states) {
      for (final (size, locale, dark) in [
        (const Size(360, 740), 'sw', false),
        (const Size(390, 844), 'en', true),
        (const Size(740, 360), 'sw', false),
      ]) {
        testWidgets('$state at ${size.width.toInt()}x${size.height.toInt()} $locale${dark ? ' dark' : ''}: '
            'at most two lines, 48 px targets, colour and text', (tester) async {
          for (final admin in [true, false]) {
            await _pump(tester, Scaffold(body: Align(alignment: Alignment.topCenter, child: _phoneBanner(state, admin: admin))),
                size: size, locale: locale, dark: dark, realFont: true);
            await checkCase(tester, phone: true, where: '$state admin $admin');
            final line = tester.renderObject<RenderParagraph>(
                find.descendant(of: find.byKey(const ValueKey('phone-subscription-banner-text')), matching: find.byType(RichText)));
            expect(line.didExceedMaxLines, isFalse);
            expect(tester.getSize(find.byKey(const ValueKey('phone-subscription-banner-text'))).height,
                lessThanOrEqualTo(2 * 14 * 1.5), reason: 'two lines at most');
            final colors = tester.element(find.byKey(_banner)).colors;
            final role = switch (state.kind) {
              SubscriptionBannerKind.locked => colors.danger,
              SubscriptionBannerKind.calmTrial => colors.info,
              _ => colors.warning,
            };
            // PH8a-fix: the role is the fill now (it floats over the content);
            // the icon is the ink that reads on it (ph8a_fix_banner_test.dart).
            final fill = tester.widget<DecoratedBox>(find.byKey(const ValueKey('phone-subscription-banner-fill')));
            expect((fill.decoration as BoxDecoration).color, role.withValues(alpha: PhoneBannerMetrics.overlayAlpha));
            expect(tester.widget<Icon>(find.descendant(of: find.byKey(_banner), matching: find.byType(Icon)).first).color,
                colors.bannerInk);
          }
        }, skip: _skip);
      }
    }

    testWidgets('an admin\'s Renew and Details open Subscription; the close button snoozes', (tester) async {
      var opened = 0;
      var snoozed = 0;
      await _pump(tester, Scaffold(body: _phoneBanner(_states[0], onOpen: () => opened++, onSnooze: () => snoozed++)));
      await tester.tap(find.text('Renew'));
      await tester.tap(find.byTooltip('Close'));
      await _pump(tester, Scaffold(body: _phoneBanner(_states[2], onOpen: () => opened++)));
      await tester.tap(find.text('Details'));
      expect((opened, snoozed), (2, 1));
    }, skip: _skip);

    testWidgets('an assistant\'s Details shows today\'s sentence; nothing opens Subscription', (tester) async {
      var opened = 0;
      await _pump(tester, Scaffold(body: _phoneBanner(_states[1], admin: false, onOpen: () => opened++)));
      expect(find.text('Renew'), findsNothing);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      final l = tester.element(find.byType(AlertDialog)).l10n;
      expect(find.text(l.subscription_expiredGrace), findsOneWidget);
      expect(find.text('Your admin manages the subscription.'), findsOneWidget);
      expect(opened, 0);
    }, skip: _skip);
  });

  group('in the phone shell', () {
    for (final (tab, label) in [('home', null), ('sales', 'Sales'), ('products', 'Products'), ('more', 'More')]) {
      testWidgets('on $tab: under the app bar, never over the floating button or the bar', (tester) async {
        await _pump(tester, _shell(banner: _phoneBanner(_states[4])));
        if (label != null) {
          await tester.tap(find.descendant(of: find.byType(PhoneBottomBar), matching: find.text(label)));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(_banner), findsOneWidget);
        final banner = tester.getRect(find.byKey(_banner));
        final appBar = tester.getRect(find.byType(AppBar).hitTestable().first);
        expect(banner.top, greaterThanOrEqualTo(appBar.bottom));
        final bar = tester.getRect(find.byType(PhoneBottomBar));
        expect(_overlaps(banner, bar), isFalse);
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) expect(_overlaps(banner, tester.getRect(fab)), isFalse);
      }, skip: _skip);
    }

    testWidgets('not on a pushed deep screen, nor with no banner', (tester) async {
      await _pump(tester, _shell(banner: _phoneBanner(_states[0])));
      await tester.tap(find.descendant(of: find.byType(PhoneBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Deep'), findsOneWidget);
      expect(find.byKey(_banner), findsNothing);
      await _pump(tester, _shell());
      expect(find.byKey(_banner), findsNothing);
    }, skip: _skip);
  });
}
