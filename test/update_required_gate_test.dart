import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/maintenance_gate.dart';
import 'package:vetbiz_pro/widgets/update_required_screen.dart';

// P1: the minimum app version gate, in MaintenanceGate, reading
// platform_config/settings.minimumVersion.
void main() {
  const home = 'THE APP';

  Future<FakeFirebaseFirestore> pump(
    WidgetTester tester, {
    Object? minimumVersion,
    bool setMinimum = true,
    String? uid = 'u1',
    bool platformAdmin = false,
    String appVersion = '1.0.0',
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final db = FakeFirebaseFirestore();
    if (setMinimum) {
      await db.collection(Collections.platformConfig).doc('settings').set({'minimumVersion': minimumVersion});
    }
    if (platformAdmin && uid != null) await db.collection(Collections.platformAdmins).doc(uid).set({});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      darkTheme: AppTheme.build(AppColorTheme.pasture, Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MaintenanceGate(
        // A new gate (and state) for each pump, so each case reads its own database.
        key: UniqueKey(),
        uidChanges: const Stream<String?>.empty(),
        initialUid: uid,
        firestore: db,
        appVersion: appVersion,
        child: child!,
      ),
      home: const Scaffold(body: Text(home)),
    ));
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('a lower version is blocked: Update required, nothing else', (tester) async {
    await pump(tester, minimumVersion: '1.0.1');
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('This version of VetBiz Pro (1.0.0) can no longer be used'), findsOneWidget);
    expect(find.textContaining('version 1.0.1 or later'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text(home), findsNothing);
  });

  testWidgets('equal or higher passes', (tester) async {
    await pump(tester, minimumVersion: '1.0.0');
    expect(find.text(home), findsOneWidget);
    await pump(tester, minimumVersion: '0.9.9', appVersion: '1.0.0');
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('1.9.0 is below 1.10.0; 1.10.0 is not below 1.9.0', (tester) async {
    await pump(tester, minimumVersion: '1.10.0', appVersion: '1.9.0');
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    await pump(tester, minimumVersion: '1.9.0', appVersion: '1.10.0');
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('absent or garbage blocks nobody', (tester) async {
    await pump(tester, setMinimum: false);
    expect(find.text(home), findsOneWidget);
    for (final v in <Object?>[null, '', 'latest', 'v9', 9]) {
      await pump(tester, minimumVersion: v);
      expect(find.text(home), findsOneWidget, reason: '$v');
    }
  });

  testWidgets('a Platform Admin is not locked out', (tester) async {
    await pump(tester, minimumVersion: '99.0.0', platformAdmin: true);
    expect(find.text(home), findsOneWidget);
    expect(find.byType(UpdateRequiredScreen), findsNothing);
  });

  testWidgets('signed out reaches the app (the sign-in screen), as for maintenance', (tester) async {
    await pump(tester, minimumVersion: '99.0.0', uid: null);
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('it follows the config live: raised, then removed', (tester) async {
    final db = await pump(tester, setMinimum: false);
    expect(find.text(home), findsOneWidget);
    final settings = db.collection(Collections.platformConfig).doc('settings');
    await settings.set({'minimumVersion': '2.0.0'});
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    await settings.set({});
    await tester.pumpAndSettle();
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('it is checked before maintenance', (tester) async {
    final db = await pump(tester, minimumVersion: '2.0.0');
    await db.collection(Collections.platformConfig).doc('settings').set({'minimumVersion': '2.0.0', 'maintenanceMode': true});
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);
    expect(find.byType(MaintenanceScreen), findsNothing);
  });

  testWidgets('the screen is light even in Dark mode', (tester) async {
    await pump(tester, minimumVersion: '2.0.0', themeMode: ThemeMode.dark);
    final context = tester.element(find.text('Update required'));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
