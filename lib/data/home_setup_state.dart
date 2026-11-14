/// HUB4b: where the phone Home's first-time checklist stands for one
/// facility, saved on this device only (never synced) under
/// `ui_home_setup_<facilityId>`. [key] is the stored string and never
/// changes. No value saved: the facility was never seen as new here.
enum HomeSetupState {
  /// Seen as new (no products, no sales held): the card shows until every
  /// step it can check is done.
  started('started'),

  /// The person chose Hide: never shown again for this facility here.
  hidden('hidden'),

  /// Every step it could check was done: never shown again.
  done('done');

  const HomeSetupState(this.key);

  final String key;

  /// The state for a stored value; unknown or missing gives null.
  static HomeSetupState? fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}
