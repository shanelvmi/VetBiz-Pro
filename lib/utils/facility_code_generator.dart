import 'dart:math';

// Shared between registration and the Facilities screen's "Add
// Facility" action - both need to generate a facility's own permanent
// code the same way, so this lives in one place rather than as a
// private method duplicated inside each screen's state class.
String _randomFacilityCode({int length = 8}) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
  );
}

/// Generates a facility code.
///
/// This used to query the facilities collection to confirm the code wasn't
/// already taken. That can no longer work, and shouldn't: facilities are only
/// readable by their own members (and Platform Admins), so a lookup of
/// "any facility with this code" is - correctly - refused. During
/// registration the person isn't even signed in yet, so Add Facility simply
/// did nothing; for a signed-in admin the same query was refused too.
///
/// Dropping the check is safe because the code is no longer a credential:
/// joining a facility goes through short-lived invite codes, and the
/// permanent code can't be used to join anything. It's an identifier, and
/// 8 random characters give 36^8 (about 2.8 trillion) possibilities - a
/// collision across even tens of thousands of facilities is vanishingly
/// unlikely, and harmless if it ever happened.
///
/// Still async, and still named for what callers expect, so they didn't need
/// to change.
Future<String> generateUniqueFacilityCode({int length = 8}) async {
  return _randomFacilityCode(length: length);
}
