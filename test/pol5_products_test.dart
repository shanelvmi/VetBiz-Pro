// POL5 (group 4, Products) on phone, tablet and computer, in every theme,
// Light and Dark:
// - A stock status is the dot plus the word, the dot in the state of its
//   STORED value (stockAppStatus); Restock shelf a neutral dot (owner note
//   3); an alert kind's dot is StockAlertsScreen.appStatus.
// - No decorative shadow or gradient; the app bars flat with a hairline;
//   the five figure cards flat (owner note 1); Stock Alerts' kinds one
//   FilterRow, no cards.
// - Batches (owner note 2): an expired batch "Expired" (danger), an empty
//   one "Empty" (neutral), with a neutral icon.
// - Text at 1.3 and reduced motion: no error at all on the phone.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/products/stock_alerts_screen.dart';
import 'package:vetbiz_pro/screens/products/view_batches_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/ui/polish/flat_stat_card.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/pol4_checks.dart';
import 'helpers/screen_size_matrix.dart';

const _stored = ['Active', 'Not Stocked', 'Unknown', 'Low Stock', 'Reorder Soon', 'Expiring Soon', 'Depleted', 'Expired'];

String _label(AppLocalizations l, String stored) => switch (stored) {
      'Active' => l.products_statusActive,
      'Not Stocked' => l.products_statusNotStocked,
      'Unknown' => l.products_statusUnknown,
      'Low Stock' => l.products_statusLowStock,
      'Reorder Soon' => l.products_statusReorderSoon,
      'Expiring Soon' => l.products_statusExpiringSoon,
      'Depleted' => l.products_statusDepleted,
      _ => l.products_statusExpired,
    };

/// Every StatusDot under [scope]: the word shown, the dot in its state's
/// role; a stock status in the state of its stored value; Restock shelf
/// neutral.
void _expectStockDots(WidgetTester tester, Finder scope, AppColors c, {required String where, int atLeast = 1}) {
  final l = tester.element(scope.first).l10n;
  final byLabel = {for (final s in _stored) _label(l, s): stockAppStatus(s), l.products_statusInStock: AppStatus.neutral};
  final dots = find.descendant(of: scope, matching: find.byType(StatusDot));
  expect(dots.evaluate().length, greaterThanOrEqualTo(atLeast), reason: where);
  for (final e in dots.evaluate()) {
    final dot = e.widget as StatusDot;
    expect(dot.label, isNotEmpty, reason: where);
    if (dot.label == l.products_restockShelf) expect(dot.status, AppStatus.neutral, reason: '$where: restock');
    final want = byLabel[dot.label];
    if (want != null) expect(dot.status, want, reason: '$where: ${dot.label}');
    final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byWidget(dot),
        matching: find.descendant(of: find.byKey(const ValueKey('statusDot-dot')), matching: find.byType(DecoratedBox))));
    expect((box.decoration as BoxDecoration).color, dot.status.roleIn(c), reason: '$where: ${dot.label}');
  }
}

Widget _alerts(FirebaseFirestore fs) => const Ph7Listening(child: StockAlertsScreen());

final _screens = <String, (Widget Function(FirebaseFirestore fs), Type)>{
  'Products': ((fs) => ProductsScreen(firestore: fs), ProductsScreen),
  'Stock Store': ((fs) => const StockStoreScreen(), StockStoreScreen),
  'Stock Alerts': (_alerts, StockAlertsScreen),
};

const _phones = [Size(390, 844), Size(360, 640)];

