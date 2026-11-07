// PH8a-fix (2), the owner's correction: on a phone the subscription banner
// floats OVER the tab content instead of pushing it down. The tab content
// keeps its full height and never moves when the banner comes, goes or is
// snoozed; the banner's top is the current tab's app bar bottom, with an
// 8 px side margin, a 12 px radius, a soft shadow and the status role at
// PhoneBannerMetrics.overlayAlpha (slightly see-through, no blend into the
// surface); it slides and fades in (not under reduced motion); its text and
// icons pass 4.5:1 over the worst backdrop (pure black and pure white
// content) in every state, in the four themes, Light and Dark; it is a live
// region. Everything else is PH8a's, still pinned by ph8a_banner_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/screens/dashboard/subscription_banner.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';

const _skip = true;

const _banner = ValueKey('phone-subscription-banner');
const _fill = ValueKey('phone-subscription-banner-fill');

const _states = [
  SubscriptionBannerState(SubscriptionBannerKind.locked),
  SubscriptionBannerState(SubscriptionBannerKind.grace),
  SubscriptionBannerState(SubscriptionBannerKind.calmTrial, 20),
  SubscriptionBannerState(SubscriptionBannerKind.calmTrial),
  SubscriptionBannerState(SubscriptionBannerKind.trialEnding, 5),
  SubscriptionBannerState(SubscriptionBannerKind.paidEnding, 1),
];

