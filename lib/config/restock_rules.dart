/// The three day-counts a single restock frequency choice maps to.
class RestockDayCounts {
  final int shelfMinDays;
  final int lowStockDays;
  final int reorderDays;

  const RestockDayCounts({
    required this.shelfMinDays,
    required this.lowStockDays,
    required this.reorderDays,
  });
}

/// The numbers behind usage-based stock suggestions
/// (UsageCalculatorService). Moved here unchanged in step 2C.
///
/// The frequency names are stored on the facility, so they are keys and
/// never change.
class RestockRules {
  RestockRules._();

  static const String weekly = 'Weekly';
  static const String everyTwoWeeks = 'Every 2 Weeks';
  static const String monthly = 'Monthly';
  static const String rarely = 'Rarely';

  /// The default for a facility that hasn't chosen.
  static const String defaultFrequency = everyTwoWeeks;

  static const List<String> frequencies = [weekly, everyTwoWeeks, monthly, rarely];

  /// Days of typical usage each threshold represents, per restock
  /// frequency a facility's admin can choose in Facility settings.
  /// Deliberately expressed as a simple, real-world choice ("how often
  /// do you typically restock") rather than asking an admin to type raw
  /// day-counts directly - most people don't think in exact numbers of
  /// days, but do know their own restocking rhythm. "Every 2 Weeks" is
  /// the default (matches this feature's original starting numbers)
  /// for any facility that hasn't set a preference.
  static const Map<String, RestockDayCounts> dayCountsByFrequency = {
    weekly: RestockDayCounts(shelfMinDays: 2, lowStockDays: 5, reorderDays: 7),
    everyTwoWeeks: RestockDayCounts(shelfMinDays: 3, lowStockDays: 7, reorderDays: 14),
    monthly: RestockDayCounts(shelfMinDays: 5, lowStockDays: 10, reorderDays: 21),
    rarely: RestockDayCounts(shelfMinDays: 7, lowStockDays: 14, reorderDays: 30),
  };

  /// How many days of past sales/service history to average usage over.
  /// 30 days is a reasonable starting point: short enough to react to a
  /// real change in how a product moves, long enough that one unusually
  /// busy or quiet week doesn't skew the number on its own.
  static const int usageLookbackDays = 30;
  static const Duration usageLookback = Duration(days: usageLookbackDays);

  /// A product needs to have moved at least this many total units over
  /// the lookback window before its calculated usage is trusted. Below
  /// this, there's too little real history to build a meaningful number
  /// from, so the product is left alone entirely - its effective*
  /// getters keep falling back to the flat shared default instead of
  /// being given a suggestion built on almost nothing.
  static const int minUnitsForConfidence = 3;
}
