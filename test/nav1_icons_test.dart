import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_icons.dart';

/// NAV1 (A): one icon system. Turned on once every screen reads AppIcons.
const _pendingSweep = false;

/// Dollar-sign glyphs (any variant: _outlined, _rounded, _sharp) that must
/// not appear in lib/: Sales is a receipt, Debtors a wallet.
final _dollar = RegExp(
  r'Icons\.(attach_money|monetization_on|money_off|money_off_csred|paid|currency_exchange|'
  r'price_change|price_check|local_atm)(_outlined|_rounded|_sharp)?\b',
);

final _dollarGlyphs = {
  Icons.attach_money, Icons.monetization_on, Icons.monetization_on_outlined, Icons.money_off, Icons.paid,
  Icons.paid_outlined, Icons.currency_exchange, Icons.price_change, Icons.price_check, Icons.local_atm,
};

/// No AI-style icons for a concept.
final _aiStyle = {Icons.auto_awesome, Icons.bolt, Icons.rocket, Icons.rocket_launch};

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('no two concepts share a glyph, outlined or filled', () {
    final owner = <int, String>{};
    for (final MapEntry(key: name, value: icon) in AppIcons.concepts.entries) {
      for (final glyph in {icon.outlined.codePoint, icon.filled.codePoint}) {
        expect(owner[glyph], isNull, reason: '$name reuses the glyph of ${owner[glyph]}');
        owner[glyph] = name;
      }
    }
  });

  test('the owner\'s choices: receipt for Sales, a non-dollar Debtors, bar_chart for Reports only', () {
    expect(AppIcons.sales.filled, Icons.receipt_long);
    expect(AppIcons.debtors.filled, Icons.account_balance_wallet);
    expect(AppIcons.payments.filled, Icons.payments);
    expect(AppIcons.transactions.filled, Icons.swap_vert);
    expect(AppIcons.expenses.filled, Icons.trending_down);
    expect(AppIcons.products.filled, Icons.inventory_2);
    expect(AppIcons.stockStore.filled, Icons.warehouse);
    expect(AppIcons.clients.filled, Icons.groups);
    expect(AppIcons.reports.filled, Icons.bar_chart);
    expect(AppIcons.insights.filled, Icons.insights);
    expect(AppIcons.home.filled, Icons.home);
    expect(AppIcons.more.filled, Icons.grid_view);
    expect(AppIcons.team.filled, Icons.group);
    expect(AppIcons.facilities.filled, Icons.store);
    expect(AppIcons.settings.filled, Icons.settings);
    expect(AppIcons.help.filled, Icons.help);
    expect(AppIcons.trash.filled, Icons.delete);
    expect(AppIcons.export.filled, Icons.download);
    expect(AppIcons.printer.filled, Icons.print);
    expect(AppIcons.businessHours.filled, Icons.schedule);
    expect(AppIcons.activityLog.filled, Icons.history);
    for (final icon in AppIcons.concepts.values) {
      expect(_aiStyle.contains(icon.outlined) || _aiStyle.contains(icon.filled), isFalse);
      expect(_dollarGlyphs.contains(icon.outlined) || _dollarGlyphs.contains(icon.filled), isFalse);
    }
  });

  test('the dollar-sign pattern catches a new raw Icons.attach_money in any variant', () {
    expect(_dollar.hasMatch('icon: Icons.attach_money,'), isTrue);
    expect(_dollar.hasMatch('Icon(Icons.attach_money_outlined)'), isTrue);
    expect(_dollar.hasMatch('Icons.money_off'), isTrue);
    expect(_dollar.hasMatch('Icons.currency_exchange_outlined'), isTrue);
    expect(_dollar.hasMatch('Icons.payments_outlined'), isFalse);
    expect(_dollar.hasMatch('Icons.receipt_long'), isFalse);
  });

  test('no dollar-sign icon remains in lib/', () {
    final hits = <String>[];
    for (final f in _dartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_dollar.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  }, skip: _pendingSweep);
}
