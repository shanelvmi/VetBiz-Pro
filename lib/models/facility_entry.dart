import 'package:flutter/foundation.dart';

/// One facility as a user document lists it (`users/{uid}.facilities`), read
/// safely (FX1). Firestore hands back untyped values, and on the web its maps
/// are `Map<dynamic, dynamic>`: a raw value passed where a String is needed
/// (a Text, a cast, a lookup) throws in a release build, where the screen then
/// shows Flutter's grey error box. Every field goes through [safeString].
@immutable
class FacilityEntry {
  final String? id;
  final String? name;
  final String? type;
  final String? typeDetail;

  const FacilityEntry({this.id, this.name, this.type, this.typeDetail});

  /// A String stays a String, a number or a bool becomes its text, anything
  /// else (null, a map, a list) becomes null.
  static String? safeString(Object? value) => throw UnimplementedError();

  /// Null for anything that is not a map. Reads the stored keys (facilityId,
  /// name, type, typeDetail), or the old in-app map's (facilityName,
  /// facilityType, facilityTypeDetail) when those are missing.
  static FacilityEntry? fromObject(Object? value) => throw UnimplementedError();

  /// Every usable entry of [list] (a List of anything): items that are not
  /// maps, or have no id, are dropped with a debugPrint.
  static List<FacilityEntry> listFrom(Object? list) => throw UnimplementedError();

  /// The old map, for the places that still take one
  /// (activateFacilityAndGoToDashboard).
  Map<String, dynamic> toMap() => throw UnimplementedError();
}
