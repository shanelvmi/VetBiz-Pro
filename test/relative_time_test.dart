import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/widgets/notification_row.dart';

/// relativeTime() has no BuildContext, so it reads L10n.current: its words
/// follow the language picked in Settings.
void main() {
  tearDown(() => L10n.setLocale(const Locale('en')));

  test('English', () {
    final now = DateTime.now();
    expect(relativeTime(now), 'Just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 5))), '5m ago');
    expect(relativeTime(now.subtract(const Duration(hours: 2))), '2h ago');
    expect(relativeTime(now.subtract(const Duration(days: 3))), '3d ago');
    expect(relativeTime(null), '');
  });

  test('Kiswahili', () {
    L10n.setLocale(const Locale('sw'));
    final now = DateTime.now();
    expect(relativeTime(now), 'Sasa hivi');
    expect(relativeTime(now.subtract(const Duration(minutes: 5))), 'dakika 5 zilizopita');
    expect(relativeTime(now.subtract(const Duration(days: 3))), 'siku 3 zilizopita');
  });
}
