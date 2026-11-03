import '../../config/app_date_format.dart';
import '../../l10n/l10n.dart';

// PH5a R5 (docs/design/phone_list_pattern.md): a phone list's rows under one
// header per day, each with that day's total once the day is fully loaded.

/// One day's rows, newest first as the list gives them.
class DayGroup<T> {
  /// Midnight of the day.
  final DateTime day;
  final List<T> items;

  /// The sum of the day's amounts; null while the day may continue on a page
  /// not loaded yet (never a partial total).
  final double? total;

  const DayGroup(this.day, this.items, this.total);
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// [items] (newest first, as the lists' queries order them) cut into days, or
/// into months when [byMonth] (PH7b: Past Reports, one report a day; a
/// group's day is then the first of its month).
/// [complete] says no further page exists: without it, the last day may go
/// on in the next page, so it gets no total.
List<DayGroup<T>> groupByDay<T>(
  List<T> items, {
  required DateTime Function(T item) dateOf,
  required double Function(T item) amountOf,
  required bool complete,
  bool byMonth = false,
}) {
  final days = <(DateTime, List<T>)>[];
  for (final item in items) {
    final date = dateOf(item);
    final day = byMonth ? DateTime(date.year, date.month) : _midnight(date);
    if (days.isEmpty || days.last.$1 != day) {
      days.add((day, <T>[]));
    }
    days.last.$2.add(item);
  }
  return [
    for (var i = 0; i < days.length; i++)
      DayGroup(
        days[i].$1,
        List.unmodifiable(days[i].$2),
        complete || i < days.length - 1 ? days[i].$2.fold<double>(0, (sum, item) => sum + amountOf(item)) : null,
      ),
  ];
}

/// "Today", "Yesterday", then the weekday and date ("Monday, 27 Oct").
String dayHeaderLabel(AppLocalizations l, DateTime day, {DateTime? now}) {
  final today = _midnight(now ?? DateTime.now());
  final d = _midnight(day);
  if (d == today) return l.common_today;
  if (d == DateTime(today.year, today.month, today.day - 1)) return l.common_yesterday;
  return AppDateFormat.weekdayDayMonth.format(d);
}

/// A day as "2026-11-02", for keys.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
