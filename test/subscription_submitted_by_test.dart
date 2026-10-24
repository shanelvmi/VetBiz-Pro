// SUBS-1 (RUNBOOK2 ledger): the subscription screens say WHO made each
// payment claim, and the operator tab who made and who reviewed it, for
// accountability. A claim stores the submitter's name (submittedByName) next
// to the email (submittedBy) and the uid (submittedById); a review stores
// reviewedByName next to reviewedBy (the email). Older documents have no
// name and show the email; the platform team's own records
// (source: 'manual') show "VetBiz Pro team".
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/platform_admin/subscription_requests_tab.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_history_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

final _recent = DateTime.now().subtract(const Duration(days: 2));

Map<String, dynamic> _claim(String status, Map<String, dynamic> who) => {
      'facilityId': 'F1',
      'facilityName': 'Ukuli Agrovet',
      'planId': 'basic_monthly',
      'planLabel': 'Basic (Monthly)',
      'amount': 20000,
      'method': 'M-Pesa',
      'reference': 'QX12',
      'status': status,
      'submittedAt': Timestamp.fromDate(_recent),
      ...who,
    };

/// A claim made since SUBS-1, an older one with only the email, and a record
/// of the platform team's own.
Future<FakeFirebaseFirestore> _seedHistory() async {
  final fs = FakeFirebaseFirestore();
  final claims = fs.collection('facilities').doc('F1').collection('payment_submissions');
  await claims.doc('new').set(_claim('approved',
      {'submittedBy': 'neema@example.com', 'submittedById': 'u1', 'submittedByName': 'Neema Mushi'}));
  await claims.doc('old').set(_claim('rejected', {'submittedBy': 'old@example.com'}));
  await claims.doc('team').set(_claim('approved', {'submittedBy': 'pa@example.com', 'source': 'manual'}));
  return fs;
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

Future<void> _pumpAt(WidgetTester tester, double width, Widget home) async {
  // The square test font overflows the pagination bar at phone width; only
  // overflows are ignored.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!'${details.exception}'.contains('overflowed')) onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home));
  await tester.pumpAndSettle();
}

void main() {
  group('the claim the subscription screen submits', () {
    test('stores the name next to the email and the uid; with no name on the profile, the email', () {
      expect(paymentClaimSubmitter(email: 'neema@example.com', uid: 'u1')['submittedByName'], 'neema@example.com');
    });

    test('the screen passes the profile\'s full name, and both reviews store the reviewer\'s', () {
      final submit = File('lib/screens/subscription/subscription_screen.dart').readAsStringSync();
      expect(submit, contains('...paymentClaimSubmitter(email: user?.email, uid: user?.uid, fullName: '));
      final review = File('lib/screens/platform_admin/subscription_requests_tab.dart').readAsStringSync();
      expect('...reviewerFields('.allMatches(review).length, 2, reason: 'approve and reject');
      expect(review, isNot(contains("'reviewedBy': admin")));
    });
  });

  group('Subscription history', () {
    testWidgets('wide: a "Submitted by" column - the name, an old row\'s email, the team', (tester) async {
      final fs = await _seedHistory();
      await _pumpAt(tester, 1400,
          SubscriptionHistoryScreen(facilityId: 'F1', primaryColor: AppPalette.primary, firestore: fs));
      expect(find.text('Submitted by'), findsOneWidget);
      expect(find.text('Neema Mushi'), findsOneWidget);
      expect(find.text('old@example.com'), findsOneWidget);
      expect(find.text('VetBiz Pro team'), findsOneWidget);
    });

    testWidgets('phone: a "Submitted by" line on each card', (tester) async {
      final fs = await _seedHistory();
      await _pumpAt(tester, 390,
          SubscriptionHistoryScreen(facilityId: 'F1', primaryColor: AppPalette.primary, firestore: fs));
      expect(find.text('Submitted by Neema Mushi'), findsOneWidget);
      expect(find.text('Submitted by old@example.com'), findsOneWidget);
      expect(find.text('Submitted by VetBiz Pro team'), findsOneWidget);
    });
  });

  group('Operator: Subscription requests', () {
    Future<FakeFirebaseFirestore> seedRequests() async {
      final fs = FakeFirebaseFirestore();
      final claims = fs.collection('facilities').doc('F1').collection('payment_submissions');
      await claims.doc('waiting').set(_claim('pending',
          {'submittedBy': 'neema@example.com', 'submittedById': 'u1', 'submittedByName': 'Neema Mushi'}));
      await claims.doc('reviewed').set({
        ..._claim('approved', {'submittedBy': 'juma@example.com', 'submittedById': 'u2', 'submittedByName': 'Juma Ally'}),
        'reviewedAt': Timestamp.fromDate(_recent),
        'reviewedBy': 'asha@vetbiz.example',
        'reviewedByName': 'Asha Admin',
      });
      await claims.doc('reviewedOld').set({
        ..._claim('rejected', {'submittedBy': 'old@example.com'}),
        'reviewedAt': Timestamp.fromDate(_recent),
        'reviewedBy': 'oldpa@vetbiz.example',
      });
      return fs;
    }

    testWidgets('Pending shows who submitted; Attended shows who submitted and who reviewed, by name or email',
        (tester) async {
      final fs = await seedRequests();
      await _pumpAt(tester, 900, Scaffold(body: SubscriptionRequestsTab(firestore: fs)));
      expect(find.text('Submitted by Neema Mushi'), findsOneWidget);

      await tester.tap(find.text('Attended'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted by Juma Ally'), findsOneWidget);
      expect(find.textContaining('Reviewed by Asha Admin'), findsOneWidget);
      expect(find.text('Submitted by old@example.com'), findsOneWidget);
      expect(find.textContaining('Reviewed by oldpa@vetbiz.example'), findsOneWidget);
    });
  });
}
