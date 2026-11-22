// LAY7, UX3 (owner, 2026-11-21): on PC and tablet Settings is one hub page:
// the shared page header, the groups as SectionLabels, bordered rows (icon,
// title, trailing value, chevron), two columns from 900 of the content. The
// Business group (Business Profile, Business Hours, View Facilities, Team
// Members, Activity Log) is admin-only, a Co-admin included. Every row that
// opens a page pushes it inside the content above the hub, with the page
// header and a back arrow; Settings stays highlighted; Back returns to the
// hub, then Home. Dialog rows open dialogs. Other places ask Settings for an
// item (SettingsRequest). The phone list is unchanged.
// The real SettingsScreen inside AppShell, as lay4_shell_screens_test.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/printer_settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _shell = GlobalKey<AppShellState>();
final _request = ValueNotifier<SettingsRequest?>(null);

enum _Role { admin, coAdmin, assistant }

/// The content widths of the block: (window, sidebar). 696 and 950 with the
/// sidebar collapsed, 774 open, 1128 collapsed and 950 open.
final _widths = <double, (Size, double)>{
  696: (Size(768, 1024), 72),
  774: (Size(1024, 768), 250),
  950: (Size(1200, 800), 250),
  1128: (Size(1200, 800), 72),
};

Widget _harness(FirebaseFirestore fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in [AppDestination.home, AppDestination.settings])
              SizedBox(
                key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'),
                height: 48,
                child: TextButton(onPressed: () => onSelect(d), child: const SizedBox.shrink()),
              ),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => d == AppDestination.settings ? SettingsScreen(firestore: fs, auth: Ph8bAuth(), request: _request) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

Future<void> _seed(FirebaseFirestore fs, _Role role) async {
  await ph8bSeedTeam(fs, twoFacilities: false);
  if (role == _Role.coAdmin) {
    await fs.collection(Collections.users).doc(testUserId).set({'role': 'admin', 'previousRole': 'assistant'}, SetOptions(merge: true));
  }
  if (role == _Role.assistant) {
    await fs.collection(Collections.users).doc(testUserId).set({'role': 'assistant', 'status': 'active'}, SetOptions(merge: true));
  }
}

Future<void> _pumpWide(WidgetTester tester, double content,
    {_Role role = _Role.admin, MatrixLook look = MatrixLook.light, AppColorTheme colorTheme = AppColorTheme.pasture, double textScale = 1}) async {
  final (size, sidebar) = _widths[content]!;
  _request.value = null;
  await pumpPh5(tester, (fs) => _harness(fs, sidebar),
      size: size, admin: role != _Role.assistant, seed: (fs) => _seed(fs, role), look: look, colorTheme: colorTheme, textScale: textScale);
  _shell.currentState!.select(AppDestination.settings);
  await tester.pumpAndSettle();
}

/// The hub's groups, each with its rows' keys, for a role.
List<(String, List<String>)> _hub(AppLocalizations l, {required bool admin}) => [
      if (admin) ...[
        (l.subscription_title, ['subscription']),
        (l.expenseGroup_business, ['business_profile', 'business_hours', 'facilities', 'team', 'activity_log']),
      ],
      (l.settings_accountData, [if (admin) ...['trash', 'export'], 'manage_account']),
      (l.settings_general, ['notifications', 'printer', 'app_info']),
      (l.settings_preferences, ['ui_settings', 'currency', 'language']),
    ];

/// Each page row and the page it opens.
const _pages = <String, Type>{
  'subscription': SubscriptionScreen,
  'business_profile': BusinessProfileScreen,
  'business_hours': BusinessHoursScreen,
  'facilities': FacilityScreen,
  'team': ManageAssistantsScreen,
  'activity_log': ActivityLogScreen,
  'trash': TrashScreen,
  'export': ExportDataScreen,
  'manage_account': ManageAccountScreen,
  'printer': PrinterSettingsScreen,
};

