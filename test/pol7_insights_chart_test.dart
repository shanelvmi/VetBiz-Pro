// POL7: Insights' services donut on the one chart palette: drawn as the
// top three by revenue, largest first, then one Other summing the rest
// (the total, and so every share, unchanged).
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/services/service_breakdown.dart';

void main() {
  test('top three by revenue, then one Other with the rest and the given Other', () {
    final given = [
      const MapEntry('Vaccination', 9000.0),
      const MapEntry('Castration', 8000.0),
      const MapEntry('Deworming', 4000.0),
      const MapEntry('Dipping', 1000.0),
      const MapEntry(ServiceSlice.otherKey, 700.0),
    ];
    final drawn = insightsDrawnSlices(given);
    expect([for (final e in drawn) e.key], ['Vaccination', 'Castration', 'Deworming', ServiceSlice.otherKey]);
    expect(drawn.last.value, 1700.0);
    double total(List<MapEntry<String, double>> s) => s.fold(0.0, (n, e) => n + e.value);
    expect(total(drawn), total(given));
  });
}
