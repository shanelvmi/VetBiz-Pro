// HUB4b (3): the profile page, the setup checklist and the Insights link add
// no Firestore listener and no read. The page joins the top bar's user
// stream (hub4b_profile_page_test); the checklist is decided from what Home
// already holds; the link only opens Insights (its reads are Insights' own,
// shared with Home through InsightsDataLoader). Cold open and a return to
// Home keep HUB4a's counts (rv1_home_counts_test, PH4's loads).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';

String _read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// The body of the member starting at [start], to the next member at two
/// spaces' indent.
String _member(String source, String start) {
  final from = source.indexOf(start);
  expect(from, isNot(-1), reason: '$start not found');
  final end = source.indexOf(RegExp(r'\n\n  [A-Za-z/@]'), from);
  return source.substring(from, end == -1 ? source.length : end);
}

const _readsOrListens = ['.get(', '.snapshots(', '.collection(', 'FirebaseFirestore.instance'];

void main() {
  test('the checklist is decided from held data only', () {
    final body = _member(_read('lib/screens/dashboard/dashboard_screen.dart'), '({List<HomeSetupItem> items, bool ready}) _homeSetup(');
    for (final banned in _readsOrListens) {
      expect(body.contains(banned), isFalse, reason: '_homeSetup has $banned');
    }
    for (final held in ['_homeDays', '_periodTotals.totalSales', 'products.products', 'clients.clients']) {
      expect(body, contains(held));
    }
  });

  test('the checklist, the card, the page and its sheet have no Firestore of their own', () {
    for (final path in [
      'lib/screens/dashboard/home_setup.dart',
      'lib/screens/dashboard/home_setup_card.dart',
      'lib/widgets/profile/profile_page.dart',
      'lib/widgets/profile/profile_switch_sheet.dart',
      'lib/screens/dashboard/profile_actions.dart',
    ]) {
      final source = _read(path);
      expect(source.contains('cloud_firestore'), isFalse, reason: path);
      for (final banned in _readsOrListens) {
        expect(source.contains(banned), isFalse, reason: '$path has $banned');
      }
    }
  });

  test('Home\'s loads are unchanged: cold open the period totals only, a return nothing', () {
    expect(dashboardLoadsFor(DashboardMoment.coldOpen, phone: true), {DashboardLoad.periodTotals});
    expect(dashboardLoadsFor(DashboardMoment.returnToHome, phone: true), isEmpty);
  });
}