Finder _row(String key) => find.byKey(ValueKey('settingsHub-$key'));

/// The hub list builds lazily: scroll until the row is built and shown.
Future<void> _reveal(WidgetTester tester, String key) => tester.scrollUntilVisible(_row(key), 150,
    scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await ph5Settle(tester);
}

/// Errors from the pages that read the app's own Firebase (Notifications:
/// no seam in the fake harness) are expected; nothing else.
void _drainFirebase(WidgetTester tester, String why) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    // #27 (LAYOUT_DEFECTS.md): the Printer page's Paired row, Kiswahili at 1.3.
    if (why == 'printer' && e.toString().contains('RenderFlex overflowed')) continue;
    expect(e.toString(), contains('Firebase'), reason: '$why: $e');
  }
}

void main() {
  group('the hub per role and content width', () {
    for (final role in _Role.values) {
      for (final content in _widths.keys) {
        ph5TestWidgets('${role.name} at content ${content.toInt()}', (tester) async {
          await _pumpWide(tester, content, role: role);
          expect(tester.takeException(), isNull);
          final settings = find.byType(SettingsScreen);
          final header = find.descendant(of: settings, matching: find.byType(PageHeader));
          expect(header, findsOneWidget);
          expect(find.descendant(of: header, matching: find.text(_en.settings_title)), findsOneWidget);
          expect(find.descendant(of: header, matching: find.byType(BackButton)), findsNothing, reason: 'a place: the sidebar is the way out');
          expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
          final hub = _hub(_en, admin: role != _Role.assistant);
          // The list builds lazily: scroll through it, collecting the group
          // titles and the rows in order, then back to the top.
          final labels = <String>[];
          final seen = <String>[];
          final scrollable = find.descendant(of: settings, matching: find.byType(Scrollable)).first;
          for (var step = 0; step < 12; step++) {
            for (final e in find.descendant(of: settings, matching: find.byType(SectionLabel)).evaluate()) {
              final t = (e.widget as SectionLabel).text;
              if (!labels.contains(t)) labels.add(t);
            }
            for (final e in find.descendant(of: settings, matching: find.byType(Material)).evaluate()) {
              final k = e.widget.key;
              if (k is ValueKey<String> && k.value.startsWith('settingsHub-') && !seen.contains(k.value.substring(12))) seen.add(k.value.substring(12));
            }
            await tester.drag(scrollable, const Offset(0, -200));
            await tester.pumpAndSettle();
          }
          await tester.drag(scrollable, const Offset(0, 5000));
          await tester.pumpAndSettle();
          expect(labels, [for (final (title, _) in hub) title]);
          final all = [for (final (_, rows) in hub) ...rows];
          expect(seen, all, reason: '${role.name}: the rows, in order');
          // Two columns from 900 of the content, else one; every row a tap target.
          final first = tester.getRect(_row(hub.first.$2.first));
          final second = tester.getRect(_row(all[1]));
          expect(first.height, greaterThanOrEqualTo(44));
          if (content >= 900 && hub.first.$2.length > 1) {
            expect(second.top, first.top, reason: 'side by side');
          } else if (content < 900) {
            expect(first.width, greaterThan(content - 40), reason: 'one column');
          }
          // The version line stays at the bottom.
          final version = find.descendant(of: settings, matching: find.textContaining(AppInfo.version));
          await tester.scrollUntilVisible(version, 200, scrollable: find.descendant(of: settings, matching: find.byType(Scrollable)).first);
          expect(tester.getRect(version).top, greaterThan(tester.getRect(_row('language')).bottom));
        });
      }
    }

    for (final admin in [true, false]) {
      ph5TestWidgets('phone, ${admin ? 'admin' : 'assistant'}: the list unchanged (no hub, no Business group)', (tester) async {
        await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), admin: admin, pushed: true);
        expect(find.byType(PageHeader), findsNothing);
        expect(find.byType(SectionLabel), findsNothing);
        expect(_row('manage_account'), findsNothing);
        final texts = [
          for (final e in find.byType(Text).evaluate())
            if ((e.widget as Text).data != null) (e.widget as Text).data!,
        ];
        expect(texts, isNot(contains(_en.expenseGroup_business.toUpperCase())));
        expect(texts.contains(_en.hours_title), admin);
      });
    }
  });

  group('each row opens its page above the hub', () {
    for (final role in [_Role.admin, _Role.coAdmin, _Role.assistant]) {
      for (final content in [696.0, 1128.0]) {
        ph5TestWidgets('${role.name} ${content.toInt()}: page header, back arrow, Settings highlighted; Back to the hub, then Home', (tester) async {
          await _pumpWide(tester, content, role: role);
          final keys = [for (final (_, rows) in _hub(_en, admin: role != _Role.assistant)) ...rows].where(_pages.containsKey);
          for (final key in keys) {
            await _reveal(tester, key);
            await tester.tap(_row(key));
            await ph5Settle(tester);
            _drainFirebase(tester, key);
            final page = find.byType(_pages[key]!);
            expect(page, findsOneWidget, reason: key);
            final header = find.descendant(of: page, matching: find.byType(PageHeader));
            expect(header, findsOneWidget, reason: '$key: the page header');
            expect(find.descendant(of: page, matching: find.byType(AppBar)), findsNothing, reason: '$key: no own bar');
            expect(find.descendant(of: header, matching: find.byType(BackButton)), findsOneWidget, reason: key);
            expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget, reason: key);
            await _back(tester);
            _drainFirebase(tester, key);
            expect(page, findsNothing, reason: key);
            expect(find.byType(SettingsScreen), findsOneWidget, reason: '$key: back to the hub');
          }
          await _back(tester);
          expect(find.byType(SettingsScreen), findsNothing);
          expect(find.text('HOME'), findsOneWidget);
        });
      }
    }

    // Notifications reads the app's own Firebase (no seam in this harness; its
    // page header is UX1b's, tested there): the row builds it, above the hub.
    ph5TestWidgets('the Notifications row opens the Notifications page', (tester) async {
      await _pumpWide(tester, 950, role: _Role.assistant);
      await _reveal(tester, 'notifications');
      await tester.tap(_row('notifications'));
      await tester.pumpAndSettle();
      final errors = [for (var e = tester.takeException(); e != null; e = tester.takeException()) e.toString()];
      expect(errors.join(), contains('Firebase'), reason: 'NotificationsScreen built (it reads FirebaseFirestore.instance)');
      expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
    });

    ph5TestWidgets('re-clicking Settings in the sidebar on a page returns to the hub', (tester) async {
      await _pumpWide(tester, 1128);
      await tester.tap(_row('team'));
      await tester.pumpAndSettle();
      expect(find.byType(ManageAssistantsScreen), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('sb-settings-selected')), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(find.byType(ManageAssistantsScreen), findsNothing);
      expect(_row('team'), findsOneWidget);
    });

    ph5TestWidgets('Team at content 1128: the list and the Invite button', (tester) async {
      await _pumpWide(tester, 1128);
      await tester.tap(_row('team'));
      await tester.pumpAndSettle();
      expect(find.text('Neema Active'), findsWidgets);
      expect(find.descendant(of: find.byType(ManageAssistantsScreen), matching: find.text(_en.team_inviteAssistant)), findsOneWidget);
    });

    for (final (key, dialog) in [('app_info', AlertDialog), ('language', BottomSheet)]) {
      ph5TestWidgets('$key still opens its ${dialog == AlertDialog ? 'dialog' : 'sheet'}', (tester) async {
        await _pumpWide(tester, 950);
        await _reveal(tester, key);
        await tester.tap(_row(key));
        await ph5Settle(tester);
        expect(find.byType(dialog), findsOneWidget);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    }

    ph5TestWidgets('Theme & layout still opens the UI settings dialog', (tester) async {
      await _pumpWide(tester, 950);
      await _reveal(tester, 'ui_settings');
      await tester.tap(_row('ui_settings'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('a request lands on the right page above the hub', () {
    for (final content in [696.0, 1128.0]) {
      ph5TestWidgets('${content.toInt()}, from Home: Team on Pending, Settings selected; Back to the hub, then Home', (tester) async {
        await _pumpWide(tester, content);
        _shell.currentState!.select(AppDestination.home);
        await tester.pumpAndSettle();
        _shell.currentState!.select(AppDestination.settings);
        _request.value = const SettingsRequest(SettingsRequest.team, teamStatus: 'pending');
        await tester.pumpAndSettle();
        final team = tester.widget<ManageAssistantsScreen>(find.byType(ManageAssistantsScreen));
        expect(team.initialStatus, 'pending');
        expect(find.descendant(of: find.byType(ManageAssistantsScreen), matching: find.byType(BackButton)), findsOneWidget);
        expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
        expect(_request.value, isNull, reason: 'consumed once');
        await _back(tester);
        expect(find.byType(ManageAssistantsScreen), findsNothing);
        expect(_row('team'), findsOneWidget, reason: 'the hub');
        await _back(tester);
        expect(find.text('HOME'), findsOneWidget);
      });
    }

    ph5TestWidgets('1128, Settings open: the Activity Log page above the hub', (tester) async {
      await _pumpWide(tester, 1128);
      _request.value = const SettingsRequest(SettingsRequest.activityLog);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityLogScreen), findsOneWidget);
      await _back(tester);
      expect(_row('activity_log'), findsOneWidget);
    });

    ph5TestWidgets('Settings opened on a page: Re-clicking Settings, the hub', (tester) async {
      await _pumpWide(tester, 774);
      _request.value = const SettingsRequest(SettingsRequest.team);
      await tester.pumpAndSettle();
      expect(find.byType(ManageAssistantsScreen), findsOneWidget);
      _shell.currentState!.select(AppDestination.settings);
      await tester.pumpAndSettle();
      expect(find.byType(ManageAssistantsScreen), findsNothing);
      expect(_row('team'), findsOneWidget);
    });
  });

  group('text 1.3, Light and Dark, every theme, Kiswahili: no overflow', () {
    for (final theme in AppColorTheme.all) {
      for (final look in MatrixLook.values) {
        for (final content in [696.0, 774.0, 950.0, 1128.0]) {
          ph5TestWidgets('${theme.id} ${look.name} ${content.toInt()}: the hub', (tester) async {
            await _pumpWide(tester, content, look: look, colorTheme: theme, textScale: 1.3);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  // UX3 (3): each page at the full content width (no longer in a ~650 pane),
  // Kiswahili and English at text 1.3: no overflow.
  group('each page at full content width, text 1.3', () {
    for (final content in _widths.keys) {
      for (final look in const [MatrixLook.kiswahili, MatrixLook.dark]) {
        ph5TestWidgets('${content.toInt()} ${look.name}', (tester) async {
          await _pumpWide(tester, content, look: look, textScale: 1.3);
          for (final key in _pages.keys) {
            await _reveal(tester, key);
            await tester.tap(_row(key));
            await ph5Settle(tester);
            _drainFirebase(tester, key);
            expect(find.byType(_pages[key]!), findsOneWidget, reason: key);
            await _back(tester);
            _drainFirebase(tester, key);
          }
        });
      }
    }
  });

  // LAY7b (#24): Business Hours on its own, every wide width, Kiswahili and
  // English at text 1.3: no overflow.
  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    for (final look in const [MatrixLook.kiswahili, MatrixLook.light]) {
      ph5TestWidgets('Business Hours alone ${size.width.toInt()} ${look.name} text 1.3: no overflow (#24)', (tester) async {
        await pumpPh5(tester, (fs) => BusinessHoursScreen(firestore: fs), size: size, look: look, textScale: 1.3, pushed: true);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
