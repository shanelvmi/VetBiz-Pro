// MR1, written before the change: the phone More page redesigned (the owner
// could not find Settings in the flat grid). Top to bottom: the app bar (More
// at the left, Settings and Help as 48 px icon buttons), a profile card (the
// avatar, the name with its title, the role label and the facility name
// alone; a tap opens the profile drawer), a "Find a feature" search (labels
// and English and Kiswahili keywords, partial, any case, accents ignored),
// then the named sections (Daily work, Stock and reports, Team and business,
// App, and Platform for platform admins); a section with nothing for the
// role is not drawn. The role gates are today's (PH3's list, the drawer's and
// Settings'); Printer settings and Manage Account join as Settings offers
// them to every role; Business profile does not, as Settings never opens it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/admin/manage_assistants_screen.dart';
import 'package:vetbiz_pro/screens/clients/clients_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/screens/debtors/debtors_screen.dart';
import 'package:vetbiz_pro/screens/facilities/facility_screen.dart';
import 'package:vetbiz_pro/screens/payments/payments_screen.dart';
import 'package:vetbiz_pro/screens/platform_admin/platform_admin_home_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/screens/services/services_screen.dart';
import 'package:vetbiz_pro/screens/settings/business_hours_screen.dart';
import 'package:vetbiz_pro/screens/settings/export_data_screen.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';
import 'package:vetbiz_pro/screens/settings/printer_settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/settings/trash_screen.dart';
import 'package:vetbiz_pro/screens/store/stockstore_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/screens/transactions/transactions_screen.dart';

import 'helpers/mr1_more.dart';

const _skip = true;

/// Records each pushed route and removes it before it is built (the real
/// screens need the app's providers): what was opened is all a spy needs.
class _Spy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushed.add(route);
  }
}

