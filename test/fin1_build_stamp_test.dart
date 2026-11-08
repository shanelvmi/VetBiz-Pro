import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_settings_wide_test.dart' show seedFacility;

// FIN1 (2): a visible build stamp. AppInfo.buildStamp is the BUILD_STAMP
// the build was given (tool/serve_web.ps1 passes the local date and time),
// dev without one; the sign-in footer's bottom row and Settings show it
// after the version. The screens' tests were written before the change.
const _skipShown = false;

const _stamp = '2026-11-09 14:05';

void main() {
  tearDown(() => AppInfo.buildStampOverride = null);

  test('without a BUILD_STAMP the stamp is dev', () {
    expect(AppInfo.definedBuildStamp, 'dev');
    expect(AppInfo.buildStamp, 'dev');
  });

  test('a stamp given is the one shown (the seam), and dev again without it', () {
    AppInfo.buildStampOverride = _stamp;
    expect(AppInfo.buildStamp, _stamp);
    AppInfo.buildStampOverride = null;
    expect(AppInfo.buildStamp, 'dev');
  });

  test('tool/serve_web.ps1 builds with the stamp it prints, then serves build/web on port 8080', () {
    final script = File('tool/serve_web.ps1').readAsStringSync();
    expect(script, contains("Get-Date -Format 'yyyy-MM-dd HH:mm'"));
    expect(script, contains(r'flutter build web --release "--dart-define=BUILD_STAMP=$stamp"'));
    expect(script, contains('Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias'));
    expect(script, contains(r'Write-Host "Build stamp: $stamp"'));
    expect(script, contains(r'http://${ip}:8080'));
    expect(script, contains('dart pub global run dhttpd --host 0.0.0.0 --port 8080 --path build/web'));
  });

  Future<void> pumpFooter(WidgetTester tester, Locale locale, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(child: AuthFooter(store: SupportContactStore.seeded(SupportContact.empty))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(1200, 800)]) {
    final at = '${size.width.toInt()}';
    testWidgets('$at: the footer shows "v1.0.0 (build <stamp>)", and dev without a stamp', (tester) async {
      AppInfo.buildStampOverride = _stamp;
      await pumpFooter(tester, const Locale('en'), size);
      expect(find.text('${AppInfo.versionLabel} (build $_stamp)'), findsOneWidget);
      AppInfo.buildStampOverride = null;
      await pumpFooter(tester, const Locale('en'), size);
      expect(find.text('${AppInfo.versionLabel} (build dev)'), findsOneWidget);
    }, skip: _skipShown);
  }

  testWidgets('the footer in Kiswahili: the version and the stamp', (tester) async {
    AppInfo.buildStampOverride = _stamp;
    await pumpFooter(tester, const Locale('sw'), const Size(390, 844));
    final shown = find.textContaining(_stamp);
    expect(shown, findsOneWidget);
    expect(tester.widget<Text>(shown).data, startsWith(AppInfo.versionLabel));
  }, skip: _skipShown);

  for (final size in const [Size(390, 844), Size(1200, 800)]) {
    final at = '${size.width.toInt()}';
    testWidgets('$at: Settings shows the stamp after the version (the App info row; on phones the version line too)', (tester) async {
      AppInfo.buildStampOverride = _stamp;
      await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8Auth()), size: size, pushed: true, seed: seedFacility);
      final en = lookupAppLocalizations(const Locale('en'));
      if (size.width < 600) {
        final line = find.text(en.settings_versionLine(AppInfo.name, '${AppInfo.version} (build $_stamp)'));
        // The list builds lazily: scroll down to its last line, then back.
        await tester.dragUntilVisible(line, find.byType(ListView).first, const Offset(0, -200));
        expect(line, findsOneWidget);
        await tester.dragUntilVisible(find.text(en.settings_appInfo).first, find.byType(ListView).first, const Offset(0, 200));
      }
      final row = find.text(en.settings_appInfo).first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('${AppInfo.version} (build $_stamp)'), findsOneWidget);
    }, skip: _skipShown);
  }

  testWidgets('390 Kiswahili: Settings, no overflow with the stamp', (tester) async {
    AppInfo.buildStampOverride = _stamp;
    await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8Auth()),
        size: const Size(390, 844), look: MatrixLook.kiswahili, pushed: true, seed: seedFacility);
    await tester.dragUntilVisible(find.textContaining(_stamp), find.byType(ListView).first, const Offset(0, -200));
    expect(find.textContaining(_stamp), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: _skipShown);
}
