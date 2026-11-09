// PH7a engine: what the product lists need from the phone list pieces and
// the product provider. A row may bring its own leading (a product's photo);
// the menu's button may carry a dot (the old bell's); the Summary sheet may
// have no period; and ProductProvider says when the products first arrived
// and why its live listener stopped, and can start it again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/product_provider.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_summary_sheet.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_seed.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    home: home,
  ));
}

Widget _list({required bool menuBadge}) => PhoneListScaffold<String>(
      title: 'Products',
      menu: [PhoneListMenuItem(label: 'Stock Alerts', icon: Icons.notifications_none, onSelected: () {})],
      menuBadge: menuBadge,
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
      items: const ['a'],
      idOf: (s) => s,
      dateOf: (_) => DateTime(2026),
      amountOf: (_) => 0,
      grouped: false,
      tileBuilder: (context, s, {required grouped}) => Text(s),
      loading: false,
      error: null,
      onRetry: () {},
      emptyIcon: Icons.inbox,
      emptyText: 'None',
      hasMore: false,
      loadingMore: false,
      onLoadMore: () {},
      onRefresh: () async {},
    );

void main() {
  testWidgets('a row may bring its own 40 px leading in place of the initials', (tester) async {
    await _pump(
        tester,
        const Scaffold(
          body: RecordTile(
            title: 'Albendazole 10%',
            amount: '40 pcs',
            details: ['Tsh 15,000'],
            initialsOf: 'Albendazole 10%',
            colorSeed: 'x',
            semanticsLabel: 'x',
            leading: SizedBox(key: ValueKey('photo'), width: 40, height: 40),
          ),
        ));
    expect(find.byKey(const ValueKey('photo')), findsOneWidget);
    expect(find.text('A1'), findsNothing);
  });

  testWidgets('the menu\'s button carries a dot only when asked', (tester) async {
    await _pump(tester, _list(menuBadge: true));
    expect(find.byKey(const ValueKey('phoneList-menuDot')), findsOneWidget);
    expect(find.byTooltip('Show menu'), findsOneWidget);
    await _pump(tester, _list(menuBadge: false));
    expect(find.byKey(const ValueKey('phoneList-menuDot')), findsNothing);
  });

  testWidgets('the Summary sheet without a period lists its rows only', (tester) async {
    await _pump(tester, Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showPhoneSummarySheet(context, rows: const [('Total Products', '7')]),
          child: const Text('OPEN'),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  test('ProductProvider: loaded after the first answer; a failed listener says why; Retry starts it again', () async {
    final db = CountingFirestore()..failListens = true;
    await ph7SeedProducts(db.inner);
    final products = ProductProvider(firestore: db, currentUserInfo: testUserInfo);
    expect(products.loaded, isFalse);
    products.listenToProducts(testFacilityId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(products.listenError, isNotNull);
    expect(products.loaded, isFalse);
    db.failListens = false;
    products.retryListening();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(products.listenError, isNull);
    expect(products.loaded, isTrue);
    expect(products.products, hasLength(ph7Products.length));
    products.clear();
    expect(products.loaded, isFalse);
  });
}
