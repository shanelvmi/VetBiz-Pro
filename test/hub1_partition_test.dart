// HUB1 (4): the owner's split. The panel is daily work, the profile menu is
// the person and Settings, the Settings screen is configuration, and no
// destination is reachable from two of them. Read from the source: each
// part's screens (`SomethingScreen(`) and openers (`showSomething(`).
// Everything the old More page, bottom bar and "+" sheet offered must still be
// reachable from exactly one of them.
//
// THE PARTITION (owner answers of 2026-11-09 applied):
// | Panel | Record Sale, Record Visit, Record Payment, Add Client, Record Transaction, Add Product (admin), Add New Batch; Sales, Products, Services, Clients, Debtors, Payments, Transactions, Stock Store; Reports, Insights, Platform Admin (platform admins) |
// | Profile menu | Edit profile, Team Members, View Facilities, Change password, Activity log, Settings, Help, Logout |
// | Settings screen | Subscription, Trash, Export Data, Business Hours, Manage Account, Printer settings (and its own preferences) |
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// HUB1: true until the panel and the profile menu are done.
const _skip = true;

/// Generic openers that are not a destination.
const _generic = {'showDialog', 'showModalBottomSheet', 'showAppSheet', 'showGeneralDialog', 'showLockedDialog'};

final _token = RegExp(r'(?<![\w.])(show[A-Z]\w*|[A-Z]\w*Screen)\(');

Set<String> _destinations(String source, {String? own}) =>
    {for (final m in _token.allMatches(source)) m.group(1)!}..removeAll({..._generic, if (own != null) own});

/// The body of the method that starts with [signature] (to its closing
/// brace at the method's indentation).
String _method(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'not found: $signature');
  final end = source.indexOf('\n  }\n', start);
  return source.substring(start, end);
}

String _read(String path) => File(path).readAsStringSync();

Set<String> _panel() => {
      ..._destinations(_read('lib/screens/dashboard/hub_destinations.dart')),
      ..._destinations(_read('lib/screens/dashboard/record_sheet.dart')),
    };

Set<String> _profileMenu() =>
    _destinations(_method(_read('lib/screens/dashboard/dashboard_screen.dart'), 'Widget _buildEndDrawerContent()'));

Set<String> _settingsScreen() =>
    _destinations(_read('lib/screens/settings/settings_screen.dart'), own: 'SettingsScreen');

/// What the old phone navigation offered (the More page, its app bar, the
/// bottom bar, the "+" sheet and its More group) and the profile menu.
const _before = {
  'ClientsScreen', 'DebtorsScreen', 'ServicesScreen', 'PaymentsScreen', 'TransactionScreen', 'StockStoreScreen',
  'ViewReportsScreen', 'showInsightsScreen', 'BusinessHoursScreen', 'SubscriptionScreen', 'PrinterSettingsScreen',
  'ExportDataScreen', 'TrashScreen', 'ManageAccountScreen', 'PlatformAdminHomeScreen', 'SettingsScreen',
  'showSupportContactDialog', 'SalesScreen', 'ProductsScreen', 'ManageAssistantsScreen', 'FacilityScreen',
  'ActivityLogScreen', 'showEditProfileScreen', 'showAddSaleScreen', 'showAddEditServiceScreen',
  'showAddPaymentScreen', 'showAddClientScreen', 'showAddEditProductScreen', 'showAddTransactionScreen',
  'showAddBatchScreen',
};

void main() {
  test('no destination is in two of the panel, the profile menu and the Settings screen', () {
    final parts = {'panel': _panel(), 'profile menu': _profileMenu(), 'Settings screen': _settingsScreen()};
    final names = parts.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        expect(parts[names[i]]!.intersection(parts[names[j]]!), isEmpty, reason: '${names[i]} and ${names[j]}');
      }
    }
  }, skip: _skip);

  test('everything the old navigation offered is reachable from exactly one of them', () {
    final parts = [_panel(), _profileMenu(), _settingsScreen()];
    for (final d in _before) {
      expect(parts.where((p) => p.contains(d)), hasLength(1), reason: d);
    }
  }, skip: _skip);

  test('the owner\'s split: Settings and Help in the profile menu; Subscription in Settings only', () {
    expect(_profileMenu(), containsAll(['SettingsScreen', 'showSupportContactDialog']));
    expect(_settingsScreen(), contains('SubscriptionScreen'));
    expect(_panel(), isNot(contains('SubscriptionScreen')));
  }, skip: _skip);
}
