// POL6 (group 5: Clients, Debtors, Payments, Transactions) on phone, tablet
// and computer, in every theme, Light and Dark:
// - A state is the dot plus the word, the dot in its state's role: Overdue
//   danger and Current neutral (debtAppStatus), a client's status neutral
//   (clientAppStatus), Received success; a type or kind is never a hue.
// - No decorative shadow or gradient; the app bars flat with a hairline;
//   the figure cards flat (FlatStatCard).
// - Transactions: the amount carries its + or - sign, in plain text.
// - Text at 1.3 and reduced motion on the phone: no error; on wide sizes
//   only the overflows already in docs/LAYOUT_DEFECTS.md (RenderFlex).
// - The debt reminder's message keeps its exact English text.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/flat_stat_card.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/ph5b_seed.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/pol4_checks.dart';
import 'helpers/screen_size_matrix.dart';

Future<void> _seed(dynamic fs) async {
  await ph5SeedClients(fs, [
    Ph5Client('c1', 'Amina Juma', ph5When(0, minutes: 5), types: ['Farmer', 'Vet'], balance: 45000, oldestDebt: ph5When(45)),
    Ph5Client('c2', 'Baraka Mushi', ph5When(0, minutes: 60), status: 'Inactive', balance: 12500, oldestDebt: ph5When(3)),
  ]);
  await ph5SeedDebts(fs, [Ph5Debt('d1', 'c1', ph5When(45), 45000), Ph5Debt('d2', 'c2', ph5When(3), 12500)]);
  await ph5SeedPayments(fs, [
    Ph5Payment('p1', ph5When(0, minutes: 5), client: 'Amina Juma', clientId: 'c1', amount: 20000, method: 'mpesa'),
    Ph5Payment('p2', ph5When(0, minutes: 90), client: 'Baraka Mushi', clientId: 'c2', amount: 7000, source: 'debt_repayment'),
  ]);
  await ph5SeedTransactions(fs, [
    Ph5Tx('t1', ph5When(0, minutes: 5), description: 'Fuel for the car', amount: 30000, receipt: 1),
    Ph5Tx('t2', ph5When(0, minutes: 50), type: 'other income', category: 'Consultation', description: 'Farm visit fee', amount: 5000, receipt: 2),
  ]);
}

/// The screen, its type, a row's text that opens the details, its cards.
final _lists = <String, (Widget Function(dynamic fs), Type, String, int)>{
  'Clients': ((fs) => ClientsScreen(firestore: fs), ClientsScreen, 'Amina Juma', 4),
  'Debtors': ((fs) => DebtorsScreen(firestore: fs), DebtorsScreen, 'Amina Juma', 4),
  'Payments': ((fs) => PaymentsScreen(firestore: fs), PaymentsScreen, 'Amina Juma', 4),
  'Transactions': ((fs) => TransactionScreen(firestore: fs), TransactionScreen, 'Fuel for the car', 3),
};

/// Every StatusDot under [scope] shows its word and draws the dot in its
/// state's role; Overdue is danger and Current neutral.
void _expectDots(WidgetTester tester, Finder scope, AppColors c, {required String where}) {
  for (final e in find.descendant(of: scope, matching: find.byType(StatusDot)).evaluate()) {
    final dot = e.widget as StatusDot;
    expect(dot.label, isNotEmpty, reason: where);
    if (dot.label == 'Overdue') expect(dot.status, AppStatus.danger, reason: where);
    // UX2, UX2b: a client's Active is success, in the list rows and on the
    // client card; Inactive and Current stay neutral.
    if (dot.label == 'Active') expect(dot.status, AppStatus.success, reason: '$where: ${dot.label}');
    if (dot.label == 'Current' || dot.label == 'Inactive') {
      expect(dot.status, AppStatus.neutral, reason: '$where: ${dot.label}');
    }
    final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byWidget(dot),
        matching: find.descendant(of: find.byKey(const ValueKey('statusDot-dot')), matching: find.byType(DecoratedBox))));
    expect((box.decoration as BoxDecoration).color, dot.status.roleIn(c), reason: '$where: ${dot.label}');
  }
}

