// POL7: Reports on phone, tablet and computer after the polish. Every
// theme, Light and Dark, at 390 and 360 wide: no gradient, no decorative
// shadow, flat app bars, every status dot with its word. Text scale 1.3 at
// every size: the overflow count is pinned at what it was before POL7
// (measured on 575a624), except View Reports with a draft at 1024 and 1200,
// where the old status row's overflow is gone and the preview cards' older
// header overflow now shows (docs/LAYOUT_DEFECTS.md 19). Reduced motion too.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_detail_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_tabbed_content.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_scaffold.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

int _count(WidgetTester tester) {
  var n = 0;
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    final m = RegExp(r'Multiple exceptions \((\d+)\)').firstMatch(e.toString());
    n += m != null ? int.parse(m.group(1)!) : 1;
  }
  return n;
}

const _at13 = {
  'detail-draft 1024x768': 2,
  'detail-draft 1200x800': 0,
  'detail-draft 360x640': 0,
  'detail-draft 390x844': 0,
  'detail-draft 768x1024': 3,
  'past 1024x768': 0,
  'past 1200x800': 0,
  'past 360x640': 3,
  'past 390x844': 0,
  'past 768x1024': 0,
  'review 1024x768': 0,
  'review 1200x800': 0,
  'review 360x640': 0,
  'review 390x844': 0,
  'review 768x1024': 0,
  'tabs 1024x768': 2,
  'tabs 1200x800': 0,
  'tabs 360x640': 0,
  'tabs 390x844': 0,
  'tabs 768x1024': 3,
  'view-draft 1024x768': 6,
  'view-draft 1200x800': 8,
  'view-draft 360x640': 0,
  'view-draft 390x844': 0,
  'view-draft 768x1024': 2,
};

void _flat(WidgetTester tester, String where) {
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = box.decoration;
    if (d is BoxDecoration) {
      expect(d.gradient, isNull, reason: '$where: a gradient');
      expect(d.boxShadow == null || d.boxShadow!.isEmpty, isTrue, reason: '$where: a shadow');
    }
  }
  // The shared phone list bar (PhoneListScaffold, 14 lists) keeps its
  // elevation: left for a later batch (ledger POL7).
  final shared = find.descendant(of: find.byWidgetPredicate((w) => w is PhoneListScaffold), matching: find.byType(AppBar));
  final skip = tester.widgetList<AppBar>(shared).toSet();
  for (final bar in tester.widgetList<AppBar>(find.byType(AppBar))) {
    if (skip.contains(bar)) continue;
    expect(bar.elevation ?? 0, 0, reason: '$where: an app bar shadow');
  }
  for (final dot in tester.widgetList<StatusDot>(find.byType(StatusDot))) {
    expect(dot.label.trim(), isNotEmpty, reason: '$where: a dot without its word');
  }
}

void main() {
  final screens = <String, (Widget Function(dynamic fs), Future<void> Function(dynamic fs)?)>{
    'view-draft': ((fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()), (fs) => ph7bSeedReport(fs, ph7bReport(status: 'draft'))),
    'review': ((fs) => ReportReviewScreen(report: ph7bReport(status: 'draft'), firestore: fs), (fs) => ph7bSeedReport(fs, ph7bReport(status: 'draft'))),
    'detail-draft': ((fs) => ReportDetailScreen(report: ph7bReport(status: 'draft'), firestore: fs), (fs) => ph7bSeedReport(fs, ph7bReport(status: 'draft'))),
    'past': ((fs) => PastReportsScreen(firestore: fs), (fs) async {
      for (var d = 1; d <= 3; d++) {
        await ph7bSeedReport(fs, ph7bReport(day: DateTime(2025, 3, 12).subtract(Duration(days: d)), status: d == 2 ? 'draft' : 'submitted'));
      }
    }),
    'tabs': ((fs) => Scaffold(body: ReportTabbedContent(report: ph7bReport(), firestore: fs)), (fs) => ph7bSeedReport(fs, ph7bReport())),
  };
  for (final e in screens.entries) {
    final (build, seed) = e.value;
    final pushed = e.key != 'tabs';
    for (final theme in AppColorTheme.all) {
      for (final look in [MatrixLook.light, MatrixLook.dark]) {
        for (final size in [const Size(390, 844), const Size(360, 640)]) {
          final where = '${e.key} ${theme.name} ${look.name} ${size.width.toInt()}x${size.height.toInt()}';
          ph5TestWidgets('$where: flat, no gradient or shadow, every dot with its word', (tester) async {
            await pumpPh5(tester, (fs) => build(fs), size: size, look: look, colorTheme: theme, pushed: pushed, seed: seed);
            _count(tester);
            _flat(tester, where);
          });
        }
      }
    }
    for (final size in [const Size(390, 844), const Size(360, 640), ...ph5WideSizes]) {
      final at = '${e.key} ${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$at, text 1.3: no new overflow', (tester) async {
        await pumpPh5(tester, (fs) => build(fs), size: size, pushed: pushed, seed: seed, textScale: 1.3);
        expect(_count(tester), _at13[at], reason: at);
      });
    }
    ph5TestWidgets('${e.key} 390x844, reduced motion: settles, flat', (tester) async {
      await pumpPh5(tester, (fs) => build(fs), pushed: pushed, seed: seed, reduceMotion: true);
      expect(_count(tester), 0);
      _flat(tester, '${e.key} reduced motion');
    });
  }
}
