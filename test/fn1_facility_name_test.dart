import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/models/sale.dart';
import 'package:vetbiz_pro/models/service.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_screen.dart';
import 'package:vetbiz_pro/screens/sales/receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/services/service_receipt_preview_screen.dart';
import 'package:vetbiz_pro/services/daily_report_pdf_service.dart';
import 'package:vetbiz_pro/services/receipt_pdf_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/facility_display.dart';

// FN1 (docs/design/facility_name_display.md, owner's Option A): the facility
// name is shown exactly as typed on every receipt, PDF, report, header and
// dropdown, never joined with the type.
const _skip = false;

const _name = 'Ukuli Animal Care';

// The same facility with two types: the words each type would have added.
final _cases = <String, ({Map<String, String?> facility, List<String> typeWords})>{
  'Agrovet': (facility: {'id': 'f1', 'name': _name, 'type': 'Agrovet'}, typeWords: ['Agrovet']),
  'Other with its own words': (
    facility: {'id': 'f1', 'name': _name, 'type': 'Other', 'typeDetail': 'Pet shop'},
    typeWords: ['Pet shop', 'Other'],
  ),
};

final _sale = Sale(
  id: 's1',
  timestamp: DateTime(2026, 10, 26, 9),
  updatedAt: DateTime(2026, 10, 26, 9),
  items: const [],
  totalAmount: 12500,
  totalPaid: 12500,
  facilityId: 'f1',
  soldById: 'u1',
  soldByName: 'Asha',
  receiptNumber: 1,
);

final _service = Service(
  id: 'v1',
  category: 'Consultation',
  name: 'Farm visit',
  description: '',
  totalAmount: 20000,
  totalPaid: 20000,
  serviceDate: DateTime(2026, 10, 26, 9),
  providedByName: 'Asha',
  receiptNumber: 2,
);

/// Every text drawn in a PDF, in order, joined by spaces: the deflated
/// content streams' literal strings (the standard fonts write `[(word)]TJ`).
String _pdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final words = <String>[];
  for (final m in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', m.end);
    if (end < 0) continue;
    final String content;
    try {
      content = latin1.decode(ZLibDecoder().convert(bytes.sublist(m.end, end)));
    } on FormatException {
      continue;
    }
    for (final t in RegExp(r'\(((?:\\.|[^\\)])*)\)').allMatches(content)) {
      words.add(t.group(1)!);
    }
  }
  return words.join(' ');
}

void _expectNameOnly(String text, List<String> typeWords, String where) {
  expect(text, contains(_name), reason: where);
  for (final word in typeWords) {
    expect(text, isNot(contains(word)), reason: '$where must not show the type ("$word")');
  }
}

Future<FacilityProvider> _provider(Map<String, String?> f) async {
  SharedPreferences.setMockInitialValues({});
  final provider = FacilityProvider(firestore: FakeFirebaseFirestore());
  // Its constructor loads the device's saved facility; let that finish
  // first, or it overwrites the one set below.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await provider.setFacility(id: f['id']!, name: f['name']!, type: f['type']!, typeDetail: f['typeDetail']);
  return provider;
}

Future<void> _pumpReceipt(WidgetTester tester, FacilityProvider provider, Widget screen) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<FacilityProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  ));
  await tester.pump();
}

/// Every Text on screen, one per line.
String _screenText(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? '',
    ].join('\n');

void main() {
  test('FacilityDisplay.name is the name as typed, trimmed, and never adds a type', () {
    expect(FacilityDisplay.name(_name), _name);
    expect(FacilityDisplay.name('  $_name  '), _name);
    expect(FacilityDisplay.name('Ukuli Vetagro Centre'), 'Ukuli Vetagro Centre');
    expect(FacilityDisplay.name(null), '');
    expect(FacilityDisplay.name('   ', fallback: 'Facility'), 'Facility');
    expect(FacilityDisplay.name(null, fallback: 'Facility'), 'Facility');
  }, skip: _skip);

  for (final entry in _cases.entries) {
    final f = entry.value.facility;
    final typeWords = entry.value.typeWords;

    group('type ${entry.key}: exactly "$_name"', () {
      test('the dashboard header', () {
        expect(DashboardScreen.headerFacilityName(f), _name);
      }, skip: _skip);

      test('the Team Members dropdown entry', () {
        expect(ManageAssistantsScreen.facilityLabel(f), _name);
      }, skip: _skip);

      test('the sale A4 PDF', () async {
        _expectNameOnly(_pdfText(await ReceiptPdfService.saleBytesFor(_sale, f)), typeWords, 'sale A4');
      }, skip: _skip);

      test('the service A4 PDF', () async {
        _expectNameOnly(_pdfText(await ReceiptPdfService.serviceBytesFor(_service, f)), typeWords, 'service A4');
      }, skip: _skip);

      test('the daily report PDF header and Facility row', () async {
        final name = DailyReportPdfService.facilityNameOf(f);
        expect(name, _name);
        final report = DailyReport(
          id: '2026-10-26',
          facilityId: 'f1',
          reportDate: DateTime(2026, 10, 26),
          generatedAt: DateTime(2026, 10, 26, 18),
          generatedByName: 'Asha',
        );
        final doc = await DailyReportPdfService.build(report, facilityName: name);
        _expectNameOnly(_pdfText(await doc.save()), typeWords, 'daily report');
      }, skip: _skip);

      testWidgets('the sale receipt (thermal preview and details panel)', (tester) async {
        final provider = await tester.runAsync(() => _provider(f));
        await _pumpReceipt(tester, provider!, ReceiptPreviewScreen(sale: _sale));
        _expectNameOnly(_screenText(tester), typeWords, 'sale receipt');
        expect(find.text(_name), findsWidgets);
      }, skip: _skip);

      testWidgets('the service receipt (thermal preview and details panel)', (tester) async {
        final provider = await tester.runAsync(() => _provider(f));
        await _pumpReceipt(tester, provider!, ServiceReceiptPreviewScreen(service: _service));
        _expectNameOnly(_screenText(tester), typeWords, 'service receipt');
        expect(find.text(_name), findsWidgets);
      }, skip: _skip);
    });
  }

  test('lib/ glues no facility name to a type, and the retired keys are gone', () {
    final glue = <RegExp>[
      RegExp(r"'\$\{?\w*[nN]ame\}? \$\{?\w*[tT]ype\w*\}?'"),
      RegExp(r"[nN]ame\w* \+ ' ' \+ \w*[tT]ype"),
      RegExp(r"\$\{[^}]*name[^}]*\}[^'\n]*\$\{[^}]*facilityTypeDisplay"),
      RegExp(r'_nameWithType|dashboard_facilityNameType|facilities_nameWithType|noFacility_askingToJoinWithType'),
    ];
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') && !file.path.endsWith('.arb')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (glue.any((p) => p.hasMatch(lines[i]))) found.add('${file.path.replaceAll('\\', '/')}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(found, isEmpty);
  }, skip: _skip);
}
