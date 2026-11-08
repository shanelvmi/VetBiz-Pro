// UI1 (6), written before the change: the More page without the profile card
// and without any item that lives in the bottom bar (Home, Sales, Products:
// none is a More item) or in the profile menu (the avatar's drawer: Edit
// profile, Team Members, View Facilities, Change password, Activity log,
// Logout). Settings and Help stay only as the top bar's two icons. Every item
// the role reached before is still reachable: from More, the top bar or the
// profile menu. Find a feature searches what remains, in English and
// Kiswahili. The size matrix at 360x740, 390x844 and 740x360.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';

import 'helpers/mr1_more.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

/// The profile menu's items that are also More destinations (the drawer
/// pushes the same screens as these items), and the top bar's two icons.
const _profileMenu = {MoreItem.team, MoreItem.facilities, MoreItem.activityLog};
const _topBar = {MoreItem.settings, MoreItem.help};

const _admin = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights'],
  'teamAndBusiness': ['businessHours', 'subscription'],
  'app': ['printerSettings', 'export', 'trash', 'manageAccount'],
};

const _assistant = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights'],
  'app': ['printerSettings', 'manageAccount'],
};

/// MR1's grid, before UI1: everything the role could reach from More.
const _beforeAdmin = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights', 'activityLog'],
  'teamAndBusiness': ['team', 'facilities', 'businessHours', 'subscription'],
  'app': ['settings', 'printerSettings', 'export', 'trash', 'manageAccount', 'help'],
};

const _beforeAssistant = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights'],
  'app': ['settings', 'printerSettings', 'manageAccount', 'help'],
};

Widget _page({bool isAdmin = true, bool isPlatformAdmin = false}) =>
    MoreScreen(isAdmin: isAdmin, isPlatformAdmin: isPlatformAdmin, onOpen: (_, __) async {});

void main() {
  test('the partition: no item of the profile menu or the top bar in More; everything still reachable', () {
    for (final (admin, platform, before) in [
      (true, false, _beforeAdmin),
      (true, true, {..._beforeAdmin, 'platform': ['platformAdmin']}),
      (false, false, _beforeAssistant),
    ]) {
      final now = moreItemsFor(isAdmin: admin, isPlatformAdmin: platform).toSet();
      expect(now.intersection(_profileMenu), isEmpty);
      expect(now.intersection(_topBar), isEmpty);
      final reachable = {...now.map((i) => i.name), ..._topBar.map((i) => i.name), if (admin) ..._profileMenu.map((i) => i.name)};
      expect(reachable, before.values.expand((v) => v).toSet(), reason: 'admin $admin, platform $platform');
    }
  }, skip: _skip);

  test('the profile menu opens the same screens as the items left out of More', () {
    final drawer = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    final more = File('lib/screens/dashboard/more_screen.dart').readAsStringSync();
    for (final (item, screen) in [
      (MoreItem.team, 'ManageAssistantsScreen()'),
      (MoreItem.facilities, 'FacilityScreen()'),
      (MoreItem.activityLog, 'const ActivityLogScreen()'),
    ]) {
      expect(drawer.contains('builder: (_) => $screen'), isTrue, reason: 'the drawer opens $screen');
      expect(RegExp('case MoreItem\\.${item.name}:\\s*return push\\(${RegExp.escape(screen)}\\)').hasMatch(more), isTrue);
    }
  }, skip: _skip);

  for (final (name, admin, expected) in [('admin', true, _admin), ('assistant', false, _assistant)]) {
    testWidgets('$name: the sections drawn, no profile card, Settings and Help in the top bar', (tester) async {
      await mrPump(tester, _page(isAdmin: admin));
      expect(mrDrawn(), expected);
      expect(find.byKey(mrProfile), findsNothing);
      expect(find.byKey(const ValueKey('more-app-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('more-app-help')), findsOneWidget);
    }, skip: _skip);
  }

  testWidgets('platform admin: the Platform section last', (tester) async {
    await mrPump(tester, _page(isPlatformAdmin: true));
    expect(mrDrawn().keys.last, 'platform');
  }, skip: _skip);

  for (final locale in ['en', 'sw']) {
    testWidgets('Find a feature over what remains ($locale)', (tester) async {
      await mrPump(tester, _page(), locale: locale);
      final sw = lookupAppLocalizations(const Locale('sw'));
      final en = lookupAppLocalizations(const Locale('en'));
      await mrType(tester, sw.clients_title);
      expect(mrItem('clients'), findsOneWidget);
      await mrType(tester, en.printer_title);
      expect(mrDrawn().values.expand((v) => v), contains('printerSettings'));
      expect(mrItem('settings'), findsNothing);
      await mrType(tester, 'zzzz');
      expect(find.byKey(mrNoMatch), findsOneWidget);
    }, skip: _skip);
  }

  for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360)]) {
    for (final look in MatrixLook.values) {
      final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name}';
      testWidgets('the page at $where: no overflow, 48 px targets, text 12 px or more', (tester) async {
        await pumpAtSize(tester, screen: _page(isPlatformAdmin: true), size: size, look: look);
        await checkCase(tester, phone: true, where: where);
        expect(find.byKey(mrProfile), findsNothing);
      }, skip: _skip);
    }
  }
}
