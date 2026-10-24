// NOTIF-2b (docs/design/notifications.md, sections 2 and 4, approved): each
// person's own notification state, facilities/{fid}/notificationState/{uid},
// written by NotificationStateService on the fake Firestore with a fake
// clock, in exactly the shape the deployed rule accepts.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/models/notification_state.dart';
import 'package:vetbiz_pro/services/notification_state_service.dart';

// Until the implementation: every call throws UnimplementedError('NOTIF-2b').
const _skipUntilImplemented = true;

final now0 = DateTime(2026, 10, 24, 10);

class FakeClock {
  DateTime now = now0;
  DateTime call() => now;
}

DocumentReference<Map<String, dynamic>> stateDoc(FirebaseFirestore fs, String uid) =>
    fs.doc('facilities/F1/notificationState/$uid');

NotificationStateService serviceFor(FirebaseFirestore fs, String uid, FakeClock clock) =>
    NotificationStateService(firestore: fs, facilityId: 'F1', uid: uid, clock: clock.call);

Future<NotificationState> stateOf(FirebaseFirestore fs, String uid) async =>
    NotificationState.fromMap((await stateDoc(fs, uid).get()).data());

List<String> ids(int n, [String prefix = 'n']) => [for (var i = 1; i <= n; i++) '$prefix$i'];

/// The keys firestore.rules accepts on a state document, read from the rule.
Set<String> ruleKeys() {
  final rules = File('firestore.rules').readAsStringSync();
  final m = RegExp(r"function isValidNotificationState\(data\) \{\s*return data\.keys\(\)\.hasOnly\(\[([^\]]*)\]\)")
      .firstMatch(rules);
  expect(m, isNotNull, reason: 'isValidNotificationState is missing from firestore.rules');
  return RegExp(r"'(\w+)'").allMatches(m!.group(1)!).map((x) => x.group(1)!).toSet();
}

/// What the rule checks on the stored result of every write.
Future<void> expectRuleShape(FirebaseFirestore fs, String uid) async {
  final data = (await stateDoc(fs, uid).get()).data()!;
  expect(ruleKeys().containsAll(data.keys), isTrue, reason: 'keys ${data.keys}');
  for (final key in ['read', 'unread', 'removed', 'seenStage']) {
    if (!data.containsKey(key)) continue;
    expect(data[key], isA<Map>(), reason: key);
    expect((data[key] as Map).length, lessThanOrEqualTo(AppLimits.notificationStateMapMax), reason: key);
  }
  expect(data['updatedAt'], isA<Timestamp>());
}

