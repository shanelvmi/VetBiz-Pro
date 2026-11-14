/// HUB4: the span of Home's three chart pages, the small 7d | 30d switch in
/// the carousel's header, saved on the device under `ui_home_chart_range`
/// (one choice for all three pages). [key] is the stored string and never
/// changes; what is shown comes from the ARB.
enum HomeChartRange {
  week('7d', 7),
  month('30d', 30);

  const HomeChartRange(this.key, this.days);

  final String key;

  /// The days a page covers, today last.
  final int days;

  /// The last 7 days until the person chooses.
  static const HomeChartRange defaultRange = week;

  /// The choice for a stored value. Unknown or missing gives [defaultRange].
  static HomeChartRange fromKey(String? key) {
    for (final r in values) {
      if (r.key == key) return r;
    }
    return defaultRange;
  }
}
