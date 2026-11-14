// HUB4b (1): the phone's full-screen profile page, in place of the end
// drawer. Every item of the old phone drawer, with the same role gates, is on
// the page (one list, profileActionsFor, feeds both); the Current facility
// card opens Switch facility only for two or more facilities; Back returns to
// Home as it was; 48 px targets and no overflow at 360x740, 390x844 and
// 740x360 in Light, Dark and Kiswahili, with very long names.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/models/facility_entry.dart';
import 'package:vetbiz_pro/screens/dashboard/profile_actions.dart';
import 'package:vetbiz_pro/widgets/profile/profile_drawer.dart';
import 'package:vetbiz_pro/widgets/profile/profile_page.dart';

import 'helpers/screen_size_matrix.dart';

const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));

/// The old phone drawer's rows (before HUB4b), in order, per role.
List<String> _oldDrawer({required bool admin}) => [
      _en.common_editProfile,
      if (admin) ...[_en.team_title, _en.dashboard_viewFacilities],
      _en.dashboard_changePassword,
      if (admin) _en.export_activityLog,
      _en.settings_title,
      _en.dashboard_help,
      _en.common_logout,
    ];

/// The handlers, each recording its own name when tapped.
ProfileHandlers _handlers(List<String> tapped) => ProfileHandlers(
      editProfile: () => tapped.add('editProfile'),
      team: () => tapped.add('team'),
      facilities: () => tapped.add('facilities'),
      changePassword: () => tapped.add('changePassword'),
      activityLog: () => tapped.add('activityLog'),
      settings: () => tapped.add('settings'),
      help: () => tapped.add('help'),
      signOut: () => tapped.add('signOut'),
    );

const _two = [
  FacilityEntry(id: 'fa', name: matrixLongFacilityName, type: 'Agrovet'),
  FacilityEntry(id: 'fb', name: 'Kliniki ya Mifugo Arusha', type: 'Vet Clinic'),
];

Widget _page(
  AppLocalizations l10n, {
  required bool admin,
  List<String>? tapped,
  VoidCallback? onSwitch,
  String role = 'Admin',
}) =>
    ProfilePage(
      avatarUrl: null,
      name: matrixLongClientName,
      roleLabel: role,
      email: 'mwanaisha.abdallah.mohamedi@kijiji-cha-mwembeni-juu.co.tz',
      phone: '+255 712 345 678',
      facility: matrixLongFacilityName,
      facilityType: 'Agrovet',
      actions: profileActionsFor(l10n, isAdmin: admin, on: _handlers(tapped ?? [])),
      onSwitchFacility: onSwitch,
    );

/// Home stand-in: a counter kept in its state, and the avatar pushing the page.
class _Home extends StatefulWidget {
  final WidgetBuilder page;
  const _Home({required this.page});
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text('home $count'),
          TextButton(onPressed: () => setState(() => count++), child: const Text('plus')),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: widget.page)),
            child: const Text('avatar'),
          ),
        ]),
      );
}

const _matrix = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

