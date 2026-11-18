// LAY2: AppSidebar (computer sidebar and tablet rail) and WideTopBar, built
// from the destination registry. The full DashboardScreen needs Firebase and
// no test pumps it, so the dashboard's own wiring (what a tap opens, the
// rail on a tablet, no drawer) is pinned by reading its source; the widgets
// themselves are pumped at the real widths, themes and text scale.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/widgets/profile/profile_menu_button.dart';
import 'package:vetbiz_pro/widgets/shell/app_sidebar.dart';
import 'package:vetbiz_pro/widgets/shell/sidebar_item.dart';
import 'package:vetbiz_pro/widgets/shell/wide_top_bar.dart';

import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

final lookupEn = lookupAppLocalizations(const Locale('en'));

const _platformKey = ValueKey('platform-admin-item');

Widget _sidebar({
  AppDestination selected = AppDestination.home,
  bool collapsed = false,
  bool isAdmin = true,
  bool platformAdmin = false,
  ValueChanged<AppDestination>? onSelect,
}) =>
    Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selected: selected,
            onSelect: onSelect ?? (_) {},
            collapsed: collapsed,
            destinations: shellDestinationsFor(isAdmin: isAdmin),
            header: (c) => SizedBox(height: c ? 60 : 100),
            platformAdminItem: platformAdmin ? const SizedBox(key: _platformKey, height: 44) : null,
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );

List<DrawerHoverItem> _items(WidgetTester tester) =>
    tester.widgetList<DrawerHoverItem>(find.byType(DrawerHoverItem)).toList();

const _ownerOrder = [
  'Home', 'Insights', 'Sales', 'Services', 'Clients', 'Debtors', //
  'Payments', 'Transactions', 'Products', 'Stock', 'Reports', 'Settings',
];

