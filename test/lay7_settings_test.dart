// LAY7 (owner, 2026-11-18): on PC and tablet Settings gains a Business group
// (Business Profile, Business Hours, View Facilities, Team Members, Activity
// Log; admins, a Co-admin included). From 900 of the content they are panes
// with no back arrow (#23); below, list rows pushed inside the content. The
// phone list is unchanged. Back goes to the previous pane, then Home. Other
// places ask Settings for an item (SettingsRequest).
// The real SettingsScreen inside AppShell, as lay4_shell_screens_test.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_profile_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _shell = GlobalKey<AppShellState>();
final _request = ValueNotifier<SettingsRequest?>(null);

enum _Role { admin, coAdmin, assistant }

/// The content widths of the block: (window, sidebar).
final _widths = <double, (Size, double)>{
  696: (Size(768, 1024), 72),
  774: (Size(1024, 768), 250),
  950: (Size(1024, 768), 72),
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

Future<void> _pumpWide(WidgetTester tester, double content, {_Role role = _Role.admin, MatrixLook look = MatrixLook.light, AppColorTheme colorTheme = AppColorTheme.pasture, double textScale = 1}) async {
  final (size, sidebar) = _widths[content]!;
  _request.value = null;
  await pumpPh5(tester, (fs) => _harness(fs, sidebar),
      size: size, admin: role != _Role.assistant, seed: (fs) => _seed(fs, role), look: look, colorTheme: colorTheme, textScale: textScale);
  _shell.currentState!.select(AppDestination.settings);
  await tester.pumpAndSettle();
}

List<String> _business(AppLocalizations l) =>
    [l.profile_title, l.hours_title, l.dashboard_viewFacilities, l.team_title, l.export_activityLog];

/// The visible texts of Settings, top to bottom.
List<String> _texts(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Text)).evaluate())
        if ((e.widget as Text).data != null) (e.widget as Text).data!,
    ];

Future<void> _tapItem(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(SettingsScreen), matching: find.text(label)).first);
  await tester.pumpAndSettle();
}

void _noBack(String why) => expect(find.byType(BackButton), findsNothing, reason: why);

