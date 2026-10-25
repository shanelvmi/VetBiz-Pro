import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/support_contact_dialog.dart';

import 'helpers/help_dialog_rows.dart';

// G3: the dashboard's Help dialog moved into one shared function, also used
// by the sign-in footer's "Help and contact" (that entry point is tested in
// g3_auth_footer_test.dart against the same rows).
void main() {
  Future<void> openFrom(WidgetTester tester, FakeFirebaseFirestore db) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSupportContactDialog(context, firestore: db),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('every contact row that is set, in the dashboard order', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection(Collections.appConfig).doc(SupportContactFields.docId).set(helpDialogContact);
    await openFrom(tester, db);
    expect(helpDialogTexts(tester), helpDialogExpectedRows);
  });

  testWidgets('an empty document shows only the title, the sentence and Close', (tester) async {
    await openFrom(tester, FakeFirebaseFirestore());
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(helpDialogTexts(tester), [l10n.dashboard_contactSupport, l10n.dashboard_supportIntro('VetBiz Pro'), l10n.common_close]);
  });

  test('the dashboard opens the shared dialog and no longer reads the document itself', () {
    final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(RegExp(r'showSupportContactDialog\(context\)').allMatches(source).length, 2);
    expect(source.contains('_showHelpDialog'), isFalse);
    expect(source.contains("doc('support_contact')"), isFalse);
  });
}
