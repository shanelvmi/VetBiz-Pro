// UX5 (owner, 2026-11-22): Settings grouped by scope; Business Profile as
// one page with three tabs; the Printer row only where Bluetooth printing
// runs (a platform check, not the width). lay7_settings_test covers the hub
// inside the shell (rows per role, each row's page, the requests); this file
// covers what UX5 adds.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_tabs.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';
import 'package:vetbiz_pro/utils/printer_support.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// The facility the harness selects (pumpPh5's stored selection).
const _facility = 'Kilimo Agrovet';

Finder _row(String key) => find.byKey(ValueKey('settingsHub-$key'));
Finder _tab(String key) => find.byKey(ValueKey('businessTab-$key'));

Future<void> _pumpHub(WidgetTester tester, {Size size = const Size(1200, 800), bool admin = true, MatrixLook look = MatrixLook.light, double textScale = 1}) =>
    pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: size, admin: admin, look: look, textScale: textScale, pushed: true);

/// Every group title and hub row key, scrolling through the lazy list.
Future<(List<String>, List<String>)> _collect(WidgetTester tester) async {
  final labels = <String>[];
  final rows = <String>[];
  final scrollable = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
  for (var step = 0; step < 12; step++) {
    for (final e in find.byType(SectionLabel).evaluate()) {
      final t = (e.widget as SectionLabel).text;
      if (!labels.contains(t)) labels.add(t);
    }
    for (final e in find.byType(Material).evaluate()) {
      final k = e.widget.key;
      if (k is ValueKey<String> && k.value.startsWith('settingsHub-') && !rows.contains(k.value.substring(12))) rows.add(k.value.substring(12));
    }
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  return (labels, rows);
}

void main() {
  tearDown(() => PrinterSupport.debugOverride = null);

  group('PrinterSupport: Android and iOS only (UX6)', () {
    test('web never; Android and iOS yes; Windows, macOS, Linux, Fuchsia no', () {
      for (final p in TargetPlatform.values) {
        expect(PrinterSupport.supportedOn(isWeb: true, platform: p), isFalse, reason: 'web on ${p.name}');
      }
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.android), isTrue);
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.iOS), isTrue);
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.macOS), isFalse);
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.windows), isFalse);
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.linux), isFalse);
      expect(PrinterSupport.supportedOn(isWeb: false, platform: TargetPlatform.fuchsia), isFalse);
    });
  });

  group('the hub by scope', () {
    for (final admin in [true, false]) {
      ph5TestWidgets('${admin ? 'admin' : 'assistant'}: groups and rows', (tester) async {
        await _pumpHub(tester, admin: admin);
        final (labels, rows) = await _collect(tester);
        expect(labels, [
          _en.settings_groupThisFacility(_facility),
          if (admin) _en.settings_groupAllFacilities,
          _en.settings_groupYouAndApp,
        ]);
        expect(rows, [
          if (admin) ...['business_profile', 'subscription', 'trash', 'export'],
          'printer',
          if (admin) ...['facilities', 'team'],
          'manage_account', 'notifications', 'ui_settings', 'currency', 'language', 'app_info',
        ]);
        expect(rows, isNot(contains('business_hours')));
        expect(rows, isNot(contains('activity_log')));
      });
    }

    ph5TestWidgets('Facilities row: "Facilities", not "View Facilities"', (tester) async {
      await _pumpHub(tester);
      await tester.scrollUntilVisible(_row('facilities'), 150,
          scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
      expect(find.descendant(of: _row('facilities'), matching: find.text(_en.facilities_title)), findsOneWidget);
      expect(find.text(_en.dashboard_viewFacilities), findsNothing);
    });

    for (final (name, platform) in [
      ('Android', TargetPlatform.android),
      ('iOS', TargetPlatform.iOS),
      ('Windows', TargetPlatform.windows),
      ('macOS', TargetPlatform.macOS),
      ('Linux', TargetPlatform.linux),
      ('Fuchsia', TargetPlatform.fuchsia),
    ]) {
      ph5TestWidgets('$name platform: Printer row ${platform == TargetPlatform.android || platform == TargetPlatform.iOS ? 'shown' : 'hidden'} (hub and phone)', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final shown = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
        await _pumpHub(tester);
        final (_, rows) = await _collect(tester);
        expect(rows.contains('printer'), shown);
        await _pumpHub(tester, size: const Size(390, 844));
        expect(find.text(_en.printer_title), shown ? findsOneWidget : findsNothing);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    ph5TestWidgets('web (simulated): no Printer row at any width', (tester) async {
      PrinterSupport.debugOverride = false;
      for (final size in const [Size(768, 1024), Size(1920, 1080)]) {
        await _pumpHub(tester, size: size);
        final (_, rows) = await _collect(tester);
        expect(rows, isNot(contains('printer')), reason: '$size');
      }
      await _pumpHub(tester, size: const Size(390, 844));
      expect(find.text(_en.printer_title), findsNothing);
    });

    for (final admin in [true, false]) {
      ph5TestWidgets('phone ${admin ? 'admin' : 'assistant'}: the list grouped by scope, rows unchanged', (tester) async {
        await _pumpHub(tester, size: const Size(390, 844), admin: admin);
        expect(find.byType(PageHeader), findsNothing, reason: 'the phone list, not the hub');
        final texts = [for (final e in find.byType(Text).evaluate()) if ((e.widget as Text).data != null) (e.widget as Text).data!];
        expect(texts, contains(_en.settings_groupThisFacility(_facility).toUpperCase()));
        expect(texts, isNot(contains(_en.settings_groupAllFacilities.toUpperCase())));
        expect(texts.contains(_en.hours_title), admin, reason: 'the phone keeps its Business Hours row');
        expect(texts.contains(_en.profile_title), isFalse, reason: 'Business Profile stays in the phone profile page');
      });
    }
  });

  group('Business Profile tabs', () {
    ph5TestWidgets('the row opens the tabs; each tab switches and keeps its state', (tester) async {
      await _pumpHub(tester);
      await tester.tap(_row('business_profile'));
      await ph5Settle(tester);
      final host = find.byType(BusinessProfileTabs);
      expect(host, findsOneWidget);
      final header = find.descendant(of: host, matching: find.byType(PageHeader));
      expect(header, findsOneWidget, reason: 'one header: the host\'s');
      expect(find.descendant(of: header, matching: find.text(_en.profile_title)), findsOneWidget);
      expect(find.descendant(of: host, matching: find.byType(AppBar)), findsNothing);
      for (final t in BusinessProfileTabs.tabs) {
        expect(find.descendant(of: _tab(t), matching: find.byType(Text)), findsOneWidget);
      }
      // Left-aligned: the first tab starts at the page padding.
      expect(tester.getRect(_tab(BusinessProfileTabs.profile)).left, lessThan(40));
      expect(find.byType(BusinessProfileScreen), findsOneWidget);
      final profileState = tester.state(find.byType(BusinessProfileScreen));

      await tester.tap(_tab(BusinessProfileTabs.hours));
      await ph5Settle(tester);
      expect(find.byType(BusinessHoursScreen), findsOneWidget);
      final hoursState = tester.state(find.byType(BusinessHoursScreen));

      await tester.tap(_tab(BusinessProfileTabs.activityLog));
      await ph5Settle(tester);
      expect(find.byType(ActivityLogScreen), findsOneWidget);

      await tester.tap(_tab(BusinessProfileTabs.profile));
      await ph5Settle(tester);
      expect(identical(tester.state(find.byType(BusinessProfileScreen)), profileState), isTrue, reason: 'kept, not rebuilt');
      await tester.tap(_tab(BusinessProfileTabs.hours));
      await ph5Settle(tester);
      expect(identical(tester.state(find.byType(BusinessHoursScreen)), hoursState), isTrue, reason: 'kept, not rebuilt');
      expect(tester.takeException(), isNull);
    });

    // Callers outside the hub still open each screen alone with its own bar.
    for (final name in const ['Business Profile', 'Business Hours', 'Activity Log']) {
      ph5TestWidgets('$name alone (wide) keeps its own page header', (tester) async {
        await pumpPh5(tester, (fs) => switch (name) {
              'Business Profile' => BusinessProfileScreen(firestore: fs),
              'Business Hours' => BusinessHoursScreen(firestore: fs),
              _ => ActivityLogScreen(firestore: fs, auth: Ph8bAuth()),
            }, size: const Size(1200, 800), pushed: true);
        expect(find.byType(PageHeader), findsOneWidget, reason: name);
      });
    }
  });

  // Widths 768, 1200, 1920; English 1.0 and 1.3, Kiswahili 1.3: the hub and
  // each tab without overflow.
  group('no overflow', () {
    for (final size in const [Size(768, 1024), Size(1200, 800), Size(1920, 1080)]) {
      for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
        ph5TestWidgets('${size.width.toInt()} ${look.name} $scale: hub and every tab', (tester) async {
          await _pumpHub(tester, size: size, look: look, textScale: scale);
          expect(tester.takeException(), isNull, reason: 'hub');
          await _collect(tester);
          expect(tester.takeException(), isNull, reason: 'hub scrolled');
          await tester.drag(find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first, const Offset(0, 5000));
          await tester.pumpAndSettle();
          await tester.tap(_row('business_profile'));
          await ph5Settle(tester);
          for (final t in BusinessProfileTabs.tabs) {
            await tester.tap(_tab(t));
            await ph5Settle(tester);
            expect(tester.takeException(), isNull, reason: 'tab $t');
          }
        });
      }
    }
  });
}