void main() {
  test('alert kinds: depleted and expired danger, low and expiring warning, restock shelf neutral', () {
    expect(StockAlertsScreen.appStatus(StockAlertKind.depleted), AppStatus.danger);
    expect(StockAlertsScreen.appStatus(StockAlertKind.expired), AppStatus.danger);
    expect(StockAlertsScreen.appStatus(StockAlertKind.lowStock), AppStatus.warning);
    expect(StockAlertsScreen.appStatus(StockAlertKind.expiringSoon), AppStatus.warning);
    expect(StockAlertsScreen.appStatus(StockAlertKind.restockShelf), AppStatus.neutral);
  });

  group('phone: the rows draw the dot and the word', () {
    for (final e in _screens.entries) {
      final (build, type) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in _phones) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: ph7SeedProducts);
              await checkCase(tester, phone: true, where: where);
              for (final chip in find.descendant(of: find.byType(RecordTile), matching: find.byType(StatusChip)).evaluate()) {
                expect((chip.widget as StatusChip).status.state, isNotNull, reason: where);
              }
              expect(find.byType(StatusChip), findsWidgets, reason: where);
              expectNoShadowOrGradient(tester, find.byType(type), where: where);
            });
          }
        }
      }
    }
  });

  group('tablet and computer: the dot, flat cards, a flat bar', () {
    for (final e in _screens.entries) {
      final (build, type) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in ph5WideSizes) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: ph7SeedProducts);
              expect(tester.takeException(), isNull, reason: where);
              final c = pol4Colors(tester, type);
              final screen = find.byType(type);
              // (The tablet's grid is lazy: at 1024x768 two cards are built.)
              _expectStockDots(tester, screen, c, where: where);
              expectNoShadowOrGradient(tester, screen, where: where);
              expectFlatBar(tester, screen, c, where: where);
              final cards = find.descendant(of: screen, matching: find.byType(FlatStatCard));
              if (type == StockAlertsScreen) {
                expect(cards, findsNothing, reason: where);
                expect(find.descendant(of: screen, matching: find.byType(FilterRow)), findsOneWidget, reason: where);
              } else {
                expect(cards, findsNWidgets(5), reason: where);
              }
            });
          }
        }
      }
    }
  });

  group('batches: Expired and Empty as the dot and the word', () {
    for (final (id, stored) in [('p5', 'Expired'), ('p6', 'Empty')]) {
      for (final size in [const Size(390, 844), const Size(1024, 768)]) {
        final where = '$stored ${size.width.toInt()}';
        ph5TestWidgets(where, (tester) async {
          final p = ph7Products.firstWhere((p) => p.id == id);
          final product = Product(
            id: p.id, name: p.name, buyPrice: p.buy, sellPrice: p.sell, stockQty: p.store, sellableQty: p.shelf,
            unit: 'pcs', type: p.type, category: p.category, facilityId: testFacilityId, batchNo: p.batchNo,
            expiry: p.expiryDays == null ? null : ph7Expiry(p.expiryDays!), hasEverHadStock: true);
          await pumpPh5(tester, (fs) => ViewBatchesScreen(product: product), size: size, seed: ph7SeedProducts);
          expect(tester.takeException(), isNull, reason: where);
          final l = L10n.current;
          final dot = tester.widget<StatusDot>(find.byType(StatusDot));
          expect(dot.label, stored == 'Expired' ? l.products_statusExpired : l.products_statusEmpty, reason: where);
          expect(dot.status, stored == 'Expired' ? AppStatus.danger : AppStatus.neutral, reason: where);
          final c = pol4Colors(tester, ViewBatchesScreen);
          final icon = tester.widget<Icon>(find.byIcon(Icons.inventory_2_outlined).first);
          expect(icon.color, c.textSecondary, reason: where);
        });
      }
    }
  });

  group('text at 1.3 and reduced motion: no error', () {
    for (final e in _screens.entries) {
      final (build, _) = e.value;
      for (final size in [const Size(360, 640), ...ph5WideSizes]) {
        final where = '${e.key} ${size.width.toInt()}x${size.height.toInt()} x1.3 reduced motion';
        ph5TestWidgets(where, (tester) async {
          final errors = await collectErrors(() async {
            await pumpPh5(tester, build, size: size, pushed: true, textScale: 1.3, reduceMotion: true, seed: ph7SeedProducts);
          });
          expect(errors, isEmpty, reason: where);
        });
      }
    }
  });
}
