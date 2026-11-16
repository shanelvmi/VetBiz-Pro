// POL1 Step D: Subscription history on phone, tablet and computer. One
// filter row (All, Approved, Pending, Rejected, with their counts from the
// claims already loaded) in place of the summary cards; the status as a dot
// and its word (approved success, pending warning, rejected danger); a
// rejected row shows its reason in muted danger text; rows grouped by month;
// the stored status keys are what the filter compares. No gradient or
// shadow is drawn.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_history_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

/// The three claims of October (approved s1, rejected s2 with a reason,
/// pending s3) and one approved claim in September.
Future<void> _seed(FirebaseFirestore fs) async {
  await seedSubscription(fs, pending: true);
  await facilityCollection(fs, Collections.paymentSubmissions).doc('s0').set({
    'planId': 'monthly',
    'planLabel': 'Monthly',
    'amount': 30000,
    'method': 'M-Pesa',
    'reference': 'REF0',
    'status': 'approved',
    'submittedAt': Timestamp.fromDate(DateTime(2026, 9, 2, 9, 30)),
  });
}

Future<void> _pump(WidgetTester tester, Size size, {MatrixLook look = MatrixLook.light, bool reduceMotion = false}) async {
  await pumpPh5(
    tester,
    (fs) => SubscriptionHistoryScreen(facilityId: testFacilityId, primaryColor: const Color(0xFF2F5D62), firestore: fs),
    size: size,
    look: look,
    pushed: true,
    reduceMotion: reduceMotion,
    seed: _seed,
  );
}

const _sizes = [('phone', Size(390, 1400)), ('tablet', Size(768, 1024)), ('computer', Size(1200, 800))];

AppColors _colors(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SubscriptionHistoryScreen))).extension<AppColors>()!;

Finder _seg(String value) => find.byKey(ValueKey('subscriptionHistory-filter-$value'));
String _count(WidgetTester tester, String value) =>
    tester.widget<Text>(find.byKey(ValueKey('subscriptionHistory-filter-$value-count'))).data!;

Map<String, AppStatus> _dots(WidgetTester tester) => {
      for (final d in tester.widgetList<StatusDot>(find.byType(StatusDot))) d.label: d.status,
    };

void main() {
  test('the status mapping is pinned: approved success, pending warning, rejected danger; unknown reads pending', () {
    expect(submissionAppStatus('approved'), AppStatus.success);
    expect(submissionAppStatus('pending'), AppStatus.warning);
    expect(submissionAppStatus('rejected'), AppStatus.danger);
    expect(submissionAppStatus('something-else'), AppStatus.warning);
  });

  for (final (name, size) in _sizes) {
    for (final look in MatrixLook.values) {
      ph5TestWidgets('$name ${look.name}: no summary cards; the filter row with its counts; status dots; months', (tester) async {
        await _pump(tester, size, look: look);
        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsNothing, reason: 'the cards were a grid');
        expect(_count(tester, 'all'), '4');
        expect(_count(tester, 'approved'), '2');
        expect(_count(tester, 'pending'), '1');
        expect(_count(tester, 'rejected'), '1');
        final colors = _colors(tester);
        for (final d in tester.widgetList<StatusDot>(find.byType(StatusDot))) {
          final dot = tester.widget<DecoratedBox>(
              find.descendant(of: find.byWidget(d), matching: find.byType(DecoratedBox)).first);
          expect((dot.decoration as BoxDecoration).color, d.status.roleIn(colors));
        }
        expect(_dots(tester).values.toSet(), {AppStatus.success, AppStatus.warning, AppStatus.danger});
        final months = tester.widgetList<SectionLabel>(find.byType(SectionLabel)).map((s) => s.text).toList();
        expect(months, hasLength(2), reason: 'October, then September');
        final reason = tester.widget<Text>(find.byKey(const ValueKey('subscriptionHistory-reason')));
        expect(reason.data, contains('The reference does not match any payment'));
        expect(reason.style!.color, colors.dangerStrong);
        for (final e in find
            .descendant(of: find.byType(SubscriptionHistoryScreen), matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox))
            .evaluate()) {
          final w = e.widget;
          final dec = w is Container ? w.decoration : (w as DecoratedBox).decoration;
          if (dec is BoxDecoration) {
            expect(dec.gradient, isNull);
            expect(dec.boxShadow, anyOf(isNull, isEmpty));
          }
        }
      });
    }

    ph5TestWidgets('$name: the filter compares the stored keys; tapped again, All', (tester) async {
      await _pump(tester, size);
      for (final (key, word) in [('approved', 'Approved'), ('pending', 'Pending'), ('rejected', 'Rejected')]) {
        await tester.ensureVisible(_seg(key));
        await tester.pumpAndSettle();
        await tester.tap(_seg(key));
        await tester.pumpAndSettle();
        expect(find.byType(StatusDot).evaluate().map((e) => (e.widget as StatusDot).label).toSet(), {word}, reason: key);
        await tester.ensureVisible(_seg(key));
        await tester.pumpAndSettle();
        await tester.tap(_seg(key));
        await tester.pumpAndSettle();
        expect(find.byType(StatusDot), findsNWidgets(4), reason: '$key tapped again: All');
      }
    });

    ph5TestWidgets('$name at text scale 1.3 with reduced motion: no overflow, the words stay', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, size, reduceMotion: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(StatusDot), findsNWidgets(4));
      expect(find.byKey(const ValueKey('subscriptionHistory-reason')), findsOneWidget);
    });
  }

  for (final size in ph5WideSizes) {
    ph5TestWidgets('${size.width.toInt()}x${size.height.toInt()} keeps its columns in order, the search and the filters', (tester) async {
      await _pump(tester, size);
      final headers = ['Submitted', 'Submitted by', 'Plan', 'Amount', 'Method', 'Status', 'Details'];
      final xs = [for (final h in headers) tester.getTopLeft(find.text(h).first).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNWidgets(2), reason: 'plan and method');
    });
  }
}
