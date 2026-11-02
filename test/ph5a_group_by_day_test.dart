// PH5a R5: groupByDay cuts a newest-first list into days with their totals;
// the last day gets none while a further page may continue it.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations_en.dart';
import 'package:vetbiz_pro/widgets/phone_list/group_by_day.dart';

typedef _R = (DateTime, double);

void main() {
  final now = DateTime(2026, 11, 2, 15, 30);
  final rows = <_R>[
    (DateTime(2026, 11, 2, 14), 1000),
    (DateTime(2026, 11, 2, 9), 500),
    (DateTime(2026, 11, 1, 18), 250),
    (DateTime(2026, 10, 27, 10, 15), 4000),
    (DateTime(2026, 10, 27, 8), 100),
  ];
  List<DayGroup<_R>> group(List<_R> items, {required bool complete}) =>
      groupByDay(items, dateOf: (r) => r.$1, amountOf: (r) => r.$2, complete: complete);

  test('one group per day in order, each with its rows and total', () {
    final groups = group(rows, complete: true);
    expect([for (final g in groups) g.day], [DateTime(2026, 11, 2), DateTime(2026, 11, 1), DateTime(2026, 10, 27)]);
    expect([for (final g in groups) g.items.length], [2, 1, 2]);
    expect([for (final g in groups) g.total], [1500, 250, 4100]);
  });

  test('more pages to come: the last day has no total, the others keep theirs', () {
    final groups = group(rows, complete: false);
    expect([for (final g in groups) g.total], [1500, 250, null]);
    expect(group(rows.take(2).toList(), complete: false).single.total, isNull);
  });

  test('an empty list has no groups', () {
    expect(group(const [], complete: true), isEmpty);
    expect(group(const [], complete: false), isEmpty);
  });

  test('headers: Today, Yesterday, then the weekday and date; keys as yyyy-MM-dd', () {
    final l = AppLocalizationsEn();
    expect(dayHeaderLabel(l, DateTime(2026, 11, 2, 1), now: now), 'Today');
    expect(dayHeaderLabel(l, DateTime(2026, 11, 1, 23), now: now), 'Yesterday');
    expect(dayHeaderLabel(l, DateTime(2026, 10, 27), now: now), 'Tuesday, 27 Oct');
    expect(dayHeaderLabel(l, DateTime(2026, 10, 31), now: DateTime(2026, 11, 1)), 'Yesterday');
    expect(dayKey(DateTime(2026, 3, 4, 22)), '2026-03-04');
  });
}