void main() {
  group('the list per role and content width', () {
    for (final role in _Role.values) {
      for (final content in _widths.keys) {
        ph5TestWidgets('${role.name} at content ${content.toInt()}', (tester) async {
          await _pumpWide(tester, content, role: role);
          // An assistant's first pane is Notifications, which reads the app's own
          // Firebase (no seam in the fake harness): its error is expected here.
          if (role == _Role.assistant && content >= 900) tester.takeException();
          expect(tester.takeException(), isNull);
          final texts = _texts(tester);
          final business = _business(_en);
          if (role == _Role.assistant) {
            for (final b in business) {
              expect(texts, isNot(contains(b)), reason: 'admin-only: $b');
            }
            expect(texts, isNot(contains(_en.expenseGroup_business.toUpperCase())));
            return;
          }
          final group = texts.indexOf(_en.expenseGroup_business.toUpperCase());
          expect(group, isNonNegative, reason: 'the Business group');
          // In this order, right under the group title, before Account & Data.
          final at = [for (final b in business) texts.indexOf(b)];
          expect(at, orderedEquals([...at]..sort()));
          expect(at.first, greaterThan(group));
          expect(at.last, lessThan(texts.indexOf(_en.settings_accountData.toUpperCase())));
          expect(texts.where((t) => t == _en.hours_title), hasLength(1), reason: 'Business Hours once');
        });
      }
    }

    for (final admin in [true, false]) {
      ph5TestWidgets('phone, ${admin ? 'admin' : 'assistant'}: unchanged (Business Hours in Account & Data, no Business group)', (tester) async {
        await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), admin: admin, pushed: true);
        final texts = _texts(tester);
        expect(texts, isNot(contains(_en.expenseGroup_business.toUpperCase())));
        for (final b in [_en.profile_title, _en.dashboard_viewFacilities, _en.team_title, _en.export_activityLog]) {
          expect(texts, isNot(contains(b)));
        }
        expect(texts.contains(_en.hours_title), admin);
        if (admin) expect(texts.indexOf(_en.hours_title), greaterThan(texts.indexOf(_en.settings_accountData.toUpperCase())));
      });
    }
  });

  group('the panes (content 950 and 1128)', () {
    for (final content in [950.0, 1128.0]) {
      for (final role in [_Role.admin, _Role.coAdmin]) {
        ph5TestWidgets('${role.name} ${content.toInt()}: each opens inside Settings with no back arrow', (tester) async {
          await _pumpWide(tester, content, role: role);
          _noBack('the default pane');
          for (final (label, type) in [
            (_en.profile_title, BusinessProfileScreen),
            (_en.hours_title, BusinessHoursScreen),
            (_en.dashboard_viewFacilities, FacilityScreen),
            (_en.team_title, ManageAssistantsScreen),
            (_en.export_activityLog, ActivityLogScreen),
          ]) {
            await _tapItem(tester, label);
            expect(tester.takeException(), isNull, reason: label);
            expect(find.descendant(of: find.byType(SettingsScreen), matching: find.byType(type)), findsOneWidget, reason: label);
            expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
            _noBack(label);
          }
        });
      }
    }

    // The invite dialog itself reads InviteCodeService (no test seam; not added
    // in LAY7): checked by the owner. Here: its button is in the pane.
    ph5TestWidgets('Team: the list shows and the Invite button is in the pane', (tester) async {
      await _pumpWide(tester, 1128);
      await _tapItem(tester, _en.team_title);
      expect(find.text('Neema Active'), findsWidgets);
      final invite = find.descendant(of: find.byType(ManageAssistantsScreen), matching: find.text(_en.team_inviteAssistant));
      expect(invite, findsOneWidget);
    });

    ph5TestWidgets('Team: a member opens as the sheet (the pane is under 1100)', (tester) async {
      await _pumpWide(tester, 1128);
      await _tapItem(tester, _en.team_title);
      await tester.tap(find.text('Neema Active').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'never selected with nothing shown');
    });
  });

  group('the tablet list (content 696 and 774)', () {
    for (final content in [696.0, 774.0]) {
      ph5TestWidgets('${content.toInt()}: Team Members pushes inside the content; Back returns to the list', (tester) async {
        await _pumpWide(tester, content);
        await _tapItem(tester, _en.team_title);
        expect(find.byType(ManageAssistantsScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget, reason: 'a pushed screen keeps its arrow');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ManageAssistantsScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    }
  });

  ph5TestWidgets('Back at 1128: the previous pane, then Home', (tester) async {
    await _pumpWide(tester, 1128);
    await _tapItem(tester, _en.team_title);
    await _tapItem(tester, _en.dashboard_viewFacilities);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ManageAssistantsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  group('a request lands on the right item', () {
    ph5TestWidgets('1128, from Home: Team on Pending, Settings selected; Back goes Home', (tester) async {
      await _pumpWide(tester, 1128);
      _shell.currentState!.select(AppDestination.home);
      await tester.pumpAndSettle();
      _shell.currentState!.select(AppDestination.settings);
      _request.value = const SettingsRequest(SettingsRequest.team, teamStatus: 'pending');
      await tester.pumpAndSettle();
      final team = tester.widget<ManageAssistantsScreen>(find.byType(ManageAssistantsScreen));
      expect(team.initialStatus, 'pending');
      expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
      expect(_request.value, isNull, reason: 'consumed once');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    ph5TestWidgets('1128, Settings open: the Activity Log pane', (tester) async {
      await _pumpWide(tester, 1128);
      _request.value = const SettingsRequest(SettingsRequest.activityLog);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityLogScreen), findsOneWidget);
      _noBack('a pane');
    });

    ph5TestWidgets('774: pushed inside the content over the list', (tester) async {
      await _pumpWide(tester, 774);
      _request.value = const SettingsRequest(SettingsRequest.team);
      await tester.pumpAndSettle();
      expect(find.byType(ManageAssistantsScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('text 1.3, Light and Dark, every theme, Kiswahili: no overflow', () {
    for (final theme in AppColorTheme.all) {
      for (final look in MatrixLook.values) {
        for (final content in [774.0, 1128.0]) {
          ph5TestWidgets('${theme.id} ${look.name} ${content.toInt()}', (tester) async {
            await _pumpWide(tester, content, look: look, colorTheme: theme, textScale: 1.3);
            expect(tester.takeException(), isNull, reason: 'the list');
            if (content < 900) return;
            final l = lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'));
            for (final label in _business(l)) {
              await _tapItem(tester, label);
              // LAY7b: Business Hours included (defect #24 fixed).
              expect(tester.takeException(), isNull, reason: label);
            }
          });
        }
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
