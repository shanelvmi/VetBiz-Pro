import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/support_contact_dialog.dart';

import 'helpers/help_dialog_rows.dart';

// G3b: Settings' Help and Support shows the platform-set contact through the
// shared Help dialog (its own title kept), never a hard-coded number or
// address. Written before the change (e2be518).

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  Future<void> open(WidgetTester tester, FakeFirebaseFirestore db) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSupportContactDialog(context, firestore: db, title: context.l10n.settings_helpSupport),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('with the Settings title: the same rows as the dashboard Help', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection(Collections.appConfig).doc(SupportContactFields.docId).set(helpDialogContact);
    await open(tester, db);
    expect(helpDialogTexts(tester), [_en.settings_helpSupport, ...helpDialogExpectedRows.skip(1)]);
  });

  testWidgets('an empty document: the title, the plain sentence and Close only', (tester) async {
    await open(tester, FakeFirebaseFirestore());
    expect(helpDialogTexts(tester), [_en.settings_helpSupport, _en.dashboard_supportIntro(AppInfo.name), _en.common_close]);
  });

  group('Settings', () {
    final settings = File('lib/screens/settings/settings_screen.dart').readAsStringSync();

    test('Help and Support opens the shared dialog with its own title', () {
      expect(settings.contains('showSupportContactDialog(context, title: context.l10n.settings_helpSupport)'), isTrue);
    });

    test('no hard-coded support contact', () {
      expect(settings.contains('AppContact'), isFalse);
      expect(File('lib/config/app_links.dart').readAsStringSync().contains('class AppContact'), isFalse);
    });
  });

  // Built from pieces so this file does not hold them either.
  final personal = ['7191' '99916', 'shanelvmi' '@gmail'];
  test('no personal phone number or address in lib/ or test/', () {
    final hits = <String>[];
    for (final dir in ['lib', 'test']) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        for (final p in personal) {
          if (text.contains(p)) hits.add('${file.path}: $p');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
