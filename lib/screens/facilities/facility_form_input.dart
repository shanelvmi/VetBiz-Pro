import 'dart:typed_data';

/// What the person entered, as typed: FacilityScreen turns it into today's
/// save (Add: addFacility then the logo; Edit: the facility document, the
/// logo, syncFacilityDetails), so the phone form saves exactly what the
/// dialogs save (test/fixtures/ph8b_saved_facility.json).
class FacilityFormInput {
  final String name;
  final String? type;
  final String typeDetail;
  final Uint8List? logoBytes;
  final bool removeLogo;
  final Map<String, String> texts;
  final String? ownership;
  final String status;
  final String restockFrequency;

  const FacilityFormInput({
    required this.name,
    required this.type,
    required this.typeDetail,
    required this.logoBytes,
    required this.removeLogo,
    required this.texts,
    required this.ownership,
    required this.status,
    required this.restockFrequency,
  });
}
