import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/payment_methods.dart';
import 'package:vetbiz_pro/config/restock_rules.dart';
import 'package:vetbiz_pro/constants/batch_move_reasons.dart';
import 'package:vetbiz_pro/constants/client_options.dart';
import 'package:vetbiz_pro/constants/facility_types.dart';
import 'package:vetbiz_pro/constants/product_categories.dart';
import 'package:vetbiz_pro/constants/product_types.dart';
import 'package:vetbiz_pro/constants/product_units.dart';
import 'package:vetbiz_pro/constants/service_categories.dart';
import 'package:vetbiz_pro/constants/subscription_plans.dart';
import 'package:vetbiz_pro/data/activity_type.dart';
import 'package:vetbiz_pro/data/facility_ownership.dart';
import 'package:vetbiz_pro/data/facility_status.dart';
import 'package:vetbiz_pro/data/membership_history_action.dart';
import 'package:vetbiz_pro/data/payment_status.dart';
import 'package:vetbiz_pro/data/payment_submission_status.dart';
import 'package:vetbiz_pro/data/user_role.dart';
import 'package:vetbiz_pro/data/user_status.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';

import 'stored_labels_check.dart';

/// Display lookups for stored values (docs/PHASE2_LOCALISATION_SPEC.md
/// section 6): every known stored value has a label in both languages, and
/// anything else comes back unchanged.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('product categories', () {
    checkStoredList(StoredValueLabels.productCategory, kProductCategories, (l, v) => l.productCategoryLabel(v),
        extra: const {'Uncategorized': 'Uncategorized'});
  });

  test('product category groups', () {
    checkStoredList(StoredValueLabels.productGroup, kProductCategoryGroups.keys.toList(), (l, v) => l.productGroupLabel(v));
    expect(en.productGroup_veterinary, 'Veterinary');
  });

  test('product types', () {
    checkStoredList(StoredValueLabels.productType, kProductTypes, (l, v) => l.productTypeLabel(v));
  });

  test('product units', () {
    checkStoredList(StoredValueLabels.productUnit, kProductUnits, (l, v) => l.productUnitLabel(v));
  });

  test('service categories', () {
    checkStoredList(StoredValueLabels.serviceCategory, kServiceCategories, (l, v) => l.serviceCategoryLabel(v));
  });

  test('facility types', () {
    checkStoredList(StoredValueLabels.facilityType, kFacilityTypes, (l, v) => l.facilityTypeLabel(v));
  });

  test('payment methods, and On Credit', () {
    checkStoredList(StoredValueLabels.paymentMethod, [for (final m in PaymentMethod.values) m.key, PaymentMethod.onCredit],
        (l, v) => l.paymentMethodLabel(v),
        // R3, D5: Tigo Pesa is shown as Mixx by Yas, never under its old name.
        english: {'Tigo Pesa': 'Mixx by Yas'});
  });

  test('activity types, ignoring case like their readers', () {
    checkStoredList(StoredValueLabels.activityType, [for (final t in ActivityType.values) t.key], (l, v) => l.activityTypeLabel(v));
    expect(en.activityTypeLabel('inventory move'), 'Inventory Move');
  });

  test('restock frequencies', () {
    checkStoredList(StoredValueLabels.restockFrequency, RestockRules.frequencies, (l, v) => l.restockFrequencyLabel(v));
  });

  test('roles, ignoring case like UserRole.fromKey', () {
    checkStoredList(StoredValueLabels.role, [for (final r in UserRole.values) r.key], (l, v) => l.roleLabel(v),
        english: const {'admin': 'Admin', 'assistant': 'Assistant'});
    expect(en.roleLabel('Assistant'), 'Assistant');
    expect(en.role_coAdmin, 'Co-admin');
  });

  test('user statuses', () {
    checkStoredList(StoredValueLabels.userStatus, [for (final s in UserStatus.values) s.key], (l, v) => l.userStatusLabel(v),
        english: const {'pending': 'Pending', 'active': 'Active', 'deactivated': 'Deactivated', 'rejected': 'Rejected'});
  });

  test('membership history actions', () {
    checkStoredList(StoredValueLabels.membershipAction, [for (final a in MembershipHistoryAction.values) a.key],
        (l, v) => l.membershipActionLabel(v),
        english: const {'approved': 'Approved', 'rejected': 'Rejected', 'deactivated': 'Deactivated', 'reactivated': 'Reactivated'});
  });

  test('facility statuses, ignoring case like FacilityStatus.fromKey', () {
    checkStoredList(StoredValueLabels.facilityStatus, [for (final s in FacilityStatus.values) s.key],
        (l, v) => l.facilityStatusLabel(v),
        english: const {'Active': 'Active', 'Inactive': 'Inactive', 'pending': 'Pending'});
    expect(en.facilityStatusLabel('active'), 'Active');
    expect(en.facilityStatusLabel('INACTIVE'), 'Inactive');
    expect(en.facilityStatusLabel('Pending'), 'Pending');
  });

  test('facility ownership', () {
    checkStoredList(StoredValueLabels.facilityOwnership, FacilityOwnership.values, (l, v) => l.facilityOwnershipLabel(v),
        english: const {'Owned': 'Owned', 'Rented': 'Rented'});
  });

  test('payment submission statuses', () {
    checkStoredList(StoredValueLabels.submissionStatus, [for (final s in PaymentSubmissionStatus.values) s.key],
        (l, v) => l.submissionStatusLabel(v),
        english: const {'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected'});
  });

  test('subscription plans, by plan id', () {
    checkStoredList(StoredValueLabels.subscriptionPlan, [for (final p in kSubscriptionPlans) p.id],
        (l, v) => l.subscriptionPlanLabel(v),
        english: {for (final p in kSubscriptionPlans) p.id: p.label});
  });

  test('client types, and the Other shown for a client with no type', () {
    checkStoredList(StoredValueLabels.clientType, kClientTypes, (l, v) => l.clientTypeLabel(v),
        extra: const {kClientTypeOther: 'Other'});
  });

  test('farmer sub-types', () {
    checkStoredList(StoredValueLabels.farmerSubType, kFarmerSubTypes, (l, v) => l.farmerSubTypeLabel(v));
  });

  test('animal species', () {
    checkStoredList(StoredValueLabels.animal, [for (final g in kAnimalGroups.values) ...g], (l, v) => l.animalLabel(v));
  });

  test('animal picker headings', () {
    checkStoredList(StoredValueLabels.animalGroup, kAnimalGroups.keys.toList(), (l, v) => l.animalGroupLabel(v));
  });

  test('vet practice types', () {
    checkStoredList(StoredValueLabels.vetPracticeType, kVetPracticeTypes, (l, v) => l.vetPracticeTypeLabel(v));
  });

  test('client statuses', () {
    checkStoredList(StoredValueLabels.clientStatus, kClientStatuses, (l, v) => l.clientStatusLabel(v));
  });

  test('payment statuses', () {
    checkStoredList(StoredValueLabels.paymentStatus, PaymentStatus.values, (l, v) => l.paymentStatusLabel(v));
  });

  test('batch move reasons', () {
    checkStoredList(StoredValueLabels.batchMoveReason, kBatchMoveReasons, (l, v) => l.batchMoveReasonLabel(v));
  });

  test('debt sources', () {
    // No shared list exists; these are the two values Debt.source holds.
    checkStoredList(StoredValueLabels.debtSource, ['Sale', 'Service'], (l, v) => l.debtSourceLabel(v));
  });
}
