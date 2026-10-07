import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:vetbiz_pro/config/app_date_format.dart';

/// Each named format must print exactly what its legacy pattern prints.
void main() {
  // A morning and an afternoon, single-digit day and month, to catch padding
  // and AM/PM differences.
  final moments = [DateTime(2026, 3, 5, 9, 7, 4), DateTime(2026, 11, 23, 15, 45, 59)];

  final cases = <String, (DateFormat, String)>{
    'date': (AppDateFormat.date, 'dd MMM yyyy'),
    'dateNoPad': (AppDateFormat.dateNoPad, 'd MMM yyyy'),
    'dateShort': (AppDateFormat.dateShort, 'd MMM'),
    'dateDay': (AppDateFormat.dateDay, 'dd MMM'),
    'dateLong': (AppDateFormat.dateLong, 'EEEE, d MMM yyyy'),
    'dateLongFull': (AppDateFormat.dateLongFull, 'EEEE, d MMMM yyyy'),
    'monthYear': (AppDateFormat.monthYear, 'MMMM yyyy'),
    'monthYearShort': (AppDateFormat.monthYearShort, 'MMM yyyy'),
    'time24': (AppDateFormat.time24, 'HH:mm'),
    'time12': (AppDateFormat.time12, 'hh:mm a'),
    'time12Short': (AppDateFormat.time12Short, 'h:mm a'),
    'dateTime24Seconds': (AppDateFormat.dateTime24Seconds, 'dd MMM yyyy - HH:mm:ss'),
    'dateTime24': (AppDateFormat.dateTime24, 'dd MMM yyyy, HH:mm'),
    'dateTime12': (AppDateFormat.dateTime12, 'dd MMM yyyy, hh:mm a'),
    'dateNoPadTime12Short': (AppDateFormat.dateNoPadTime12Short, 'd MMM yyyy, h:mm a'),
    'dateLongPadded': (AppDateFormat.dateLongPadded, 'EEEE, dd MMM yyyy'),
    'dateWeekdayShort': (AppDateFormat.dateWeekdayShort, 'EEE, dd MMM yyyy'),
    'dateDayTime24': (AppDateFormat.dateDayTime24, 'dd MMM, HH:mm'),
    'dateNoPadY': (AppDateFormat.dateNoPadY, 'd MMM y'),
    'dayMonthNumeric': (AppDateFormat.dayMonthNumeric, 'd/M'),
  };

  for (final entry in cases.entries) {
    test(entry.key, () {
      final (named, legacyPattern) = entry.value;
      expect(named.pattern, legacyPattern);
      for (final m in moments) {
        expect(named.format(m), DateFormat(legacyPattern).format(m), reason: '$m');
      }
    });
  }

  test('a few exact strings', () {
    final m = DateTime(2026, 3, 5, 15, 7, 4);
    expect(AppDateFormat.date.format(m), '05 Mar 2026');
    expect(AppDateFormat.dateTime24.format(m), '05 Mar 2026, 15:07');
    expect(AppDateFormat.time12.format(m), '03:07 PM');
    expect(AppDateFormat.dateLong.format(m), 'Thursday, 5 Mar 2026');
  });
}
