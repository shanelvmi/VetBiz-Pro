/// Dotted version numbers ("1.0.0", "1.10.2"), compared number by number, so
/// 1.10.0 is higher than 1.9.0 (a text comparison gets that wrong). Used by
/// the minimum app version gate (P1, `platform_config/settings.minimumVersion`).
class AppVersion {
  AppVersion._();

  static final RegExp _shape = RegExp(r'^\d+(\.\d+)*$');

  /// The numbers of [value], or null when it is not a dotted version
  /// (absent, not a string, empty, "1.0.0-beta", "v1", "1..0").
  static List<int>? parse(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (!_shape.hasMatch(text)) return null;
    return text.split('.').map(int.parse).toList();
  }

  /// Negative when [a] is lower than [b], 0 when equal, positive when higher.
  /// Missing parts count as 0, so 1.0 equals 1.0.0.
  static int compare(List<int> a, List<int> b) {
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  /// True only when both are versions and [running] is lower than
  /// [minimum]. An absent or unreadable minimum never blocks anyone.
  static bool isBelowMinimum(String running, Object? minimum) {
    final min = parse(minimum);
    final run = parse(running);
    if (min == null || run == null) return false;
    return compare(run, min) < 0;
  }
}
