// NOTIF-2b (docs/design/notifications.md, sections 2 and 4, approved): the
// notification policy as plain rules - the class of every type, what
// resolves a persistent one, the lifetimes, and escalation by stage.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_ranges.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/notification_model.dart';
import 'package:vetbiz_pro/models/notification_policy.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';

const persistent = NotificationClass.persistent;
const dismissible = NotificationClass.dismissible;
const routine = NotificationClass.routine;

// Until the implementation: every call throws UnimplementedError('NOTIF-2b').
const _skipUntilImplemented = true;

final t0 = DateTime(2026, 10, 1, 9);
DateTime days(DateTime from, int n) => from.add(Duration(days: n));

void main() {
  group('the class of every type (section 2 table)', () {
    const table = {
      NotificationType.subscriptionExpiring: persistent,
      NotificationType.trialStatus: persistent,
      NotificationType.assistantPending: persistent,
      NotificationType.subscriptionRejected: persistent,
      NotificationType.promotion: dismissible,
      NotificationType.criticalStock: routine,
      NotificationType.lowStock: routine,
      NotificationType.reorderSoon: routine,
      NotificationType.restockShelf: routine,
      NotificationType.paymentReceived: routine,
      NotificationType.serviceRecorded: routine,
      NotificationType.newClient: routine,
      NotificationType.roleChanged: routine,
      NotificationType.general: routine,
      // No writer today; routine if one ever appears.
      NotificationType.debtReminder: routine,
      NotificationType.productExpiry: routine,
      // Legacy, never shown (isNeverShown); routine otherwise.
      NotificationType.trialStarted: routine,
    };

    test('every NotificationType is in the table: a new type must be classed here', () {
      expect(table.keys.toSet(), NotificationType.values.toSet());
    });

    for (final entry in table.entries) {
      test('${entry.key.name}: ${entry.value.name}, removable ${entry.value != persistent}', () {
        expect(NotificationPolicy.classOf(entry.key), entry.value);
        expect(NotificationPolicy.canRemove(entry.key), entry.value != persistent);
        expect(NotificationPolicy.persistentReason(entry.key) != null, entry.value == persistent);
      }, skip: _skipUntilImplemented);
    }

    test('urgent announcements are dismissible (D5); only the legacy trialStarted is never shown', () {
      expect(NotificationPolicy.urgentAnnouncementClass, dismissible);
      for (final type in NotificationType.values) {
        expect(NotificationPolicy.isNeverShown(type), type == NotificationType.trialStarted, reason: type.name);
      }
    }, skip: _skipUntilImplemented);

    test('the explanation for each persistent type', () {
      expect(NotificationPolicy.persistentReason(NotificationType.subscriptionExpiring), PersistentReason.untilRenewed);
      expect(NotificationPolicy.persistentReason(NotificationType.trialStatus), PersistentReason.untilTrialEnds);
      expect(NotificationPolicy.persistentReason(NotificationType.assistantPending), PersistentReason.untilDecided);
      expect(NotificationPolicy.persistentReason(NotificationType.subscriptionRejected), PersistentReason.untilNewClaim);
    }, skip: _skipUntilImplemented);
  });

  group('a persistent item is resolved only by its own condition', () {
    bool resolved(NotificationType t, PersistentFacts f) => NotificationPolicy.isResolved(t, f);

    test('payment rejected: once a newer claim exists', () {
      const t = NotificationType.subscriptionRejected;
      expect(resolved(t, const PersistentFacts(newerClaimExists: true)), isTrue);
      expect(resolved(t, const PersistentFacts(newerClaimExists: false)), isFalse);
      expect(resolved(t, const PersistentFacts()), isFalse, reason: 'an unknown fact resolves nothing');
    }, skip: _skipUntilImplemented);

    test('assistant waiting: once the decision is made', () {
      const t = NotificationType.assistantPending;
      expect(resolved(t, const PersistentFacts(decisionMade: true)), isTrue);
      expect(resolved(t, const PersistentFacts(decisionMade: false)), isFalse);
      expect(resolved(t, const PersistentFacts()), isFalse);
    }, skip: _skipUntilImplemented);

    test('subscription: once nothing needs attention; trial row: once the calm trial is over', () {
      expect(resolved(NotificationType.subscriptionExpiring,
          const PersistentFacts(subscriptionStage: SubscriptionNoticeStage.none)), isTrue);
      for (final s in [SubscriptionNoticeStage.expiring, SubscriptionNoticeStage.grace, SubscriptionNoticeStage.locked]) {
        expect(resolved(NotificationType.subscriptionExpiring, PersistentFacts(subscriptionStage: s)), isFalse);
      }
      expect(resolved(NotificationType.subscriptionExpiring, const PersistentFacts()), isFalse);
      expect(resolved(NotificationType.trialStatus, const PersistentFacts(inCalmTrial: false)), isTrue);
      expect(resolved(NotificationType.trialStatus, const PersistentFacts(inCalmTrial: true)), isFalse);
    }, skip: _skipUntilImplemented);

    test('never for a type that is not persistent, whatever the facts', () {
      const all = PersistentFacts(
          subscriptionStage: SubscriptionNoticeStage.none, inCalmTrial: false, newerClaimExists: true, decisionMade: true);
      for (final t in [NotificationType.newClient, NotificationType.promotion, NotificationType.lowStock]) {
        expect(resolved(t, all), isFalse, reason: t.name);
      }
    }, skip: _skipUntilImplemented);
  });

  group('lifetimes (the day before, the day of, the day after each limit)', () {
    bool hidden(NotificationClass cls, DateTime now,
            {DateTime? created, DateTime? mine, DateTime? shared, bool unread = false, DateTime? ends}) =>
        NotificationPolicy.isHiddenByAge(
            cls: cls, now: now, createdAt: created, myReadAt: mine, sharedReadAt: shared, markedUnread: unread, endsAt: ends);

    test('the thresholds are named constants: 30 days after read, 90 after created', () {
      expect(AppRanges.notificationReadLifetime, const Duration(days: 30));
      expect(AppRanges.notificationUnreadLifetime, const Duration(days: 90));
      expect(AppRanges.notificationStatePrune, const Duration(days: 120));
    });

    test('routine, read by me: hidden 30 days after MY read', () {
      final readAt = days(t0, 5);
      expect(hidden(routine, days(readAt, 29), created: t0, mine: readAt), isFalse);
      expect(hidden(routine, days(readAt, 30), created: t0, mine: readAt), isTrue);
      expect(hidden(routine, days(readAt, 31), created: t0, mine: readAt), isTrue);
    }, skip: _skipUntilImplemented);

    test('routine, unread: hidden 90 days after it was created', () {
      expect(hidden(routine, days(t0, 89), created: t0), isFalse);
      expect(hidden(routine, days(t0, 90), created: t0), isTrue);
      expect(hidden(routine, days(t0, 91), created: t0), isTrue);
      expect(hidden(routine, days(t0, 400)), isFalse, reason: 'no createdAt: never hidden by age');
    }, skip: _skipUntilImplemented);

    test('a legacy shared readAt counts as read for me, 30 days from it; my own read wins', () {
      final shared = days(t0, 2);
      expect(hidden(routine, days(shared, 29), created: t0, shared: shared), isFalse);
      expect(hidden(routine, days(shared, 30), created: t0, shared: shared), isTrue);
      final mine = days(t0, 20);
      expect(hidden(routine, days(shared, 31), created: t0, shared: shared, mine: mine), isFalse);
      expect(hidden(routine, days(mine, 30), created: t0, shared: shared, mine: mine), isTrue);
    }, skip: _skipUntilImplemented);

    test('marked unread by me over a shared readAt: the 90 days from created apply', () {
      final shared = days(t0, 1);
      expect(hidden(routine, days(shared, 31), created: t0, shared: shared, unread: true), isFalse);
      expect(hidden(routine, days(t0, 90), created: t0, shared: shared, unread: true), isTrue);
    }, skip: _skipUntilImplemented);

    test('dismissible: hidden at its end; with no end, as routine', () {
      final ends = days(t0, 10);
      expect(hidden(dismissible, days(ends, -1), created: t0, ends: ends), isFalse);
      expect(hidden(dismissible, ends, created: t0, ends: ends), isTrue);
      expect(hidden(dismissible, days(ends, 1), created: t0, ends: ends), isTrue);
      expect(hidden(dismissible, days(t0, 89), created: t0), isFalse);
      expect(hidden(dismissible, days(t0, 90), created: t0), isTrue);
      expect(hidden(dismissible, days(t0, 31), created: t0, mine: t0), isTrue);
    }, skip: _skipUntilImplemented);

    test('persistent: never hidden by age, read or not', () {
      final ages = [days(t0, 31), days(t0, 91), days(t0, 1000)];
      for (final now in ages) {
        expect(hidden(persistent, now, created: t0, mine: t0, shared: t0, ends: days(t0, 1)), isFalse);
        expect(hidden(persistent, now, created: t0), isFalse);
      }
    }, skip: _skipUntilImplemented);
  });

  group('escalation by stage (replaces comparing the English message)', () {
    bool again(SubscriptionNoticeStage? seen, SubscriptionNoticeStage now) =>
        NotificationPolicy.isUnreadAgain(seenStage: seen, current: now);

    test('read at expiring, then grace: unread again; grace, then locked: unread again', () {
      expect(again(SubscriptionNoticeStage.expiring, SubscriptionNoticeStage.grace), isTrue);
      expect(again(SubscriptionNoticeStage.grace, SubscriptionNoticeStage.locked), isTrue);
      expect(again(SubscriptionNoticeStage.expiring, SubscriptionNoticeStage.locked), isTrue);
    }, skip: _skipUntilImplemented);

    test('the same stage, a calmer stage, or nothing seen yet: not unread again', () {
      expect(again(SubscriptionNoticeStage.expiring, SubscriptionNoticeStage.expiring), isFalse);
      expect(again(SubscriptionNoticeStage.locked, SubscriptionNoticeStage.expiring), isFalse);
      expect(again(SubscriptionNoticeStage.grace, SubscriptionNoticeStage.none), isFalse);
      expect(again(null, SubscriptionNoticeStage.grace), isFalse);
    }, skip: _skipUntilImplemented);

    test('the stored stage keys never change', () {
      expect([for (final s in SubscriptionNoticeStage.values) s.key], ['none', 'expiring', 'grace', 'locked']);
      expect(SubscriptionNoticeStage.fromKey('grace'), SubscriptionNoticeStage.grace);
      expect(SubscriptionNoticeStage.fromKey('Grace'), isNull);
      expect(subscriptionNoticeId, 'subscription_expiring');
    });

    group('SubscriptionProvider.attentionStage', () {
      Future<SubscriptionNoticeStage> stageFor(Map<String, Object?> facility) async {
        final fs = FakeFirebaseFirestore();
        await fs.collection('facilities').doc('F1').set(facility);
        final sub = SubscriptionProvider(firestore: fs)..listenToFacility('F1');
        await Future<void>.delayed(Duration.zero);
        return sub.attentionStage;
      }

      Timestamp inDays(double d) =>
          Timestamp.fromDate(DateTime.now().add(Duration(minutes: (d * 24 * 60).round())));

      test('comfortably active: none; 7 days and 6 days left: both expiring (read at 7 stays read at 6)', () async {
        expect(await stageFor({'subscriptionExpiresAt': inDays(30)}), SubscriptionNoticeStage.none);
        final at7 = await stageFor({'subscriptionExpiresAt': inDays(6.9)});
        final at6 = await stageFor({'subscriptionExpiresAt': inDays(5.9)});
        expect((at7, at6), (SubscriptionNoticeStage.expiring, SubscriptionNoticeStage.expiring));
        expect(NotificationPolicy.isUnreadAgain(seenStage: at7, current: at6), isFalse);
      }, skip: _skipUntilImplemented);

      test('expired: grace, then locked after the grace days; a trial the same', () async {
        expect(await stageFor({'subscriptionExpiresAt': inDays(-1)}), SubscriptionNoticeStage.grace);
        expect(await stageFor({'subscriptionExpiresAt': inDays(-10)}), SubscriptionNoticeStage.locked);
        expect(await stageFor({'trialExpiresAt': inDays(3)}), SubscriptionNoticeStage.expiring);
        expect(await stageFor({'trialExpiresAt': inDays(-1)}), SubscriptionNoticeStage.grace);
      }, skip: _skipUntilImplemented);

      test('a change of language cannot change the stage', () async {
        final facility = {'subscriptionExpiresAt': inDays(-1)};
        final english = await stageFor(facility);
        L10n.setLocale(const Locale('sw'));
        addTearDown(() => L10n.setLocale(const Locale('en')));
        expect(await stageFor(facility), english);
      }, skip: _skipUntilImplemented);
    });
  });
}
