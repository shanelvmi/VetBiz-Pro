// LAY1 (3): the wide shell's destination registry (lib/navigation/
// app_destinations.dart). Plain data: the order (the owner's, LAY2), the
// labels the sidebar used before LAY2, the icons, the link to the phone hub's
// tiles, labels in every locale, the web paths, and that the file stays free
// of screens and navigation. The phone hub's own tests (hub1_*,
// ui5_*, ui6_*) are unchanged.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';

final _en = lookupAppLocalizations(const Locale('en'));

const _registryPath = 'lib/navigation/app_destinations.dart';

/// The sidebar before LAY2, top to bottom (75cda9b, dashboard_screen.dart
/// :2594-2701): the nine places and their English labels.
const _oldSidebar = [
  (AppDestination.stockStore, 'Stock'),
  (AppDestination.products, 'Products'),
  (AppDestination.sales, 'Sales'),
  (AppDestination.services, 'Services'),
  (AppDestination.clients, 'Clients'),
  (AppDestination.payments, 'Payments'),
  (AppDestination.debtors, 'Debtors'),
  (AppDestination.transactions, 'Transactions'),
  (AppDestination.reports, 'Reports'),
];

void main() {
  // Owner order, LAY2 (2026-11-18).
  const expected = [
    AppDestination.home,
    AppDestination.insights,
    AppDestination.sales,
    AppDestination.services,
    AppDestination.clients,
    AppDestination.debtors,
    AppDestination.payments,
    AppDestination.transactions,
    AppDestination.products,
    AppDestination.stockStore,
    AppDestination.reports,
    AppDestination.settings,
  ];

  test('1. order: the owner\'s (LAY2), Settings last, for both roles', () {
    expect(shellDestinationsFor(isAdmin: true), expected);
    expect(shellDestinationsFor(isAdmin: false), expected);
    expect(AppDestination.values.where((d) => d.section == DestinationSection.bottom), [AppDestination.settings]);
  });

  test('2. the labels the sidebar used before LAY2', () {
    for (final (d, label) in _oldSidebar) {
      expect(d.label(_en), label, reason: d.name);
    }
    expect(AppDestination.settings.label(_en), 'Settings');
    expect(AppDestination.home.label(_en), 'Home');
    expect(AppDestination.insights.label(_en), 'Insights');

    // The keys the sidebar used before LAY2 (75cda9b), kept.
    const keys = [
      'nav_stock', 'nav_products', 'nav_sales', 'nav_services', 'clients_title', //
      'payments_title', 'nav_debtors', 'transactions_title', 'nav_reports', 'settings_title',
    ];
    final registry = File(_registryPath).readAsStringSync();
    for (final k in keys) {
      expect(registry, contains('l.$k;'), reason: k);
    }
  });

  test('3. icons: distinct outlined, a filled one, as AppIcons', () {
    final outlined = AppDestination.values.map((d) => d.icon).toSet();
    expect(outlined.length, AppDestination.values.length);
    for (final d in AppDestination.values) {
      expect(d.icon, isNotNull);
      expect(d.selectedIcon, isNotNull);
      expect(d.selectedIcon, isNot(d.icon), reason: d.name);
    }
    final filled = AppDestination.values.map((d) => d.selectedIcon).toSet();
    expect(filled.length, AppDestination.values.length);
    // The outlined icon is the phone hub's.
    for (final (d, _) in _oldSidebar) {
      final tile = HubTile.values.firstWhere((t) => destinationForHubTile(t) == d);
      expect(d.icon, hubTileIcon(tile), reason: d.name);
    }
  });

  test('4. mapping: each hub place to one destination, actions to none', () {
    final places = HubTile.values.where((t) => hubTileAction(t) == null && t != HubTile.platformAdmin);
    final mapped = <AppDestination>{};
    for (final t in places) {
      final d = destinationForHubTile(t);
      expect(d, isNotNull, reason: t.name);
      expect(mapped.add(d!), isTrue, reason: '${t.name} shares ${d.name}');
      expect(d.name, t.name);
    }
    expect(mapped, AppDestination.values.toSet()..removeAll([AppDestination.home, AppDestination.settings]));
    for (final t in HubTile.values.where((t) => hubTileAction(t) != null)) {
      expect(destinationForHubTile(t), isNull, reason: t.name);
    }
    expect(destinationForHubTile(HubTile.platformAdmin), isNull);
  });

  test('5. every label is non-empty in every supported locale', () {
    expect(AppLocalizations.supportedLocales.map((l) => l.languageCode), containsAll(['en', 'sw']));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final d in AppDestination.values) {
        expect(d.label(l10n).trim(), isNotEmpty, reason: '${locale.languageCode} ${d.name}');
      }
    }
  });

  test('6. webPath: unique, starts with /, lower case', () {
    final paths = AppDestination.values.map((d) => d.webPath).toList();
    expect(paths.toSet().length, paths.length);
    for (final p in paths) {
      expect(p.startsWith('/'), isTrue, reason: p);
      expect(p, p.toLowerCase());
    }
  });

  test('7. guard: the registry has no screen, BuildContext or Navigator', () {
    final src = File(_registryPath).readAsStringSync();
    final code = src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
    expect(code, isNot(contains('BuildContext')));
    expect(code, isNot(contains('Navigator')));
    expect(code, isNot(contains('MaterialPageRoute')));
    final imports = RegExp(r"^import '([^']+)'", multiLine: true).allMatches(src).map((m) => m.group(1)!).toList();
    for (final i in imports) {
      if (!i.contains('screens/')) continue;
      // HubTile only, for the phone link.
      expect(i, '../screens/dashboard/hub_destinations.dart');
    }
    expect(src, contains("hub_destinations.dart' show HubTile;"));
  });

  test('adminOnly: none today (the sidebar gates no item)', () {
    expect(AppDestination.values.where((d) => d.adminOnly), isEmpty);
  });

  test('refreshHomeOnReturn matches the sidebar\'s _refreshDashboardData', () {
    expect(AppDestination.values.where((d) => d.refreshHomeOnReturn).toList(), [
      AppDestination.sales,
      AppDestination.services,
      AppDestination.debtors,
      AppDestination.payments,
      AppDestination.transactions,
      AppDestination.products,
      AppDestination.stockStore,
    ]);
  });
}
