// NOTIF-2c test harness: notifications on the fake Firestore, a fake clock,
// a changeable live subscription, and the Notifications screen or dropdown
// pumped at a given width and brightness with a controller injected.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/subscription_notice_stage.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';

final t0 = DateTime(2026, 10, 24, 10);

class Clock {
  DateTime now = t0;
  DateTime call() => now;
}

/// The live subscription, changeable during a test.
class Subs extends ChangeNotifier {
  SubscriptionFacts facts = SubscriptionFacts.none;
  void set(SubscriptionFacts f) {
    facts = f;
    notifyListeners();
  }
}

const expiring = SubscriptionFacts(
    stage: SubscriptionNoticeStage.expiring, notice: (title: 'Subscription Expiring Soon', message: '7 days left'));

Future<void> seed(FirebaseFirestore fs, String id, String type,
    {DateTime? createdAt,
    DateTime? readAt,
    DateTime? expiresAt,
    String? audience,
    String? title,
    String? relatedType,
    String? relatedId}) =>
    fs.doc('facilities/F1/notifications/$id').set({
      'type': type,
      'title': title ?? 'T $id',
      'message': 'M $id',
      'createdAt': Timestamp.fromDate(createdAt ?? t0),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (audience != null) 'audience': audience,
      if (relatedType != null) 'relatedEntityType': relatedType,
      if (relatedId != null) 'relatedEntityId': relatedId,
    });

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

NotificationFeedController newFeed(FirebaseFirestore fs, String uid, Clock clock,
        {Subs? subs, int window = 200, int olderPage = 100, bool admin = true}) =>
    NotificationFeedController(
      firestore: fs,
      facilityId: 'F1',
      uid: uid,
      isAdmin: () => admin,
      subscription: subs == null ? null : () => subs.facts,
      subscriptionChanges: subs,
      window: window,
      olderPage: olderPage,
      clock: clock.call,
    );

/// Pumps the full screen (or the dropdown in its 400 px panel) on [c].
Future<void> pumpNotifications(WidgetTester tester, NotificationFeedController c,
    {double width = 390, double height = 800, bool dark = false, bool dropdown = false, String locale = 'en'}) async {
  SharedPreferences.setMockInitialValues({});
  // The view itself (not only the surface), so MediaQuery says the same
  // width as the layout: the phone layout and the swipes go by MediaQuery.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final screen = NotificationsScreen(isDropdown: dropdown, controller: c);
  await tester.pumpWidget(MaterialApp(
    scaffoldMessengerKey: AppFeedback.messengerKey,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    theme: AppTheme.build(AppColorTheme.pasture, dark ? Brightness.dark : Brightness.light),
    home: dropdown
        ? Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 400, height: 600, child: Material(child: screen))))
        : screen,
  ));
  await tester.pumpAndSettle();
}

/// The three-dots menu of row [id].
Finder moreOf(String id) => find.byKey(ValueKey('notification-more-$id'));

Future<void> openMenu(WidgetTester tester, String id) async {
  await tester.tap(moreOf(id));
  await tester.pumpAndSettle();
}

/// Lets the Undo toast's own timer run out, so no timer is left pending.
Future<void> letToastGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}
