// PH8b (1) Team Members on phones (docs/design/phone_list_pattern.md, the
// PH5a list): a pushed list with a back arrow, Invite floating, search, the
// status chips (and a Filter sheet for the facility), rows with a 40 px
// avatar, the name and role chip, the email or phone and the status chip, no
// buttons in rows; the details as a full page with today's actions through
// today's confirmations (sheets on a phone), the C2 warning; pull to
// refresh; six skeleton rows; the empty, error and no-members states. The
// people shown and the actions allowed are today's, Co-admin rules included.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/services/membership_service.dart';
import 'package:vetbiz_pro/widgets/initials_avatar.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// True until Team Members has its phone list.
const _skip = true;

final _en = lookupAppLocalizations(const Locale('en'));
const _everyone = ['user1', ph8bCoAdminId, 'a1', 'a2', 'a3', 'a4', 'x1'];

Future<Ph5App> _pump(WidgetTester tester,
    {Size size = const Size(390, 844),
    MatrixLook look = MatrixLook.light,
    String uid = testUserId,
    FakeMembership? membership,
    Future<void> Function(FirebaseFirestore fs)? seed,
    FirebaseFirestore? screenFirestore,
    bool settle = true}) {
  return pumpPh5(
    tester,
    (fs) => ph8bTeamScreen(screenFirestore ?? fs, uid: uid, membership: membership),
    size: size,
    look: look,
    pushed: true,
    seed: seed ?? ph8bSeedTeam,
    settle: settle,
  );
}

Finder _row(String id) => find.byKey(ValueKey('phoneList-row-$id'));

/// The ids of the rows the phone list shows.
List<String> _phoneIds() => [for (final id in _everyone) if (_row(id).evaluate().isNotEmpty) id];

/// The ids of the rows today's table shows (a tall window builds them all).
List<String> _tableIds() => [for (final id in _everyone) if (find.byKey(ValueKey(id)).evaluate().isNotEmpty) id];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await _settle(tester);
}

/// The labels of the buttons under [root].
Set<String> _buttons(Finder root) => {
      for (final b in find.descendant(of: root, matching: find.byType(OutlinedButton)).evaluate())
        for (final t in find.descendant(of: find.byWidget(b.widget), matching: find.byType(Text)).evaluate())
          (t.widget as Text).data ?? '',
    };

Finder get _page => find.byKey(const ValueKey('team-details'));

Future<void> _openDetails(WidgetTester tester, String id) => _tap(tester, _row(id));

