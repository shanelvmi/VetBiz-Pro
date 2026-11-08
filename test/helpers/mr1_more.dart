// MR1: what the More page tests share (mr1_more_page_test.dart,
// mr1_more_search_test.dart): the page with its profile parameters, the app
// around it as the shell has it, and the sections and items it draws.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

const mrSearch = ValueKey<String>('more-search');
const mrClear = ValueKey<String>('more-search-clear');
const mrNoMatch = ValueKey<String>('more-no-match');
const mrProfile = ValueKey<String>('more-profile-card');

const mrAdminSections = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights', 'activityLog'],
  'teamAndBusiness': ['team', 'facilities', 'businessHours', 'subscription'],
  'app': ['settings', 'printerSettings', 'export', 'trash', 'manageAccount', 'help'],
};

const mrAssistantSections = {
  'dailyWork': ['clients', 'debtors', 'services', 'payments', 'transactions'],
  'stockAndReports': ['stockStore', 'reports', 'insights'],
  'app': ['settings', 'printerSettings', 'manageAccount', 'help'],
};

/// The page with its profile card filled.
Widget mrMore({
  bool isAdmin = true,
  bool isPlatformAdmin = false,
  Future<void> Function(BuildContext, MoreItem)? onOpen,
  bool realOpen = false,
  String name = 'Mr. Shanel',
  String roleLabel = 'Admin',
  String facilityName = 'Mwanzo Agrovet',
  VoidCallback? onProfile,
}) =>
    MoreScreen(
      isAdmin: isAdmin,
      isPlatformAdmin: isPlatformAdmin,
      onOpen: realOpen ? null : (onOpen ?? (_, __) async {}),
      profileName: name,
      profileRoleLabel: roleLabel,
      profileFacilityName: facilityName,
      onProfile: onProfile ?? () {},
    );

Widget mrApp(Widget home, {String locale = 'en', List<NavigatorObserver> observers = const []}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      navigatorObservers: observers,
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      // As in the shell: the page is a tab inside the shell's Scaffold.
      home: Scaffold(body: home),
    );

Future<void> mrPump(WidgetTester tester, Widget page, {Size size = const Size(390, 844), String locale = 'en'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final before = L10n.locale;
  L10n.setLocale(Locale(locale));
  addTearDown(() => L10n.setLocale(before));
  await tester.pumpWidget(mrApp(page, locale: locale));
  await tester.pump();
}

bool mrKeyStarts(Widget w, String prefix) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix);

String mrKeyRest(Element e, String prefix) => (e.widget.key! as ValueKey<String>).value.substring(prefix.length);

/// The sections drawn, in order, each with its items in order.
Map<String, List<String>> mrDrawn() {
  final out = <String, List<String>>{};
  for (final s in find.byWidgetPredicate((w) => mrKeyStarts(w, 'more-section-')).evaluate()) {
    final name = mrKeyRest(s, 'more-section-');
    out[name] = find
        .descendant(of: find.byKey(ValueKey('more-section-$name')), matching: find.byWidgetPredicate((w) => mrKeyStarts(w, 'more-item-')))
        .evaluate()
        .map((e) => mrKeyRest(e, 'more-item-'))
        .toList();
  }
  return out;
}

Finder mrItem(String name) => find.byKey(ValueKey('more-item-$name'));

Future<void> mrType(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(mrSearch), text);
  await tester.pump();
}

