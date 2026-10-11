import '../config/payment_methods.dart';
import '../config/restock_rules.dart';
import '../data/activity_type.dart';
import '../data/facility_status.dart';
import '../data/membership_history_action.dart';
import '../data/payment_submission_status.dart';
import '../data/user_role.dart';
import '../data/user_status.dart';
import 'app_localizations.dart';

/// How one stored value is shown, in the language of [l].
typedef StoredLabel = String Function(AppLocalizations l);

/// The labels of one list of values that are stored in Firestore as English
/// text (docs/PHASE2_LOCALISATION_SPEC.md section 6).
///
/// Only what is SHOWN is translated. Dropdowns, filters and chips keep saving
/// and comparing the stored value, and pass it through here to show it. A
/// value the table doesn't know (a custom category, an old record) comes back
/// unchanged, never blank.
class StoredLabelTable {
  StoredLabelTable(this.labels, {this.ignoreCase = false})
      : _lookup = ignoreCase ? {for (final e in labels.entries) e.key.toLowerCase(): e.value} : labels;

  /// Stored value -> its label, in the list's own order.
  final Map<String, StoredLabel> labels;

  /// Match ignoring case, for lists the app's readers compare that way.
  final bool ignoreCase;

  final Map<String, StoredLabel> _lookup;

  String labelOf(AppLocalizations l, String stored) => _lookup[ignoreCase ? stored.toLowerCase() : stored]?.call(l) ?? stored;
}

/// One table per stored list. The keys are the stored values exactly as
/// saved; test/stored_labels_test.dart checks each table against its list.
class StoredValueLabels {
  StoredValueLabels._();

  static final productCategory = StoredLabelTable({
    'Antibiotic': (l) => l.productCategory_antibiotic,
    'Anthelmintics': (l) => l.productCategory_anthelmintics,
    'Vitamin & Supplements': (l) => l.productCategory_vitaminsSupplements,
    'Hormones & Reproductive': (l) => l.productCategory_hormonesReproductive,
    'Vaccines': (l) => l.productCategory_vaccines,
    'Disinfectant': (l) => l.productCategory_disinfectant,
    'Feeds': (l) => l.productCategory_feeds,
    'Anti-inflammatory': (l) => l.productCategory_antiInflammatory,
    'Ectoparasiticides': (l) => l.productCategory_ectoparasiticides,
    'Wound Management': (l) => l.productCategory_woundManagement,
    'Surgical Supplies': (l) => l.productCategory_surgicalSupplies,
    'Farm Tools & Equipment': (l) => l.productCategory_farmToolsEquipment,
    'Seeds': (l) => l.productCategory_seeds,
    'Fertilizers': (l) => l.productCategory_fertilizers,
    'Crop Pesticides': (l) => l.productCategory_cropPesticides,
    'Miscellaneous': (l) => l.productCategory_miscellaneous,
    // Not stored: what the product lists group a product with no category under.
    'Uncategorized': (l) => l.productCategory_uncategorized,
  });

  /// The department groups of the category filter (kProductCategoryGroups).
  /// Not stored, but compared by name, so they go through a table too.
  static final productGroup = StoredLabelTable({
    'Vet': (l) => l.productGroup_vet,
    'Agro': (l) => l.productGroup_agro,
    'Miscellaneous': (l) => l.productCategory_miscellaneous,
  });

  static final productType = StoredLabelTable({
    'Injectable': (l) => l.productType_injectable,
    'Oral Liquid': (l) => l.productType_oralLiquid,
    'Powder': (l) => l.productType_powder,
    'Tablet/Bolus': (l) => l.productType_tabletBolus,
    'Topical': (l) => l.productType_topical,
    'Intramammary': (l) => l.productType_intramammary,
    'Spray': (l) => l.productType_spray,
    'Granules': (l) => l.productType_granules,
    'Wettable Powder': (l) => l.productType_wettablePowder,
    'Emulsifiable Concentrate': (l) => l.productType_emulsifiableConcentrate,
    'Seed': (l) => l.productType_seed,
    'Fertilizer': (l) => l.productType_fertilizer,
    'Feed': (l) => l.productType_feed,
    'Equipment': (l) => l.productType_equipment,
    'Other': (l) => l.productType_other,
  });

