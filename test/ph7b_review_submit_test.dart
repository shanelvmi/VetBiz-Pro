// PH7b R8: on a phone the review form submits exactly what it submitted
// before PH7b. For fixed counts and reasons, the report in the fake
// Firestore after Submit (times masked) is compared with what the old form
// left there (test/fixtures/ph7b_submitted_report.json, recorded once from
// the code before PH7b with --dart-define=PH7B_RECORD=true). The fields are
// found by their hints, the same on the old and the new form.
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

// The phone case runs once the phone form exists.
const _skipPhone = false;

const _fixture = 'test/fixtures/ph7b_submitted_report.json';

final _isoTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');

Object? _normalize(Object? node) {
  if (node is Map) {
    return Map.fromEntries([for (final e in node.entries) MapEntry('${e.key}', _normalize(e.value))]
      ..sort((a, b) => a.key.compareTo(b.key)));
  }
  if (node is List) return [for (final v in node) _normalize(v)];
  if (node is String && _isoTime.hasMatch(node)) return '<time>';
  return node;
}

void _expectSameSubmitted(FakeFirebaseFirestore fs) {
  final saved = jsonEncode(_normalize(storedData(fs)));
  final file = File(_fixture);
  if (const bool.fromEnvironment('PH7B_RECORD')) {
    file.writeAsStringSync('$saved\n');
    return;
  }
  expect(jsonDecode(saved), jsonDecode(file.readAsStringSync()), reason: 'the submitted report changed');
}

Finder _hint(String hint) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
}

/// Today's phone layout of the form may overflow (PH7b fixes it): the data
/// is what is compared.
void _drain(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// The same counts and reasons on any layout: the long-named product counted
/// 2 short with a reason, Albendazole matching; Cash 5,000 short with a
/// reason, M-Pesa matching; the declaration ticked; Submit.
Future<void> _fillAndSubmit(WidgetTester tester) async {
  _drain(tester);
  await _type(tester, _hint('Physical count').at(0), '118');
  await _type(tester, _hint('Physical count').at(1), '34');
  await _type(tester, _hint('Reason for variance (e.g. damaged, unable to locate)'), 'Two bottles broken');
  await _type(tester, _hint('0').at(0), '420000');
  await _type(tester, _hint('0').at(1), '12345678');
  await _type(tester, _hint('Reason for Cash variance'), 'Change given short');
  final declaration = find.byType(Checkbox);
  await tester.ensureVisible(declaration);
  await tester.pump();
  await tester.tap(declaration);
  await tester.pump();
  _drain(tester);
  await tester.tap(find.text('Submit Daily Closing'));
  await ph5Settle(tester);
  _drain(tester);
}

void main() {
  for (final (name, size, skip) in [
    ('a computer (the old form)', const Size(1200, 800), false),
    ('a phone', const Size(390, 844), _skipPhone),
  ]) {
    ph5TestWidgets('on $name the form submits the recorded report', (tester) async {
      final report = ph7bReport(status: 'draft', day: DateTime(2025, 3, 12));
      final app = await pumpPh5(tester, (fs) => ReportReviewScreen(report: report, firestore: fs),
          size: size, pushed: true, seed: (fs) => ph7bSeedReport(fs, report));
      await _fillAndSubmit(tester);
      expect(find.byType(ReportReviewScreen), findsNothing, reason: 'the form closed after Submit');
      _expectSameSubmitted(app.fs as FakeFirebaseFirestore);
    }, skip: skip);
  }
}
