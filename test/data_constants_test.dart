import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/data/facility_status.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/data/membership_history_action.dart';
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

  test("old 'Sale' entries read as 'Sales'; other types are unchanged", () {
    expect(ActivityType.canonicalKey('Sale'), 'Sales');
    expect(ActivityType.canonicalKey('sale'), 'Sales');
    expect(ActivityType.canonicalKey('Sales'), 'Sales');
    expect(ActivityType.canonicalKey('Services'), 'Services');
    expect(ActivityType.canonicalKey('Unknown'), 'Unknown');
  });

  test('UserStatus.fromKey round-trips and defaults to pending', () {
    for (final s in UserStatus.values) {
      expect(UserStatus.fromKey(s.key), s);
    }
    expect(UserStatus.fromKey('approved'), UserStatus.pending);
    expect(UserStatus.fromKey(null), UserStatus.pending);
  });

  test('FacilityStatus keys are the stored strings; reading ignores case', () {
    expect(FacilityStatus.values.map((s) => s.key), ['Active', 'Inactive', 'pending']);
    expect(FacilityStatus.fromKey('Active'), FacilityStatus.active);
    expect(FacilityStatus.fromKey('active'), FacilityStatus.active);
    expect(FacilityStatus.fromKey('INACTIVE'), FacilityStatus.inactive);
    expect(FacilityStatus.fromKey('Pending'), FacilityStatus.pending);
    expect(FacilityStatus.fromKey(null), FacilityStatus.active);
    expect(FacilityStatus.fromKey('closed'), isNull);
  });
  test('Fields.active is the stored promotions field name', () {
    // Stored on every promotions/{id} and queried by name: never rename.
    expect(Fields.active, 'active');
  });
  test('MembershipHistoryAction.fromKey reads stored history keys', () {
    for (final a in MembershipHistoryAction.values) {
      expect(MembershipHistoryAction.fromKey(a.key), a);
    }
    expect(MembershipHistoryAction.fromKey('approve'), isNull, reason: 'a request is not a stored key');
    expect(MembershipHistoryAction.fromKey(null), isNull);
  });
}