void main() {
  group('the sections and items by role', () {
    testWidgets('admin: four sections with today\'s admin items, no Platform', (tester) async {
      await mrPump(tester, mrMore());
      expect(mrDrawn(), mrAdminSections);
    }, skip: _skip);

    testWidgets('Co-admin (an admin in the app): the admin\'s sections and items', (tester) async {
      await mrPump(tester, mrMore(roleLabel: 'Co-admin'));
      expect(mrDrawn(), mrAdminSections);
    }, skip: _skip);

    testWidgets('assistant: no admin item, and Team and business is not drawn', (tester) async {
      await mrPump(tester, mrMore(isAdmin: false, roleLabel: 'Assistant'));
      expect(mrDrawn(), mrAssistantSections);
      for (final label in ['Team Members', 'Facilities', 'Trash', 'Export Data', 'Business Hours', 'Subscription', 'Activity Log', 'Team and business']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    }, skip: _skip);

    testWidgets('platform admin: the Platform section last, only when the sidebar shows it', (tester) async {
      await mrPump(tester, mrMore(isPlatformAdmin: true));
      expect(mrDrawn(), {...mrAdminSections, 'platform': ['platformAdmin']});
      expect(mrDrawn().keys.last, 'platform');
      await mrPump(tester, mrMore(isAdmin: false, isPlatformAdmin: true));
      expect(mrDrawn(), {...mrAssistantSections, 'platform': ['platformAdmin']});
    }, skip: _skip);

    testWidgets('section titles and the existing screen titles as labels', (tester) async {
      await mrPump(tester, mrMore(isPlatformAdmin: true));
      for (final t in ['Daily work', 'Stock and reports', 'Team and business', 'App', 'Platform']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final label in ['Clients', 'Debtors', 'Stock Store', 'Team Members', 'Printer & Receipt Settings', 'Manage Account', 'Export Data']) {
        expect(find.descendant(of: find.byWidgetPredicate((w) => mrKeyStarts(w, 'more-item-')), matching: find.text(label)), findsOneWidget,
            reason: label);
      }
      final header = tester.widget<Text>(find.text('Daily work'));
      expect(header.style?.fontSize, 14);
      expect(header.style?.fontWeight, FontWeight.w600);
    }, skip: _skip);
  });

  group('each item opens what it opened before', () {
    const expected = <String, Type>{
      'clients': ClientsScreen,
      'debtors': DebtorsScreen,
      'services': ServicesScreen,
      'payments': PaymentsScreen,
      'transactions': TransactionScreen,
      'stockStore': StockStoreScreen,
      'reports': ViewReportsScreen,
      'insights': InsightsScreen,
      'activityLog': ActivityLogScreen,
      'team': ManageAssistantsScreen,
      'facilities': FacilityScreen,
      'businessHours': BusinessHoursScreen,
      'subscription': SubscriptionScreen,
      'settings': SettingsScreen,
      'printerSettings': PrinterSettingsScreen,
      'export': ExportDataScreen,
      'trash': TrashScreen,
      'manageAccount': ManageAccountScreen,
      'platformAdmin': PlatformAdminHomeScreen,
    };
    for (final e in expected.entries) {
      testWidgets('${e.key} pushes ${e.value} over the bar', (tester) async {
        final spy = _Spy();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(mrApp(mrMore(isPlatformAdmin: true, realOpen: true), observers: [spy]));
        await tester.ensureVisible(mrItem(e.key));
        await tester.pump();
        await tester.tap(mrItem(e.key));
        expect(spy.pushed, hasLength(1));
        final route = spy.pushed.single;
        expect(route, isA<MaterialPageRoute<dynamic>>());
        final navigator = route.navigator!;
        expect((route as MaterialPageRoute<dynamic>).builder(navigator.context).runtimeType, e.value);
        navigator.removeRoute(route);
        await tester.pump();
      }, skip: _skip);
    }

    testWidgets('Help and every item reach the opener with their own item', (tester) async {
      final opened = <String>[];
      await mrPump(tester, mrMore(isPlatformAdmin: true, onOpen: (_, item) async => opened.add(item.name)));
      final all = [for (final s in mrDrawn().values) ...s];
      for (final name in all) {
        await tester.ensureVisible(mrItem(name));
        await tester.pump();
        await tester.tap(mrItem(name));
        await tester.pump();
      }
      expect(opened, all);
    }, skip: _skip);
  });

  group('the app bar', () {
    testWidgets('More at the left; Settings and Help are 48 px with tooltips and open their items', (tester) async {
      final opened = <String>[];
      await mrPump(tester, mrMore(onOpen: (_, item) async => opened.add(item.name)));
      final appBar = find.byType(AppBar);
      final title = find.descendant(of: appBar, matching: find.text('More'));
      expect(tester.getTopLeft(title).dx, lessThan(390 / 4));
      for (final tip in ['Settings', 'Help']) {
        final button = find.descendant(of: appBar, matching: find.byTooltip(tip));
        expect(button, findsOneWidget, reason: tip);
        final size = tester.getSize(find.ancestor(of: button, matching: find.byType(IconButton)).first);
        expect(size.width, greaterThanOrEqualTo(48), reason: tip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tip);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel(tip), findsWidgets, reason: tip);
        semantics.dispose();
        await tester.tap(button);
        await tester.pump();
      }
      expect(opened, ['settings', 'help']);
    }, skip: _skip);
  });

  group('the profile card', () {
    testWidgets('the name with its title, the role and the facility name alone; a tap opens the drawer', (tester) async {
      var opened = 0;
      await mrPump(tester, mrMore(facilityName: '  Mwanzo Agrovet ', onProfile: () => opened++));
      final card = find.byKey(mrProfile);
      expect(find.descendant(of: card, matching: find.text('Mr. Shanel')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Admin')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Mwanzo Agrovet')), findsOneWidget);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
      await tester.tap(card);
      await tester.pump();
      expect(opened, 1);
    }, skip: _skip);
  });
}
