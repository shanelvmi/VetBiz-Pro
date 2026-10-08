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

  /// The dashboard's slow repeating colour cycle (dashboard_screen.dart).
  static const Duration colorCycle = Duration(milliseconds: 1400);

  /// A one-shot emphasis: an entrance, or a flash when a value changes.
  static const Duration emphasis = Duration(milliseconds: 900);

  /// One cycle of a slow, gentle repeating float or pulse.
  static const Duration float = Duration(milliseconds: 1400);

  /// One cycle of the maintenance screen's slow breathing pulse.
  static const Duration pulseSlow = Duration(seconds: 2);

  static const Duration toastShort = Duration(seconds: 2);
  static const Duration toastLong = Duration(seconds: 3);

  /// How long each AppFeedback type stays up (PHASE2_FEEDBACK_SPEC section
  /// 3). toastShort and toastLong go once nothing uses them.
  static const Duration toastSuccess = Duration(seconds: 3);
  static const Duration toastInfo = Duration(seconds: 4);
  static const Duration toastWarning = Duration(seconds: 5);
  static const Duration toastUndo = Duration(seconds: 6);
  static const Duration toastError = Duration(seconds: 7);
}
