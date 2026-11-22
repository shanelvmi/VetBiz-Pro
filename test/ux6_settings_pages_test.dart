// UX6 (owner, 2026-11-22): the Settings pages on PC and tablet. Currency is
// an information row; Subscription spans the content in two columns from
// 900; Trash, Export Data and Manage Account share the PageCard template;
// Notifications' actions sit in the page header (Mark all read, then a
// "more" menu), its filters left-aligned and its footer the ListPageBar;
// Language opens a centred dialog off the phone. Phones keep their pages.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/services/notification_feed.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/ui/polish/page_card.dart';
import 'package:vetbiz_pro/widgets/list_page_bar.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';

import 'helpers/notification_harness.dart';
import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;
import 'ph8a_settings_wide_test.dart' show seedTrash, ph8UserInfo;
import 'ph8a_subscription_wide_test.dart' show seedSubscription;

final _en = lookupAppLocalizations(const Locale('en'));

const _phone = Size(390, 844);
const _wide = [Size(768, 1024), Size(1200, 800), Size(1920, 1080)];
const _looks = [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)];

Finder _row(String key) => find.byKey(ValueKey('settingsHub-$key'));

Future<NotificationFeedController> _feed(WidgetTester tester) async {
  final fs = FakeFirebaseFirestore();
  final at = t0.subtract(const Duration(hours: 1));
  final c = (await tester.runAsync(() async {
    for (var i = 0; i < 14; i++) {
      await seed(fs, 'n$i', i.isEven ? 'lowStock' : 'paymentReceived',
          createdAt: at.subtract(Duration(minutes: i)), readAt: i % 3 == 0 ? at : null);
    }
    final c = newFeed(fs, 'A', Clock())..start();
    await settle();
    return c;
  }))!;
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Currency: information only', () {
    ph5TestWidgets('hub: no chevron, no tap', (tester) async {
      await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: const Size(1200, 800), pushed: true);
      await tester.scrollUntilVisible(_row('currency'), 150,
          scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
      expect(find.descendant(of: _row('currency'), matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing);
      expect(find.descendant(of: _row('currency'), matching: find.text(_en.settings_currency)), findsOneWidget);
      final ink = tester.widget<InkWell>(find.descendant(of: _row('currency'), matching: find.byType(InkWell)));
      expect(ink.onTap, isNull);
      // A neighbour still has its chevron.
      expect(find.descendant(of: _row('language'), matching: find.byIcon(Icons.chevron_right_rounded)), findsOneWidget);
    });

    ph5TestWidgets('phone: no chevron, no tap', (tester) async {
      await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: _phone, pushed: true);
      final tile = find.ancestor(of: find.text(_en.settings_currency), matching: find.byType(ListTile));
      await tester.scrollUntilVisible(tile, 150, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing);
    });
  });

  group('Subscription', () {
    for (final size in _wide) {
      ph5TestWidgets('${size.width.toInt()}: banner on top, ${size.width >= 1200 ? 'two columns' : 'one column'}, full width', (tester) async {
        await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
            size: size, pushed: true, seed: (fs) => seedSubscription(fs));
        final left = tester.getRect(find.byKey(const ValueKey('subscription-left')));
        final right = tester.getRect(find.byKey(const ValueKey('subscription-right')));
        final body = tester.getRect(find.byKey(const ValueKey('subscription-wide')));
        if (size.width >= 1200) {
          expect(right.left, greaterThan(left.right), reason: 'side by side');
          expect(right.top, left.top);
        } else {
          expect(right.top, greaterThan(left.bottom - 1), reason: 'stacked');
          expect(left.width, greaterThan(body.width - 40), reason: 'full width, not a narrow centred column');
        }
        expect(left.left - body.left, lessThan(40), reason: 'starts at the page padding');
      });
    }

    ph5TestWidgets('phone keeps its single column', (tester) async {
      await pumpPh5(tester, (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()), size: _phone, pushed: true, seed: (fs) => seedSubscription(fs));
      expect(find.byKey(const ValueKey('subscription-wide')), findsNothing);
      expect(find.byKey(const ValueKey('subscription-left')), findsNothing);
    });
  });

  group('the card template', () {
    for (final (name, build) in <(String, Widget Function(dynamic fs))>[
      ('Trash', (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo)),
      ('Export Data', (fs) => ExportDataScreen(firestore: fs)),
      ('Manage Account', (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth())),
    ]) {
      ph5TestWidgets('$name: PageCard on PC/tablet, full width; not on a phone', (tester) async {
        await pumpPh5(tester, (fs) => build(fs), size: const Size(1200, 800), pushed: true, seed: seedTrash);
        expect(find.byType(PageCard), findsWidgets);
        // UX7: the cards together span the content (Export: two columns).
        final cards = find.byKey(const ValueKey('pageCard')).evaluate().map((e) => tester.getRect(find.byWidget(e.widget)));
        final span = cards.reduce((a, b) => a.expandToInclude(b));
        expect(span.width, greaterThan(1200 - 80), reason: 'the full content width');
        await pumpPh5(tester, (fs) => build(fs), size: _phone, pushed: true, seed: seedTrash);
        expect(find.byType(PageCard), findsNothing, reason: 'the phone keeps its page');
      });
    }

    ph5TestWidgets('Trash: a table with Date, Restore at the right', (tester) async {
      await pumpPh5(tester, (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo), size: const Size(1200, 800), pushed: true, seed: seedTrash);
      expect(find.text(_en.common_date), findsOneWidget);
      final restore = find.byKey(const ValueKey('trash-restore-p1'));
      expect(restore, findsOneWidget);
      final row = tester.getRect(find.byKey(const ValueKey('trash-row-p1')));
      expect(row.right - tester.getRect(restore).right, lessThan(80), reason: 'the actions at the right');
      expect(tester.getSize(restore).height, greaterThanOrEqualTo(44));
    });

    ph5TestWidgets('Export: one card per data set, its Export button at the right', (tester) async {
      await pumpPh5(tester, (fs) => ExportDataScreen(firestore: fs), size: const Size(1200, 800), pushed: true);
      final actions = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('export-action-'));
      expect(actions.evaluate().length, greaterThanOrEqualTo(5));
      final first = actions.first;
      expect(tester.getRect(first).right, greaterThan(1200 - 80));
      expect(tester.getSize(first).height, greaterThanOrEqualTo(44));
    });

    ph5TestWidgets('Manage Account: grouped by purpose', (tester) async {
      await pumpPh5(tester, (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth()), size: const Size(1200, 800), pushed: true);
      for (final k in ['account-card-signin', 'account-card-data', 'account-card-danger']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text(_en.account_groupSignIn), findsOneWidget);
      expect(find.text(_en.account_dangerZone), findsOneWidget);
    });
  });

  group('Notifications header and footer (PC/tablet)', () {
    for (final width in [768.0, 1200.0, 1920.0]) {
      testWidgets('$width: Mark all read and "more" in the header, no button row, left filters, ListPageBar', (tester) async {
        final c = await _feed(tester);
        await pumpNotifications(tester, c, width: width, height: 900);
        final header = find.byType(PageHeader);
        expect(find.descendant(of: header, matching: find.byKey(const ValueKey('notifications-mark-all-read'))), findsOneWidget);
        expect(find.descendant(of: header, matching: find.byKey(const ValueKey('notifications-wide-more'))), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, _en.notifications_removeReadOnes), findsNothing, reason: 'the old row is gone');
        await tester.tap(find.byKey(const ValueKey('notifications-wide-more')));
        await tester.pumpAndSettle();
        expect(find.text(_en.notifications_removeReadOnes), findsOneWidget);
        expect(find.text(_en.notifications_select), findsOneWidget);
        await tester.tap(find.text(_en.notifications_select));
        await tester.pumpAndSettle();
        expect(find.descendant(of: header, matching: find.byKey(const ValueKey('notifications-remove-selected'))), findsOneWidget);
        // Left-aligned filters: the first segment at the page padding.
        final all = tester.getRect(find.byKey(const ValueKey('notifications-filter-all')));
        expect(all.left, lessThan(40));
        expect(find.byType(FilterRow), findsOneWidget);
        expect(find.byKey(const ValueKey('notifications-page-bar')), findsOneWidget);
        expect(find.byType(ListPageBar), findsOneWidget);
        // The range and the page size no longer run together.
        final range = tester.getRect(find.textContaining(RegExp(r'^Showing')));
        // PAGE1: PC/tablet starts at 25 per page (the shared pager's default).
        final size = tester.getRect(find.text(_en.common_perPage(25)));
        expect(size.left - range.right > 8 || size.top >= range.bottom, isTrue, reason: 'apart');
      });
    }

    testWidgets('phone keeps its bar, menu and pager', (tester) async {
      final c = await _feed(tester);
      await pumpNotifications(tester, c, width: 390, height: 900);
      expect(find.byType(PageHeader), findsNothing);
      expect(find.byKey(const ValueKey('notifications-page-more')), findsOneWidget);
      expect(find.byType(ListPageBar), findsNothing);
    });
  });

  group('Language and Theme dialogs', () {
    ph5TestWidgets('PC/tablet: Language opens the centred dialog, at most 500 wide, 44 px options', (tester) async {
      await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: const Size(1920, 1080), pushed: true);
      await tester.scrollUntilVisible(_row('language'), 150,
          scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
      await tester.tap(_row('language'));
      await tester.pumpAndSettle();
      final dialog = find.byKey(const ValueKey('language-dialog'));
      expect(dialog, findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final panel = tester.getRect(find.descendant(of: dialog, matching: find.byType(ConstrainedBox)).first);
      expect(panel.width, lessThanOrEqualTo(500));
      expect((panel.center.dx - 960).abs(), lessThan(2), reason: 'centred');
      expect(tester.getSize(find.byKey(const ValueKey('language-option-sw'))).height, greaterThanOrEqualTo(44));
      expect(find.descendant(of: dialog, matching: find.byTooltip(_en.common_close)), findsOneWidget);
      await tester.tap(find.byTooltip(_en.common_close));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      // Theme and layout: the same dialog style and width.
      await tester.tap(_row('ui_settings'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(ConstrainedBox)).first).width, lessThanOrEqualTo(500));
    });

    ph5TestWidgets('phone: Language keeps its bottom sheet', (tester) async {
      await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: _phone, pushed: true);
      final row = find.text(_en.settings_languageBoth);
      await tester.scrollUntilVisible(row, 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('language-dialog')), findsNothing);
    });
  });

  // Widths 768, 1200, 1920; English 1.0 and 1.3, Kiswahili 1.3: no overflow.
  group('no overflow', () {
    for (final size in _wide) {
      for (final (look, scale) in _looks) {
        final at = '${size.width.toInt()} ${look.name} $scale';
        ph5TestWidgets('$at: Subscription, Trash, Export, Manage Account, Language dialog', (tester) async {
          for (final build in <Widget Function(dynamic fs)>[
            (fs) => SubscriptionScreen(firestore: fs, auth: Ph8Auth()),
            (fs) => TrashScreen(firestore: fs, currentUserInfo: ph8UserInfo),
            (fs) => ExportDataScreen(firestore: fs),
            (fs) => ManageAccountScreen(firestore: fs, auth: Ph8Auth()),
          ]) {
            await pumpPh5(tester, (fs) => build(fs), size: size, look: look, textScale: scale, pushed: true, seed: (fs) async {
              await seedSubscription(fs);
              await seedTrash(fs);
            });
            expect(tester.takeException(), isNull);
          }
          await pumpPh5(tester, (fs) => SettingsScreen(firestore: fs, auth: Ph8bAuth()), size: size, look: look, textScale: scale, pushed: true);
          await tester.scrollUntilVisible(_row('language'), 150,
              scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
          await tester.tap(_row('language'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('language-dialog')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('$at: Notifications', (tester) async {
          final c = await _feed(tester);
          await pumpNotifications(tester, c, width: size.width, height: size.height,
              locale: look == MatrixLook.kiswahili ? 'sw' : 'en', textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
