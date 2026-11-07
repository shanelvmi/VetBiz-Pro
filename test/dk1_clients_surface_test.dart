// DK1: Clients in Dark (and Light for the reverse mistake), on a phone and
// wide: the list, a client's details (the page on phones, the side panel on
// wide), the Summary and Filter sheets and the delete confirmation hold no
// bright filled box with text or icons on it (the owner saw a white box at
// the centre of a client's details on the phone).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';

import 'helpers/dark_surface_scan.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

final _clients = [
  Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer', 'Vet'], phone: '0712111111'),
  Ph5Client('c2', 'Baraka Mushi', ph5When(0, minutes: 30), types: ['Retailer'], status: 'Inactive'),
];

Future<void> _pump(WidgetTester tester, Size size, MatrixLook look) => pumpPh5(tester, (fs) => ClientsScreen(firestore: fs),
    size: size, look: look, pushed: true, seed: (fs) => ph5SeedClients(fs, _clients));

void main() {
  for (final look in [MatrixLook.dark, MatrixLook.light]) {
    final dark = look == MatrixLook.dark;
    ph5TestWidgets('${look.name} phone: list, details page, sheets and delete confirmation', (tester) async {
      await _pump(tester, const Size(390, 844), look);
      expectNoBadSurfaces(tester, dark: dark, where: 'Clients list');
      await ph5OpenSummary(tester);
      expectNoBadSurfaces(tester, dark: dark, where: 'Clients Summary sheet');
      await tester.tapAt(const Offset(10, 10));
      await ph5Settle(tester);
      await ph5OpenSheet(tester, 'Filter');
      expectNoBadSurfaces(tester, dark: dark, where: 'Clients Filter sheet');
      await tester.tapAt(const Offset(10, 10));
      await ph5Settle(tester);
      await tester.tap(ph5Key('phoneList-row-c1'));
      await ph5Settle(tester);
      expect(ph5Key('phoneList-details'), findsOneWidget);
      expectNoBadSurfaces(tester, dark: dark, where: 'Client details page');
      await tester.tap(find.byTooltip('Delete'));
      await ph5Settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expectNoBadSurfaces(tester, dark: dark, where: 'Delete client confirmation');
    }, skip: _skip);

    ph5TestWidgets('${look.name} wide: the side panel', (tester) async {
      await _pump(tester, const Size(1200, 800), look);
      await tester.tap(find.text('Amina Juma').last);
      await ph5Settle(tester);
      expect(find.text('Client Details'), findsOneWidget);
      expectNoBadSurfaces(tester, dark: dark, where: 'Client details panel');
    }, skip: _skip);
  }
}
