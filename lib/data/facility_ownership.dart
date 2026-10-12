/// A facility's ownership, as stored on `facilities/{id}.ownership` by the
/// Edit Facility dialog. The values are the stored strings and never change;
/// screens show them through `facilityOwnershipLabel`.
class FacilityOwnership {
  FacilityOwnership._();

  static const String owned = 'Owned';
  static const String rented = 'Rented';

  /// The dropdown's choices, in order.
  static const List<String> values = [owned, rented];
}
