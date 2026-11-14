import 'package:cloud_firestore/cloud_firestore.dart';

/// HUB4: one group of services: the stored service name ([otherKey] for a
/// service saved without one, and for the tail), how many were provided and
/// their revenue. [tail] marks the group of everything after the top ones.
class ServiceSlice {
  final String key;
  final int count;
  final double revenue;
  final bool tail;

  const ServiceSlice(this.key, this.count, this.revenue, {this.tail = false});

  /// The group of services saved without a name, and the tail's key.
  static const String otherKey = 'Other';

  @override
  bool operator ==(Object other) =>
      other is ServiceSlice && other.key == key && other.count == count && other.revenue == revenue && other.tail == tail;

  @override
  int get hashCode => Object.hash(key, count, revenue, tail);

  @override
  String toString() => 'ServiceSlice($key, $count, $revenue${tail ? ', tail' : ''})';
}

/// HUB4: the ONE breakdown of services by type behind Insights' donut and
/// Home's Visit activity donut (the logic Insights had inline): grouped by
/// the stored `name`, the largest revenue first (a tie by count, then by
/// name, so the order is stable), the first [top] groups and then one
/// [ServiceSlice.tail] group summing the rest (none when nothing is left).
/// [since] (inclusive, by `serviceDate`) narrows the window; null keeps
/// every service given (Insights' whole window).
List<ServiceSlice> serviceBreakdownOf(List<Map<String, dynamic>> services, {DateTime? since, int top = 5}) {
  final counts = <String, int>{};
  final revenue = <String, double>{};
  for (final data in services) {
    if (since != null) {
      final at = data['serviceDate'];
      final when = at is Timestamp ? at.toDate() : null;
      if (when == null || when.isBefore(since)) continue;
    }
    final name = data['name'] as String?;
    final key = (name == null || name.isEmpty) ? ServiceSlice.otherKey : name;
    counts[key] = (counts[key] ?? 0) + 1;
    revenue[key] = (revenue[key] ?? 0) + ((data['totalAmount'] as num?)?.toDouble() ?? 0);
  }
  final sorted = [for (final k in counts.keys) ServiceSlice(k, counts[k]!, revenue[k]!)]
    ..sort((a, b) => a.revenue != b.revenue
        ? b.revenue.compareTo(a.revenue)
        : a.count != b.count
            ? b.count.compareTo(a.count)
            : a.key.compareTo(b.key));
  final rest = sorted.skip(top);
  return [
    ...sorted.take(top),
    if (rest.isNotEmpty)
      ServiceSlice(
        ServiceSlice.otherKey,
        rest.fold(0, (n, s) => n + s.count),
        rest.fold(0.0, (n, s) => n + s.revenue),
        tail: true,
      ),
  ];
}