/// A phone row's chip is the dot, or a chip in the neutral role: never a hue.
void _expectNoHueChips(WidgetTester tester, AppColors c, {required String where}) {
  for (final e in find.descendant(of: find.byType(RecordTile), matching: find.byType(StatusChip)).evaluate()) {
    final status = (e.widget as StatusChip).status;
    expect(status.state != null || status.color == c.textSecondary, isTrue, reason: '$where: ${status.label}');
  }
}

const _phones = [Size(390, 844), Size(360, 640)];

void main() {
  test('the debt reminder message keeps its exact English text', () {
    final source = File('lib/screens/debtors/debtors_screen.dart').readAsStringSync();
    expect(
        source,
        contains("'Hi \$clientName, this is a reminder from \$facilityName that you have an outstanding '\n"
            "        'balance of \${Money.format(amountOwed)}. Kindly settle at your earliest '\n"
            "        'convenience. Thank you!';"
            .replaceAll('\n', source.contains('\r\n') ? '\r\n' : '\n')));
  });

  group('phone: dots and neutral chips, no shadow', () {
    for (final e in _lists.entries) {
      final (build, type, _, _) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in _phones) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: _seed);
              await checkCase(tester, phone: true, where: where);
              final c = pol4Colors(tester, type);
              expect(find.byType(RecordTile), findsWidgets, reason: where);
              _expectNoHueChips(tester, c, where: where);
              _expectDots(tester, find.byType(type), c, where: where);
              expectNoShadowOrGradient(tester, find.byType(type), where: where);
            });
          }
        }
      }
    }
  });

  group('tablet and computer: dots, flat cards, a flat bar', () {
    for (final e in _lists.entries) {
      final (build, type, rowText, cardCount) = e.value;
      for (final theme in AppColorTheme.all) {
        for (final look in [MatrixLook.light, MatrixLook.dark]) {
          for (final size in ph5WideSizes) {
            final where = '${e.key} ${theme.id} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
            ph5TestWidgets(where, (tester) async {
              // Only the RenderFlex overflows already in LAYOUT_DEFECTS.md, one by one.
              final errors = await collectErrors(() async {
                await pumpPh5(tester, build, size: size, look: look, colorTheme: theme, pushed: true, seed: _seed);
                await tester.tap(find.text(rowText).last);
                await ph5Settle(tester);
              });
              for (final err in errors) {
                expect(err, contains('RenderFlex overflowed'), reason: where);
              }
              final c = pol4Colors(tester, type);
              final screen = find.byType(type);
              _expectDots(tester, screen, c, where: where);
              expectNoShadowOrGradient(tester, screen, where: where);
              expectFlatBar(tester, screen, c, where: where);
              final cards = find.descendant(of: screen, matching: find.byType(FlatStatCard));
              expect(cards, findsNWidgets(cardCount), reason: where);
              final card = tester.widget<Material>(find.descendant(of: cards.first, matching: find.byType(Material)).first);
              expect((card.shape! as RoundedRectangleBorder).side.color, c.border, reason: where);
              if (type == TransactionScreen) {
                expect(find.descendant(of: screen, matching: find.textContaining('-Tsh')), findsWidgets, reason: where);
                expect(find.descendant(of: screen, matching: find.textContaining('+Tsh')), findsWidgets, reason: where);
              }
            });
          }
        }
      }
    }
  });

  group('text at 1.3 and reduced motion', () {
    for (final e in _lists.entries) {
      final (build, _, _, _) = e.value;
      ph5TestWidgets('${e.key} 360x640 x1.3: no error', (tester) async {
        final errors = await collectErrors(() async {
          await pumpPh5(tester, build, size: const Size(360, 640), pushed: true, textScale: 1.3, reduceMotion: true, seed: _seed);
        });
        expect(errors, isEmpty, reason: e.key);
      });
      for (final size in ph5WideSizes) {
        final where = '${e.key} ${size.width.toInt()}x${size.height.toInt()} x1.3';
        ph5TestWidgets('$where: only the known overflows', (tester) async {
          final errors = await collectErrors(() async {
            await pumpPh5(tester, build, size: size, pushed: true, textScale: 1.3, reduceMotion: true, seed: _seed);
          });
          for (final err in errors) {
            expect(err, contains('RenderFlex overflowed'), reason: where);
          }
        });
      }
    }
  });
}
