/// HUB2: what the phone Home card shows, the switch at its top, saved on the
/// device under `ui_home_card_mode`. [key] is the stored string and never
/// changes; what is shown comes from the ARB.
enum HomeCardMode {
  sales('sales'),
  services('services');

  const HomeCardMode(this.key);

  final String key;

  /// Sales until the person chooses.
  static const HomeCardMode defaultMode = sales;

  /// The choice for a stored value. Unknown or missing gives [defaultMode].
  static HomeCardMode fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return defaultMode;
  }
}
