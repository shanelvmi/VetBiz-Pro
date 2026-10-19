import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/services/daily_report_service.dart';

// E4c: the report every member reads carries no activity log (a1), and a
// draft may only be submitted (C3). The emulator tests
// (firestore_rules_tests) use copies of the app's write shapes; these tests
// keep those copies and firestore.rules equal to the app.

/// The keys of the JS object literal that follows [start] in [src].
Set<String> _jsKeys(String src, String start, String end) {
  final from = src.indexOf(start);
  expect(from, isNot(-1), reason: 'could not find $start');
  final body = src.substring(from + start.length, src.indexOf(end, from));
  return RegExp(r'(?:^|[\s{,])(\w+):').allMatches(body).map((m) => m.group(1)!).toSet();
}

DailyReport _report() => DailyReport(
      id: '2026-10-19',
      facilityId: 'F1',
      reportDate: DateTime(2026, 10, 19),
      generatedAt: DateTime(2026, 10, 19, 18),
      generatedByName: 'Asha',
    );

void main() {
  final rulesTests = File('firestore_rules_tests/firestore.rules.test.js').readAsStringSync();
  final rules = File('firestore.rules').readAsStringSync();

  test('the report the app writes has no activity log, and is the shape the emulator tests create', () {
    final keys = _report().toMap().keys.toSet();
    expect(keys, isNot(contains('activityLogEntries')));
    // Nested keys (method, expected...) appear in the JS too; top-level only.
    final jsTop = _jsKeys(rulesTests, 'const reportMap = (extra = {}) => ({', '...extra');
    expect(keys.difference(jsTop), isEmpty, reason: 'toMap keys missing from the emulator shape');
    expect(jsTop.intersection(keys), keys);
  });

  test('an old report that still holds activityLogEntries is read without them', () {
    final old = {..._report().toMap(), 'activityLogEntries': [ActivityLogEntry(time: DateTime(2026), actionType: 'Sale', description: 'x', userName: 'y').toMap()]};
    expect(DailyReport.fromMap('old', old).toMap().containsKey('activityLogEntries'), isFalse);
  });

  test('submitUpdate writes exactly the keys firestore.rules allows on a draft, and the emulator tests use', () {
    final update = DailyReportService.submitUpdate(
      submittedAt: DateTime(2026, 10, 19, 19),
      productMovement: const [],
      paymentReconciliation: const [],
      declarationConfirmed: true,
    );
    expect(update['status'], 'submitted');
    expect(update['submittedAt'], isA<Timestamp>());
    final ruleList = RegExp(r"affectedKeys\(\)\s*\.hasOnly\(\['status', 'submittedAt'[^\]]*\]\)").firstMatch(rules);
    expect(ruleList, isNotNull, reason: 'the dailyReports update rule is missing');
    final ruleKeys = RegExp(r"'(\w+)'").allMatches(ruleList!.group(0)!).map((m) => m.group(1)!).toSet();
    expect(update.keys.toSet(), ruleKeys);
    expect(_jsKeys(rulesTests, 'const submitUpdate = () => ({', '});'), containsAll(ruleKeys));
  });

  test('the subdocument path is the one the rules protect', () {
    expect(DailyReportService.activityLogPath, 'private');
    expect(DailyReportService.activityLogDocId, 'activityLog');
    expect(rules, contains('match /private/{docId}'));
    expect(rules, contains("docId == 'activityLog'"));
  });
}
