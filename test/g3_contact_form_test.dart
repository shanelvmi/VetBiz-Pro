import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/platform_admin/announcements_tab.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// G3: the Platform Admin's Contact Details form gets the six social links,
// checked by SocialLink.sanitize before anything is saved. Written before the
// fields, skipped until they exist.
const _skip = true;

const _invalid = 'Enter a full web address, like https://facebook.com/yourpage';

void main() {
  late FakeFirebaseFirestore db;

  Future<Map<String, dynamic>?> stored() async =>
      (await db.collection(Collections.appConfig).doc(SupportContactFields.docId).get()).data();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: ContactDetailsCard(firestore: db))),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save Contact Details'));
    await tester.pumpAndSettle();
  }

  setUp(() => db = FakeFirebaseFirestore());

  group('Contact Details form', skip: _skip, () {
    testWidgets('has the six optional link fields, filled from the document', (tester) async {
      await db.collection(Collections.appConfig).doc(SupportContactFields.docId).set({'facebook': 'https://facebook.com/v'});
      await pump(tester);
      for (final label in const ['Facebook', 'Instagram', 'X', 'LinkedIn', 'YouTube', 'TikTok']) {
        expect(field(label), findsOneWidget, reason: label);
      }
      expect(tester.widget<TextField>(field('Facebook')).controller!.text, 'https://facebook.com/v');
    });

    testWidgets('an invalid link shows an inline error and nothing is saved', (tester) async {
      await pump(tester);
      await tester.enterText(field('Email address'), 'help@vetbiz.co.tz');
      await tester.enterText(field('Instagram'), 'javascript:alert(1)');
      await save(tester);
      expect(find.text(_invalid), findsOneWidget);
      expect(await stored(), isNull);
    });

    testWidgets('valid links are saved cleaned, with all six fields and the contact rows', (tester) async {
      await pump(tester);
      await tester.enterText(field('Email address'), 'help@vetbiz.co.tz');
      await tester.enterText(field('Facebook'), 'facebook.com/vetbiz');
      await tester.enterText(field('Instagram'), '  www.instagram.com/vetbiz ');
      await tester.enterText(field('TikTok'), 'https://www.tiktok.com/@vetbiz');
      await save(tester);
      final data = (await stored())!;
      expect(data['email'], 'help@vetbiz.co.tz');
      expect(data['facebook'], 'https://facebook.com/vetbiz');
      expect(data['instagram'], 'https://www.instagram.com/vetbiz');
      expect(data['x'], '');
      expect(data['linkedin'], '');
      expect(data['youtube'], '');
      expect(data['tiktok'], 'https://www.tiktok.com/@vetbiz');
      // The field shows what was saved.
      expect(tester.widget<TextField>(field('Facebook')).controller!.text, 'https://facebook.com/vetbiz');
    });

    testWidgets('fixing the link clears the error and saves', (tester) async {
      await pump(tester);
      await tester.enterText(field('X'), 'ftp://x.com/vetbiz');
      await save(tester);
      expect(find.text(_invalid), findsOneWidget);
      await tester.enterText(field('X'), 'x.com/vetbiz');
      await save(tester);
      expect(find.text(_invalid), findsNothing);
      expect((await stored())!['x'], 'https://x.com/vetbiz');
    });
  });
}
