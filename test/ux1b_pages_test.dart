// UX1b: the pages pushed above a place on PC and tablet, inside AppShell
// (openInContent): the receipt previews, the Sales and Services archives,
// Past Reports and the info pages show the shared PageHeader (no AppBar, no
// teal bar), the title on the left, a back arrow; Back returns where you
// were. Content 696, 774, 950 and 1128, text 1.3, Light, Dark, Kiswahili.
// Print: A4 still goes straight to the system dialog (Printing.layoutPdf,
// no in-app step after Print); the thermal path is unchanged (#25, UX1c).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/info/faq_screen.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/sales/receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_archive_screen.dart';
import 'package:vetbiz_pro/screens/services/service_receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/services/services_archive_screen.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'pol4_fingerprints_test.dart' show pol4Sale, pol4Service, seedPol4Archives;

final _shell = GlobalKey<AppShellState>();

Widget _harness(double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in const [AppDestination.home, AppDestination.sales])
              SizedBox(key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'), height: 48),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (_) => null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

final _pages = <String, (Widget Function(FirebaseFirestore fs), Type)>{
  'sale receipt': ((_) => ReceiptPreviewScreen(sale: pol4Sale), ReceiptPreviewScreen),
  'service receipt': ((_) => ServiceReceiptPreviewScreen(service: pol4Service), ServiceReceiptPreviewScreen),
  'sales archive': ((fs) => SalesArchiveScreen(firestore: fs), SalesArchiveScreen),
  'services archive': ((fs) => ServicesArchiveScreen(firestore: fs), ServicesArchiveScreen),
  'past reports': ((fs) => PastReportsScreen(firestore: fs), PastReportsScreen),
  'FAQs': ((_) => const FaqScreen(), FaqScreen),
};

Future<void> _open(WidgetTester tester, Widget Function(FirebaseFirestore fs) build, Size size, double sidebar,
    {MatrixLook look = MatrixLook.light, double textScale = 1}) async {
  late FirebaseFirestore store;
  await pumpPh5(tester, (fs) {
    store = fs;
    return _harness(sidebar);
  }, size: size, look: look, textScale: textScale, seed: seedPol4Archives);
  _shell.currentState!.openInContent(build(store), highlight: AppDestination.sales);
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = (size.width - sidebar).toInt();
    for (final look in const [MatrixLook.light, MatrixLook.dark, MatrixLook.kiswahili]) {
      for (final MapEntry(key: name, value: (build, type)) in _pages.entries) {
        ph5TestWidgets('$name, content $content ${look.name} text 1.3: PageHeader, title left, back arrow', (tester) async {
          await _open(tester, build, size, sidebar, look: look, textScale: 1.3);
          final screen = find.byType(type);
          expect(screen, findsOneWidget);
          expect(tester.getTopLeft(screen).dx, sidebar, reason: 'in the content');
          final header = find.descendant(of: screen, matching: find.byType(PageHeader));
          expect(header, findsOneWidget);
          expect(find.descendant(of: screen, matching: find.byType(AppBar)), findsNothing, reason: 'no teal bar');
          final back = find.descendant(of: header, matching: find.byType(BackButton));
          expect(back, findsOneWidget, reason: 'pushed above a place');
          final title = find.descendant(of: header, matching: find.byType(Text)).first;
          expect(tester.getTopLeft(title).dx, lessThan(tester.getRect(back).right + 16), reason: 'left, not centred');
          expect(find.byKey(const ValueKey('sb-sales-selected')), findsOneWidget, reason: 'the place stays highlighted');
          // The archives' known overflow from the body (POL4) aside; the
          // receipts' (#26) is fixed in UX2 and must not come back.
          for (var e = tester.takeException(); e != null; e = tester.takeException()) {
            final known = name.contains('archive');
            expect(known && e.toString().contains('overflowed'), isTrue, reason: '$name: $e');
          }
        });
      }
    }
  }

  for (final MapEntry(key: name, value: (build, type)) in _pages.entries) {
    ph5TestWidgets('$name: Back returns where you were', (tester) async {
      await _open(tester, build, const Size(1200, 800), 250);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(type), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });
  }

  for (final MapEntry(key: name, value: (build, type)) in _pages.entries) {
    ph5TestWidgets('$name on a phone: its own bar, no PageHeader', (tester) async {
      await pumpPh5(tester, build, size: const Size(390, 844), pushed: true, seed: seedPol4Archives);
      expect(find.descendant(of: find.byType(type), matching: find.byType(PageHeader)), findsNothing);
    });
  }

  group('Print (owner decision (c): no printing change in UX1b)', () {
    String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');
    for (final path in ['lib/screens/sales/receipt_preview_screen.dart', 'lib/screens/services/service_receipt_preview_screen.dart']) {
      test('$path: A4 Print opens the system dialog directly; thermal as before', () {
        final src = read(path);
        final print = src.substring(src.indexOf('  Future<void> _print() async {'), src.indexOf('  Future<void> _shareOrPrintA4Pdf() async {'));
        expect(print, contains("if (_selectedFormat == 'a4') {\n      await _shareOrPrintA4Pdf();\n      return;\n    }"));
        expect(print, contains('printerService.isConnected'));
        expect(print, isNot(contains('PdfPreview')), reason: 'no in-app preview after Print');
      });
    }
    test('the A4 receipt goes to Printing.layoutPdf (the system print dialog)', () {
      final src = read('lib/services/receipt_pdf_service.dart');
      expect('Printing.layoutPdf('.allMatches(src).length, greaterThanOrEqualTo(2));
    });
  });
}