void main() {
  test('the service\'s limit is the rule\'s, and the rule names the five keys', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(RegExp(r'size\(\) <= (\d+)').allMatches(rules).map((m) => int.parse(m.group(1)!)).toSet(),
        {AppLimits.notificationStateMapMax});
    expect(ruleKeys(), {'read', 'unread', 'removed', 'seenStage', 'updatedAt'});
  });

  group('NotificationStateService', () {
    late FakeFirebaseFirestore fs;
    late FakeClock clock;
    setUp(() {
      fs = FakeFirebaseFirestore();
      clock = FakeClock();
    });

    test('read, unread, seenStage: one person, in the rule\'s shape', () async {
      final me = serviceFor(fs, 'owner', clock);
      expect((await me.watch().first).read, isEmpty, reason: 'no document yet: the empty state');
      await me.markRead(['n1', 'n2']);
      await expectRuleShape(fs, 'owner');
      var s = await stateOf(fs, 'owner');
      expect(s.read, {'n1': now0, 'n2': now0});
      clock.now = now0.add(const Duration(hours: 1));
      await me.markUnread(['n2']);
      s = await stateOf(fs, 'owner');
      expect(s.read.keys, ['n1']);
      expect(s.unread.keys, ['n2']);
      expect(s.isReadByMe('n2', sharedReadAt: now0), isFalse, reason: 'unread by me over a shared readAt');
      await me.markRead(['n2']);
      expect((await stateOf(fs, 'owner')).unread, isEmpty);
      await me.recordSeenStage(NotificationType.subscriptionExpiring, SubscriptionNoticeStage.grace);
      expect((await stateOf(fs, 'owner')).seenStage, {subscriptionNoticeId: 'grace'});
      await expectRuleShape(fs, 'owner');
      expect((await me.watch().first).read.keys.toSet(), {'n1', 'n2'});
    }, skip: _skipUntilImplemented);

    test('per person: A removes and reads; B, from B\'s own state, still sees it, unread', () async {
      final a = serviceFor(fs, 'owner', clock);
      final b = serviceFor(fs, 'coadmin', clock);
      await a.remove(['n1']);
      await a.markRead(['n2']);
      final sa = await stateOf(fs, 'owner');
      final sb = await stateOf(fs, 'coadmin');
      expect((sa.isRemoved('n1'), sa.isReadByMe('n2')), (true, true));
      expect((sb.isRemoved('n1'), sb.isReadByMe('n2')), (false, false));
      expect((await b.watch().first).removed, isEmpty);
    }, skip: _skipUntilImplemented);

    test('a bulk removal of 50 is ONE write; its Undo restores the previous state exactly', () async {
      final me = serviceFor(fs, 'owner', clock);
      final earlier = now0.subtract(const Duration(days: 3));
      await stateDoc(fs, 'owner').set({
        'removed': {'old': Timestamp.fromDate(earlier), 'n7': Timestamp.fromDate(earlier)},
        'read': {'r1': Timestamp.fromDate(earlier)},
        'updatedAt': Timestamp.fromDate(earlier),
      });
      final before = await stateOf(fs, 'owner');
      var writes = 0;
      final sub = stateDoc(fs, 'owner').snapshots().skip(1).listen((_) => writes++);
      final undo = await me.remove(ids(50));
      await pumpEventQueue();
      expect(writes, 1);
      expect((await stateOf(fs, 'owner')).removed.length, 51);
      expect(undo.previous['n7'], earlier, reason: 'already removed: its earlier time');
      expect(undo.previous['n8'], isNull);
      await expectRuleShape(fs, 'owner');
      await me.restoreRemoved(undo);
      await pumpEventQueue();
      expect(writes, 2);
      final after = await stateOf(fs, 'owner');
      expect(after.removed, before.removed);
      expect(after.read, before.read);
      await sub.cancel();
    }, skip: _skipUntilImplemented);

    test('two devices of the same person: both writes survive (merge)', () async {
      final phone = serviceFor(fs, 'owner', clock);
      final laptop = serviceFor(fs, 'owner', FakeClock()..now = now0.add(const Duration(minutes: 5)));
      await phone.markRead(['p1']);
      await laptop.remove(['l1']);
      await phone.remove(['p2']);
      await laptop.markRead(['l2']);
      final s = await stateOf(fs, 'owner');
      expect(s.read.keys.toSet(), {'p1', 'l2'});
      expect(s.removed.keys.toSet(), {'l1', 'p2'});
    }, skip: _skipUntilImplemented);

    test('entries older than 120 days are pruned on the next write (119 kept, 120 and 121 gone)', () async {
      Timestamp ago(int d) => Timestamp.fromDate(now0.subtract(Duration(days: d)));
      await stateDoc(fs, 'owner').set({
        'read': {'d119': ago(119), 'd120': ago(120), 'd121': ago(121)},
        'unread': {'u121': ago(121), 'u10': ago(10)},
        'removed': {'x121': ago(121), 'x1': ago(1)},
        'seenStage': {subscriptionNoticeId: 'grace'},
        'updatedAt': ago(1),
      });
      await serviceFor(fs, 'owner', clock).markRead(['new']);
      final s = await stateOf(fs, 'owner');
      expect(s.read.keys.toSet(), {'d119', 'new'});
      expect(s.unread.keys.toSet(), {'u10'});
      expect(s.removed.keys.toSet(), {'x1'});
      expect(s.seenStage, {subscriptionNoticeId: 'grace'}, reason: 'a stage has no age');
    }, skip: _skipUntilImplemented);

    test('never above 2000 entries: the oldest go first', () async {
      final max = AppLimits.notificationStateMapMax;
      await stateDoc(fs, 'owner').set({
        'removed': {
          for (var i = 1; i <= max; i++) 'n$i': Timestamp.fromDate(now0.subtract(Duration(minutes: max - i + 1))),
        },
        'updatedAt': Timestamp.fromDate(now0),
      });
      await serviceFor(fs, 'owner', clock).remove(['new1', 'new2', 'n5']);
      final s = await stateOf(fs, 'owner');
      expect(s.removed.length, max);
      expect(s.removed.keys, containsAll(['new1', 'new2', 'n5']));
      expect(s.removed.keys, isNot(contains('n1')));
      expect(s.removed.keys, isNot(contains('n2')));
      expect(s.removed.keys, contains('n3'));
      await expectRuleShape(fs, 'owner');
    }, skip: _skipUntilImplemented);
  });
}
