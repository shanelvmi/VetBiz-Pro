// NOTIF-2c (docs/design/notifications.md, sections 3 and 4, approved): the
// controller behind the Notifications screen and the dropdown, on the fake
// Firestore with a fake clock. Per person, lifetimes, escalation by stage,
// "Remove read ones" with Undo, Load older.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/models/notification_state.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';

import 'helpers/notification_harness.dart';

// Was true until the implementation (every call threw UnimplementedError).
const _skip = false;

Future<NotificationFeedController> feed(FirebaseFirestore fs, String uid, Clock clock,
    {Subs? subs, int window = 200, int olderPage = 100, bool admin = true}) async {
  final c = newFeed(fs, uid, clock, subs: subs, window: window, olderPage: olderPage, admin: admin)..start();
  addTearDown(c.dispose);
  await settle();
  return c;
}

List<String> idsOf(NotificationFeedController c) => c.items.map((i) => i.id).toList();
NotificationItem item(NotificationFeedController c, String id) => c.items.firstWhere((i) => i.id == id);

void main() {
  bellTests();
  test('per person: A removing or reading changes nothing in B\'s list', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    await seed(fs, 'n1', 'lowStock');
    await seed(fs, 'n2', 'paymentReceived', createdAt: t0.subtract(const Duration(hours: 1)));
    final a = await feed(fs, 'A', clock);
    final b = await feed(fs, 'B', clock);

    await a.remove([item(a, 'n1')]);
    await a.markRead([item(a, 'n2')]);
    await settle();

    expect(idsOf(a), ['n2']);
    expect(item(a, 'n2').isRead, isTrue);
    expect(idsOf(b), ['n1', 'n2']);
    expect(b.items.every((i) => !i.isRead), isTrue);
    // Nothing shared changed: no readAt on the documents.
    expect((await fs.doc('facilities/F1/notifications/n2').get()).data()!.containsKey('readAt'), isFalse);
  }, skip: _skip);

  test('Mark all as read is per person', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    await seed(fs, 'n1', 'lowStock');
    await seed(fs, 'n2', 'newClient');
    final a = await feed(fs, 'A', clock);
    final b = await feed(fs, 'B', clock);
    await a.markAllRead();
    await settle();
    expect(a.hasUnread, isFalse);
    expect(b.hasUnread, isTrue);
  }, skip: _skip);

  test('lifetimes hide items through the policy (injected clock)', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    await seed(fs, 'read', 'lowStock');
    await seed(fs, 'unread', 'serviceRecorded');
    await seed(fs, 'promo', 'promotion', expiresAt: t0.add(const Duration(days: 10)));
    await seed(fs, 'pending', 'assistantPending', audience: 'admins');
    await seed(fs, 'legacy', 'trialStarted');
    final c = await feed(fs, 'A', clock);
    expect(idsOf(c), isNot(contains('legacy')));
    await c.markRead([item(c, 'read')]);
    await settle();

    clock.now = t0.add(const Duration(days: 29));
    c.refresh();
    expect(idsOf(c), containsAll(['read', 'unread', 'pending']));
    expect(idsOf(c), isNot(contains('promo')), reason: 'the offer ended on day 10');

    clock.now = t0.add(const Duration(days: 30));
    c.refresh();
    expect(idsOf(c), isNot(contains('read')), reason: '30 days after I read it');
    expect(idsOf(c), contains('unread'));

    clock.now = t0.add(const Duration(days: 90));
    c.refresh();
    expect(idsOf(c), ['pending'], reason: 'unread: 90 days; persistent: never by age');
  }, skip: _skip);

  test('an assistant does not see an admins-only notice', () async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'pending', 'assistantPending', audience: 'admins');
    final c = await feed(fs, 'S', Clock(), admin: false);
    expect(c.items, isEmpty);
  }, skip: _skip);

  test('escalation by stage: a new stage is unread again, a new day count is not', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    final subs = Subs()..facts = expiring;
    // The daily function's stored copy: replaced by the live row.
    await seed(fs, subscriptionNoticeId, 'subscriptionExpiring', title: 'stored');
    final c = await feed(fs, 'A', clock, subs: subs);
    expect(c.items.where((i) => i.type == NotificationType.subscriptionExpiring).length, 1);
    final row = item(c, subscriptionNoticeId);
    expect(row.notification.title, 'Subscription Expiring Soon');
    expect(row.isRead, isFalse, reason: 'no longer inserted already read');
    expect(row.canRemove, isFalse);

    await c.markRead([row]);
    await settle();
    expect(item(c, subscriptionNoticeId).isRead, isTrue);

    subs.set(const SubscriptionFacts(
        stage: SubscriptionNoticeStage.expiring, notice: (title: 'Subscription Expiring Soon', message: '6 days left')));
    await settle();
    expect(item(c, subscriptionNoticeId).isRead, isTrue, reason: '7 days then 6 days: still read');

    subs.set(const SubscriptionFacts(
        stage: SubscriptionNoticeStage.grace, notice: (title: 'Subscription Expired', message: 'grace')));
    await settle();
    expect(item(c, subscriptionNoticeId).isRead, isFalse, reason: 'expiring then grace: unread again');

    subs.set(SubscriptionFacts.none);
    await settle();
    expect(idsOf(c), isNot(contains(subscriptionNoticeId)), reason: 'renewed: resolved');
  }, skip: _skip);

  test('a read from an earlier subscription cycle does not count', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    final subs = Subs()..facts = expiring;
    final c = await feed(fs, 'A', clock, subs: subs);
    await c.markRead([item(c, subscriptionNoticeId)]);
    await settle();
    clock.now = t0.add(const Duration(days: 30));
    subs.set(SubscriptionFacts(stage: SubscriptionNoticeStage.expiring, notice: expiring.notice, cycleStart: clock.now));
    await settle();
    expect(item(c, subscriptionNoticeId).isRead, isFalse);
  }, skip: _skip);

  test('Remove read ones: only my read routine and dismissible items; Undo restores exactly', () async {
    final fs = FakeFirebaseFirestore();
    final clock = Clock();
    final subs = Subs()..facts = expiring;
    await seed(fs, 'r1', 'lowStock');
    await seed(fs, 'r2', 'promotion', expiresAt: t0.add(const Duration(days: 5)));
    await seed(fs, 'u1', 'paymentReceived');
    await seed(fs, 'p1', 'assistantPending');
    final c = await feed(fs, 'A', clock, subs: subs);
    await c.markRead([item(c, 'r1'), item(c, 'r2'), item(c, 'p1'), item(c, subscriptionNoticeId)]);
    await settle();
    final before = [for (final i in c.items) '${i.id}:${i.isRead}'];

    expect(c.readRemovable.map((i) => i.id).toSet(), {'r1', 'r2'});
    final entries = await c.remove(c.readRemovable);
    await settle();
    expect(idsOf(c).toSet(), {subscriptionNoticeId, 'u1', 'p1'});

    await c.restore(entries);
    await settle();
    expect([for (final i in c.items) '${i.id}:${i.isRead}'], before);
  }, skip: _skip);

  test('remove skips persistent items', () async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'p1', 'assistantPending');
    await seed(fs, 'rej', 'subscription_rejected');
    final c = await feed(fs, 'A', Clock());
    await c.remove(c.items);
    await settle();
    expect(idsOf(c).toSet(), {'p1', 'rej'});
  }, skip: _skip);

  test('a rejection stays until a newer claim is sent', () async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'rej', 'subscription_rejected');
    final c = await feed(fs, 'A', Clock());
    expect(idsOf(c), ['rej']);
    await fs.collection('facilities/F1/payment_submissions').add(
        {'status': 'pending', 'submittedAt': Timestamp.fromDate(t0.add(const Duration(hours: 1)))});
    await settle();
    expect(c.items, isEmpty);
  }, skip: _skip);

  test('Load older: the window, then 100 at a time, until none are left', () async {
    final fs = FakeFirebaseFirestore();
    for (var i = 1; i <= 7; i++) {
      await seed(fs, 'n$i', 'lowStock', createdAt: t0.subtract(Duration(minutes: i)));
    }
    final c = await feed(fs, 'A', Clock(), window: 3, olderPage: 2);
    expect(idsOf(c), ['n1', 'n2', 'n3']);
    expect(c.canLoadOlder, isTrue);
    await c.loadOlder();
    expect(idsOf(c), ['n1', 'n2', 'n3', 'n4', 'n5']);
    await c.loadOlder();
    await c.loadOlder();
    expect(idsOf(c).length, 7);
    expect(c.canLoadOlder, isFalse);
  }, skip: _skip);

  test('a dismissed promotion is dismissed for me only', () async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'promo', 'promotion', title: 'October Offer', expiresAt: t0.add(const Duration(days: 5)));
    final a = await feed(fs, 'A', Clock());
    final b = await feed(fs, 'B', Clock());
    await a.remove([item(a, 'promo')]);
    await settle();
    final stored = [FacilityNotification.fromFirestore(await fs.doc('facilities/F1/notifications/promo').get())];
    NotificationState stateOf(String uid) => uid == 'A'
        ? NotificationState(removed: {'promo': t0})
        : NotificationState.empty;
    expect(isPromotionDismissed(promotionLabel: 'October Offer', stored: stored, state: stateOf('A')), isTrue);
    expect(isPromotionDismissed(promotionLabel: 'October Offer', stored: stored, state: stateOf('B')), isFalse);
    expect(isPromotionDismissed(promotionLabel: 'Another', stored: stored, state: stateOf('A')), isFalse);
    expect(idsOf(b), ['promo']);
  }, skip: _skip);
}