  static final productUnit = StoredLabelTable({
    'pcs': (l) => l.unit_pcs,
    'kg': (l) => l.unit_kg,
    'g': (l) => l.unit_g,
    'litres': (l) => l.unit_litres,
    'ml': (l) => l.unit_ml,
    'vials': (l) => l.unit_vials,
    'ampoules': (l) => l.unit_ampoules,
    'bottles': (l) => l.unit_bottles,
    'sachets': (l) => l.unit_sachets,
    'sacks': (l) => l.unit_sacks,
    'bags': (l) => l.unit_bags,
    'boxes': (l) => l.unit_boxes,
    'cartons': (l) => l.unit_cartons,
    'packs': (l) => l.unit_packs,
    'strips': (l) => l.unit_strips,
    'tablets': (l) => l.unit_tablets,
    'tubes': (l) => l.unit_tubes,
    'rolls': (l) => l.unit_rolls,
    'pairs': (l) => l.unit_pairs,
    'others': (l) => l.unit_others,
  });

  static final serviceCategory = StoredLabelTable({
    'Surgical': (l) => l.serviceCategory_surgical,
    'Treatment': (l) => l.serviceCategory_treatment,
    'Management': (l) => l.serviceCategory_management,
    'Consultation': (l) => l.serviceCategory_consultation,
    'Diagnostics': (l) => l.serviceCategory_diagnostics,
    'Preventive': (l) => l.serviceCategory_preventive,
    'Other': (l) => l.serviceCategory_other,
  });

  static final facilityType = StoredLabelTable({
    'Agrovet': (l) => l.facilityType_agrovet,
    'Vet Clinic': (l) => l.facilityType_vetClinic,
    'Vet Hospital': (l) => l.facilityType_vetHospital,
    'Ambulatory Vet': (l) => l.facilityType_ambulatoryVet,
    'Other': (l) => l.facilityType_other,
  });

  static final paymentMethod = StoredLabelTable({
    PaymentMethod.cash.key: (l) => l.paymentMethod_cash,
    PaymentMethod.mPesa.key: (l) => l.paymentMethod_mPesa,
    PaymentMethod.mixxByYas.key: (l) => l.paymentMethod_mixxByYas,
    PaymentMethod.haloPesa.key: (l) => l.paymentMethod_haloPesa,
    PaymentMethod.airtelMoney.key: (l) => l.paymentMethod_airtelMoney,
    PaymentMethod.bankTransfer.key: (l) => l.paymentMethod_bankTransfer,
    PaymentMethod.tigoPesa.key: (l) => l.paymentMethod_tigoPesa,
    PaymentMethod.onCredit: (l) => l.paymentMethod_onCredit,
  });

  /// Readers compare activity types ignoring case (see ActivityType).
  static final activityType = StoredLabelTable({
    ActivityType.account.key: (l) => l.activityType_account,
    ActivityType.debtors.key: (l) => l.activityType_debtors,
    ActivityType.products.key: (l) => l.activityType_products,
    ActivityType.inventoryMove.key: (l) => l.activityType_inventoryMove,
    ActivityType.sales.key: (l) => l.activityType_sales,
    ActivityType.sale.key: (l) => l.activityType_sale,
    ActivityType.services.key: (l) => l.activityType_services,
    ActivityType.transactions.key: (l) => l.activityType_transactions,
    ActivityType.trash.key: (l) => l.activityType_trash,
    ActivityType.reportDraftDeleted.key: (l) => l.activityType_reportDraftDeleted,
  }, ignoreCase: true);

  static final restockFrequency = StoredLabelTable({
    RestockRules.weekly: (l) => l.restockFrequency_weekly,
    RestockRules.everyTwoWeeks: (l) => l.restockFrequency_everyTwoWeeks,
    RestockRules.monthly: (l) => l.restockFrequency_monthly,
    RestockRules.rarely: (l) => l.restockFrequency_rarely,
  });

