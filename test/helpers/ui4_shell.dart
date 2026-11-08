// UI4: what the trough and dead-band tests share (ui4_trough_test,
// ui4_dead_band_test): the shell around plain or real tabs (Home, Sales and
// More drawn by the real screens), and the trough's points.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';

import 'phone_home_harness.dart';
import 'real_font.dart';

const ui4R = PhoneShellMetrics.recordSize / 2;

// A Material icon draws in the 20 px live area of its 24 px box.
const ui4IconLiveInset = 2.0;

/// Every half pixel of [path] inside the trough's opening.
List<Offset> ui4TroughPoints(Path path, double centerX, double top) => [
      for (final PathMetric m in path.computeMetrics())
        for (var d = 0.0; d < m.length; d += 0.5)
          if ((m.getTangentForOffset(d)!.position.dx - centerX).abs() < PhoneShellMetrics.troughWidth / 2 &&
              m.getTangentForOffset(d)!.position.dy > top + 0.01)
            m.getTangentForOffset(d)!.position,
    ];

double ui4Gap(Rect r, Offset p) =>
    Offset(math.max(0, math.max(r.left - p.dx, p.dx - r.right)), math.max(0, math.max(r.top - p.dy, p.dy - r.bottom))).distance;

Widget ui4List(String title) => PhoneListScaffold<String>(
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
      fab: null,
      hasMore: false,
      loadingMore: false,
      onLoadMore: () {},
      onRefresh: () async {},
    );

Widget ui4Plain(String name) => Scaffold(
      body: ListView(
        key: ValueKey('$name list'),
        children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('$name row $i'))],
      ),
    );

double? ui4SeenOverhang;
Completer<void>? ui4Sheet;

Future<void> ui4Shell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  bool real = false,
  bool realFont = false,
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: realFont ? _realFont(AppTheme.build(theme, brightness)) : AppTheme.build(theme, brightness),
    home: PhoneShell(
      home: (context) {
        ui4SeenOverhang = PhoneShellInsets.overhangOf(context);
        return real
            ? PhoneHome(
                figures: ph4BigFigures,
                isAdmin: true,
                period: 'Today',
                onPeriodChanged: (_) {},
                attention: ph4SomeAttention,
                onAllDetails: () {},
                onQuickAction: (_) async {},
                onViewAll: () {},
                onGoTo: (_) {},
                onAttention: (_) {},
              )
            : ui4Plain('home');
      },
      sales: (_) => real ? ui4List('Sales') : ui4Plain('sales'),
      products: (_) => ui4Plain('products'),
      more: (_) => real ? MoreScreen(isAdmin: true, onOpen: (_, __) async {}) : ui4Plain('more'),
      onRecord: () => (ui4Sheet = Completer<void>()).future,
    ),
  ));
  await tester.pumpAndSettle();
}

// The square test font draws text about twice as wide as real text.
ThemeData _realFont(ThemeData t) => t.copyWith(textTheme: t.textTheme.apply(fontFamily: realFontFamily));

final ui4Bar = find.byType(PhoneBottomBar);
final ui4Shape = find.byKey(const ValueKey('phone-bar-shape'));
final ui4Record = find.byKey(const ValueKey('phone-bar-record'));