void main() {
  ph5TestWidgets('a pushed list: back arrow, title only, search, Invite floating, the status chips', (tester) async {
    await _pump(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text(_en.team_subtitle), findsNothing);
    expect(find.byTooltip(_en.common_search), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('phoneList-fab')), matching: find.text(_en.team_inviteAssistant)),
        findsOneWidget);
    for (final chip in [_en.common_all, 'Pending', 'Active', 'Deactivated']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    // Today's cards, buttons in rows and pager are gone on a phone.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text(_en.team_acrossFacilities), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('rows: a 40 px avatar, the name and role chip, the email or phone and the status chip', (tester) async {
    await _pump(tester);
    final row = _row('a2');
    expect(row, findsOneWidget);
    final avatar = find.descendant(of: row, matching: find.byType(InitialsAvatar));
    expect(tester.getSize(avatar), const Size(40, 40));
    expect(find.descendant(of: row, matching: find.text('Neema Active')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Assistant')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('a2@kilimo.co.tz')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Active')), findsOneWidget);
    expect(find.descendant(of: _row(ph8bCoAdminId), matching: find.text('Co-admin')), findsOneWidget);
    // Not a team member, never listed.
    expect(_row('x1'), findsNothing);
    expect(find.descendant(of: find.byType(RecordTile), matching: find.byType(ButtonStyleButton)), findsNothing);
  }, skip: _skip);

  group('the chips, the facility filter and search equal the tablet\'s on the same data', () {
    final cases = <(String, Future<void> Function(WidgetTester) phone, Future<void> Function(WidgetTester) table)>[
      ('All', (t) async {}, (t) async {}),
      for (final (chip, card) in [('Pending', 'Waiting Approval'), ('Active', 'Active'), ('Deactivated', 'Deactivated')])
        (chip, (t) => _tap(t, find.widgetWithText(ChoiceChip, chip)), (t) => _tap(t, find.text(card).first)),
      (
        'facility Mifugo Clinic',
        (t) async {
          await _tap(t, find.byTooltip(_en.facilityPicker_filter));
          await _tap(t, find.text('Mifugo Clinic').last);
          await _tap(t, find.text(_en.common_apply));
        },
        (t) async {
          await _tap(t, find.text(_en.common_filterValue(_en.common_facility, _en.common_all)));
          await _tap(t, find.text(_en.common_filterValue(_en.common_facility, 'Mifugo Clinic')).last);
        },
      ),
      (
        'search "clinic"',
        (t) async {
          await _tap(t, find.byTooltip(_en.common_search));
          await t.enterText(find.byKey(const ValueKey('phoneList-searchField')), 'clinic');
          await _settle(t);
        },
        (t) async {
          await t.enterText(find.byType(TextField).first, 'clinic');
          await _settle(t);
        },
      ),
    ];
    for (final (name, phone, table) in cases) {
      ph5TestWidgets(name, (tester) async {
        await _pump(tester, size: const Size(1200, 2000));
        await table(tester);
        final expected = _tableIds();
        await _pump(tester);
        await phone(tester);
        expect(_phoneIds(), expected);
      }, skip: _skip);
    }
  });

  group('the details page offers exactly today\'s actions', () {
    for (final (viewer, uid) in [('the owner', testUserId), ('a Co-admin', ph8bCoAdminId)]) {
      ph5TestWidgets('as $viewer', (tester) async {
        await _pump(tester, uid: uid, size: const Size(1200, 2000));
        final today = {for (final id in _tableIds()) id: _buttons(find.byKey(ValueKey(id)))};
        await _pump(tester, uid: uid);
        expect(_phoneIds(), today.keys.toList());
        for (final id in today.keys) {
          await _openDetails(tester, id);
          expect(_page, findsOneWidget, reason: id);
          expect(_buttons(_page), today[id], reason: '$viewer, $id');
          await tester.pageBack();
          await _settle(tester);
        }
      }, skip: _skip);
    }

    ph5TestWidgets('a Co-admin cannot deactivate another Co-admin; the owner can', (tester) async {
      await _pump(tester, uid: ph8bCoAdminId);
      await _openDetails(tester, testUserId);
      expect(find.descendant(of: _page, matching: find.text(_en.team_facilityAdmin)), findsOneWidget);
      expect(_buttons(_page), isEmpty);
      await tester.pageBack();
      await _settle(tester);
      await _pump(tester);
      await _openDetails(tester, ph8bCoAdminId);
      expect(_buttons(_page), {_en.team_deactivate});
    }, skip: _skip);
  });

  group('the actions do what they do today, through sheets on a phone', () {
    ph5TestWidgets('Approve and Reactivate go to the server', (tester) async {
      final server = FakeMembership();
      await _pump(tester, membership: server);
      await _openDetails(tester, 'a1');
      await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_approve)));
      await tester.pageBack();
      await _settle(tester);
      await _openDetails(tester, 'a3');
      await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_reactivate)));
      expect(server.calls, ['status a1 approve', 'status a3 reactivate']);
    }, skip: _skip);

    for (final failed in [false, true]) {
      ph5TestWidgets('Deactivate: ${failed ? 'the C2 warning when the sign-in could not be switched off' : 'done'}',
          (tester) async {
        final server = FakeMembership()..signIn = failed ? MembershipService.signInFailed : '';
        await _pump(tester, membership: server);
        await _openDetails(tester, 'a2');
        await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_deactivate)));
        expect(server.calls, ['status a2 deactivate']);
        expect(find.text(_en.team_signInSwitchFailed), failed ? findsOneWidget : findsNothing);
        expect(find.text(_en.team_actionDone('Neema Active', 'deactivated')), failed ? findsNothing : findsOneWidget);
      }, skip: _skip);
    }

    ph5TestWidgets('Reject asks in a sheet, then goes to the server', (tester) async {
      final server = FakeMembership();
      await _pump(tester, membership: server);
      await _openDetails(tester, 'a1');
      await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_reject)));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(_en.team_rejectTitle('Juma Pending')), findsOneWidget);
      await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text(_en.team_reject)));
      expect(server.calls, ['status a1 reject']);
    }, skip: _skip);

    for (final failed in [false, true]) {
      ph5TestWidgets('Remove from Facility asks in a sheet${failed ? ', then the C2 warning' : ''}', (tester) async {
        final server = FakeMembership()..signIn = failed ? MembershipService.signInFailed : '';
        await _pump(tester, membership: server);
        await _openDetails(tester, 'a3');
        await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_removeFromFacility)));
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text(_en.team_removeTitle('Baraka Paused', 'Kilimo Agrovet')), findsOneWidget);
        await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text(_en.team_removeFromFacilityConfirm)));
        expect(server.calls, ['remove a3 $testFacilityId']);
        expect(find.text(_en.team_signInSwitchFailed), failed ? findsOneWidget : findsNothing);
        expect(find.text(_en.team_removed), failed ? findsNothing : findsOneWidget);
      }, skip: _skip);
    }

    ph5TestWidgets('Reassign picks the other facility in a sheet', (tester) async {
      final server = FakeMembership();
      await _pump(tester, membership: server);
      await _openDetails(tester, 'a2');
      await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_reassign)));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(_en.team_moveTitle('Neema Active')), findsOneWidget);
      await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Mifugo Clinic')));
      expect(server.calls, ['reassign a2 $ph8bSecondFacilityId']);
    }, skip: _skip);

    ph5TestWidgets('the owner deactivates a Co-admin after the 340 px question, now a sheet: the same write and log',
        (tester) async {
      final app = await _pump(tester);
      await _openDetails(tester, ph8bCoAdminId);
      await _tap(tester, find.descendant(of: _page, matching: find.text(_en.team_deactivate)));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(_en.team_deactivateTitle('Zawadi Co-admin')), findsOneWidget);
      await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text(_en.team_deactivate)));
      final user = (await tester.runAsync(() => app.fs.collection(Collections.users).doc(ph8bCoAdminId).get()))!.data()!;
      expect(user['status'], 'deactivated');
      expect(user['statusChangedBy'], '$testUserId@kilimo.co.tz');
      expect(user['statusChangedByRole'], 'Facility Admin');
      final log = (await tester.runAsync(() => facilityCollection(app.fs, Collections.activityLogs).get()))!.docs;
      expect(log.map((d) => d.data()['description']), ['Deactivated co-admin Zawadi Co-admin']);
      expect(log.single.data()['targetUserId'], ph8bCoAdminId);
    }, skip: _skip);

    ph5TestWidgets('Invite with two facilities asks which one in a sheet; a second tap opens nothing more', (tester) async {
      await _pump(tester);
      final fab = find.byKey(const ValueKey('phoneList-fab'));
      await tester.tap(fab);
      await tester.tap(fab, warnIfMissed: false);
      await _settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(_en.team_inviteTo), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Mifugo Clinic')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Kilimo Agrovet')), findsOneWidget);
    }, skip: _skip);
  });

  group('states', () {
    ph5TestWidgets('six skeleton rows until the team has loaded', (tester) async {
      await _pump(tester, settle: false);
      expect(find.byKey(const ValueKey('phoneList-skeleton')), findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('just you: your row, then today\'s hint with Invite', (tester) async {
      await _pump(tester, seed: (fs) async {
        await ph8bSeedTeam(fs, twoFacilities: false);
        for (final id in [ph8bCoAdminId, 'a1', 'a2', 'a3', 'x1']) {
          await fs.collection(Collections.users).doc(id).delete();
        }
      });
      expect(_phoneIds(), [testUserId]);
      expect(find.text(_en.team_noAssistants), findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('no facilities: today\'s sentence', (tester) async {
      await _pump(tester, seed: (fs) async {});
      expect(find.text(_en.team_noFacilities), findsOneWidget);
    }, skip: _skip);

    ph5TestWidgets('no matches: today\'s sentence and Reset filters', (tester) async {
      await _pump(tester);
      await _tap(tester, find.byTooltip(_en.common_search));
      await tester.enterText(find.byKey(const ValueKey('phoneList-searchField')), 'nobody at all');
      await _settle(tester);
      expect(find.text(_en.team_noMatches), findsOneWidget);
      await _tap(tester, find.text(_en.common_resetFilters));
      expect(_phoneIds(), isNotEmpty);
    }, skip: _skip);

    ph5TestWidgets('pull to refresh reads the facilities again (the old Refresh button)', (tester) async {
      final app = await _pump(tester);
      expect(_row('a5'), findsNothing);
      await tester.runAsync(() async {
        await app.fs.collection(Collections.facilities).doc('facility3').set({'name': 'Shamba Hub', 'createdBy': testUserId});
        await app.fs.collection(Collections.users).doc('a5').set(
            {'fullName': 'Halima New', 'role': 'assistant', 'status': 'pending', 'facilityIds': ['facility3']});
      });
      await _settle(tester);
      await tester.fling(find.byKey(const ValueKey('phoneList-scroll')), const Offset(0, 400), 1000);
      await _settle(tester);
      expect(find.descendant(of: find.byType(RecordTile), matching: find.text('Halima New')), findsOneWidget);
    }, skip: _skip);
  });

  for (final size in ph5PhoneSizes) {
    for (final look in MatrixLook.values) {
      final where = 'Team Members ${size.label} ${look.name}';
      ph5TestWidgets('$where, very long names: the list, a details page and a sheet; no overflow, 48 px, 12 px',
          (tester) async {
        await _pump(tester, size: size.size, look: look, seed: (fs) => ph8bSeedTeam(fs, longNames: true));
        await checkCase(tester, phone: true, where: where);
        await _openDetails(tester, 'a1');
        await checkCase(tester, phone: true, where: '$where details');
        final reject = lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en')).team_reject;
        await _tap(tester, find.descendant(of: _page, matching: find.text(reject)));
        await checkCase(tester, phone: true, where: '$where sheet');
      }, skip: _skip);
    }
  }
}
