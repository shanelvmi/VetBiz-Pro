import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/data/payment_submission_status.dart';
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

  test('PaymentSubmissionStatus keys are the stored strings; unknown is pending', () {
    expect(PaymentSubmissionStatus.values.map((s) => s.key), ['pending', 'approved', 'rejected']);
    for (final s in PaymentSubmissionStatus.values) {
      expect(PaymentSubmissionStatus.fromKey(s.key), s);
    }
    expect(PaymentSubmissionStatus.fromKey('cancelled'), PaymentSubmissionStatus.pending);
    expect(PaymentSubmissionStatus.fromKey(null), PaymentSubmissionStatus.pending);
  });

  test('ActivityType keys are the stored actionType strings', () {
    expect(ActivityType.values.map((t) => t.key), [
      'Account', 'Debtors', 'Products', 'Inventory Move', 'Sales', 'Sale',
      'Services', 'Transactions', 'Trash', 'Report Draft Deleted',
    ]);
  });

  test('UserStatus.fromKey round-trips and defaults to pending', () {
    for (final s in UserStatus.values) {
      expect(UserStatus.fromKey(s.key), s);
    }
    expect(UserStatus.fromKey('approved'), UserStatus.pending);
    expect(UserStatus.fromKey(null), UserStatus.pending);
  });
}
