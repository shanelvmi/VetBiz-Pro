/// Animation durations, and how long a snackbar or toast stays up.
///
/// Only for motion. Network timeouts, debounces and business date ranges are
/// not motion: they live in `lib/config/` (app_timeouts.dart, app_ranges.dart).
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 400);
  static const Duration slowest = Duration(milliseconds: 500);

  /// One cycle of a repeating pulse or shimmer.
  static const Duration loop = Duration(milliseconds: 900);

  static const Duration toastShort = Duration(seconds: 2);
  static const Duration toastLong = Duration(seconds: 3);
}
