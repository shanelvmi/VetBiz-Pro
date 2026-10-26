import '../config/app_limits.dart';

// Shared between registration (add a facility while signing up) and
// the Facilities screen (add a facility to an existing account) - kept
// in one place so the two forms can never quietly drift into offering
// different type options.
const List<String> kFacilityTypes = [
  'Agrovet',
  'Vet Clinic',
  'Vet Hospital',
  'Ambulatory Vet',
  'Other',
];

/// The stored type whose facility carries the owner's own words
/// (typeDetail, RW2b2), shown instead of "Other".
const String kFacilityTypeOther = 'Other';

/// What is wrong with a typed typeDetail.
enum TypeDetailIssue { required, length, characters }

/// The server's rule for typeDetail (cleanTypeDetail in
/// functions/membership.js): trimmed, AppLimits.typeDetailMin to
/// AppLimits.typeDetailMax characters, letters of any language, digits,
/// spaces and . , & ' - only. Null when it is fine.
TypeDetailIssue? typeDetailIssue(String typed) {
  final text = typed.trim();
  if (text.isEmpty) return TypeDetailIssue.required;
  if (text.length < AppLimits.typeDetailMin || text.length > AppLimits.typeDetailMax) return TypeDetailIssue.length;
  if (!_typeDetailPattern.hasMatch(text)) return TypeDetailIssue.characters;
  return null;
}

final RegExp _typeDetailPattern = RegExp(r"^[\p{L}\p{N} .,&'\-]+$", unicode: true);
