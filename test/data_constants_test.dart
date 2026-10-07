import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/user_role.dart';
import 'package:vetbiz_pro/data/user_status.dart';

/// Stored keys must stay exactly the strings already saved in Firestore, and
/// an unknown value must fall back safely instead of crashing.
void main() {
  test('UserRole keys are the stored strings', () {
    expect(UserRole.values.map((r) => r.key), ['admin', 'assistant']);
  });

  test('UserRole.fromKey round-trips, ignores case, defaults to assistant', () {
    for (final r in UserRole.values) {
      expect(UserRole.fromKey(r.key), r);
    }
    expect(UserRole.fromKey('Admin'), UserRole.admin);
    expect(UserRole.fromKey('owner'), UserRole.assistant);
    expect(UserRole.fromKey(''), UserRole.assistant);
    expect(UserRole.fromKey(null), UserRole.assistant);
  });

  test('UserStatus keys are the stored strings', () {
    expect(UserStatus.values.map((s) => s.key), ['pending', 'active', 'deactivated', 'rejected']);
  });

  test('UserStatus.fromKey round-trips and defaults to pending', () {
    for (final s in UserStatus.values) {
      expect(UserStatus.fromKey(s.key), s);
    }
    expect(UserStatus.fromKey('approved'), UserStatus.pending);
    expect(UserStatus.fromKey(null), UserStatus.pending);
  });
}
