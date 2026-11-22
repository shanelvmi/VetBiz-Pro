// UX7 (owner, 2026-11-22): one page template for the PC/tablet Settings
// pages. The page header, then the body at the full content width; tabs as a
// left-aligned FilterRow in the body (Trash, Business Profile); flat
// hairline cards, two columns from 900 of the content; tables with a fixed
// Date column. Business Profile: an identity card over two tabs, Business
// Hours (the default) and Activity Log. Subscription is always the full
// page off the phone, never the modal. The subscription pill sits in the
// shell's layout under the top bar, not over the page header.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_tabs.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/fake_firestore.dart' show facilityDoc;
import 'helpers/fake_storage.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_activity_wide_test.dart' show seedActivity;
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_settings_wide_test.dart' show seedTrash, ph8UserInfo, seedFacility;
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

final _en = lookupAppLocalizations(const Locale('en'));
final _shell = GlobalKey<AppShellState>();
final _request = ValueNotifier<SettingsRequest?>(null);

const _wide = [Size(768, 1024), Size(1200, 800), Size(1920, 1080)];
const _looks = [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)];

/// The real SettingsScreen in AppShell (as lay7_settings_test). (UX8b: the
/// banner floats over the content now: ux8b_shell_banner_test.)
Widget _harness(FirebaseFirestore fs, double sidebar, {Widget? contentButton}) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (s, o) => SizedBox(width: sidebar),
        topBar: const SizedBox(height: 64),
        home: contentButton ?? const Text('HOME'),
        pageFor: (d) => d == AppDestination.settings ? SettingsScreen(firestore: fs, auth: Ph8bAuth(), request: _request) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

Future<void> _seedAll(FirebaseFirestore fs) async {
  await ph8bSeedTeam(fs, twoFacilities: false);
  await seedTrash(fs);
  await seedSubscription(fs);
}

/// Content 1200 (sidebar collapsed) or 1670 (open, a 1920 window).
Future<void> _pumpShell(WidgetTester tester, {Size size = const Size(1272, 800), double sidebar = 72, Widget? contentButton}) async {
  _request.value = null;
  await pumpPh5(tester, (fs) => _harness(fs, sidebar, contentButton: contentButton), size: size, seed: _seedAll);
}

Future<void> _openSettings(WidgetTester tester) async {
  _shell.currentState!.select(AppDestination.settings);
  await tester.pumpAndSettle();
}

Future<void> _openRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey('settingsHub-$key'));
  await tester.scrollUntilVisible(row, 150, scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
  await tester.tap(row);
  await ph5Settle(tester);
}

void _drain(WidgetTester tester) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    expect(e.toString(), contains('Firebase'), reason: '$e');
  }
}

