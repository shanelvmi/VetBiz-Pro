// FN1 (docs/design/facility_name_display.md): a facility's name is shown
// exactly as the customer typed it, on every receipt, PDF, report, header
// and dropdown. It is never joined with the facility type: customers name
// their business freely ("Ukuli Animal Care"), and the app used to print
// names such as "Ukuli Animal Care Agrovet". The type is only a tag, in
// the facility picker, the Facilities cards and the business profile.
class FacilityDisplay {
  FacilityDisplay._();

  /// The facility's name as typed, trimmed, or [fallback] when there is none.
  /// Never adds the type.
  static String name(String? rawName, {String fallback = ''}) {
    throw UnimplementedError('FN1');
  }
}