Widget _app(Widget home, {AppColorTheme theme = AppColorTheme.pasture, bool dark = false, bool reduceMotion = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(theme, dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => reduceMotion
          ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
          : child!,
      home: home,
    );

void _size(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

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

/// The shell with the banner the dashboard would give it: [shown] holds it,
/// and its close button snoozes it (null, as the dashboard does).
Widget _shell(ValueNotifier<SubscriptionBannerState?> shown) => ValueListenableBuilder<SubscriptionBannerState?>(
      valueListenable: shown,
      builder: (context, state, _) => PhoneShell(
        homeAppBar: AppBar(title: const Text('HOME BAR')),
        banner: state == null
            ? null
            : PhoneSubscriptionBanner(
                key: _banner,
                state: state,
                isAdmin: true,
                onOpenSubscription: () {},
                onSnooze: () => shown.value = null,
              ),
        home: (_) => ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Home row $i'))]),
        sales: (_) => _list('Sales'),
        products: (_) => _list('Products', fab: true),
        more: (_) => _list('More'),
        onRecord: () {},
      ),
    );

Future<void> _tab(WidgetTester tester, String? label) async {
  if (label == null) return;
  await tester.tap(find.descendant(of: find.byType(PhoneBottomBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

bool _overlaps(Rect a, Rect b) => a.intersect(b).width > 0 && a.intersect(b).height > 0;

void main() {
  test('the fill\'s alpha is a named constant, about 92 percent', () {
    expect(PhoneBannerMetrics.overlayAlpha, 0.92);
  }, skip: _skip);

  for (final (tab, label) in [('Home', null), ('Sales', 'Sales')]) {
    testWidgets('on $tab the first row does not move: banner present, absent, snoozed', (tester) async {
      _size(tester);
      final shown = ValueNotifier<SubscriptionBannerState?>(null);
      await tester.pumpWidget(_app(_shell(shown)));
      await _tab(tester, label);
      final row = find.text('$tab row 0');
      final absent = tester.getRect(row);
      shown.value = _states[4];
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsOneWidget);
      expect(tester.getRect(row), absent, reason: 'present');
      await tester.tap(find.descendant(of: find.byKey(_banner), matching: find.byTooltip('Close')));
      await tester.pumpAndSettle();
      expect(find.byKey(_banner), findsNothing);
      expect(tester.getRect(row), absent, reason: 'snoozed');
    }, skip: _skip);
  }

  for (final (tab, label) in [('Home', null), ('Sales', 'Sales'), ('Products', 'Products'), ('More', 'More')]) {
    testWidgets('on $tab: top at the app bar\'s bottom, 8 px margins, clear of the app bar, the FAB and the bar', (tester) async {
      _size(tester);
      await tester.pumpWidget(_app(_shell(ValueNotifier(_states[0]))));
      await _tab(tester, label);
      final banner = tester.getRect(find.byKey(_banner));
      final appBar = tester.getRect(find.byType(AppBar).hitTestable().first);
      expect(banner.top, moreOrLessEquals(appBar.bottom));
      expect(_overlaps(banner, appBar), isFalse);
      expect(banner.left, PhoneBannerMetrics.overlayMargin);
      expect(banner.right, 390 - PhoneBannerMetrics.overlayMargin);
      expect(_overlaps(banner, tester.getRect(find.byType(PhoneBottomBar))), isFalse);
      final fab = find.byType(FloatingActionButton);
      if (label == 'Products') expect(fab, findsOneWidget);
      if (fab.evaluate().isNotEmpty) expect(_overlaps(banner, tester.getRect(fab)), isFalse);
    }, skip: _skip);
  }

  testWidgets('a 12 px radius, a soft shadow, the role see-through (no blend into the surface), a live region',
      (tester) async {
    _size(tester);
    for (final state in _states) {
      await tester.pumpWidget(_app(_shell(ValueNotifier(state))));
      final colors = tester.element(find.byKey(_banner)).colors;
      final box = tester.widget<DecoratedBox>(find.byKey(_fill)).decoration as BoxDecoration;
      final role = switch (state.kind) {
        SubscriptionBannerKind.locked => colors.danger,
        SubscriptionBannerKind.calmTrial => colors.info,
        _ => colors.warning,
      };
      expect(box.color, role.withValues(alpha: PhoneBannerMetrics.overlayAlpha), reason: '$state');
      expect(box.borderRadius, BorderRadius.circular(PhoneBannerMetrics.overlayRadius));
      expect(PhoneBannerMetrics.overlayRadius, 12);
      expect(box.boxShadow, isNotEmpty);
      expect(
          find.descendant(
              of: find.byKey(_banner), matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true)),
          findsOneWidget);
    }
  }, skip: _skip);

  for (final theme in AppColorTheme.all) {
    for (final dark in [false, true]) {
      testWidgets('${theme.id} ${dark ? 'Dark' : 'Light'}: text and icons 4.5:1 over black and over white content, every state',
          (tester) async {
        _size(tester);
        for (final state in _states) {
          for (final admin in [true, false]) {
            await tester.pumpWidget(_app(
                Scaffold(
                    body: PhoneSubscriptionBanner(
                        key: _banner, state: state, isAdmin: admin, onOpenSubscription: () {}, onSnooze: () {})),
                theme: theme,
                dark: dark));
            final fill = (tester.widget<DecoratedBox>(find.byKey(_fill)).decoration as BoxDecoration).color!;
            final inks = <Color>[
              for (final p in tester.renderObjectList<RenderParagraph>(
                  find.descendant(of: find.byKey(_banner), matching: find.byType(RichText))))
                p.text.style!.color!,
              for (final i in tester.widgetList<Icon>(find.descendant(of: find.byKey(_banner), matching: find.byType(Icon))))
                i.color!,
            ];
            expect(inks.length, greaterThanOrEqualTo(4), reason: 'the line, the action, the icon and the close');
            for (final backdrop in [const Color(0xFF000000), const Color(0xFFFFFFFF)]) {
              final over = ColorMath.composite(fill, backdrop);
              for (final ink in inks) {
                expect(ColorMath.contrast(ink, over), greaterThanOrEqualTo(4.5),
                    reason: '$state admin $admin over $backdrop: $ink on $over');
              }
            }
          }
        }
      }, skip: _skip);
    }
  }

  for (final reduce in [false, true]) {
    testWidgets(reduce ? 'reduced motion: there at once, no slide or fade' : 'it slides and fades in', (tester) async {
      _size(tester);
      final shown = ValueNotifier<SubscriptionBannerState?>(null);
      await tester.pumpWidget(_app(_shell(shown), reduceMotion: reduce));
      shown.value = _states[1];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The shell's own entrance, not the route's transitions further up.
      final entrance = find.byKey(const ValueKey('phone-subscription-banner-entrance'));
      expect(find.descendant(of: entrance, matching: find.byKey(_banner)), findsOneWidget);
      final fade = tester.widget<FadeTransition>(find.descendant(of: entrance, matching: find.byType(FadeTransition)).first);
      final slide = tester.widget<SlideTransition>(find.descendant(of: entrance, matching: find.byType(SlideTransition)).first);
      if (reduce) {
        expect(fade.opacity.value, 1);
        expect(slide.position.value, Offset.zero);
        expect(tester.hasRunningAnimations, isFalse);
      } else {
        expect(fade.opacity.value, lessThan(1));
        expect(slide.position.value, isNot(Offset.zero));
        await tester.pumpAndSettle();
        expect(fade.opacity.value, 1);
      }
    }, skip: _skip);
  }
}