// The bell (dashboard_screen.dart) reads the same controller: its red dot
// follows MY read state, and a promotion I removed no longer lights its
// accent for me.
void bellTests() {
  test('the bell\'s red dot follows my read state; the trial is not red', () async {
    final fs = FakeFirebaseFirestore();
    final subs = Subs()..facts = const SubscriptionFacts(trialInfo: (title: 'Free Trial', message: '20 days left'));
    await seed(fs, 'n1', 'lowStock');
    final a = await feed(fs, 'A', Clock(), subs: subs);
    final b = await feed(fs, 'B', Clock(), subs: subs);
    expect(a.hasUnreadAlert, isTrue);
    await a.markRead([item(a, 'n1')]);
    await settle();
    expect(a.hasUnreadAlert, isFalse, reason: 'the unread trial row is the blue dot');
    expect(b.hasUnreadAlert, isTrue);
  }, skip: _skipBell);

  test('a dismissed promotion no longer lights the accent for me', () async {
    final fs = FakeFirebaseFirestore();
    await seed(fs, 'promo', 'promotion', title: 'October Offer', expiresAt: t0.add(const Duration(days: 5)));
    final a = await feed(fs, 'A', Clock());
    final b = await feed(fs, 'B', Clock());
    expect(a.isPromotionDismissedForMe('October Offer'), isFalse);
    await a.remove([item(a, 'promo')]);
    await settle();
    expect(a.isPromotionDismissedForMe('October Offer'), isTrue);
    expect(b.isPromotionDismissedForMe('October Offer'), isFalse);
  }, skip: _skipBell);
}

// Until the bell's members are implemented.
const _skipBell = true;
