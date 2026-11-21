// POL4 (group 3, Sales and Services): the seed and the checks shared by
// pol4_sales_services_test.dart and pol4_archives_receipts_test.dart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';
import 'package:vetbiz_pro/data/payment_status.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';

import 'phone_list_harness.dart';

/// One of each state: paid, part paid, unpaid.
final pol4Sales = [
  Ph5Sale('s1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 45000, paid: 20000, receipt: 1),
  Ph5Sale('s2', ph5When(0, minutes: 30), amount: 12500, paid: 0, receipt: 2),
  Ph5Sale('s3', ph5When(1), client: 'Baraka Mushi', amount: 8000, paid: 8000, seller: 'Juma', receipt: 3),
];

final pol4Services = [
  Ph5Service('v1', ph5When(0, minutes: 5), client: 'Amina Juma', amount: 45000, paid: 20000, category: 'Vaccination', receipt: 1),
  Ph5Service('v2', ph5When(0, minutes: 30), amount: 15000, paid: 0, receipt: 2),
  Ph5Service('v3', ph5When(1), client: 'Baraka Mushi', amount: 9000, paid: 9000, category: 'Consultation', receipt: 3),
];

Future<void> pol4Seed(FirebaseFirestore fs) async {
  await ph5SeedSales(fs, pol4Sales);
  await ph5SeedServices(fs, pol4Services);
}

AppColors pol4Colors(WidgetTester tester, Type screen) => tester.element(find.byType(screen).first).colors;

/// Every StatusDot under [scope]: its word is shown, and its dot is in the
/// role of its state, which is one of the three payment states.
void expectPol4Dots(WidgetTester tester, Finder scope, AppColors c, {required String where, int atLeast = 1}) {
  final dots = find.descendant(of: scope, matching: find.byType(StatusDot));
  expect(dots.evaluate().length, greaterThanOrEqualTo(atLeast), reason: where);
  final words = {for (final s in PaymentStatus.values) s: tester.element(scope.first).l10n.paymentStatusLabel(s)};
  for (final e in dots.evaluate()) {
    final dot = e.widget as StatusDot;
    expect(dot.label, isNotEmpty, reason: '$where: the word is shown');
    expect(find.descendant(of: find.byWidget(dot), matching: find.text(dot.label)), findsOneWidget, reason: where);
    final stored = words.entries.where((w) => w.value == dot.label).map((w) => w.key).firstOrNull;
    if (stored != null) expect(dot.status, paymentAppStatus(stored), reason: '$where: ${dot.label}');
    final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byWidget(dot), matching: find.descendant(of: find.byKey(const ValueKey('statusDot-dot')), matching: find.byType(DecoratedBox))));
    expect((box.decoration as BoxDecoration).color, dot.status.roleIn(c), reason: '$where: ${dot.label}');
  }
}

/// No decorative shadow and no gradient under [scope].
void expectNoShadowOrGradient(WidgetTester tester, Finder scope, {required String where}) {
  final boxes = find.descendant(of: scope, matching: find.byWidgetPredicate((w) => w is DecoratedBox || w is Container));
  for (final e in boxes.evaluate()) {
    final w = e.widget;
    final d = w is DecoratedBox ? w.decoration : (w as Container).decoration;
    if (d is BoxDecoration) {
      expect(d.boxShadow ?? const [], isEmpty, reason: '$where: a shadow on ${w.runtimeType}');
      expect(d.gradient, isNull, reason: '$where: a gradient on ${w.runtimeType}');
    }
  }
}

/// The bar: no shadow, a hairline in the divider role.
void expectFlatBar(WidgetTester tester, Finder scope, AppColors c, {required String where}) {
  // UX1a: on PC and tablet the top-level screens use PageHeader; the same
  // rule (no shadow, the divider hairline).
  final header = find.descendant(of: scope, matching: find.byType(PageHeader));
  if (header.evaluate().isNotEmpty) {
    final box = tester.widget<Container>(find.descendant(of: header.first, matching: find.byType(Container)).first);
    final d = box.foregroundDecoration! as BoxDecoration;
    expect(d.boxShadow, isNull, reason: where);
    expect((d.border! as Border).bottom.color, c.divider, reason: where);
    return;
  }
  final bar = tester.widget<AppBar>(find.descendant(of: scope, matching: find.byType(AppBar)).first);
  expect(bar.elevation, 0, reason: where);
  expect((bar.shape! as Border).bottom.color, c.divider, reason: where);
}

/// On tablets and computers the Sales and Services lists' filter toolbar
/// (at 768, even without the details) and, with the details panel open
/// (380 px), the pagination bar overflow:
/// the same widths before POL4 (checked on f0167c7: 103, 217, 228 and 52 px
/// on Sales), a layout fix for later, listed in the ledger. Only a RenderFlex
/// overflow is let through here; any other error fails.
void knownWideOverflowOnly(WidgetTester tester, String where) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    expect('$e', contains('RenderFlex overflowed'), reason: '$where: $e');
  }
}

/// Runs [body] and returns each error's first line, one by one (several
/// errors in one frame would otherwise come back as one summary).
Future<List<String>> collectErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}
