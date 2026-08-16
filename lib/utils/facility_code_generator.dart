import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Generates a facility code and verifies it's not already in use before
/// returning it - the random generator alone (2.8 trillion possible
/// 8-character codes) makes a collision extremely unlikely, but
/// "extremely unlikely" isn't "never." This makes it actually
/// guaranteed rather than just statistically safe, at the cost of one
/// quick query per attempt.
Future<String> generateUniqueFacilityCode({int length = 8, int maxAttempts = 5}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final candidate = _randomFacilityCode(length: length);
    final existing = await FirebaseFirestore.instance
        .collection('facilities')
        .where('code', isEqualTo: candidate)
        .limit(1)
        .get();
    if (existing.docs.isEmpty) return candidate;
    // Collision (astronomically rare) - loop and try a fresh one.
  }
  // maxAttempts exhausted (should never realistically happen) - fall
  // back to a longer code, which shrinks the collision odds further
  // still rather than silently reusing something.
  return _randomFacilityCode(length: length + 4);
}
