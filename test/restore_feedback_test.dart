// E2 (delete_restore.md test 8 and owner conditions 1, 2, 4, 5, 8): deleting
// a sale or a service offers Undo, and Undo restores it with its effects;
// the restore and refusal messages use the owner's wording.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/models/restore_outcome.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';
import 'package:vetbiz_pro/ui/feedback/restore_feedback.dart';

import 'helpers/fake_firestore.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: AppFeedback.messengerKey,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: const Scaffold(body: SizedBox.expand()),
    ));
  }

  Future<void> settleIn(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('deleting a sale offers Undo, and Undo puts back the sale, its stock, debt and balance', (tester) async {
    await pumpApp(tester);
    final fs = newFakeFirestore();
    final provider = newSaleProvider(fs);
    await tester.runAsync(() async {
      await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
      await seedClient(fs, id: 'c1');
      await provider.addSale(
          testSale(id: 's1', items: [saleItem('p1', 2)], paid: 1000, clientId: 'c1', clientName: 'Juma'),
          testFacilityId);
      await provider.deleteSale('s1', testFacilityId);
      await settle();
    });
    var refreshed = false;

    RestoreFeedback.offerUndo(TrashedRecord.sale,
        restore: () => provider.restoreSale('s1', testFacilityId), onRestored: () => refreshed = true);
    await settleIn(tester);
    expect(find.text('Sale moved to Trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settleIn(tester);

    expect(find.text('Sale restored'), findsOneWidget);
    expect(find.text('Stock, debt and client balance are updated.'), findsOneWidget);
    expect(refreshed, isTrue);
    await tester.runAsync(() async {
      expect(await countDocs(fs, Collections.sales), 1);
      expect(await sellableQty(fs, 'p1'), 3);
      final client = await facilityCollection(fs, Collections.clients).doc('c1').get();
      expect(client.data()?['balance'], 3000);
      expect((await facilityCollection(fs, Collections.debts).doc('sale_s1').get()).exists, isTrue);
    });
  });

  testWidgets('deleting a service offers Undo, and Undo puts back its stock, debt and expense', (tester) async {
    await pumpApp(tester);
    final fs = newFakeFirestore();
    final provider = newServiceProvider(fs);
    await tester.runAsync(() async {
      await seedProduct(fs, id: 'p1', batchQty: {'b1': 5});
      await seedClient(fs, id: 'c1');
      await provider.addService(testService(
        id: 'v1',
        items: [serviceItem('p1', productId: 'p1'), serviceItem('Gloves', price: 500)],
        paid: 4000,
        clientId: 'c1',
        clientName: 'Juma',
      ));
      await provider.deleteService('v1');
      await settle();
    });

    RestoreFeedback.offerUndo(TrashedRecord.service, restore: () => provider.restoreService('v1', testFacilityId));
    await settleIn(tester);
    expect(find.text('Service moved to Trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settleIn(tester);

    expect(find.text('Service restored'), findsOneWidget);
    expect(find.text('Stock, debt, expense and client balance are updated.'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await sellableQty(fs, 'p1'), 4);
      expect((await facilityCollection(fs, Collections.transactions).doc('service_v1').get()).exists, isTrue);
      expect((await facilityCollection(fs, Collections.debts).doc('service_v1').get()).exists, isTrue);
    });
  });

  testWidgets('condition 5: a copy deleted before the update adds the stock check line', (tester) async {
    await pumpApp(tester);
    RestoreFeedback.restored(TrashedRecord.sale, RestoreResult.restoredFromOldCopy);
    await settleIn(tester);
    expect(find.text('Sale restored'), findsOneWidget);
    expect(
      find.text('Stock, debt and client balance are updated.\n'
          'This item was deleted before the update. Check its stock afterwards.'),
      findsOneWidget,
    );
  });

  testWidgets('a refused restore says "Can\'t restore this sale" with the reason', (tester) async {
    await pumpApp(tester);
    RestoreFeedback.failed(
      TrashedRecord.sale,
      const RestoreRefusedException(RestoreRefusal.notEnoughStock, productName: 'Dewormer', needed: 3, available: 1),
      StackTrace.empty,
    );
    await settleIn(tester);
    expect(find.text("Can't restore this sale"), findsOneWidget);
    expect(find.text('Not enough Dewormer in stock: 3 needed, 1 left. Add stock first.'), findsOneWidget);
  });

  test('the refusal reasons, in the owner\'s words (conditions 1, 2, 4)', () {
    expect(
      FriendlyError.messageFor(
          const RestoreRefusedException(RestoreRefusal.notEnoughStock, productName: 'Dewormer', needed: 2, available: 0)),
      'Not enough Dewormer in stock: 2 needed, 0 left. Add stock first.',
    );
    expect(FriendlyError.messageFor(const RestoreRefusedException(RestoreRefusal.clientGone)),
        'The client no longer exists.');
    expect(FriendlyError.messageFor(const RestoreRefusedException(RestoreRefusal.productGone, productName: 'Dewormer')),
        'Dewormer no longer exists.');
  });
}
