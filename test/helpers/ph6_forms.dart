// PH6: the money forms and the two stock dialogs on the real providers over
// a fake Firestore (phone_list_harness.dart's pumpPh5), at a window size and
// look, with seeded clients, debtors and products.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/models/product_batch.dart';
import 'package:vetbiz_pro/screens/clients/add_client_screen.dart';
import 'package:vetbiz_pro/screens/debtors/add_payment_screen.dart';
import 'package:vetbiz_pro/screens/products/move_expired_to_stock_dialog.dart';
import 'package:vetbiz_pro/screens/sales/add_sale_screen.dart';
import 'package:vetbiz_pro/screens/services/add_edit_service_screen.dart';
import 'package:vetbiz_pro/screens/store/release_to_shop_flow.dart';
import 'package:vetbiz_pro/screens/transactions/add_transaction_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';

import 'fake_firestore.dart';
import 'ph5b_seed.dart';
import 'phone_list_harness.dart';
import 'screen_size_matrix.dart';

/// The test user, signed in (Add Transaction reads their name).
class Ph6Auth implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A debtor with a long Kiswahili name and an 8-digit balance.
final ph6Debtor = Ph5Client('c1', matrixLongClientName, ph5When(90), balance: matrixBigAmount, oldestDebt: ph5When(45));
final ph6Amina = Ph5Client('c2', 'Amina Juma', ph5When(90), phone: '0712111111', balance: 45000, oldestDebt: ph5When(10));

Client ph6ClientOf(Ph5Client c) =>
    Client(id: c.id, name: c.name, phone: c.phone, address: 'Arusha', balance: c.balance, types: c.types);

/// A sellable product (a long name, an 8-digit price) and its batch.
Product ph6Product({String id = 'p1', String? name, double price = matrixBigAmount, int qty = 40}) => Product(
      id: id,
      name: name ?? matrixLongProductName,
      buyPrice: 1000,
      sellPrice: price,
      stockQty: 30,
      sellableQty: qty,
      unit: 'pcs',
      type: 'Injectable',
      category: 'Dawa za Mifugo',
      facilityId: testFacilityId,
      hasEverHadStock: true,
    );

ProductBatch ph6Batch() => ProductBatch(
      id: 'b1',
      productId: 'p1',
      batchNo: 'BN-2026-001',
      expiry: DateTime.now().subtract(const Duration(days: 5)),
      buyPrice: 1000,
      stockQty: 0,
      sellableQty: 12,
    );

Future<void> ph6Seed(dynamic fs) async {
  await ph5SeedClients(fs, [ph6Debtor, ph6Amina]);
  await seedProduct(fs, id: 'p1', legacyQty: 40, buyPrice: 1000);
}

/// The seven forms and dialogs: a builder for the form itself (the
/// dialogs: a host page whose button opens them), and the type to look at.
final Map<String, (Widget Function(dynamic fs, {required bool isModal}), Type)> ph6Forms = {
  'add-sale': ((fs, {required isModal}) => AddSaleScreen(firestore: fs, isModal: isModal), AddSaleScreen),
  'record-payment': (
    (fs, {required isModal}) => AddPaymentScreen(
          firestore: fs,
          isModal: isModal,
          facilityId: testFacilityId,
          debtorClients: [ph6ClientOf(ph6Debtor), ph6ClientOf(ph6Amina)],
          debtorBalances: {ph6Debtor.id: ph6Debtor.balance, ph6Amina.id: ph6Amina.balance},
        ),
    AddPaymentScreen
  ),
  'add-client': ((fs, {required isModal}) => AddClientScreen(isModal: isModal), AddClientScreen),
  'add-transaction': (
    (fs, {required isModal}) => AddTransactionScreen(firestore: fs, authService: Ph6Auth(), isModal: isModal),
    AddTransactionScreen
  ),
  'record-visit': ((fs, {required isModal}) => AddEditServiceScreen(isModal: isModal), AddEditServiceScreen),
  'move-expired': ((fs, {required isModal}) => const Ph6DialogHost(dialog: 'move-expired'), AlertDialog),
  'release': ((fs, {required isModal}) => const Ph6DialogHost(dialog: 'release'), AlertDialog),
};

/// A page with one button that opens a stock dialog.
class Ph6DialogHost extends StatelessWidget {
  final String dialog;
  const Ph6DialogHost({super.key, required this.dialog});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('ph6-open-dialog'),
          onPressed: () => dialog == 'release'
              ? releaseProductToShop(context, ph6Product(), initialQuantity: 3)
              : promptQuantityAndMoveToStock(context, ph6Product(), ph6Batch()),
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

/// Pumps form [name] at [size] (a modal from 900 wide up, as
/// showAdaptiveForm opens it; a full page below); a dialog is opened.
Future<Ph5App> pumpPh6(
  WidgetTester tester,
  String name, {
  Size size = const Size(390, 844),
  MatrixLook look = MatrixLook.light,
  bool admin = true,
  bool locked = false,
}) async {
  final (build, _) = ph6Forms[name]!;
  final app = await pumpPh5(tester, (fs) => build(fs, isModal: size.width >= 900),
      size: size, look: look, admin: admin, locked: locked, seed: ph6Seed);
  if (find.byKey(const ValueKey('ph6-open-dialog')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('ph6-open-dialog')));
    await ph5Settle(tester);
  }
  return app;
}