void main() {
  setUpAll(loadRealFont);

  for (final isAdmin in [true, false]) {
    testWidgets('1. the owner\'s order, ${isAdmin ? 'admin' : 'assistant'}', (tester) async {
      await pumpAtSize(tester, screen: _sidebar(isAdmin: isAdmin), size: const Size(1200, 800));
      expect(_items(tester).map((i) => i.title).toList(), _ownerOrder);
    });
  }

  testWidgets('2. the selected place: filled icon, pill, heavier label; others outlined', (tester) async {
    for (final sel in [AppDestination.home, AppDestination.sales, AppDestination.settings]) {
      await pumpAtSize(tester, screen: _sidebar(selected: sel), size: const Size(1200, 800));
      final items = _items(tester);
      for (final d in shellDestinationsFor(isAdmin: true)) {
        final item = items.firstWhere((i) => i.key == ValueKey('sidebar-${d.name}'));
        expect(item.selected, d == sel, reason: d.name);
        expect(item.icon, d == sel ? d.selectedIcon : d.icon, reason: '${sel.name}: ${d.name}');
      }
      final selText = tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('sidebar-${sel.name}')), matching: find.byType(Text)));
      final other = sel == AppDestination.home ? AppDestination.sales : AppDestination.home;
      final otherText = tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('sidebar-${other.name}')), matching: find.byType(Text)));
      expect(selText.style!.fontWeight!.value, greaterThan(otherText.style!.fontWeight!.value));
    }
  });

  testWidgets('3a. a tap hands the place to the caller', (tester) async {
    final tapped = <AppDestination>[];
    await pumpAtSize(tester, screen: _sidebar(onSelect: tapped.add), size: const Size(1200, 1000));
    for (final d in shellDestinationsFor(isAdmin: true)) {
      await tester.tap(find.byKey(ValueKey('sidebar-${d.name}')));
    }
    expect(tapped, shellDestinationsFor(isAdmin: true));
  });

  test('3b. the dashboard opens the same screens and refreshes Home only where the registry says', () {
    final src = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _openDestination(AppDestination d)');
    expect(start, greaterThan(0));
    final body = src.substring(start, src.indexOf('\n}\n', start));
    const screens = {
      'sales': 'SalesScreen()',
      'services': 'ServicesScreen()',
      'clients': 'ClientsScreen()',
      'debtors': 'DebtorsScreen()',
      'payments': 'const PaymentsScreen()',
      'transactions': 'TransactionScreen()',
      'products': 'ProductsScreen()',
      'stockStore': 'StockStoreScreen()',
      'reports': 'const ViewReportsScreen()',
      'settings': 'SettingsScreen()',
    };
    screens.forEach((d, screen) => expect(body, contains('AppDestination.$d => $screen'), reason: d));
    expect(body, contains('AppDestination.home || AppDestination.insights => null'));
    expect(body, contains('await showInsightsScreen(context)'));
    expect(body, contains('if (mounted && d.refreshHomeOnReturn) _refreshDashboardData();'));
    expect('_refreshDashboardData()'.allMatches(body).length, 1);
  });

  testWidgets('4. expanded 250 and collapsed 72; the collapse button and Fixed Mode stay wired', (tester) async {
    for (final size in [const Size(1024, 768), const Size(1200, 800)]) {
      await pumpAtSize(tester, screen: _sidebar(), size: size);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppSidebar)).width, AppSidebar.expandedWidth);
      expect(find.text('Sales'), findsOneWidget);
      await pumpAtSize(tester, screen: _sidebar(collapsed: true), size: size);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppSidebar)).width, AppSidebar.railWidth);
    }
    final src = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(src, contains('final bool collapsed = _isDrawerCollapsed && !layoutFixed;'));
    expect(src, contains('final bool effectivelyCollapsed = rail || (collapsed && !isSmallScreen);'));
    expect(src, contains('leading: rail || Provider.of<UiSettingsProvider>(context).layoutFixed'));
    expect(src, contains('onPressed: _toggleDrawerCollapsed,'));
  });

  testWidgets('5. the rail at 768: icons only, a tooltip and Semantics per place', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAtSize(tester, screen: _sidebar(collapsed: true), size: const Size(768, 1024));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
    for (final d in shellDestinationsFor(isAdmin: true)) {
      final key = find.byKey(ValueKey('sidebar-${d.name}'));
      expect(find.descendant(of: key, matching: find.byWidgetPredicate((w) => w is Tooltip && w.message == d.label(lookupEn))), findsOneWidget, reason: d.name);
      final node = tester.getSemantics(find.descendant(of: key, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == d.label(lookupEn))));
      expect(node.label, d.label(lookupEn));
      expect(node.flagsCollection.isSelected.toBoolOrNull(), d == AppDestination.home, reason: d.name);
      expect(node.flagsCollection.isButton, isTrue);
    }
    handle.dispose();
  });

  test('5b. the dashboard has no tablet drawer, AppBar or hamburger any more', () {
    final src = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(src, isNot(contains('Drawer(child: _buildDrawerContent())')));
    expect(src, isNot(contains('appBar: appBar')));
    expect(src, contains('_buildDrawerContent(rail: !isLargeScreen),'));
    expect(src, contains('_buildTopBar(context, rail: !isLargeScreen),'));
  });

  testWidgets('6. every place is a tap target of at least 44 x 44, both modes', (tester) async {
    for (final collapsed in [false, true]) {
      await pumpAtSize(tester, screen: _sidebar(collapsed: collapsed), size: const Size(1200, 1000));
      await tester.pumpAndSettle();
      for (final d in shellDestinationsFor(isAdmin: true)) {
        final r = tester.getSize(find.descendant(of: find.byKey(ValueKey('sidebar-${d.name}')), matching: find.byType(InkWell)));
        expect(r.width, greaterThanOrEqualTo(44), reason: '${d.name} collapsed=$collapsed');
        expect(r.height, greaterThanOrEqualTo(44), reason: '${d.name} collapsed=$collapsed');
      }
    }
  });

  for (final size in [const Size(768, 1024), const Size(1024, 768), const Size(1200, 800)]) {
    testWidgets('7. text 1.3 at ${size.width.toInt()}: sidebar and rail without overflow', (tester) async {
      for (final collapsed in [false, true]) {
        await pumpAtSize(tester, screen: _sidebar(collapsed: collapsed || size.width < 1024, platformAdmin: true), size: size, textScale: 1.3);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final width in [600.0, 719.0, 768.0, 900.0, 1023.0, 1024.0, 1200.0]) {
    testWidgets('7b. top bar at ${width.toInt()}, text 1.3: bell, Help and profile fit', (tester) async {
      final contentWidth = width - (width < 1024 ? AppSidebar.railWidth : AppSidebar.expandedWidth);
      await pumpAtSize(
        tester,
        size: Size(width, 800),
        textScale: 1.3,
        screen: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: contentWidth,
              child: WideTopBar(
                leading: width < 1024 ? null : IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
                search: const SizedBox(key: ValueKey('search'), height: 38, width: double.infinity),
                onSearchIcon: () {},
                trailing: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ProfileMenuButton(avatarUrl: null, name: 'Mwanaisha Abdallah Khamis', roleLabel: 'Co-admin', onTap: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final icon = find.byKey(const ValueKey('top-bar-search-icon'));
      if (width < 720) {
        expect(icon, findsOneWidget);
        expect(find.byKey(const ValueKey('search')), findsNothing);
      } else {
        expect(icon, findsNothing);
        expect(tester.getSize(find.byKey(const ValueKey('search'))).width, lessThanOrEqualTo(WideTopBar.searchMaxWidth));
      }
    });
  }

  test('8. the pill against the sidebar, every theme, Light and Dark (LAY2c floor)', () {
    var lowest = double.infinity;
    var lowestAt = '';
    final rows = <String>[];
    for (final theme in AppColorTheme.all) {
      for (final b in Brightness.values) {
        final c = AppColors.fromTheme(theme, brightness: b);
        final ratio = ColorMath.contrast(c.sidebarPress, c.brandSurface);
        final dE = ColorMath.deltaE(c.sidebarPress, c.brandSurface);
        // The item's ink (sidebar_item.dart onBrandInk): background in
        // Light, onBrandSurface in Dark.
        final ink = b == Brightness.dark ? c.onBrandSurface : c.background;
        final inkOnPill = ColorMath.contrast(ink, c.sidebarPress);
        rows.add('${theme.name} ${b.name}: ${ratio.toStringAsFixed(2)}:1, dE ${dE.toStringAsFixed(1)}, '
            'ink ${inkOnPill.toStringAsFixed(2)}:1');
        if (ratio < lowest) {
          lowest = ratio;
          lowestAt = '${theme.name} ${b.name}';
        }
        // LAY2c (owner): at least dE 12 from the sidebar (hover keeps 8),
        // and the label and icon at least 4.5:1 on the pill.
        expect(dE, greaterThanOrEqualTo(12), reason: '${theme.name} ${b.name}');
        expect(inkOnPill, greaterThanOrEqualTo(4.5), reason: '${theme.name} ${b.name}');
        // Lightness only: the pill keeps the rule's hue and saturation.
        final pill = HSLColor.fromColor(c.sidebarPress);
        final hover = HSLColor.fromColor(c.sidebarHover);
        expect((pill.hue - hover.hue).abs(), lessThan(1.5), reason: '${theme.name} ${b.name}');
      }
    }
    // ignore: avoid_print
    print('LAY2c pill on the sidebar: ${rows.join('; ')}. Lowest contrast $lowestAt ${lowest.toStringAsFixed(2)}');
  });

  testWidgets('8b. Light and Dark, every theme: the sidebar draws without error', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        await pumpAtSize(tester, screen: _sidebar(), size: const Size(1200, 800), look: look, colorTheme: theme);
        expect(tester.takeException(), isNull, reason: '${theme.name} ${look.name}');
        final box = tester.widget<AnimatedContainer>(find.descendant(
          of: find.byKey(const ValueKey('sidebar-home')),
          matching: find.byType(AnimatedContainer),
        ));
        final ctx = tester.element(find.byType(AppSidebar));
        expect((box.decoration! as BoxDecoration).color, Theme.of(ctx).extension<AppColors>()!.sidebarPress);
      }
    }
  });

  testWidgets('10. the Platform Admin item only when given, both modes', (tester) async {
    for (final collapsed in [false, true]) {
      await pumpAtSize(tester, screen: _sidebar(collapsed: collapsed, platformAdmin: true), size: const Size(1200, 1000));
      expect(find.byKey(_platformKey), findsOneWidget);
      await pumpAtSize(tester, screen: _sidebar(collapsed: collapsed), size: const Size(1200, 1000));
      expect(find.byKey(_platformKey), findsNothing);
    }
    final src = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(src, contains('future: _isPlatformAdmin(),'));
    expect(src, contains('platformAdminItem: platformAdminItem,'));
  });
}
