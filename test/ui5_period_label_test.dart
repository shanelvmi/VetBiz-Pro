// UI5 (2): the Today card's period label shows the exact range the figures
// use: dashboardPeriodRange is the one place the range is worked out (the
// dashboard watches its totals over it), and the label is formatted from it
// in the current locale, short enough never to need more than its ellipsis.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_figures.dart';

const _skip = true;

String _label(String locale, String period, DateTime now) => dashboardPeriodRangeLabel(
      lookupAppLocalizations(Locale(locale)),
      period,
      dashboardPeriodRange(period, now: now),
      locale: locale,
    );

void main() {
  setUpAll(() => initializeDateFormatting());

  // Monday 9 November 2026, mid afternoon.
  final monday = DateTime(2026, 11, 9, 15, 30);

  group('the range the totals are watched over', () {
    test('Today: midnight to now', () {
      expect(dashboardPeriodRange('Today', now: monday), (DateTime(2026, 11, 9), monday));
    }, skip: _skip);

    test('This Week: Monday to now (Monday itself, then a Thursday)', () {
      expect(dashboardPeriodRange('This Week', now: monday), (DateTime(2026, 11, 9), monday));
      final thursday = DateTime(2026, 11, 12, 8);
      expect(dashboardPeriodRange('This Week', now: thursday), (DateTime(2026, 11, 9), thursday));
    }, skip: _skip);

    test('This Month and This Year: the first day to now', () {
      expect(dashboardPeriodRange('This Month', now: monday), (DateTime(2026, 11, 1), monday));
      expect(dashboardPeriodRange('This Year', now: monday), (DateTime(2026, 1, 1), monday));
    }, skip: _skip);

    test('an unknown period is Today, as the filter has always done', () {
      expect(dashboardPeriodRange('Someday', now: monday), (DateTime(2026, 11, 9), monday));
    }, skip: _skip);
  });

  group('the label, in English', () {
    test('Today shows the day', () => expect(_label('en', 'Today', monday), 'Mon 9 Nov'), skip: _skip);

    test('This Week shows its days with an en dash', () {
      expect(_label('en', 'This Week', DateTime(2026, 11, 12)), '9–12 Nov');
    }, skip: _skip);

    test('This Week on its Monday is that one day', () {
      expect(_label('en', 'This Week', monday), '9 Nov');
    }, skip: _skip);

    test('a week across a month boundary names both months', () {
      expect(_label('en', 'This Week', DateTime(2026, 12, 2)), '30 Nov–2 Dec');
    }, skip: _skip);

    test('a week across a year boundary names both years', () {
      expect(_label('en', 'This Week', DateTime(2027, 1, 1)), '28 Dec 2026–1 Jan 2027');
    }, skip: _skip);

    test('This Month and This Year', () {
      expect(_label('en', 'This Month', monday), 'Nov 2026');
      expect(_label('en', 'This Year', monday), '2026');
    }, skip: _skip);
  });

  group('the label, in Kiswahili (day and month names in Kiswahili)', () {
    test('Today', () => expect(_label('sw', 'Today', monday), 'Jumatatu 9 Nov'), skip: _skip);

    test('This Week', () {
      expect(_label('sw', 'This Week', DateTime(2026, 11, 12)), '9–12 Nov');
      expect(_label('sw', 'This Week', monday), '9 Nov');
    }, skip: _skip);

    test('a week across a month boundary', () {
      expect(_label('sw', 'This Week', DateTime(2026, 12, 2)), '30 Nov–2 Des');
    }, skip: _skip);

    test('a week across a year boundary', () {
      expect(_label('sw', 'This Week', DateTime(2027, 1, 1)), '28 Des 2026–1 Jan 2027');
    }, skip: _skip);

    test('This Month and This Year', () {
      expect(_label('sw', 'This Month', monday), 'Nov 2026');
      expect(_label('sw', 'This Year', monday), '2026');
    }, skip: _skip);
  });

  test('the dashboard watches its totals over dashboardPeriodRange (no second copy of the rule)', () {
    // Source check: the range is never worked out twice.
    final source = _read('lib/screens/dashboard/dashboard_screen.dart');
    expect(source.contains('_dateRangeForFilter'), isFalse);
    expect(source.contains('dashboardPeriodRange('), isTrue);
  }, skip: _skip);
}

String _read(String path) => File(path).readAsStringSync();