  /// UserRole.fromKey ignores case, so this does too. "Co-admin" is not a
  /// stored role: it is l.role_coAdmin, chosen by the screen.
  static final role = StoredLabelTable({
    UserRole.admin.key: (l) => l.role_admin,
    UserRole.assistant.key: (l) => l.role_assistant,
  }, ignoreCase: true);

  static final userStatus = StoredLabelTable({
    UserStatus.pending.key: (l) => l.userStatus_pending,
    UserStatus.active.key: (l) => l.userStatus_active,
    UserStatus.deactivated.key: (l) => l.userStatus_deactivated,
    UserStatus.rejected.key: (l) => l.userStatus_rejected,
  });

  static final membershipAction = StoredLabelTable({
    MembershipHistoryAction.approved.key: (l) => l.membershipAction_approved,
    MembershipHistoryAction.rejected.key: (l) => l.membershipAction_rejected,
    MembershipHistoryAction.deactivated.key: (l) => l.membershipAction_deactivated,
    MembershipHistoryAction.reactivated.key: (l) => l.membershipAction_reactivated,
  });

  /// Some older facilities hold lower-case values; FacilityStatus.fromKey
  /// ignores case, so this does too.
  static final facilityStatus = StoredLabelTable({
    FacilityStatus.active.key: (l) => l.facilityStatus_active,
    FacilityStatus.inactive.key: (l) => l.facilityStatus_inactive,
    FacilityStatus.pending.key: (l) => l.facilityStatus_pending,
  }, ignoreCase: true);

  static final submissionStatus = StoredLabelTable({
    PaymentSubmissionStatus.pending.key: (l) => l.submissionStatus_pending,
    PaymentSubmissionStatus.approved.key: (l) => l.submissionStatus_approved,
    PaymentSubmissionStatus.rejected.key: (l) => l.submissionStatus_rejected,
  });

  /// Keyed by plan id (kSubscriptionPlans), which is what identifies a plan.
  /// The English planLabel saved on a payment submission stays as saved.
  static final subscriptionPlan = StoredLabelTable({
    'daily': (l) => l.plan_daily,
    'weekly': (l) => l.plan_weekly,
    'monthly': (l) => l.plan_monthly,
    'yearly': (l) => l.plan_yearly,
  });
}

/// `context.l10n.productCategoryLabel(stored)` in widgets,
/// `L10n.current.productCategoryLabel(stored)` elsewhere.
extension StoredLabels on AppLocalizations {
  String productCategoryLabel(String stored) => StoredValueLabels.productCategory.labelOf(this, stored);
  String productGroupLabel(String stored) => StoredValueLabels.productGroup.labelOf(this, stored);
  String productTypeLabel(String stored) => StoredValueLabels.productType.labelOf(this, stored);
  String productUnitLabel(String stored) => StoredValueLabels.productUnit.labelOf(this, stored);
  String serviceCategoryLabel(String stored) => StoredValueLabels.serviceCategory.labelOf(this, stored);
  String facilityTypeLabel(String stored) => StoredValueLabels.facilityType.labelOf(this, stored);
  String paymentMethodLabel(String stored) => StoredValueLabels.paymentMethod.labelOf(this, stored);
  String activityTypeLabel(String stored) => StoredValueLabels.activityType.labelOf(this, stored);
  String restockFrequencyLabel(String stored) => StoredValueLabels.restockFrequency.labelOf(this, stored);
  String roleLabel(String stored) => StoredValueLabels.role.labelOf(this, stored);
  String userStatusLabel(String stored) => StoredValueLabels.userStatus.labelOf(this, stored);
  String membershipActionLabel(String stored) => StoredValueLabels.membershipAction.labelOf(this, stored);
  String facilityStatusLabel(String stored) => StoredValueLabels.facilityStatus.labelOf(this, stored);
  String submissionStatusLabel(String stored) => StoredValueLabels.submissionStatus.labelOf(this, stored);
  String subscriptionPlanLabel(String planId) => StoredValueLabels.subscriptionPlan.labelOf(this, planId);
}
