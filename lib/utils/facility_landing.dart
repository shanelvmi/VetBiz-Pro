/// UX9: where a signed-in person lands, by how many facilities they have.
/// The one rule the login decision (main.dart) and owner registration
/// (register_screen.dart) both follow, so it can be tested: exactly one
/// facility goes straight into it and NEVER sees the Select Facility screen.
enum FacilityLanding {
  /// No facility: the no-facility screen (or a Platform Admin's home).
  none,

  /// Exactly one: straight to that facility's dashboard.
  straightIn,

  /// Two or more: the Select Facility screen.
  picker,
}

FacilityLanding facilityLandingFor(int facilityCount) => switch (facilityCount) {
      <= 0 => FacilityLanding.none,
      1 => FacilityLanding.straightIn,
      _ => FacilityLanding.picker,
    };
