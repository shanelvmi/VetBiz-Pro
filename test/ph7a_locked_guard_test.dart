// PH7a finding: Add Product had no locked-facility guard at any width except
// the phone's "+" sheet (Products' and Stock Store's Add Product buttons and
// the dashboard's Add Product card opened the form). A new product now goes
// through navigateOrShowLockedDialog inside showAddEditProductScreen, so
// every entry point at every width gets the friendly locked message and no
// form. Editing an existing product is not a new record and stays as it was.
// The phone lists' floating Add Product is checked in their own tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/products/add_edit_product_screen.dart';
import 'package:vetbiz_pro/screens/products/products_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';

import 'helpers/ph7a_seed.dart';
import 'helpers/phone_list_harness.dart';

const _skip = true;

const _phone = Size(390, 844);
const _wide = Size(1200, 800);

/// A page with one button that opens Add Product (or Edit), as the
/// dashboard's card and the "+" sheet do.
class _Opener extends StatelessWidget {
  final bool edit;
  const _Opener({this.edit = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showAddEditProductScreen(context, product: edit ? ph7LongProduct : null),
            child: const Text('OPEN'),
          ),
        ),
      );
}

void _expectLocked(WidgetTester tester) {
  expect(find.text('Subscription Expired'), findsOneWidget);
  expect(find.byType(AddEditProductScreen), findsNothing);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await ph5Settle(tester);
}

void main() {
  final cases = <String, (Widget Function(dynamic fs), Size, Finder)>{
    'Products, the computer\'s Add Product': ((fs) => ProductsScreen(firestore: fs), _wide, find.text('Add Product')),
    'Stock Store, the computer\'s Add Product': ((fs) => const StockStoreScreen(), _wide, find.text('Add Product')),
    'showAddEditProductScreen on a phone (the dashboard card, the "+" sheet)': ((fs) => const _Opener(), _phone, find.text('OPEN')),
    'showAddEditProductScreen on a computer': ((fs) => const _Opener(), _wide, find.text('OPEN')),
  };
  for (final e in cases.entries) {
    final (build, size, opener) = e.value;
    for (final admin in [true, false]) {
      // Only an admin sees the lists' Add Product (creating a product is
      // admin-only, E4d-2).
      if (!admin && !e.key.startsWith('show')) continue;
      ph5TestWidgets('${e.key}${admin ? '' : ' (assistant)'}: locked, the message and no form', (tester) async {
        await pumpPh5(tester, build, size: size, admin: admin, locked: true, pushed: true, seed: ph7SeedProducts);
        await _tapAndSettle(tester, opener);
        _expectLocked(tester);
      }, skip: _skip);
    }
  }

  ph5TestWidgets('editing a product while locked still opens the form (not a new record)', (tester) async {
    await pumpPh5(tester, (fs) => const _Opener(edit: true), size: _wide, locked: true, pushed: true, seed: ph7SeedProducts);
    await _tapAndSettle(tester, find.text('OPEN'));
    expect(find.text('Subscription Expired'), findsNothing);
    expect(find.byType(AddEditProductScreen), findsOneWidget);
  });

  ph5TestWidgets('not locked: Add Product opens the form', (tester) async {
    await pumpPh5(tester, (fs) => const _Opener(), size: _wide, pushed: true, seed: ph7SeedProducts);
    await _tapAndSettle(tester, find.text('OPEN'));
    expect(find.byType(AddEditProductScreen), findsOneWidget);
  });
}
