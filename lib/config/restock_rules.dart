/// The day-counts behind each restock frequency a facility admin can choose.
///
/// Copied exactly from `UsageCalculatorService._dayCountsByFrequency`, which
/// moves onto this table in step 2C. The frequency names are stored on the
/// facility, so they are keys and never change.
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

class RestockRules {
  RestockRules._();

  static const String weekly = 'Weekly';
  static const String everyTwoWeeks = 'Every 2 Weeks';
  static const String monthly = 'Monthly';
  static const String rarely = 'Rarely';

  /// The default for a facility that hasn't chosen.
  static const String defaultFrequency = everyTwoWeeks;

  static const List<String> frequencies = [weekly, everyTwoWeeks, monthly, rarely];

  static const Map<String, RestockDayCounts> dayCountsByFrequency = {
    weekly: RestockDayCounts(shelfMinDays: 2, lowStockDays: 5, reorderDays: 7),
    everyTwoWeeks: RestockDayCounts(shelfMinDays: 3, lowStockDays: 7, reorderDays: 14),
    monthly: RestockDayCounts(shelfMinDays: 5, lowStockDays: 10, reorderDays: 21),
    rarely: RestockDayCounts(shelfMinDays: 7, lowStockDays: 14, reorderDays: 30),
  };
}