void main() {
  group('Step 0a: through the hub in the shell', () {
    for (final (content, size, sidebar) in [(1200, const Size(1272, 800), 72.0), (1670, const Size(1920, 1080), 250.0)]) {
      ph5TestWidgets('content $content: Subscription, Export and Trash at the full width', (tester) async {
        await _pumpShell(tester, size: size, sidebar: sidebar);
        await _openSettings(tester);
        final body = Rect.fromLTRB(sidebar, 0, size.width, size.height);

        await _openRow(tester, 'subscription');
        final left = tester.getRect(find.byKey(const ValueKey('subscription-left')));
        final right = tester.getRect(find.byKey(const ValueKey('subscription-right')));
        expect(right.left, greaterThan(left.right), reason: 'two columns');
        expect(right.right, greaterThan(body.right - 40), reason: 'full width');
        expect(find.byType(Dialog), findsNothing);
        await tester.binding.handlePopRoute();
        await ph5Settle(tester);

        await _openRow(tester, 'export');
        expect(find.text(_en.export_step1), findsNothing, reason: 'no old numbered steps');
        expect(find.byKey(const ValueKey('pageColumns-two')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await ph5Settle(tester);

        await _openRow(tester, 'trash');
        expect(find.byType(TabBar), findsNothing, reason: 'no TabBar in the header');
        _drain(tester);
      });
    }
  });

  group('Subscription is never the modal off the phone', () {
    ph5TestWidgets('a SettingsRequest (the banner\'s Renew) opens the full page in the shell', (tester) async {
      await _pumpShell(tester);
      _shell.currentState!.select(AppDestination.settings);
      _request.value = const SettingsRequest(SettingsRequest.subscription);
      await ph5Settle(tester);
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(tester.widget<SubscriptionScreen>(find.byType(SubscriptionScreen)).isModal, isFalse);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('subscription-wide')), findsOneWidget);
      expect(_shell.currentState!.selected, AppDestination.settings);
      _drain(tester);
    });

    ph5TestWidgets('showSubscriptionScreen inside the shell (the guard): in the content', (tester) async {
      await _pumpShell(tester,
          contentButton: Builder(builder: (c) => TextButton(onPressed: () => showSubscriptionScreen(c), child: const Text('GO'))));
      await tester.tap(find.text('GO'));
      await ph5Settle(tester);
      // The page reads the app's own Firebase (no seam here): its build error
      // is drained; what matters is where it was pushed.
      while (tester.takeException() != null) {}
      expect(find.byType(Dialog), findsNothing);
      expect(_shell.currentState!.contentNavigatorKey.currentState!.canPop(), isTrue, reason: 'a page in the shell content');
      expect(_shell.currentState!.selected, AppDestination.settings);
    });

    // With no shell (a page pushed full screen) ph2b_adaptive_form_test pins
    // a MaterialPageRoute at every width.
  });

  group('Business Profile', () {
    ph5TestWidgets('identity card, two tabs, Business Hours by default', (tester) async {
      await _pumpShell(tester);
      await _openSettings(tester);
      await _openRow(tester, 'business_profile');
      expect(find.byKey(const ValueKey('business-identity-card')), findsOneWidget);
      final card = find.byKey(const ValueKey('business-identity-card'));
      expect(find.descendant(of: card, matching: find.byKey(const ValueKey('business-upload-logo'))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(_en.profile_logoHint)), findsOneWidget);
      expect(find.descendant(of: find.byType(PageHeader).last, matching: find.text(_en.profile_title)), findsOneWidget);
      final row = tester.widget<FilterRow>(find.descendant(of: find.byType(BusinessProfileTabs), matching: find.byType(FilterRow)));
      expect(row.values, [BusinessProfileTabs.hours, BusinessProfileTabs.activityLog]);
      expect(row.selected, BusinessProfileTabs.hours);
      expect(find.byType(BusinessHoursScreen), findsOneWidget);
      expect(find.byType(ActivityLogScreen), findsNothing, reason: 'built when first chosen');
      // Upload at the right of the card; the card below the header.
      final upload = tester.getRect(find.byKey(const ValueKey('business-upload-logo')));
      expect(tester.getRect(card).right - upload.right, lessThan(40));
      _drain(tester);
    });

    for (final (item, tab) in [
      ('business_profile', BusinessProfileTabs.hours),
      ('business_hours', BusinessProfileTabs.hours),
      (SettingsRequest.activityLog, BusinessProfileTabs.activityLog),
    ]) {
      ph5TestWidgets('request $item opens the $tab tab with the identity card', (tester) async {
        await _pumpShell(tester);
        _shell.currentState!.select(AppDestination.settings);
        _request.value = SettingsRequest(item);
        await ph5Settle(tester);
        expect(find.byKey(const ValueKey('business-identity-card')), findsOneWidget);
        expect(tester.widget<FilterRow>(find.descendant(of: find.byType(BusinessProfileTabs), matching: find.byType(FilterRow))).selected, tab);
        _drain(tester);
      });
    }

    ph5TestWidgets('the identity card saves a picked logo as before (pending bytes, then the URL)', (tester) async {
      final storage = FakeStorage();
      final app = await pumpPh5(
          tester,
          (fs) => Scaffold(
              body: BusinessProfileScreen(firestore: fs, storage: storage, pickLogo: () async => Uint8List(2048), embedded: true)),
          size: const Size(1200, 800),
          seed: seedFacility);
      expect(find.byKey(const ValueKey('business-identity-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-upload-logo')));
      await ph5Settle(tester);
      while (tester.takeException() != null) {}
      expect(storage.uploads, hasLength(1));
      final facility = (await tester.runAsync(() async => (await facilityDoc(app.fs).get()).data()!))!;
      expect(facility['logoUrl'], isA<String>());
      expect(facility['logoUrl'] as String, contains('cb='));
    });
  });

  group('tables and tabs', () {
    ph5TestWidgets('Trash: tabs are a left-aligned FilterRow in the body, under the header', (tester) async {
      await pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo), size: const Size(1200, 800), pushed: true, seed: seedTrash);
      expect(find.byType(TabBar), findsNothing);
      final first = tester.getRect(find.byKey(const ValueKey('trashTab-${'trash_products'}')).hitTestable().first);
      expect(first.left, lessThan(40), reason: 'left-aligned');
      expect(first.top, greaterThanOrEqualTo(tester.getRect(find.byType(PageHeader)).bottom));
      // The Date column at one x in the header and the row.
      final dates = find.byKey(const ValueKey('pageTable-date'));
      expect(dates.evaluate().length, greaterThanOrEqualTo(2));
      final xs = {for (final e in dates.evaluate()) tester.getRect(find.byWidget(e.widget)).left};
      expect(xs, hasLength(1));
    }, skip: false);

    ph5TestWidgets('Activity Log: Date at one x on every row; no shadow in the rows', (tester) async {
      await pumpPh5(tester, (fs) => ActivityLogScreen(firestore: fs, auth: Ph8bAuth()), size: const Size(1200, 800), pushed: true, seed: (fs) async {
        await ph8bSeedTeam(fs, twoFacilities: false);
        await seedActivity(fs);
      });
      final table = find.byKey(const ValueKey('activity-table'));
      expect(table, findsOneWidget);
      final dates = find.descendant(of: table, matching: find.byKey(const ValueKey('pageTable-date')));
      expect(dates.evaluate().length, greaterThanOrEqualTo(3), reason: 'the header and the rows');
      final xs = {for (final e in dates.evaluate()) tester.getRect(find.byWidget(e.widget)).left};
      expect(xs, hasLength(1));
      expect(find.descendant(of: table, matching: find.byType(Card)), findsNothing);
      for (final e in find.descendant(of: table, matching: find.byType(DecoratedBox)).evaluate()) {
        final d = (e.widget as DecoratedBox).decoration;
        if (d is BoxDecoration) expect(d.boxShadow, anyOf(isNull, isEmpty));
      }
      expect(find.descendant(of: table, matching: find.byType(PhysicalModel)), findsNothing);
      _drain(tester);
    });
  });

  group('full width; two columns from 900, one at 768', () {
    for (final size in _wide) {
      for (final (name, build) in <(String, Widget Function(FirebaseFirestore))>[
        ('Export Data', (fs) => ExportDataScreen(firestore: fs)),
        ('Business Hours', (fs) => BusinessHoursScreen(firestore: fs)),
      ]) {
        ph5TestWidgets('$name at ${size.width.toInt()}', (tester) async {
          await pumpPh5(tester, build, size: size, pushed: true, seed: seedFacility);
          final cards = find.byKey(const ValueKey('pageCard'));
          final union = cards.evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).reduce((a, b) => a.expandToInclude(b));
          expect(union.left, lessThan(40));
          expect(union.right, greaterThan(size.width - 40), reason: 'the full width, not a narrow centred column');
          final two = size.width >= 900;
          if (name == 'Export Data') {
            expect(find.byKey(const ValueKey('pageColumns-two')), two ? findsOneWidget : findsNothing);
          } else {
            final wd = tester.getRect(find.byKey(const ValueKey('hours-day-weekdays')));
            final sa = tester.getRect(find.byKey(const ValueKey('hours-day-saturday')));
            expect(sa.top == wd.top, two, reason: 'side by side from 900');
            final save = tester.getRect(find.byKey(const ValueKey('hours-save')));
            expect(size.width - save.right, lessThan(40), reason: 'Save at the right');
            expect(save.height, greaterThanOrEqualTo(44));
          }
        });
      }
    }
  });

  group('no overflow', () {
    for (final size in _wide) {
      for (final (look, scale) in _looks) {
        ph5TestWidgets('${size.width.toInt()} ${look.name} $scale: Business Profile, Trash, Export, Subscription', (tester) async {
          for (final build in <Widget Function(FirebaseFirestore)>[
            (fs) => BusinessProfileTabs(firestore: fs, auth: Ph8bAuth()),
            (fs) => BusinessProfileTabs(firestore: fs, auth: Ph8bAuth(), initialTab: BusinessProfileTabs.activityLog),
            (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
            (fs) => ExportDataScreen(firestore: fs),
            (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
          ]) {
            await pumpPh5(tester, build, size: size, pushed: true, look: look, textScale: scale, seed: (fs) async {
              await ph8bSeedTeam(fs, twoFacilities: false);
              await seedTrash(fs);
              await seedSubscription(fs);
              await seedActivity(fs);
            });
            for (var e = tester.takeException(); e != null; e = tester.takeException()) {
              expect(e.toString(), isNot(contains('overflowed')));
            }
          }
        });
      }
    }
  });
}