void main() {
  group('every old drawer item, with the same gates', () {
    for (final (who, admin) in [('admin', true), ('Co-admin (role admin)', true), ('assistant', false)]) {
      testWidgets('$who: the page holds exactly the old drawer\'s items, and each runs its own action', (tester) async {
        final tapped = <String>[];
        final actions = profileActionsFor(_en, isAdmin: admin, on: _handlers(tapped));
        expect(actions.map((a) => a.label), _oldDrawer(admin: admin), reason: 'the drawer\'s list is unchanged');
        expect(actions.every((a) => a.item != null), isTrue);

        await pumpAtSize(tester, screen: _page(_en, admin: admin, tapped: tapped), size: const Size(390, 844));
        for (final action in actions) {
          final finder = find.text(action.label);
          await tester.scrollUntilVisible(finder, 100, scrollable: find.byType(Scrollable).first);
          expect(finder, findsOneWidget, reason: '${action.label} on the page');
          await tester.tap(finder);
          await tester.pump();
        }
        expect(tapped, [for (final a in actions) a.item!.name], reason: 'every row runs its own action');
        if (!admin) {
          expect(find.byKey(const ValueKey('profile-group-business')), findsNothing, reason: 'no empty Business group');
        }
      }, skip: _skip);
    }

    test('the groups: Account, Business, App; Sign out is the button, not a row', () {
      final sections = profilePageSections(profileActionsFor(_en, isAdmin: true, on: _handlers([])));
      expect([for (final s in sections) s.group], ProfileGroup.values);
      expect([for (final s in sections) s.actions.map((a) => a.item).toList()], [
        [ProfileItem.editProfile, ProfileItem.changePassword],
        [ProfileItem.team, ProfileItem.facilities, ProfileItem.activityLog],
        [ProfileItem.settings, ProfileItem.help],
      ]);
    }, skip: _skip);

    test('an action with no known place is kept, at the end of App', () {
      const extra = ProfileDrawerAction(icon: Icons.star, label: 'Extra', onTap: _noop);
      final sections = profilePageSections([extra]);
      expect(sections.single.group, ProfileGroup.app);
      expect(sections.single.actions, [extra]);
    }, skip: _skip);

    testWidgets('Sign out is a red text button at the bottom, through the drawer\'s own sign-out', (tester) async {
      final tapped = <String>[];
      await pumpAtSize(tester, screen: _page(_en, admin: true, tapped: tapped), size: const Size(390, 844));
      final button = find.byKey(const ValueKey('profile-sign-out'));
      await tester.scrollUntilVisible(button, 100, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: button, matching: find.text(_en.common_logout)), findsOneWidget);
      await tester.tap(button);
      expect(tapped, ['signOut']);
    }, skip: _skip);
  });

  group('the Current facility card and Switch facility', () {
    testWidgets('one facility: a label with the type tag, no tap, no chevron', (tester) async {
      await pumpAtSize(tester, screen: _page(_en, admin: true), size: const Size(390, 844));
      final card = find.byKey(const ValueKey('profile-facility-card'));
      expect(find.descendant(of: card, matching: find.text(_en.profile_currentFacility)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(matrixLongFacilityName)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)), findsNothing);
      expect(tester.widget<InkWell>(find.descendant(of: card, matching: find.byType(InkWell))).onTap, isNull);
    }, skip: _skip);

    testWidgets('two facilities: the card opens the sheet; a check on the current one; a tap on the other picks it',
        (tester) async {
      final picked = <String?>[];
      late BuildContext pageContext;
      await pumpAtSize(
        tester,
        screen: Builder(builder: (context) {
          pageContext = context;
          return _page(_en, admin: true, onSwitch: () {
            showSwitchFacilitySheet(pageContext, facilities: _two, currentId: 'fa', onPick: (f) => picked.add(f.id));
          });
        }),
        size: const Size(390, 844),
      );
      final card = find.byKey(const ValueKey('profile-facility-card'));
      expect(find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(_en.profile_switchFacility), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('switch-facility-fa')), matching: find.byIcon(Icons.check)),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('switch-facility-fb')), matching: find.byIcon(Icons.check)),
          findsNothing);
      expect(find.text('Vet Clinic'), findsOneWidget, reason: 'the type tag');

      await tester.tap(find.byKey(const ValueKey('switch-facility-fa')));
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'the current one only closes the sheet');
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('switch-facility-fb')));
      await tester.pumpAndSettle();
      expect(picked, ['fb']);
      expect(find.text(_en.profile_switchFacility), findsNothing, reason: 'the sheet closed');
    }, skip: _skip);
  });

  testWidgets('Back returns to the same Home, its state kept', (tester) async {
    await pumpAtSize(tester, screen: _Home(page: (_) => _page(_en, admin: true)), size: const Size(390, 844));
    await tester.tap(find.text('plus'));
    await tester.pump();
    await tester.tap(find.text('avatar'));
    await tester.pumpAndSettle();
    expect(find.text(_en.profile_pageTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget, reason: 'the back icon at the left of the app bar');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('home 1'), findsOneWidget);
  }, skip: _skip);

  group('the size matrix (very long names; 48 px targets; no overflow)', () {
    for (final s in _matrix) {
      for (final look in MatrixLook.values) {
        for (final admin in [true, false]) {
          testWidgets('${matrixCase(s, look)} ${admin ? 'admin' : 'assistant'}: the page and the sheet', (tester) async {
            final l10n = lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'));
            late BuildContext pageContext;
            await pumpAtSize(
              tester,
              screen: Builder(builder: (context) {
                pageContext = context;
                return _page(l10n, admin: admin, onSwitch: () {
                  showSwitchFacilitySheet(pageContext, facilities: _two, currentId: 'fa', onPick: (_) {});
                });
              }),
              size: s.size,
              look: look,
            );
            await checkCase(tester, phone: true, where: '${matrixCase(s, look)} page');
            final card = find.byKey(const ValueKey('profile-facility-card'));
            await tester.scrollUntilVisible(card, 100, scrollable: find.byType(Scrollable).first);
            await tester.tap(card);
            await tester.pumpAndSettle();
            await checkCase(tester, phone: true, where: '${matrixCase(s, look)} sheet');
          }, skip: _skip);
        }
      }
    }
  });

  group('the dashboard', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    test('the phone avatar pushes the page; the phone hub has no end drawer; wide keeps it', () {
      expect(dash, contains('onAvatar: _openProfilePage,'));
      final phone = dash.substring(dash.indexOf('phone: (_) => PhoneHub('), dash.indexOf('wide: (_) => Scaffold('));
      expect(phone.contains('endDrawer'), isFalse);
      final wide = dash.substring(dash.indexOf('wide: (_) => Scaffold('));
      expect(wide, contains('endDrawer: endDrawer,'));
    }, skip: _skip);

    test('the drawer and the page take the same list; the switch is the picker\'s activation', () {
      expect(RegExp(r'profileActionsFor\(').allMatches(dash).length, 2);
      expect(dash, contains('FacilityEntry.listFrom(data[\'facilities\'])'));
      expect(dash, contains('mine.length < 2'));
      final activation = File('lib/utils/facility_activation.dart').readAsStringSync();
      final switcher = activation.substring(activation.indexOf('Future<void> switchFacilityFromProfile('));
      expect(switcher, contains('activateFacilityAndGoToDashboard(context: context, facility: facility.toMap(), role: role)'));
    }, skip: _skip);

    test('the page adds no listener or read: the top bar\'s stream, seeded with what it holds', () {
      final open = dash.substring(dash.indexOf('void _openProfilePage()'));
      final body = open.substring(0, open.indexOf('\n  }\n') + 1);
      expect(body, contains('stream: _userDocStream,'));
      expect(body, contains('initialData: _heldUserDoc,'));
      for (final banned in ['.get(', '.snapshots(', 'collection(']) {
        expect(body.contains(banned), isFalse, reason: 'the page builder has $banned');
      }
    }, skip: _skip);
  });
}

void _noop() {}
