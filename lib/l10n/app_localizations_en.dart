// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get common_language => 'Language';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_remove => 'Remove';

  @override
  String get common_close => 'Close';

  @override
  String get common_ok => 'OK';

  @override
  String get common_yes => 'Yes';

  @override
  String get common_no => 'No';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_done => 'Done';

  @override
  String get common_apply => 'Apply';

  @override
  String get common_reset => 'Reset';

  @override
  String get common_refresh => 'Refresh';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_tryAgain => 'Try Again';

  @override
  String get common_undo => 'Undo';

  @override
  String get common_details => 'Details';

  @override
  String get common_viewDetails => 'View Details';

  @override
  String get common_copy => 'Copy';

  @override
  String get common_share => 'Share';

  @override
  String get common_print => 'Print';

  @override
  String get common_search => 'Search';

  @override
  String get common_add => 'Add';

  @override
  String get common_clear => 'Clear';

  @override
  String get common_change => 'Change';

  @override
  String get common_call => 'Call';

  @override
  String get common_moreActions => 'More actions';

  @override
  String get common_loading => 'Loading…';

  @override
  String get common_optional => 'Optional';

  @override
  String get common_all => 'All';

  @override
  String get common_date => 'Date';

  @override
  String get common_amount => 'Amount';

  @override
  String get common_total => 'Total';

  @override
  String get common_status => 'Status';

  @override
  String get common_type => 'Type';

  @override
  String get common_email => 'Email';

  @override
  String get common_password => 'Password';

  @override
  String get common_notes => 'Notes';

  @override
  String get error_generic => 'Something went wrong. Try again.';

  @override
  String get error_noPermission => 'You don\'t have permission to do that.';

  @override
  String get error_noConnection =>
      'No connection. Check your internet and try again.';

  @override
  String get error_tooSlow => 'That took too long. Try again.';

  @override
  String get error_notFound => 'That item no longer exists.';

  @override
  String get error_alreadyExists => 'That already exists.';

  @override
  String get error_rateLimited =>
      'Too many requests. Wait a moment and try again.';

  @override
  String get login_wrongCredentials => 'Incorrect email or password.';

  @override
  String get login_accountDisabled =>
      'This account has been disabled. Contact your admin.';

  @override
  String get login_tooManyAttempts =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get login_signInFailed => 'Couldn\'t sign in. Try again.';

  @override
  String get common_facility => 'Facility';

  @override
  String get common_signOut => 'Sign out';

  @override
  String get common_hideDetails => 'Hide details';

  @override
  String get dateRange_title => 'Select Date Range';

  @override
  String get dateRange_start => 'Start Date:';

  @override
  String get dateRange_end => 'End Date:';

  @override
  String get error_couldNotLoad => 'Could not load data';

  @override
  String get error_indexNeeded =>
      'This view needs a one-time database index to be created first.';

  @override
  String get error_createIndex => 'Create Missing Index';

  @override
  String get error_createIndexHint =>
      'This opens Firebase Console with the exact index needed already filled in.';

  @override
  String get maintenance_title => 'We\'ll be right back';

  @override
  String get maintenance_defaultMessage =>
      'We\'re currently performing scheduled maintenance. Please try again shortly.';

  @override
  String get time_justNow => 'Just now';

  @override
  String time_minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String time_hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String time_daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get payments_method => 'Payment Method';

  @override
  String get products_categoriesHeading => 'CATEGORIES';

  @override
  String get products_stockStatusHeading => 'STOCK STATUS';

  @override
  String get products_allProducts => 'All Products';

  @override
  String get products_statusAll => 'All Status';

  @override
  String get products_statusInStock => 'In Stock';

  @override
  String get products_statusLowStock => 'Low Stock';

  @override
  String get products_statusReorderSoon => 'Reorder Soon';

  @override
  String get products_statusDepleted => 'Depleted';

  @override
  String get products_statusExpired => 'Expired';

  @override
  String get summary_trendNew => 'New';

  @override
  String get loading_accountTitle => 'Loading your account...';

  @override
  String get loading_accountSubtitle =>
      'Preparing your facility data and services';

  @override
  String facilities_settingUp(String facilityName) {
    return 'Setting up $facilityName...';
  }

  @override
  String get facilities_yourFacility => 'your facility';

  @override
  String get subscription_expiredTitle => 'Subscription Expired';

  @override
  String get subscription_expiredAssistant =>
      'This facility\'s subscription has expired, so new sales and services can\'t be recorded right now. You can still view all existing data. Please ask your admin to renew the subscription.';

  @override
  String get subscription_expiredAdmin =>
      'Your subscription has expired, so new sales and services can\'t be recorded right now. You can still view all your existing data. Submit a payment to restore full access.';

  @override
  String get subscription_goTo => 'Go to Subscription';

  @override
  String get productCategory_antibiotic => 'Antibiotic';

  @override
  String get productCategory_anthelmintics => 'Anthelmintics';

  @override
  String get productCategory_vitaminsSupplements => 'Vitamin & Supplements';

  @override
  String get productCategory_hormonesReproductive => 'Hormones & Reproductive';

  @override
  String get productCategory_vaccines => 'Vaccines';

  @override
  String get productCategory_disinfectant => 'Disinfectant';

  @override
  String get productCategory_feeds => 'Feeds';

  @override
  String get productCategory_antiInflammatory => 'Anti-inflammatory';

  @override
  String get productCategory_ectoparasiticides => 'Ectoparasiticides';

  @override
  String get productCategory_woundManagement => 'Wound Management';

  @override
  String get productCategory_surgicalSupplies => 'Surgical Supplies';

  @override
  String get productCategory_farmToolsEquipment => 'Farm Tools & Equipment';

  @override
  String get productCategory_seeds => 'Seeds';

  @override
  String get productCategory_fertilizers => 'Fertilizers';

  @override
  String get productCategory_cropPesticides => 'Crop Pesticides';

  @override
  String get productCategory_miscellaneous => 'Miscellaneous';

  @override
  String get productCategory_uncategorized => 'Uncategorized';

  @override
  String get productGroup_vet => 'Vet';

  @override
  String get productGroup_agro => 'Agro';

  @override
  String get productGroup_veterinary => 'Veterinary';

  @override
  String get productType_injectable => 'Injectable';

  @override
  String get productType_oralLiquid => 'Oral Liquid';

  @override
  String get productType_powder => 'Powder';

  @override
  String get productType_tabletBolus => 'Tablet/Bolus';

  @override
  String get productType_topical => 'Topical';

  @override
  String get productType_intramammary => 'Intramammary';

  @override
  String get productType_spray => 'Spray';

  @override
  String get productType_granules => 'Granules';

  @override
  String get productType_wettablePowder => 'Wettable Powder';

  @override
  String get productType_emulsifiableConcentrate => 'Emulsifiable Concentrate';

  @override
  String get productType_seed => 'Seed';

  @override
  String get productType_fertilizer => 'Fertilizer';

  @override
  String get productType_feed => 'Feed';

  @override
  String get productType_equipment => 'Equipment';

  @override
  String get productType_other => 'Other';

  @override
  String get unit_pcs => 'pcs';

  @override
  String get unit_kg => 'kg';

  @override
  String get unit_g => 'g';

  @override
  String get unit_litres => 'litres';

  @override
  String get unit_ml => 'ml';

  @override
  String get unit_vials => 'vials';

  @override
  String get unit_ampoules => 'ampoules';

  @override
  String get unit_bottles => 'bottles';

  @override
  String get unit_sachets => 'sachets';

  @override
  String get unit_sacks => 'sacks';

  @override
  String get unit_bags => 'bags';

  @override
  String get unit_boxes => 'boxes';

  @override
  String get unit_cartons => 'cartons';

  @override
  String get unit_packs => 'packs';

  @override
  String get unit_strips => 'strips';

  @override
  String get unit_tablets => 'tablets';

  @override
  String get unit_tubes => 'tubes';

  @override
  String get unit_rolls => 'rolls';

  @override
  String get unit_pairs => 'pairs';

  @override
  String get unit_others => 'others';

  @override
  String get serviceCategory_surgical => 'Surgical';

  @override
  String get serviceCategory_treatment => 'Treatment';

  @override
  String get serviceCategory_management => 'Management';

  @override
  String get serviceCategory_consultation => 'Consultation';

  @override
  String get serviceCategory_diagnostics => 'Diagnostics';

  @override
  String get serviceCategory_preventive => 'Preventive';

  @override
  String get serviceCategory_other => 'Other';

  @override
  String get facilityType_agrovet => 'Agrovet';

  @override
  String get facilityType_vetClinic => 'Vet Clinic';

  @override
  String get facilityType_vetHospital => 'Vet Hospital';

  @override
  String get facilityType_ambulatoryVet => 'Ambulatory Vet';

  @override
  String get facilityType_other => 'Other';

  @override
  String get paymentMethod_cash => 'Cash';

  @override
  String get paymentMethod_mPesa => 'M-Pesa';

  @override
  String get paymentMethod_mixxByYas => 'Mixx by Yas';

  @override
  String get paymentMethod_haloPesa => 'HaloPesa';

  @override
  String get paymentMethod_airtelMoney => 'Airtel Money';

  @override
  String get paymentMethod_bankTransfer => 'Bank Transfer';

  @override
  String get paymentMethod_tigoPesa => 'Tigo Pesa';

  @override
  String get paymentMethod_onCredit => 'On Credit';

  @override
  String get activityType_account => 'Account';

  @override
  String get activityType_debtors => 'Debtors';

  @override
  String get activityType_products => 'Products';

  @override
  String get activityType_inventoryMove => 'Inventory Move';

  @override
  String get activityType_sales => 'Sales';

  @override
  String get activityType_sale => 'Sale';

  @override
  String get activityType_services => 'Services';

  @override
  String get activityType_transactions => 'Transactions';

  @override
  String get activityType_trash => 'Trash';

  @override
  String get activityType_reportDraftDeleted => 'Report Draft Deleted';

  @override
  String get restockFrequency_weekly => 'Weekly';

  @override
  String get restockFrequency_everyTwoWeeks => 'Every 2 Weeks';

  @override
  String get restockFrequency_monthly => 'Monthly';

  @override
  String get restockFrequency_rarely => 'Rarely';

  @override
  String get role_admin => 'Admin';

  @override
  String get role_assistant => 'Assistant';

  @override
  String get role_coAdmin => 'Co-admin';

  @override
  String get userStatus_pending => 'Pending';

  @override
  String get userStatus_active => 'Active';

  @override
  String get userStatus_deactivated => 'Deactivated';

  @override
  String get userStatus_rejected => 'Rejected';

  @override
  String get membershipAction_approved => 'Approved';

  @override
  String get membershipAction_rejected => 'Rejected';

  @override
  String get membershipAction_deactivated => 'Deactivated';

  @override
  String get membershipAction_reactivated => 'Reactivated';

  @override
  String get facilityStatus_active => 'Active';

  @override
  String get facilityStatus_inactive => 'Inactive';

  @override
  String get facilityStatus_pending => 'Pending';

  @override
  String get submissionStatus_pending => 'Pending';

  @override
  String get submissionStatus_approved => 'Approved';

  @override
  String get submissionStatus_rejected => 'Rejected';

  @override
  String get plan_daily => 'Daily';

  @override
  String get plan_weekly => 'Weekly';

  @override
  String get plan_monthly => 'Monthly';

  @override
  String get plan_yearly => 'Yearly';

  @override
  String get clientType_farmer => 'Farmer';

  @override
  String get clientType_vet => 'Vet';

  @override
  String get clientType_wholesaler => 'Wholesaler';

  @override
  String get clientType_retailer => 'Retailer';

  @override
  String get clientType_other => 'Other';

  @override
  String get farmerSubType_cropProducer => 'Crop Producer';

  @override
  String get farmerSubType_animalKeeper => 'Animal Keeper';

  @override
  String get animal_cattle => 'Cattle';

  @override
  String get animal_goat => 'Goat';

  @override
  String get animal_sheep => 'Sheep';

  @override
  String get animal_pig => 'Pig';

  @override
  String get animal_donkey => 'Donkey';

  @override
  String get animal_chicken => 'Chicken';

  @override
  String get animal_duck => 'Duck';

  @override
  String get animal_turkey => 'Turkey';

  @override
  String get animal_guineaFowl => 'Guinea Fowl';

  @override
  String get animal_bees => 'Bees';

  @override
  String get animal_dog => 'Dog';

  @override
  String get animal_cat => 'Cat';

  @override
  String get animal_rabbit => 'Rabbit';

  @override
  String get animalGroup_livestock => 'Livestock';

  @override
  String get animalGroup_poultry => 'Poultry';

  @override
  String get animalGroup_other => 'Other';

  @override
  String get vetPractice_clinic => 'Clinic';

  @override
  String get vetPractice_consultant => 'Consultant';

  @override
  String get vetPractice_hospital => 'Hospital';

  @override
  String get vetPractice_ambulatory => 'Ambulatory';

  @override
  String get clientStatus_active => 'Active';

  @override
  String get clientStatus_inactive => 'Inactive';

  @override
  String get paymentStatus_paid => 'Paid';

  @override
  String get paymentStatus_partial => 'Partial';

  @override
  String get paymentStatus_unpaid => 'Unpaid';

  @override
  String get moveReason_expired => 'Expired';

  @override
  String get moveReason_deteriorated => 'Deteriorated';

  @override
  String get moveReason_other => 'Other (specify)';

  @override
  String get cropGroup_foodCrops => 'Food Crops';

  @override
  String get cropGroup_cashCrops => 'Cash Crops';

  @override
  String get cropGroup_vegetables => 'Vegetables';

  @override
  String get cropGroup_fruits => 'Fruits';

  @override
  String get crop_maize => 'Maize';

  @override
  String get crop_rice => 'Rice';

  @override
  String get crop_wheat => 'Wheat';

  @override
  String get crop_cassava => 'Cassava';

  @override
  String get crop_sorghum => 'Sorghum';

  @override
  String get crop_millet => 'Millet';

  @override
  String get crop_beans => 'Beans';

  @override
  String get crop_bananas => 'Bananas';

  @override
  String get crop_sweetPotatoes => 'Sweet Potatoes';

  @override
  String get crop_irishPotatoes => 'Irish Potatoes';

  @override
  String get crop_groundnuts => 'Groundnuts';

  @override
  String get crop_coffee => 'Coffee';

  @override
  String get crop_cotton => 'Cotton';

  @override
  String get crop_tobacco => 'Tobacco';

  @override
  String get crop_cashewNuts => 'Cashew Nuts';

  @override
  String get crop_sisal => 'Sisal';

  @override
  String get crop_tea => 'Tea';

  @override
  String get crop_pyrethrum => 'Pyrethrum';

  @override
  String get crop_sugarcane => 'Sugarcane';

  @override
  String get crop_cloves => 'Cloves';

  @override
  String get crop_sesame => 'Sesame';

  @override
  String get crop_sunflower => 'Sunflower';

  @override
  String get crop_tomatoes => 'Tomatoes';

  @override
  String get crop_onions => 'Onions';

  @override
  String get crop_cabbage => 'Cabbage';

  @override
  String get crop_okra => 'Okra';

  @override
  String get crop_mangoes => 'Mangoes';

  @override
  String get crop_oranges => 'Oranges';

  @override
  String get crop_avocado => 'Avocado';

  @override
  String get crop_watermelon => 'Watermelon';

  @override
  String get expenseGroup_administration => 'Administration';

  @override
  String get expenseGroup_premisesUtilities => 'Premises & Utilities';

  @override
  String get expenseGroup_operations => 'Operations';

  @override
  String get expenseGroup_transport => 'Transport';

  @override
  String get expenseGroup_business => 'Business';

  @override
  String get expenseGroup_other => 'Other';

  @override
  String get expenseCategory_mealsRefreshments => 'Meals & Refreshments';

  @override
  String get expenseCategory_salariesWages => 'Salaries & Wages';

  @override
  String get expenseCategory_officeSupplies => 'Office Supplies';

  @override
  String get expenseCategory_electricity => 'Electricity';

  @override
  String get expenseCategory_water => 'Water';

  @override
  String get expenseCategory_rent => 'Rent';

  @override
  String get expenseCategory_drugsMedicines => 'Drugs & Medicines';

  @override
  String get expenseCategory_veterinarySupplies => 'Veterinary Supplies';

  @override
  String get expenseCategory_fuel => 'Fuel';

  @override
  String get expenseCategory_vehicleMaintenance => 'Vehicle Maintenance';

  @override
  String get expenseCategory_marketing => 'Marketing';

  @override
  String get expenseCategory_licencesRegistration => 'Licences & Registration';

  @override
  String get incomeCategory_commission => 'Commission Income';

  @override
  String get incomeCategory_delivery => 'Delivery Income';

  @override
  String get incomeCategory_training => 'Training Income';

  @override
  String get incomeCategory_consultancy => 'Consultancy Income';

  @override
  String get incomeCategory_rental => 'Rental Income';

  @override
  String get incomeCategory_interest => 'Interest Income';

  @override
  String get incomeCategory_refundsReceived => 'Refunds Received';

  @override
  String get incomeCategory_discountsReceived => 'Discounts Received';

  @override
  String get incomeCategory_assetDisposal => 'Asset Disposal Income';

  @override
  String get incomeCategory_other => 'Other Income';

  @override
  String get common_method => 'Method';

  @override
  String common_filterValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String common_totalValue(String amount) {
    return 'Total: $amount';
  }

  @override
  String get common_today => 'Today';

  @override
  String get common_yesterday => 'Yesterday';

  @override
  String common_perPage(int count) {
    return '$count per page';
  }

  @override
  String common_page(int page) {
    return 'Page $page';
  }

  @override
  String get common_dialerFailed => 'Couldn\'t open the dialer';

  @override
  String get common_printReceipt => 'Print Receipt';

  @override
  String get common_resetFilters => 'Reset filters';

  @override
  String get common_notesOptional => 'Notes (optional)';

  @override
  String get common_notifications => 'Notifications';

  @override
  String get payments_title => 'Payments';

  @override
  String payments_titleForClient(String clientName) {
    return 'Payments - $clientName';
  }

  @override
  String get payments_subtitle => 'All payments received across your business';

  @override
  String get payments_typeSales => 'Sales';

  @override
  String get payments_typeServices => 'Services';

  @override
  String get payments_typeDebtRepayments => 'Debt Repayments';

  @override
  String get payments_typeOtherIncome => 'Other Income';

  @override
  String get payments_allMethods => 'All Methods';

  @override
  String get payments_searchHint => 'Search payer, reference, invoice...';

  @override
  String payments_newEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new entries available',
      one: '1 new entry available',
    );
    return '$_temp0';
  }

  @override
  String get payments_emptyPeriod => 'No payments in this period.';

  @override
  String get payments_colDateTime => 'Date & Time';

  @override
  String get payments_payer => 'Payer';

  @override
  String get payments_source => 'Source';

  @override
  String get payments_reference => 'Reference';

  @override
  String get payments_recordedBy => 'Recorded By';

  @override
  String get payments_thisWeek => 'This Week';

  @override
  String get payments_thisMonth => 'This Month';

  @override
  String payments_paymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
    );
    return '$_temp0';
  }

  @override
  String get payments_outstanding => 'Outstanding';

  @override
  String payments_debtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count debts',
    );
    return '$_temp0';
  }

  @override
  String get payments_detailsTitle => 'Payment Details';

  @override
  String get payments_received => 'Payment Received';

  @override
  String get payments_noReceipt => 'No receipt available for this payment';

  @override
  String get subscription_title => 'Subscription';

  @override
  String get subscription_statusTrial => 'Trial';

  @override
  String get subscription_statusTrialNoSetup =>
      'Trial - no subscription set up yet';

  @override
  String get subscription_statusActive => 'Active';

  @override
  String get subscription_statusGrace => 'Payment overdue - grace period';

  @override
  String get subscription_statusLocked => 'Locked - subscription expired';

  @override
  String subscription_expiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String subscription_trialExpiresOn(String date) {
    return 'Trial expires on $date';
  }

  @override
  String subscription_renewsOn(String date) {
    return 'Renews / expires on $date';
  }

  @override
  String get subscription_readOnly =>
      'Your account is in read-only mode. Submit a payment below to restore full access - your data is safe and untouched.';

  @override
  String subscription_promoAllPlans(String percent) {
    return '$percent% off every plan - applied automatically below.';
  }

  @override
  String subscription_promoSomePlans(String percent) {
    return '$percent% off select plans - applied automatically below.';
  }

  @override
  String get subscription_choosePlan => 'Choose a Plan';

  @override
  String get subscription_referenceLabel => 'Transaction / Confirmation Code';

  @override
  String get subscription_referenceHint => 'e.g. the M-Pesa confirmation code';

  @override
  String get subscription_attachProof => 'Attach Proof (optional)';

  @override
  String get subscription_proofAttached => 'Proof attached';

  @override
  String get subscription_pendingWarning =>
      'Your last payment is still under review. Please wait for it to be approved or rejected before submitting another.';

  @override
  String get subscription_priceUnavailableWarning =>
      'Pricing for this plan isn\'t available right now. Please try again shortly or contact support.';

  @override
  String get subscription_awaitingReview => 'Awaiting Review';

  @override
  String get subscription_pricingUnavailable => 'Pricing Unavailable';

  @override
  String get subscription_submitForReview => 'Submit Payment for Review';

  @override
  String get subscription_recentSubmissions => 'Recent Submissions';

  @override
  String get subscription_noSubmissionsYetDot => 'No submissions yet.';

  @override
  String get subscription_viewAll => 'View all';

  @override
  String get subscription_enterReference =>
      'Enter the payment reference / confirmation code';

  @override
  String get subscription_submitted => 'Payment submitted';

  @override
  String get subscription_submittedDetail =>
      'It will be reviewed and confirmed shortly';

  @override
  String get subscription_submitFailed => 'Couldn\'t submit the payment';

  @override
  String subscription_rejectReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get subscription_noReason => 'No reason was given';

  @override
  String get subscription_historyTitle => 'Subscription History';

  @override
  String get subscription_historySubtitle =>
      'Your payments and their review status';

  @override
  String subscription_historyLoadError(String error) {
    return 'Could not load history: $error';
  }

  @override
  String get subscription_noSubmissionsYet => 'No submissions yet';

  @override
  String get subscription_noSubmissionsHint =>
      'Payments you submit will be listed here.';

  @override
  String get subscription_totalSubmissions => 'Total Submissions';

  @override
  String get subscription_allPayments => 'All payments';

  @override
  String get subscription_awaitingReviewLower => 'Awaiting review';

  @override
  String get subscription_notAccepted => 'Not accepted';

  @override
  String get subscription_searchHint =>
      'Search by plan, method, reference or reason...';

  @override
  String get subscription_plan => 'Plan';

  @override
  String get subscription_noMatches => 'No submissions match your filters';

  @override
  String get subscription_colSubmitted => 'Submitted';

  @override
  String subscription_rejectedOn(String date) {
    return 'Rejected $date';
  }

  @override
  String get subscription_noSubmissions => 'No submissions';

  @override
  String subscription_showingRange(int total, int start, int end) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total submissions',
      one: 'Showing $start to $end of 1 submission',
    );
    return '$_temp0';
  }

  @override
  String get store_title => 'Stock Store';

  @override
  String get store_subtitle => 'Manage your inventory';

  @override
  String get store_stockValue => 'Store Stock Value';

  @override
  String get store_searchHint => 'Search stock, brand or batch...';

  @override
  String store_productsInStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products in stock',
      one: '1 product in stock',
    );
    return '$_temp0';
  }

  @override
  String get store_empty => 'No products in stock store';

  @override
  String get products_totalProducts => 'Total Products';

  @override
  String get products_statusActive => 'Active';

  @override
  String get products_statusNotStocked => 'Not Stocked';

  @override
  String get products_statusUnknown => 'Unknown';

  @override
  String get products_statusExpiringSoon => 'Expiring Soon';

  @override
  String get products_confirmDeleteTitle => 'Confirm Delete';

  @override
  String get products_confirmDeleteBody =>
      'Are you sure you want to delete this product?';

  @override
  String get products_movedToTrash => 'Product moved to Trash';

  @override
  String get products_deleteFailed => 'Couldn\'t delete the product';

  @override
  String get products_restored => 'Product restored';

  @override
  String get products_restoreFailed => 'Couldn\'t restore the product';

  @override
  String get products_noMatches => 'No products match your filters';

  @override
  String get products_restockShelf => 'Restock Shelf';

  @override
  String get products_stock => 'Stock';

  @override
  String get products_price => 'Price';

  @override
  String get products_release => 'Release';

  @override
  String get products_addNewBatch => 'Add New Batch';

  @override
  String get products_viewBatches => 'View Batches';

  @override
  String get products_stockAlerts => 'Stock Alerts';

  @override
  String get products_addProduct => 'Add Product';

  @override
  String products_showingRange(int total, int start, int end) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total products',
    );
    return '$_temp0';
  }

  @override
  String products_sellableBatch(String quantity, String unit, String batch) {
    return 'Sellable: $quantity $unit • Batch: $batch';
  }

  @override
  String products_buyPrice(String price) {
    return 'Buy: $price';
  }

  @override
  String products_expiryDate(String date) {
    return 'Expiry: $date';
  }

  @override
  String store_batchName(String batchNo) {
    return 'Batch $batchNo';
  }

  @override
  String get store_unlabeledBatch => 'an unlabeled batch';

  @override
  String get store_expiredStockTitle => 'Expired Stock';

  @override
  String get store_expiredStockBody =>
      'This product is expired. Do you still want to release it to the shelf?';

  @override
  String store_expiredPortionLine(String quantity, String unit, String batch) {
    return '• $quantity $unit from $batch';
  }

  @override
  String get store_releaseAnyway => 'Release Anyway';

  @override
  String get store_releaseTitle => 'Release to Shelf';

  @override
  String store_availableStock(String quantity, String unit) {
    return 'Available stock: $quantity $unit';
  }

  @override
  String get store_quantityToRelease => 'Quantity to release';

  @override
  String get store_notesHint => 'e.g., Quality checked, ready for sale';

  @override
  String store_quantityRange(String max) {
    return 'Enter a quantity from 1 to $max';
  }

  @override
  String store_released(String quantity, String unit, String product) {
    return 'Released $quantity $unit of $product to the shelf';
  }

  @override
  String get store_releaseFailed => 'Couldn\'t release the product';

  @override
  String get common_unknown => 'Unknown';

  @override
  String common_showingRange(int start, int end) {
    return 'Showing $start to $end';
  }

  @override
  String get common_phone => 'Phone';

  @override
  String get common_address => 'Address';

  @override
  String get common_name => 'Name';

  @override
  String get common_description => 'Description';

  @override
  String get common_category => 'Category';

  @override
  String get common_required => 'Required';

  @override
  String common_requiredLabel(String label) {
    return '$label *';
  }

  @override
  String get common_export => 'Export';

  @override
  String get common_actions => 'Actions';

  @override
  String get common_summary => 'Summary';

  @override
  String get common_noNotes => 'No notes added';

  @override
  String get common_none => 'None';

  @override
  String get common_searchEllipsis => 'Search...';

  @override
  String get common_noFacility => 'No facility selected';

  @override
  String get common_linkFailed => 'Couldn\'t open the link';

  @override
  String get common_linkFailedDetail => 'Copy it from the error log instead';

  @override
  String get common_noPrinterTitle => 'No Printer Connected';

  @override
  String get common_noPrinterBody =>
      'Connect a Bluetooth receipt printer in Printer Settings first.';

  @override
  String get common_goToPrinterSettings => 'Go to Printer Settings';

  @override
  String get common_receiptSentToPrinter => 'Receipt sent to printer';

  @override
  String get common_printFailed => 'Couldn\'t print the receipt';

  @override
  String get common_printFailedDetail => 'The printer did not accept it';

  @override
  String get transactionType_expense => 'Expense';

  @override
  String get transactions_title => 'Transactions';

  @override
  String get transactions_subtitle => 'All income and expense transactions';

  @override
  String get transactions_record => 'Record Transaction';

  @override
  String get transactions_edit => 'Edit Transaction';

  @override
  String get transactions_update => 'Update Transaction';

  @override
  String get transactions_expenses => 'Expenses';

  @override
  String get transactions_incomeVsExpenses => 'Other Income vs Expenses';

  @override
  String get transactions_searchHint => 'Search by description, category...';

  @override
  String transactions_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get transactions_empty => 'No transactions.';

  @override
  String transactions_emptyForType(String type) {
    return 'No transactions for $type.';
  }

  @override
  String get transactions_deleteTitle => 'Delete this transaction?';

  @override
  String transactions_deleteBody(String description, String amount) {
    return '\"$description\" - $amount\n\nYou can restore it from Trash.';
  }

  @override
  String get transactions_movedToTrash => 'Transaction moved to Trash';

  @override
  String get transactions_deleteFailed => 'Couldn\'t delete the transaction';

  @override
  String get transactions_restored => 'Transaction restored';

  @override
  String get transactions_restoreFailed => 'Couldn\'t restore the transaction';

  @override
  String get transactions_detailsTitle => 'Transaction Details';

  @override
  String get transactions_allShown => 'Showing all recent transactions';

  @override
  String get transactions_loadMore => 'Load more transactions';

  @override
  String get transactions_fillRequired =>
      'Fill in all required fields correctly';

  @override
  String get transactions_selectPaymentMethod =>
      'Select how this transaction was paid';

  @override
  String get transactions_updated => 'Transaction updated';

  @override
  String get transactions_updateFailed => 'Couldn\'t update the transaction';

  @override
  String get transactions_saved => 'Transaction saved';

  @override
  String get transactions_saveFailed => 'Couldn\'t save the transaction';

  @override
  String get transactions_selectCategory => 'Select category...';

  @override
  String get transactions_descriptionHint => 'What was this for?';

  @override
  String get transactions_noteLabel => 'Reference/Note (optional)';

  @override
  String get transactions_noteHint => 'Add any additional information';

  @override
  String get transactions_amountPayment => 'Amount & Payment';

  @override
  String transactions_amountRequired(String currency) {
    return 'Amount ($currency) *';
  }

  @override
  String get transactions_selectMethod => 'Select method';

  @override
  String get transactions_noCategories => 'No categories found';

  @override
  String get transactions_selectCategoryTitle => 'Select Category';

  @override
  String get transactions_searchCategories => 'Search categories...';

  @override
  String get debtSource_service => 'Service';

  @override
  String get debtors_title => 'Active Debts';

  @override
  String get debtors_subtitle => 'Track and manage all outstanding debts';

  @override
  String debtors_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new debtors available',
      one: '1 new debtor available',
    );
    return '$_temp0';
  }

  @override
  String get debtors_emptyNone => 'No outstanding debts';

  @override
  String get debtors_emptySearch => 'No debtors match your search';

  @override
  String get debtors_totalDebtors => 'Total Debtors';

  @override
  String get debtors_withBalance => 'With outstanding balance';

  @override
  String get debtors_totalOwed => 'Total Owed';

  @override
  String get debtors_outstandingBalance => 'Outstanding balance';

  @override
  String get debtors_overdueDebtors => 'Overdue Debtors';

  @override
  String debtors_overDays(int days) {
    return 'Over $days days';
  }

  @override
  String get debtors_paidThisMonth => 'Paid This Month';

  @override
  String get debtors_fromDebtPayments => 'From debt payments';

  @override
  String get debtors_recordPayment => 'Record Payment';

  @override
  String get debtors_overdue => 'Overdue';

  @override
  String get debtors_current => 'Current';

  @override
  String get debtors_colOverdue => 'Overdue';

  @override
  String debtors_rangeDays(int from, int to) {
    return '$from-$to days overdue';
  }

  @override
  String debtors_rangeDaysPlus(int from) {
    return '$from+ days overdue';
  }

  @override
  String get debtors_searchHint => 'Search debtor by name...';

  @override
  String get debtors_debtor => 'Debtor';

  @override
  String get debtors_oldestDebtSince => 'Oldest Debt Since';

  @override
  String debtors_daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
    );
    return '$_temp0';
  }

  @override
  String get debtors_sendReminder => 'Send Reminder';

  @override
  String get debtors_paymentHistory => 'Payment History';

  @override
  String get debtors_none => 'No debtors';

  @override
  String get debtors_detailsTitle => 'Debtor Details';

  @override
  String get debtors_overdueAmount => 'Overdue Amount';

  @override
  String get debtors_lastTransaction => 'Last Transaction';

  @override
  String debtors_outstandingDebts(int count) {
    return 'Outstanding Debts ($count)';
  }

  @override
  String get debtors_addNote => 'Add Note';

  @override
  String debtors_invoiceLine(String invoice, String date) {
    return 'Invoice: $invoice • $date';
  }

  @override
  String get debtors_pay => 'Pay';

  @override
  String get debtors_exportFailed => 'Couldn\'t export the active debts';

  @override
  String get debtors_noteHint => 'e.g. Promised to pay by Friday';

  @override
  String get debtors_noteSaveFailed => 'Couldn\'t save the note';

  @override
  String debtors_reminderBody(String name, String amount) {
    return 'Remind $name about their $amount balance via:';
  }

  @override
  String get debtors_viaSms => 'SMS';

  @override
  String get debtors_viaWhatsApp => 'WhatsApp';

  @override
  String get debtors_whatsAppFailed => 'Couldn\'t open WhatsApp';

  @override
  String get debtors_messagesFailed => 'Couldn\'t open Messages';

  @override
  String get debtors_reminderFailed => 'Couldn\'t send the reminder';

  @override
  String get debtors_errChooseDebtor => 'Choose the debtor this payment is for';

  @override
  String debtors_errNoMatch(String name) {
    return 'No debtor found with the name \"$name\"';
  }

  @override
  String get debtors_errTooShort =>
      'Type at least 2 letters of the debtor\'s name';

  @override
  String get debtors_errPickSuggestion =>
      'Choose a debtor from the suggestions';

  @override
  String debtors_clientLabel(String name) {
    return 'Client: $name';
  }

  @override
  String get debtors_totalOwedLabel => 'Total owed:';

  @override
  String get debtors_selectPaymentMethod => 'Select how this payment was made';

  @override
  String get debtors_signInAgain => 'Sign in again to record this payment';

  @override
  String get debtors_selectClient => 'Select a client';

  @override
  String debtors_paymentRecorded(String amount, String name) {
    return 'Payment of $amount recorded for $name';
  }

  @override
  String get debtors_paymentSaveFailed => 'Couldn\'t save the payment';

  @override
  String get debtors_debtorSearchHint => 'Search by name or phone';

  @override
  String get debtors_debtorHelper =>
      'Only clients who currently owe money are listed';

  @override
  String debtors_amountOwed(String amount) {
    return 'Amount owed: $amount';
  }

  @override
  String get debtors_paymentAmount => 'Payment Amount';

  @override
  String get debtors_errEnterAmount => 'Enter an amount';

  @override
  String get debtors_errValidAmount => 'Enter a valid amount';

  @override
  String get debtors_errMoreThanOwed => 'Cannot pay more than owed';

  @override
  String get debtors_errMoreThanTotal => 'Cannot pay more than total owed';

  @override
  String get debtors_savePayment => 'Save Payment';

  @override
  String get clients_title => 'Clients';

  @override
  String get clients_subtitle => 'Manage all your clients in one place';

  @override
  String get clients_add => 'Add Client';

  @override
  String get clients_edit => 'Edit Client';

  @override
  String get clients_total => 'Total Clients';

  @override
  String get clients_allTime => 'All time';

  @override
  String get clients_newThisMonth => 'New This Month';

  @override
  String get clients_mostActiveType => 'Most Active Type';

  @override
  String clients_percentOfClients(String percent) {
    return '$percent% of clients';
  }

  @override
  String get clients_lastAdded => 'Last Added';

  @override
  String get clients_searchHint => 'Search by name, phone, address...';

  @override
  String get clients_deleteTitle => 'Delete Client';

  @override
  String clients_deleteBody(String name) {
    return 'Delete \"$name\" permanently?';
  }

  @override
  String get clients_deleted => 'Client deleted';

  @override
  String get clients_deleteFailed => 'Couldn\'t delete the client';

  @override
  String get clients_shareFailed => 'Couldn\'t share the client card';

  @override
  String get clients_detailsTitle => 'Client Details';

  @override
  String get clients_clientType => 'Client Type';

  @override
  String get clients_joinedOn => 'Joined On';

  @override
  String get clients_totalTransactions => 'Total Transactions';

  @override
  String get clients_totalSpent => 'Total Spent';

  @override
  String get clients_saveShare => 'Save / Share';

  @override
  String get clients_searchingNote => 'Searching by name (across all types)';

  @override
  String clients_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new clients available',
      one: '1 new client available',
    );
    return '$_temp0';
  }

  @override
  String clients_emptySearch(String query) {
    return 'No clients match \"$query\"';
  }

  @override
  String get clients_empty => 'No clients found';

  @override
  String get clients_client => 'Client';

  @override
  String get clients_indexNeeded =>
      'This filter needs a one-time database index to be created first.';

  @override
  String clients_loadError(String error) {
    return 'Could not load clients: $error';
  }

  @override
  String get clients_createIndex => 'Create Index';

  @override
  String get clients_indexBuildingHint =>
      'This takes a minute or two to finish building after you create it - then try this filter again.';

  @override
  String get clients_none => 'No clients';

  @override
  String get clients_errSelectType => 'Select at least one client type';

  @override
  String get clients_saveFailed => 'Couldn\'t save the client';

  @override
  String get clients_added => 'Client added';

  @override
  String get clients_updated => 'Client updated';

  @override
  String get clients_duplicateTitle => 'Client already exists';

  @override
  String get clients_duplicateByPhone =>
      'A client with this phone number already exists:';

  @override
  String get clients_duplicateByName =>
      'A client with a similar name already exists:';

  @override
  String get clients_noPhone => 'No phone number';

  @override
  String clients_duplicateBody(String action, String match) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'add': 'this client was not saved',
      'other': 'your changes were not saved',
    });
    String _temp1 = intl.Intl.selectLogic(match, {
      'phone': 'enter a different phone number',
      'other': 'change the name slightly',
    });
    return 'To avoid duplicate clients, $_temp0. If it is the same person, use the existing client from the Clients list. If it is a different person, $_temp1 and try again.';
  }

  @override
  String get clients_infoSection => 'Client Information';

  @override
  String get clients_nameHint => 'Enter client name';

  @override
  String get clients_phoneHint => 'e.g. 07XX XXX XXX';

  @override
  String get clients_addressHint => 'Enter address';

  @override
  String get clients_notesHint =>
      'Any additional information about the client...';

  @override
  String get clients_quickSummary => 'Quick Summary';

  @override
  String get clients_tip =>
      'You can update this client\'s animal species or crops anytime by editing their profile.';

  @override
  String get clients_cropInfo => 'Crop Information (Optional)';

  @override
  String get clients_animalInfo => 'Animal Information (Optional)';

  @override
  String get clients_cropHint => 'Add crops grown by this client if available.';

  @override
  String get clients_animalHint =>
      'Add animals owned by this client if available.';

  @override
  String get clients_farmerTypeHint =>
      'Select a farmer type below to add crops or animals.';

  @override
  String get clients_farmerType => 'Farmer Type';

  @override
  String get clients_addCrops => 'Add Crops';

  @override
  String get clients_addAnimals => 'Add Animals';

  @override
  String get clients_selectCrops => 'Select Crops';

  @override
  String get clients_selectAnimals => 'Select Animal Species';

  @override
  String get clients_noMatches => 'No matches found';

  @override
  String get clients_additionalDetails => 'Additional Details';

  @override
  String get clients_practiceType => 'Practice Type';

  @override
  String get clients_businessName => 'Business Name';

  @override
  String get clients_businessNameHint => 'Enter business name';

  @override
  String get clients_update => 'Update Client';

  @override
  String get clients_save => 'Save Client';

  @override
  String get common_tryAgainLower => 'Try again';

  @override
  String get common_restore => 'Restore';

  @override
  String get common_noFacilityDot => 'No facility selected.';

  @override
  String get team_working => 'Working...';

  @override
  String team_actionDone(String name, String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'approved': '$name approved',
      'rejected': '$name rejected',
      'deactivated': '$name deactivated',
      'reactivated': '$name reactivated',
      'other': '$name $action',
    });
    return '$_temp0';
  }

  @override
  String get team_updateFailed => 'Couldn\'t update the assistant';

  @override
  String get team_removed => 'Assistant removed from this facility';

  @override
  String get team_removeFailed => 'Couldn\'t remove the assistant';

  @override
  String get team_reassigned => 'Assistant reassigned';

  @override
  String get team_reassignFailed => 'Couldn\'t reassign the assistant';

  @override
  String get team_thisAssistant => 'this assistant';

  @override
  String get team_thisAssistantCap => 'This assistant';

  @override
  String get team_thisPerson => 'this person';

  @override
  String get team_thisCoAdmin => 'this co-admin';

  @override
  String team_moveTitle(String name) {
    return 'Move $name';
  }

  @override
  String get team_moveBody =>
      'Choose the facility they should work in. They keep their account and their approval.';

  @override
  String get team_noOtherFacility =>
      'You don\'t run any other facility to move them to.';

  @override
  String get team_inviteTo => 'Invite Assistant To...';

  @override
  String get team_unknownFacility => 'Unknown facility';

  @override
  String get team_you => 'You';

  @override
  String get team_facilityAdmin => 'Facility admin';

  @override
  String get team_approve => 'Approve';

  @override
  String get team_reject => 'Reject';

  @override
  String get team_deactivate => 'Deactivate';

  @override
  String get team_reactivate => 'Reactivate';

  @override
  String get team_reassign => 'Reassign';

  @override
  String get team_removeFromFacility => 'Remove from Facility';

  @override
  String get team_removeFromFacilityConfirm => 'Remove from facility';

  @override
  String team_deactivateTitle(String name) {
    return 'Deactivate $name?';
  }

  @override
  String get team_deactivateBody =>
      'They\'ll be signed out straight away and can\'t log in until you reactivate them. This doesn\'t change their role - only the platform administrator can do that.';

  @override
  String get team_updateStatusFailed => 'Couldn\'t update the status';

  @override
  String team_facilityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count facilities',
    );
    return '$_temp0';
  }

  @override
  String team_removeTitle(String name, String facility) {
    return 'Remove $name from $facility?';
  }

  @override
  String team_removePoint1(String name, String facility) {
    return '$name will no longer be part of $facility, and won\'t see its records.';
  }

  @override
  String team_removePoint2(String name, String facility) {
    return 'What $name recorded stays in $facility\'s history.';
  }

  @override
  String get team_removePoint3 =>
      'Their account is kept. When they next sign in they can enter an invite code to join a facility again.';

  @override
  String team_rejectTitle(String name) {
    return 'Reject $name?';
  }

  @override
  String team_rejectPoint1(String name, String facility) {
    return '$name is removed from $facility and is no longer waiting for approval.';
  }

  @override
  String get team_rejectPoint2 =>
      'When they next sign in they\'ll see the request wasn\'t approved, and be asked for an invite code - they can join again with a new one.';

  @override
  String get team_rejectPoint3 =>
      'They aren\'t sent a message. Tell them yourself if you\'d like them to know.';

  @override
  String get team_title => 'Team Members';

  @override
  String get team_subtitle => 'Manage your team\'s access and status';

  @override
  String get team_inviteAssistant => 'Invite Assistant';

  @override
  String get team_noAdmin => 'No logged in admin user found';

  @override
  String get team_noFacilities => 'No facilities found for your account.';

  @override
  String get team_acrossFacilities => 'Across your facilities';

  @override
  String get team_haveAccess => 'Have access';

  @override
  String get team_accessPaused => 'Access paused';

  @override
  String get team_waitingApproval => 'Waiting Approval';

  @override
  String get team_needDecision => 'Need your decision';

  @override
  String get team_searchHint => 'Search by name, phone or facility...';

  @override
  String get team_emptyTitle => 'No team members yet';

  @override
  String get team_emptyHint =>
      'Use Invite Assistant to add your first team member.';

  @override
  String get team_noAssistants => 'No assistants yet';

  @override
  String get team_noMatches => 'No team members match your filters';

  @override
  String get team_colUserName => 'User name';

  @override
  String get team_colRole => 'Role';

  @override
  String get team_notRecorded => 'Not recorded';

  @override
  String get team_registered => 'Registered';

  @override
  String get team_detailsTitle => 'Team Member Details';

  @override
  String team_nameYou(String name) {
    return '$name  (you)';
  }

  @override
  String get team_joined => 'Joined';

  @override
  String team_askedAgain(String date) {
    return 'Asked to join again: $date';
  }

  @override
  String get team_approvedLabel => 'Approved';

  @override
  String get team_waitingForApproval => 'Waiting for approval';

  @override
  String team_byName(String name) {
    return 'by $name';
  }

  @override
  String get team_approvedBeforeRecords =>
      'Approved before approvals were recorded';

  @override
  String get team_lastStatusChange => 'Last status change';

  @override
  String team_byNameRole(String name, String role) {
    return 'by $name ($role)';
  }

  @override
  String get team_lastActive => 'Last active';

  @override
  String get team_history => 'History';

  @override
  String team_historyLine(String when, String name) {
    return '$when  ·  by $name';
  }

  @override
  String get team_useCardButtons =>
      'Use the buttons on this person\'s card to approve, reject or remove them.';

  @override
  String get team_noAssistantsPage => 'No assistants';

  @override
  String team_showingRange(int start, int end, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total assistants',
      one: 'Showing $start to $end of 1 assistant',
    );
    return '$_temp0';
  }

  @override
  String get invite_checking => 'Checking for an existing invite...';

  @override
  String invite_checkFailed(String error) {
    return 'Could not check for an existing invite: $error';
  }

  @override
  String get invite_generating => 'Generating your invite code...';

  @override
  String invite_generateFailed(String error) {
    return 'Could not generate an invite: $error';
  }

  @override
  String get invite_revoking => 'Revoking the code...';

  @override
  String invite_revokeFailed(String error) {
    return 'Could not revoke: $error';
  }

  @override
  String get invite_shareHint =>
      'Share this code with the person you\'re hiring - they\'ll enter it when registering as an Assistant.';

  @override
  String invite_expires(String date) {
    return 'Expires $date';
  }

  @override
  String get invite_copied => 'Copied to clipboard';

  @override
  String get invite_revoke => 'Revoke';

  @override
  String get invite_generateNew => 'Generate a new one instead';

  @override
  String get invite_generateHint =>
      'Generate a one-time code for the person you\'re hiring - it works for 48 hours or until used once, whichever comes first.';

  @override
  String get invite_generate => 'Generate Invite Code';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_subscriptionBilling => 'Subscription & Billing';

  @override
  String get settings_accountData => 'Account & Data';

  @override
  String get settings_exportData => 'Export Data';

  @override
  String get hours_title => 'Business Hours';

  @override
  String get account_title => 'Manage Account';

  @override
  String get settings_general => 'General';

  @override
  String get printer_title => 'Printer & Receipt Settings';

  @override
  String get settings_helpSupport => 'Help & Support';

  @override
  String get settings_appInfo => 'App Info';

  @override
  String get settings_preferences => 'Preferences';

  @override
  String get uiSettings_title => 'UI Settings';

  @override
  String get settings_themeLayout => 'Theme & layout';

  @override
  String get settings_currency => 'Currency';

  @override
  String get settings_languageBoth => 'Language / Lugha';

  @override
  String get settings_selectLanguageBoth => 'SELECT LANGUAGE / CHAGUA LUGHA';

  @override
  String settings_versionLine(String appName, String version) {
    return '$appName - v$version';
  }

  @override
  String get settings_selectPane => 'Select a setting from the left';

  @override
  String get settings_appName => 'App Name';

  @override
  String get settings_version => 'Version';

  @override
  String get settings_builtFor => 'Built For';

  @override
  String get settings_builtForValue =>
      'Veterinary & agrovet business management';

  @override
  String get uiSettings_colourTheme => 'COLOUR THEME';

  @override
  String get uiSettings_appearance => 'APPEARANCE';

  @override
  String get uiSettings_darkMode => 'Dark Mode';

  @override
  String get uiSettings_comingSoon => 'Coming soon';

  @override
  String get uiSettings_layout => 'LAYOUT';

  @override
  String get uiSettings_layoutFixed => 'Layout Fixed Mode';

  @override
  String get uiSettings_layoutFixedHint =>
      'Keeps the sidebar open and hides its collapse button on large screens.';

  @override
  String get uiSettings_system => 'SYSTEM';

  @override
  String get uiSettings_systemRefresh => 'System Refresh';

  @override
  String get uiSettings_systemRefreshHint =>
      'Reloads your data and takes you back to the start. You stay signed in.';

  @override
  String get uiSettings_savedOnDevice => 'Saved on this device';

  @override
  String get uiSettings_refreshTitle => 'Refresh the app?';

  @override
  String get uiSettings_refreshBody =>
      'This reloads your data and takes you back to the start. You stay signed in, but anything you haven\'t saved will be lost.';

  @override
  String get uiSettings_themeKilimanjaro => 'Kilimanjaro Green';

  @override
  String get uiSettings_themeSerengeti => 'Serengeti Yellow';

  @override
  String get uiSettings_themeVictoria => 'Victoria Blue';

  @override
  String get hours_saved => 'Business hours saved';

  @override
  String get hours_saveFailed => 'Couldn\'t save the business hours';

  @override
  String get hours_intro =>
      'Sets when the \"Generate Today\'s Report\" button becomes active in View Reports.';

  @override
  String get hours_weekdays => 'Weekdays (Mon–Fri)';

  @override
  String get hours_saturday => 'Saturday';

  @override
  String get hours_sunday => 'Sunday';

  @override
  String get hours_allowAnytime => 'Allow anytime';

  @override
  String get hours_allowAnytimeHint =>
      'Emergency override - makes the report button active regardless of the schedule above. Turn this on for an early closure, and back off once things return to normal.';

  @override
  String get hours_save => 'Save Business Hours';

  @override
  String get hours_closedAllDay => 'Closed all day';

  @override
  String hours_closesAt(String time) {
    return 'Closes at $time';
  }

  @override
  String get hours_noClosingTime => 'No closing time needed - closed all day.';

  @override
  String get profile_logoUpdated => 'Logo updated';

  @override
  String get profile_logoFailed => 'Couldn\'t update the logo';

  @override
  String get profile_yourFacility => 'Your facility';

  @override
  String get profile_title => 'Business Profile';

  @override
  String get profile_logoHint =>
      'This logo appears on the dashboard, receipts, and anywhere your facility is shown throughout the app.';

  @override
  String get profile_changeLogo => 'Change Logo';

  @override
  String get profile_uploadLogo => 'Upload Logo';

  @override
  String get searchIndex_title => 'Rebuild Client Search Index';

  @override
  String get searchIndex_body =>
      'This makes clients added before search was available show up correctly when searched by name, and lets the app spot a new client whose phone number or name matches one you already have. It only needs to be run once - clients that are already up to date are left alone.';

  @override
  String get searchIndex_nothing =>
      'Nothing to update - every client is already searchable.';

  @override
  String searchIndex_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done. $count clients updated and now searchable.',
      one: 'Done. 1 client updated and now searchable.',
    );
    return '$_temp0';
  }

  @override
  String searchIndex_failed(String error) {
    return 'Could not complete: $error';
  }

  @override
  String get searchIndex_run => 'Run Now';

  @override
  String get printer_unavailableConnect =>
      'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t connect to a printer from a web browser.';

  @override
  String get printer_unavailableList =>
      'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t list paired devices from a web browser.';

  @override
  String printer_connected(String name) {
    return 'Connected to $name';
  }

  @override
  String printer_connectFailedNamed(String name) {
    return 'Couldn\'t connect to $name';
  }

  @override
  String get printer_connectFailed => 'Couldn\'t connect to the printer';

  @override
  String get printer_disconnectFailed => 'Couldn\'t disconnect the printer';

  @override
  String get printer_testSent => 'Test page sent to printer';

  @override
  String get printer_testFailed => 'Couldn\'t print the test page';

  @override
  String get printer_savedPrinter => 'Saved printer';

  @override
  String get printer_statusConnected => 'Connected';

  @override
  String get printer_statusNotConnected => 'Not connected';

  @override
  String get printer_disconnect => 'Disconnect';

  @override
  String get printer_forget => 'Forget this printer';

  @override
  String get printer_paired => 'Paired Devices';

  @override
  String get printer_pairHint =>
      'Pair your printer in your device\'s Bluetooth settings first - this list only shows devices already paired there.';

  @override
  String get printer_noPaired => 'No paired devices found.';

  @override
  String get printer_connect => 'Connect';

  @override
  String get printer_printOptions => 'Print Options';

  @override
  String get printer_paperSize => 'Paper Size';

  @override
  String printer_paperWidth(String width) {
    return '${width}mm';
  }

  @override
  String get printer_autoPrint => 'Auto-print receipt after each sale';

  @override
  String get printer_sending => 'Sending...';

  @override
  String get printer_sendTest => 'Send Test Print';

  @override
  String get printer_connectFirst => 'Connect a printer above before testing.';

  @override
  String get common_serviceRecords => 'Service Records';

  @override
  String get trash_restoreSaleTitle => 'Restore this sale?';

  @override
  String get trash_restoreSaleBody =>
      'The sale will be back in your sales list, but restoring will NOT change:\n• stock: the items stay back on the shelf, as they were put back when the sale was deleted\n• debt: the client\'s debt for this sale is not re-created\n• client balance: it stays as it is now\n\nAdjust these by hand if the sale really happened.';

  @override
  String get trash_restoreServiceTitle => 'Restore this service?';

  @override
  String get trash_restoreServiceBody =>
      'The service will be back in your services list, but restoring will NOT change:\n• stock: the items it used stay back in stock\n• debt: the client\'s debt for this service is not re-created\n• client balance: it stays as it is now\n• expenses: its expense transaction was deleted for good and does not come back\n\nAdjust these by hand if the service really happened.';

  @override
  String get trash_restored => 'Item restored';

  @override
  String get trash_restoreFailed => 'Couldn\'t restore the item';

  @override
  String get trash_deleteForeverTitle => 'Delete Forever?';

  @override
  String trash_deleteForeverBody(String label) {
    return '\"$label\" will be permanently deleted. This cannot be undone.';
  }

  @override
  String get trash_deleteForever => 'Delete Forever';

  @override
  String get trash_deleted => 'Permanently deleted';

  @override
  String get trash_deleteFailed => 'Couldn\'t delete the item permanently';

  @override
  String get trash_empty => 'Trash is empty';

  @override
  String trash_expiringBanner(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count items will be permanently deleted within $days days. Restore now if you still need them.',
      one:
          '1 item will be permanently deleted within $days days. Restore now if you still need it.',
    );
    return '$_temp0';
  }

  @override
  String get trash_deletingSoon => 'Deleting soon';

  @override
  String get trash_expiresTomorrow => 'Expires tomorrow';

  @override
  String trash_expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count days',
    );
    return '$_temp0';
  }

  @override
  String trash_deletedBy(String name) {
    return 'Deleted by $name';
  }

  @override
  String trash_deletedByOn(String name, String date) {
    return 'Deleted by $name on $date';
  }

  @override
  String get export_title => 'Export Center';

  @override
  String get export_step1 => '1. Select Dataset Category';

  @override
  String get export_step2 => '2. Scope & Date Range Filtering';

  @override
  String get export_step3 => '3. Output Document Layout';

  @override
  String get export_salesTransactions => 'Sales & Transactions';

  @override
  String get export_salesTransactionsHint =>
      'Sales (incl. archived) and transaction history';

  @override
  String get export_serviceRecordsHint =>
      'Services performed (incl. archived), by client and category';

  @override
  String get export_productCatalog => 'Product Inventory Catalog';

  @override
  String get export_productCatalogHint =>
      'Current stock levels, costs, and SKU list';

  @override
  String get export_clientDirectory => 'Client Directory & Balances';

  @override
  String get export_clientDirectoryHint =>
      'Client contacts and current outstanding balances';

  @override
  String get export_debtors => 'Debtors / Outstanding Balances';

  @override
  String get export_debtorsHint => 'Itemized list of everything currently owed';

  @override
  String get export_paymentsLedger => 'Payments Ledger';

  @override
  String get export_paymentsLedgerHint =>
      'Every payment collected - sales, services, debts, other income';

  @override
  String get export_activityLog => 'Activity Log';

  @override
  String get export_activityLogHint => 'Who did what, and when';

  @override
  String export_done(String dataset) {
    return 'Exported $dataset';
  }

  @override
  String export_failed(String dataset) {
    return 'Couldn\'t export $dataset';
  }

  @override
  String get export_selectStart => 'Select Start Date';

  @override
  String get export_selectEnd => 'Select End Date';

  @override
  String get export_dateRange => 'Date Range';

  @override
  String get export_last7 => 'Last 7 Days';

  @override
  String get export_last30 => 'Last 30 Days';

  @override
  String get export_lastMonth => 'Last Month';

  @override
  String get export_thisYear => 'This Year';

  @override
  String get export_allTime => 'All Time';

  @override
  String get export_customRange => 'Custom Range...';

  @override
  String get export_notApplicable =>
      'Not applicable - this is a current snapshot';

  @override
  String get export_pickRange => 'Please select a date range below';

  @override
  String get export_allRecords => 'All Records (No Filters Applied)';

  @override
  String export_rangeLine(String start, String end) {
    return '$start  to  $end';
  }

  @override
  String get export_scope => 'Date Selection Scope';

  @override
  String get export_modify => 'Modify';

  @override
  String get export_xlsx => 'Excel Workbook (.xlsx)';

  @override
  String get export_xlsxHint =>
      'Bolded headers, multiple sheets, real dates - opens clean, ready to keep';

  @override
  String get export_csv => 'CSV (Plain Text)';

  @override
  String get export_csvHint =>
      'Universal, simple text - opens in Excel, Sheets, or any editor';

  @override
  String get export_pickRangeFirst =>
      'Select a date range above before exporting.';

  @override
  String get export_pickRangeWarning => 'Select a date range before exporting';

  @override
  String get export_generate => 'Generate & Export Data';

  @override
  String get account_logoutAllTitle => 'Log Out of All Devices?';

  @override
  String get account_logoutAllBody =>
      'This will clear active sessions and log you out on all other phones, tablets, or computers currently signed into your account.';

  @override
  String get account_logoutEverywhere => 'Log Out Everywhere';

  @override
  String get account_logoutAllFailed => 'Couldn\'t clear other sessions';

  @override
  String get account_thisFacility => 'this facility';

  @override
  String get account_wipeTitle => 'Wipe All Data?';

  @override
  String account_wipeFacility(String facility) {
    return 'Business data for \"$facility\" will be permanently wiped.';
  }

  @override
  String get account_wipeBody =>
      'All records of sales, products, clients, and transactions for this facility are erased. Other facilities you have are not affected. Your login credentials remain unaffected.';

  @override
  String get account_wipe => 'Wipe Data';

  @override
  String get account_confirmTitle => 'Confirm Action';

  @override
  String account_typeErase(String word) {
    return 'Please type \"$word\" to finalize clearing all records:';
  }

  @override
  String get account_wiped => 'All business data permanently wiped';

  @override
  String get account_wipeFailed => 'Couldn\'t clear the records';

  @override
  String get account_cannotDeactivateTitle => 'Cannot Deactivate';

  @override
  String get account_cannotDeactivateBody =>
      'This account has Platform Admin access, so it can\'t be deactivated - not by you, and not by anyone else. This keeps the platform from ever being locked out of its own oversight tools.';

  @override
  String get account_deactivateTitle => 'Deactivate Account';

  @override
  String get account_deactivateBody =>
      'Are you sure you want to deactivate your account? You\'ll be signed out immediately, and will need your facility admin (or Platform Admin) to reactivate it before you can sign back in.';

  @override
  String get account_confirmDeactivation => 'Confirm Deactivation';

  @override
  String account_typeToConfirm(String word) {
    return 'Type \"$word\" to confirm:';
  }

  @override
  String get account_deactivated => 'Your account has been deactivated.';

  @override
  String get account_deactivateFailed => 'Couldn\'t deactivate the account';

  @override
  String get account_deleteTitle => 'Delete Account';

  @override
  String get account_deleteWarning =>
      'Deleting your account is permanent and cannot be undone. All your data will be erased.';

  @override
  String get account_deleted => 'Your account has been deleted';

  @override
  String get account_deleteFailed => 'Couldn\'t delete the account';

  @override
  String get account_checking => 'Checking...';

  @override
  String get account_platformAdminNoDelete =>
      'Platform Admin accounts can\'t be deleted from here.';

  @override
  String get account_deleteOwnedFirst =>
      'Delete all facilities you own in View Facilities first.';

  @override
  String get account_deleteHint =>
      'Permanently delete your account. This action cannot be undone.';

  @override
  String get account_dangerZone => 'Danger Zone';

  @override
  String get account_dangerHint =>
      'These actions affect your account and business data. Review carefully before proceeding.';

  @override
  String get account_logoutAll => 'Log Out of All Devices';

  @override
  String get account_logoutAllHint =>
      'Disconnect your active profile session from all other active platforms.';

  @override
  String get account_wipeAll => 'Wipe All Business Data';

  @override
  String get account_wipeInProgress =>
      'Erase in progress - please wait, this may take a moment...';

  @override
  String get account_wipeHint =>
      'Permanently delete records of transactions, sales, and products while keeping your log in profile.';

  @override
  String get account_deactivateHint =>
      'Temporarily disable your account. Can be reactivated later.';

  @override
  String get common_walkIn => 'Walk-in';

  @override
  String services_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new services available',
      one: '1 new service available',
    );
    return '$_temp0';
  }

  @override
  String get services_empty => 'No services yet';

  @override
  String get services_emptyFiltered => 'No services match your filters';

  @override
  String get services_totalServices => 'Total Services';

  @override
  String get services_paidAmount => 'Paid Amount';

  @override
  String get services_digitalPayments => 'Digital Payments';

  @override
  String get services_last30 => 'Last 30 days';

  @override
  String get services_last7 => 'Last 7 days';

  @override
  String get services_thisMonth => 'This month';

  @override
  String get services_subtitle => 'Track all services provided to your clients';

  @override
  String get services_recordVisit => 'Record Visit';

  @override
  String get services_archive => 'Archive';

  @override
  String get services_searchHint =>
      'Search service by client, category, note...';

  @override
  String get services_colServiceCategory => 'Service / Category';

  @override
  String get services_colProvider => 'Provider';

  @override
  String get services_none => 'No services';

  @override
  String get services_deleteTitle => 'Delete Service?';

  @override
  String get services_deleteBody =>
      'This moves the service to Trash and puts its stock back, removes its debt and updates the client\'s balance. Restoring from Trash brings back the record only.';

  @override
  String get services_movedToTrash => 'Service moved to Trash';

  @override
  String get services_deleteFailed => 'Couldn\'t delete the service';

  @override
  String get services_detailsTitle => 'Service Details';

  @override
  String get services_paymentInfo => 'Payment Information';

  @override
  String get services_transactionId => 'Transaction ID';

  @override
  String get services_paidOn => 'Paid On';

  @override
  String get services_providedBy => 'Provided By';

  @override
  String get services_serviceDate => 'Service Date';

  @override
  String get services_createdOn => 'Created On';

  @override
  String get services_fallbackName => 'Service';

  @override
  String get services_archiveTitle => 'Services Archive';

  @override
  String services_archiveSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Services archived after $days days',
    );
    return '$_temp0';
  }

  @override
  String get services_archiveEmpty => 'No archived services found';

  @override
  String get services_archiveEmptyHint =>
      'Try a different search, category, or date range';

  @override
  String services_archivePeriod(String start, String end) {
    return 'Period: $start – $end';
  }

  @override
  String get services_archivedServices => 'Archived services';

  @override
  String services_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count found',
    );
    return '$_temp0';
  }

  @override
  String services_archiveShowing(int start, int end, int total, String more) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total$more services',
    );
    return '$_temp0';
  }

  @override
  String services_pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String services_notesValue(String notes) {
    return 'Notes: $notes';
  }

  @override
  String get services_searchArchiveTitle => 'Search Archived Services';

  @override
  String get services_searchBy => 'Search By:';

  @override
  String get services_specificMonth => 'Specific Month';

  @override
  String services_archiveCutoffNote(String date) {
    return 'Only services before $date have reached the archive.';
  }

  @override
  String get services_selectMonth => 'Select Month:';

  @override
  String get services_editVisit => 'Edit Visit';

  @override
  String get services_selectClientRequired => 'Select Client *';

  @override
  String get services_clientSearchHint => 'Search or select client...';

  @override
  String get services_errSelectClient => 'Please select a client';

  @override
  String get services_addNewClient => 'Add New Client';

  @override
  String get services_visitDetails => 'Visit Details';

  @override
  String get services_serviceName => 'Service Name';

  @override
  String get services_errServiceName => 'Enter service name';

  @override
  String get services_errProvider => 'Enter provider';

  @override
  String get services_itemsUsed => 'Expenses (Items Used)';

  @override
  String get services_addItem => 'Add Item';

  @override
  String get services_itemName => 'Item Name';

  @override
  String get services_errItemName => 'Enter name';

  @override
  String get services_noMatchingProduct =>
      'No matching product - will be recorded as a plain expense.';

  @override
  String services_sellableQty(String quantity, String unit) {
    return 'Sellable: $quantity $unit';
  }

  @override
  String get services_inStockDeduct =>
      'In stock - will deduct, no expense recorded';

  @override
  String get services_errPrice => 'Enter price';

  @override
  String services_totalItemsCost(String amount) {
    return 'Total Items Cost: $amount';
  }

  @override
  String get services_visitSummary => 'Visit Summary';

  @override
  String services_totalAmountRequired(String currency) {
    return 'Total Amount ($currency) *';
  }

  @override
  String get services_errTotalAmount => 'Enter total amount';

  @override
  String services_totalPaidRequired(String currency) {
    return 'Total Paid ($currency) *';
  }

  @override
  String get services_errPaidAmount => 'Enter paid amount';

  @override
  String get services_transactionIdOptional => 'Transaction ID (optional)';

  @override
  String get services_errPaidOverTotal =>
      'Total Paid cannot exceed Total Amount';

  @override
  String get services_updated => 'Service updated';

  @override
  String get services_added => 'Service added';

  @override
  String get services_saveFailed => 'Couldn\'t save the service';

  @override
  String get services_updateVisit => 'Update Visit';

  @override
  String get services_noClientFound => 'No client found';

  @override
  String get receipt_shareFailed => 'Couldn\'t share the receipt';

  @override
  String get receipt_pdfFailed => 'Couldn\'t generate the PDF';

  @override
  String get receipt_previewTitle => 'Receipt Preview';

  @override
  String get receipt_formatThermal => 'Receipt (Thermal)';

  @override
  String get receipt_formatA4 => 'A4 Format';

  @override
  String get receipt_shareSave => 'Share / Save';

  @override
  String get receipt_details => 'Receipt Details';

  @override
  String get receipt_number => 'Receipt Number';

  @override
  String get receipt_customer => 'Customer';

  @override
  String get receipt_quickActions => 'Quick Actions';

  @override
  String get receipt_infoNote =>
      'This receipt shows the final amount paid for the selected transaction. You can print or share it for your records.';

  @override
  String get receipt_statusPartiallyPaid => 'Partially Paid';

  @override
  String get receipt_statusBalanceDue => 'Balance Due';

  @override
  String get receipt_statusPaidInFull => 'Paid in Full';

  @override
  String get common_notApplicable => 'N/A';

  @override
  String get reports_thisYear => 'This year';

  @override
  String get reports_pastTitle => 'Past Reports';

  @override
  String get reports_pastSubtitle =>
      'Every daily closing report for this facility';

  @override
  String get reports_noneYet => 'No reports generated yet.';

  @override
  String get reports_noMatch => 'No reports match your search.';

  @override
  String get reports_loadMore => 'Load more';

  @override
  String get reports_searchHint => 'Search reports...';

  @override
  String get reports_generatedCount => 'Reports generated';

  @override
  String get reports_loadedPeriod => 'Loaded period';

  @override
  String get reports_latest => 'Latest';

  @override
  String reports_rowSummary(String amount, String name) {
    return '$amount total revenue - generated by $name';
  }

  @override
  String get reports_notSubmitted => 'Not submitted';

  @override
  String get reports_completed => 'Completed';

  @override
  String reports_submittedBy(String name) {
    return 'Submitted by $name';
  }

  @override
  String get reports_draftNotSubmitted => 'Draft - not yet submitted';

  @override
  String get reports_pdf => 'PDF';

  @override
  String get reports_fullReport => 'Full Report';

  @override
  String get reports_dailyClosingReport => 'Daily Closing Report';

  @override
  String get reports_dailySummary => 'Daily Summary';

  @override
  String get reports_totalSales => 'Total Sales';

  @override
  String get reports_serviceRevenue => 'Service Revenue';

  @override
  String get reports_totalRevenue => 'Total Revenue';

  @override
  String get reports_newDebtToday => 'New Debt Today';

  @override
  String get reports_noSalesToday => 'No sales recorded today.';

  @override
  String get reports_vetServices => 'Veterinary Services';

  @override
  String get reports_noServicesToday => 'No services provided today.';

  @override
  String get reports_productMovement => 'Product Movement';

  @override
  String get reports_noMovementToday => 'No product movement today.';

  @override
  String reports_movementLine(int sold, int closing, String unit) {
    return 'Sold: $sold $unit  |  Closing: $closing $unit';
  }

  @override
  String reports_movementLineAdjusted(
    int sold,
    String adjustment,
    int closing,
    String unit,
  ) {
    return 'Sold: $sold $unit  |  Adjusted: $adjustment $unit  |  Closing: $closing $unit';
  }

  @override
  String get reports_expectedVsPhysical => 'Expected vs Physical Stock';

  @override
  String get reports_noWatchlisted =>
      'No watch-listed products for this facility.';

  @override
  String get reports_countsNotSubmitted =>
      'Physical counts have not been submitted yet.';

  @override
  String reports_expectedPhysical(int expected, String physical) {
    return 'Expected: $expected  |  Physical: $physical';
  }

  @override
  String get reports_debtActivity => 'Debt Activity';

  @override
  String get reports_noDebtActivity => 'No debt activity today.';

  @override
  String get reports_expensesRecorded => 'Expenses Recorded';

  @override
  String get reports_noExpensesToday => 'No expenses recorded today.';

  @override
  String get reports_paymentReconciliation => 'Payment Reconciliation';

  @override
  String get reports_noPaymentsToday => 'No payments recorded today.';

  @override
  String get reports_expectedBalance => 'Expected balance';

  @override
  String get reports_physicalBalance => 'Physical balance counted';

  @override
  String get reports_variance => 'Variance';

  @override
  String reports_varianceValue(String amount) {
    return '$amount - VARIANCE';
  }

  @override
  String reports_matchValue(String amount) {
    return '$amount - Match';
  }

  @override
  String get reports_reason => 'Reason';

  @override
  String reports_outflowOnly(String method) {
    return 'No income via $method today - outflow only, no count needed.';
  }

  @override
  String get reports_notYetSubmitted => 'Not yet submitted.';

  @override
  String get reports_paymentMethods => 'Payment Methods';

  @override
  String get reports_noSalesShort => 'No sales today.';

  @override
  String get reports_noServicesShort => 'No services today.';

  @override
  String get reports_noRepaymentsShort => 'No repayments today.';

  @override
  String get reports_noOtherIncomeShort => 'No other income today.';

  @override
  String get reports_declaration => 'Daily Closing Declaration';

  @override
  String get reports_declarationConfirmed =>
      'Confirmed - I have reviewed today\'s transactions and that the cash and stock figures entered represent the closing figures for my shift.';

  @override
  String get reports_notConfirmed => 'Not yet confirmed.';

  @override
  String get reports_submitFailed => 'Couldn\'t submit the report';

  @override
  String get reports_reviewSubmit => 'Review & Submit';

  @override
  String get reports_reviewIntro =>
      'Sales, services, transactions, and debt activity have already been calculated automatically. Count the items below and enter what you actually find before submitting.';

  @override
  String get reports_physicalStockCount => 'Physical Stock Count';

  @override
  String get reports_watchlistedHint =>
      'Watch-listed products only - count these before submitting.';

  @override
  String reports_expectedValue(int count) {
    return 'Expected: $count';
  }

  @override
  String get reports_physicalCount => 'Physical count';

  @override
  String reports_varianceCount(String variance) {
    return '$variance variance';
  }

  @override
  String get reports_match => 'Match';

  @override
  String get reports_varianceReasonHint =>
      'Reason for variance (e.g. damaged, unable to locate)';

  @override
  String get reports_errVarianceReason =>
      'Please provide a reason for the variance.';

  @override
  String get reports_countEachMethod =>
      'Count what you actually have for each method used today - mobile money balance, bank balance, and cash in the drawer.';

  @override
  String get reports_amountPaidOut => 'Amount paid out';

  @override
  String reports_noIncomeVia(String method) {
    return 'No income came in via $method today - just an outflow. No physical count needed here.';
  }

  @override
  String get reports_physicalBalanceRequired => 'Physical balance counted *';

  @override
  String reports_methodVariance(String method, String amount) {
    return '$method variance: $amount';
  }

  @override
  String reports_methodVarianceReason(String method) {
    return 'Reason for $method variance';
  }

  @override
  String reports_methodMatches(String method) {
    return '$method matches';
  }

  @override
  String get reports_confirmDeclaration =>
      'I confirm that I have reviewed today\'s transactions and that the cash and stock figures entered above represent the closing figures for my shift.';

  @override
  String get reports_blockedCounts =>
      'Enter a physical count for every watch-listed product';

  @override
  String get reports_blockedBalances =>
      'Enter the physical balance for every payment method';

  @override
  String get reports_blockedReason =>
      'Please provide a reason for the variance found';

  @override
  String get reports_blockedDeclaration =>
      'Confirm the closing declaration to submit';

  @override
  String get reports_submitDailyClosing => 'Submit Daily Closing';

  @override
  String get reports_tabStock => 'Stock Reconciliation';

  @override
  String get reports_tabDebt => 'Debt';

  @override
  String get reports_tabProducts => 'Products';

  @override
  String get reports_outstandingNewDebt => 'Outstanding New Debt';

  @override
  String get reports_servicesPerformed => 'Services Performed';

  @override
  String get reports_productsSold => 'Products Sold';

  @override
  String reports_unitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
    );
    return '$_temp0';
  }

  @override
  String get reports_totalRevenueToday => 'Total Revenue Today';

  @override
  String reports_generatedAtBy(String time, String name) {
    return 'Generated at $time by $name';
  }

  @override
  String reports_submittedAt(String time) {
    return 'Submitted at $time';
  }

  @override
  String reports_soldCount(int count) {
    return 'Sold: $count';
  }

  @override
  String get reports_colTime => 'Time';

  @override
  String get reports_colReceipt => 'Receipt';

  @override
  String get reports_colItems => 'Items';

  @override
  String get reports_colPayment => 'Payment';

  @override
  String get reports_colService => 'Service';

  @override
  String get reports_colNumber => 'Number';

  @override
  String get reports_colRevenue => 'Revenue';

  @override
  String get reports_totalServiceRevenue => 'Total Service Revenue';

  @override
  String get reports_colProduct => 'Product';

  @override
  String get reports_colUnit => 'Unit';

  @override
  String get reports_colOpening => 'Opening';

  @override
  String get reports_colAdded => 'Added';

  @override
  String get reports_colAdjusted => 'Adjusted';

  @override
  String get reports_colSold => 'Sold';

  @override
  String get reports_colExpectedClosing => 'Expected Closing';

  @override
  String get reports_totalUnitsSold => 'Total Units Sold';

  @override
  String get reports_systemTracked =>
      'System-tracked - only products with movement today, or watch-listed products, are shown.';

  @override
  String get reports_watchlistedOnly => 'Watch-listed products only.';

  @override
  String get reports_colExpected => 'Expected';

  @override
  String get reports_colPhysical => 'Physical';

  @override
  String get reports_colDifference => 'Difference';

  @override
  String reports_reasonValue(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get reports_newDebtTodayLower => 'New debt today';

  @override
  String get reports_repaymentsCollected => 'Repayments collected';

  @override
  String get reports_outstandingChange => 'Outstanding change';

  @override
  String get reports_byCustomer => 'By Customer';

  @override
  String get reports_colNewDebt => 'New Debt';

  @override
  String get reports_colRepayment => 'Repayment';

  @override
  String get reports_colClosing => 'Closing';

  @override
  String get reports_totalExpenses => 'Total Expenses';

  @override
  String get reports_allTransactions => 'All Transactions';

  @override
  String get reports_transactionsNote =>
      'Income and expenses recorded directly, separate from sales and service revenue.';

  @override
  String get reports_noTransactionsToday => 'No transactions recorded today.';

  @override
  String get reports_everythingToday => 'Everything recorded today, in order.';

  @override
  String get reports_activityNotIncluded =>
      'Not included - this draft was generated by an assistant, who can only see their own activity. Delete the draft and generate it again for the full log.';

  @override
  String get reports_noActivityToday => 'No activity recorded today.';

  @override
  String get reports_colBy => 'By';

  @override
  String get reports_combinedAll => 'Combined - All Payment Methods';

  @override
  String get reports_combinedNote =>
      'Sales, services, debt repayments, and other income together, by how it was actually received.';

  @override
  String get reports_generateFailed => 'Couldn\'t generate the report';

  @override
  String get reports_deleteDraftTitle => 'Delete Draft?';

  @override
  String get reports_deleteDraftBody =>
      'This clears today\'s draft report so it can be regenerated from scratch. It doesn\'t affect any of the underlying sales, services, or transactions - only this working snapshot.';

  @override
  String get reports_deleteDraft => 'Delete Draft';

  @override
  String get reports_deleteDraftFailed => 'Couldn\'t delete the draft';

  @override
  String get reports_shareFailed => 'Couldn\'t share the report';

  @override
  String get reports_viewTitle => 'View Reports';

  @override
  String get reports_viewSubtitle => 'Daily closing report for this facility';

  @override
  String get reports_todaySubmitted => 'Today\'s Report - Submitted';

  @override
  String get reports_continueClosing => 'Continue Closing';

  @override
  String get reports_generateToday => 'Generate Today\'s Report';

  @override
  String get reports_generateClosedToday =>
      'Generate Today\'s Report (closed today)';

  @override
  String reports_generateAt(String time) {
    return 'Generate Today\'s Report (at $time)';
  }

  @override
  String get reports_generateAfterClosing =>
      'Generate Today\'s Report (after closing time)';

  @override
  String get reports_tapGenerate =>
      'Tap \"Generate Today\'s Report\" above to get started.';

  @override
  String get reports_closedToday => 'This facility is marked closed today.';

  @override
  String reports_availableAt(String time) {
    return 'Available at $time.';
  }

  @override
  String get reports_availableOnceClosing =>
      'Available once today\'s closing time is reached.';

  @override
  String get reports_noneToday => 'No report generated yet today';

  @override
  String get reports_todayHeading => 'Daily Closing Report - Today\'s Report';

  @override
  String get reports_viewFull => 'View Full Report';

  @override
  String get reports_viewFullHint => 'See all sections in detail';

  @override
  String get reports_downloadPdf => 'Download PDF';

  @override
  String get reports_downloadPdfHint => 'Get a printable report';

  @override
  String get reports_deleteDraftHint => 'Clear today\'s draft to restart';

  @override
  String get reports_shareWithAdmin => 'Share with Admin';

  @override
  String get reports_shareWithAdminHint => 'Send report to your admin';

  @override
  String get reports_accountability => 'Accountability';

  @override
  String get reports_submittedByLabel => 'Submitted by';

  @override
  String get reports_declarationPending =>
      'This declaration is confirmed as part of Submit Daily Closing, once physical stock and cash counts have been entered.';

  @override
  String get reports_savedNote =>
      'The report will be saved in the system and available for you and the admin to view or download at any time.';

  @override
  String get batch_mergedIntoExisting =>
      'Added to the existing batch with this number and expiry';

  @override
  String get batch_added => 'New batch added';

  @override
  String get batch_addFailed => 'Couldn\'t add the batch';

  @override
  String get batch_addIntro =>
      'Choose where this delivery goes - this is recorded as its own batch, separate from any existing stock.';

  @override
  String get batch_batchNoOptional => 'Batch No (optional)';

  @override
  String get batch_expiryDate => 'Expiry Date';

  @override
  String get batch_addStockTo => 'Add This Stock To';

  @override
  String get batch_storeHint =>
      'Needs a separate \"Release\" step before it can be sold';

  @override
  String get batch_sellableOption => 'Sellable (straight to the shelf)';

  @override
  String get batch_sellableHint => 'Ready to sell immediately';

  @override
  String get batch_quantityReceived => 'Quantity Received';

  @override
  String get batch_validQuantity => 'Enter a valid quantity';

  @override
  String batch_buyPriceLabel(String currency) {
    return 'Buy Price ($currency)';
  }

  @override
  String get batch_addBatch => 'Add Batch';

  @override
  String get batch_moveToStock => 'Move to Stock';

  @override
  String get batch_removeFromSellable => 'Remove from Sellable';

  @override
  String batch_moveIntro(
    String product,
    String batchPart,
    String expiryPart,
    int quantity,
    String unit,
  ) {
    return '$product$batchPart$expiryPart. Up to $quantity $unit can move back to Stock Store.';
  }

  @override
  String batch_moveBatchPart(String batchNo) {
    return ' - Batch $batchNo';
  }

  @override
  String batch_moveExpiredPart(String date) {
    return ' (expired $date)';
  }

  @override
  String batch_moveExpiresPart(String date) {
    return ' (expires $date)';
  }

  @override
  String batch_quantityToMove(String unit) {
    return 'Quantity to move ($unit)';
  }

  @override
  String get batch_noteRequiredOther => 'Note (required for Other)';

  @override
  String get batch_noteOptional => 'Note (optional)';

  @override
  String batch_quantityUpTo(int max) {
    return 'Enter a quantity up to $max';
  }

  @override
  String get batch_selectReason => 'Select a reason';

  @override
  String get batch_describeReason => 'Describe the reason in the note below';

  @override
  String batch_movedBack(int quantity, String unit) {
    return 'Moved $quantity $unit back to Stock Store';
  }

  @override
  String batch_removedFromSellable(int quantity, String unit) {
    return 'Removed $quantity $unit from Sellable';
  }

  @override
  String get batch_moveFailed => 'Couldn\'t move the stock';

  @override
  String get batch_unlabeledTitle => 'Unlabeled Batch';

  @override
  String batch_currently(int stock, int sellable) {
    return 'Currently: $stock store · $sellable sellable';
  }

  @override
  String get batch_modeAdd => 'Add to it';

  @override
  String get batch_modeSet => 'Correct to';

  @override
  String get batch_modeAddHint =>
      'Adds this amount on top of what\'s already there (a top-up delivery).';

  @override
  String get batch_modeSetHint =>
      'Sets the exact amount on file right now (fixing a miscount).';

  @override
  String get batch_addStoreQty => 'Add to Store Qty';

  @override
  String get batch_setStoreQty => 'Correct Store Qty to';

  @override
  String get batch_addSellableQty => 'Add to Sellable Qty';

  @override
  String get batch_setSellableQty => 'Correct Sellable Qty to';

  @override
  String batch_saveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get batch_deleteExpiredTitle => 'Delete Expired Batch?';

  @override
  String get batch_deleteTitle => 'Delete This Batch?';

  @override
  String get batch_notExpiredWarning =>
      'This batch has not expired - it still has good, sellable stock.';

  @override
  String batch_deleteBody(String batch, int stock, int sellable) {
    return 'This permanently removes $batch and subtracts its $stock store and $sellable sellable units from this product\'s totals. This cannot be undone.';
  }

  @override
  String get batch_thisUnlabeled => 'this unlabeled batch';

  @override
  String batch_deleteFailed(String error) {
    return 'Could not delete: $error';
  }

  @override
  String get batch_editDetails => 'Edit Details';

  @override
  String get batch_batches => 'Batches';

  @override
  String batch_loadFailed(String error) {
    return 'Could not load batches: $error';
  }

  @override
  String get batch_noneYet => 'No batches recorded yet.';

  @override
  String get batch_unlabeled => 'Unlabeled batch';

  @override
  String get batch_outOfStock => 'Out of Stock - 0 available';

  @override
  String batch_rowQuantities(int stock, int sellable, String price) {
    return 'Store: $stock · Shelf: $sellable · $price';
  }

  @override
  String batch_expiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String batch_expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get batch_deleteExpiredTooltip => 'Delete expired batch';

  @override
  String get batch_deleteTooltip => 'Delete batch';

  @override
  String get batch_adjustQuantity => 'Adjust quantity';

  @override
  String get alerts_outOfStock => 'Out of Stock';

  @override
  String alerts_messageStock(String product, int sellable, int stock) {
    return '$product - Shelf: $sellable · Store: $stock';
  }

  @override
  String alerts_messageExpired(
    String product,
    String date,
    int quantity,
    String unit,
  ) {
    return '$product - expired $date · $quantity $unit on hand';
  }

  @override
  String alerts_messageExpiring(
    String product,
    String when,
    String date,
    int quantity,
    String unit,
  ) {
    return '$product - expires $when ($date) · $quantity $unit on hand';
  }

  @override
  String get alerts_today => 'today';

  @override
  String alerts_inDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String alerts_messageRestock(String product, int sellable, int stock) {
    return '$product - $sellable on shelf · $stock in store';
  }

  @override
  String get alerts_title => 'Product Alerts';

  @override
  String get alerts_subtitle => 'Stock and expiry problems that need action';

  @override
  String alerts_viewAllCount(int count) {
    return 'View all $count alerts';
  }

  @override
  String get alerts_viewAll => 'View all alerts';

  @override
  String get alerts_allCaughtUp => 'You\'re all caught up!';

  @override
  String get alerts_noneNow => 'No stock alerts right now.';

  @override
  String get alerts_hintLowStock => 'Below minimum level';

  @override
  String get alerts_hintDepleted => 'Nothing left';

  @override
  String get alerts_hintRestockShelf => 'Store has stock';

  @override
  String get alerts_hintExpiringSoon => 'Within 30 days';

  @override
  String get alerts_hintExpired => 'Still on hand';

  @override
  String get alerts_restock => 'Restock';

  @override
  String get alerts_moveToShelf => 'Move to shelf';

  @override
  String get alerts_adminOnlyMove =>
      'Only an admin can move stock to the shelf';

  @override
  String get alerts_viewBatches => 'View batches';

  @override
  String get alerts_removeExpired => 'Remove expired';

  @override
  String alerts_inStock(int count) {
    return '$count in stock';
  }

  @override
  String alerts_minRequired(int count) {
    return 'Min. required: $count';
  }

  @override
  String alerts_onShelf(int count) {
    return '$count on shelf';
  }

  @override
  String alerts_shelfMinimum(int count) {
    return 'Shelf minimum: $count';
  }

  @override
  String get alerts_expiresToday => 'Expires today';

  @override
  String alerts_expiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String alerts_dateOnHand(String date, int quantity, String unit) {
    return '$date · $quantity $unit on hand';
  }

  @override
  String alerts_onHand(int quantity, String unit) {
    return '$quantity $unit on hand';
  }

  @override
  String get alerts_searchHint => 'Search by product, category or alert...';

  @override
  String get alerts_noMatches => 'No alerts match your filters';

  @override
  String get alerts_colAlert => 'Alert';

  @override
  String get alerts_colStoreShelf => 'Store / Shelf';

  @override
  String get alerts_colAction => 'Action';

  @override
  String alerts_storeQty(int count) {
    return 'Store: $count';
  }

  @override
  String alerts_shelfQty(int count) {
    return 'Shelf: $count';
  }

  @override
  String alerts_storeShelfQty(int stock, int sellable) {
    return 'Store: $stock  ·  Shelf: $sellable';
  }

  @override
  String get alerts_none => 'No alerts';

  @override
  String alerts_showingRange(int start, int end, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total alerts',
      one: 'Showing $start to $end of 1 alert',
    );
    return '$_temp0';
  }

  @override
  String get products_smartDefaultsRunning => 'Recalculating smart defaults…';

  @override
  String products_smartDefaultsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Updated smart defaults for $count products with enough usage history',
      one: 'Updated smart defaults for 1 product with enough usage history',
    );
    return '$_temp0';
  }

  @override
  String get products_smartDefaultsNone =>
      'No products have enough sales/service history yet to compute smart defaults';

  @override
  String get products_smartDefaultsFailed =>
      'Couldn\'t recalculate smart defaults';

  @override
  String get products_shelfStockValue => 'Shelf Stock Value';

  @override
  String get products_watchlistFailed => 'Couldn\'t update the watchlist';

  @override
  String products_confirmDeleteNamed(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get products_noSellable => 'No sellable products';

  @override
  String get products_releaseFromStore => 'Release products from Stock Store';

  @override
  String get products_sellable => 'Sellable';

  @override
  String get products_nothingSellable => 'Out of stock - nothing sellable';

  @override
  String get products_sell => 'Sell';

  @override
  String get products_removeFromWatchlist => 'Remove from Watchlist';

  @override
  String get products_addToWatchlist => 'Add to Watchlist';

  @override
  String get products_sellableTitle => 'Sellable Products';

  @override
  String get products_sellableSubtitle => 'Products ready for sale';

  @override
  String get products_recalculateTooltip =>
      'Recalculate smart defaults from usage history';

  @override
  String get products_searchHint => 'Search product, brand or batch...';

  @override
  String products_stockBatch(int quantity, String unit, String batch) {
    return 'Stock: $quantity $unit • Batch: $batch';
  }

  @override
  String get products_watchlisted => 'Watch-listed for daily reports';

  @override
  String get products_selectFacilityFirst => 'Select a facility first';

  @override
  String get products_imageUploadFailed => 'Couldn\'t upload the image';

  @override
  String get products_addPhoto => 'Add photo';

  @override
  String get products_batchNo => 'Batch No';

  @override
  String get products_expiry => 'Expiry';

  @override
  String get products_selectType => 'Select Type';

  @override
  String get products_selectCategoryError => 'Please select a category';

  @override
  String get products_supplier => 'Supplier';

  @override
  String products_buyingPriceLabel(String currency) {
    return 'Buying Price ($currency)';
  }

  @override
  String products_sellingPriceLabel(String currency) {
    return 'Selling Price ($currency)';
  }

  @override
  String get products_greaterThanZero => 'Must be greater than 0';

  @override
  String get products_quantity => 'Quantity';

  @override
  String get products_cannotBeNegative => 'Cannot be negative';

  @override
  String get products_destinationTitle => 'Where should this product go?';

  @override
  String get products_destinationCatalog => 'Sellable Product Catalog';

  @override
  String get products_destinationCatalogHint =>
      'Available for sales and transactions';

  @override
  String get products_destinationStoreHint => 'Stored but not sellable yet';

  @override
  String get products_continue => 'Continue';

  @override
  String get products_nameExists => 'Product name already exists';

  @override
  String get products_addedToCatalog => 'Product added to Sellable Catalog';

  @override
  String get products_addedToStore => 'Product added to Stock Store';

  @override
  String get products_updated => 'Product updated';

  @override
  String get products_saveFailed => 'Couldn\'t save the product';

  @override
  String get products_editProduct => 'Edit Product';

  @override
  String get products_updateProduct => 'Update Product';

  @override
  String get products_saveProduct => 'Save Product';

  @override
  String get products_basicInfo => 'Basic Information';

  @override
  String get products_productName => 'Product Name';

  @override
  String get products_nameRequired => 'Product name is required';

  @override
  String products_alreadyExistsNamed(String name) {
    return '\"$name\" already exists';
  }

  @override
  String get products_openBelowHint =>
      'Adding new stock for it, or updating its quantity? Open it below - you can edit its details and quantity right there.';

  @override
  String get products_openThisProduct => 'Open This Product';

  @override
  String get products_similarExist => 'Similar products already exist';

  @override
  String get products_open => 'Open';

  @override
  String get products_details => 'Product Details';

  @override
  String get products_currentQuantity => 'Current Quantity';

  @override
  String get products_storeQty => 'Store Qty';

  @override
  String get products_invalid => 'Invalid';

  @override
  String get products_shelfQty => 'Shelf Qty';

  @override
  String get products_quantityEditHint =>
      'Editing these corrects the actual quantity on hand right now.';

  @override
  String products_manyBatchesHint(int count) {
    return 'This product has $count separate batches - manage them individually for accuracy.';
  }

  @override
  String get products_manageBatches => 'Manage Batches';

  @override
  String get products_addNewBatchLong =>
      'Add New Batch (new delivery, different expiry)';

  @override
  String get products_pricingStock => 'Pricing & Stock';

  @override
  String get products_additionalInfo => 'Additional Information';

  @override
  String get products_minStockLevel => 'Minimum Stock Level';

  @override
  String products_minStockHint(int count) {
    return 'e.g. 5 (defaults to $count if left blank)';
  }

  @override
  String get products_trackInReports => 'Track in Daily Reports';

  @override
  String get products_trackInReportsHint =>
      'Watch-listed products need a physical stock count before the daily closing report can be submitted.';

  @override
  String sales_newRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new sales available',
      one: '1 new sale available',
    );
    return '$_temp0';
  }

  @override
  String get sales_empty => 'No sales yet';

  @override
  String get sales_emptyFiltered => 'No sales match your filters';

  @override
  String get sales_collected => 'Collected';

  @override
  String get sales_pending => 'Pending';

  @override
  String get sales_searchHint => 'Search sale by product, client, invoice...';

  @override
  String get sales_paymentStatus => 'Payment Status';

  @override
  String get sales_seller => 'Seller';

  @override
  String get sales_title => 'Sales Records';

  @override
  String get sales_subtitle => 'Track and manage all sales transactions';

  @override
  String get sales_recordSale => 'Record Sale';

  @override
  String get sales_invoiceNo => 'Invoice No.';

  @override
  String sales_firstItem(String name, String quantity) {
    return '$name × $quantity';
  }

  @override
  String sales_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get sales_none => 'No sales';

  @override
  String get sales_deleteTitle => 'Delete Sale?';

  @override
  String sales_deleteBody(String invoice) {
    return 'This permanently deletes $invoice and restores its stock. This cannot be undone.';
  }

  @override
  String get sales_deleted => 'Sale deleted';

  @override
  String get sales_deleteFailed => 'Couldn\'t delete the sale';

  @override
  String get sales_details => 'Sale Details';

  @override
  String sales_quantityTimes(String quantity) {
    return '× $quantity';
  }

  @override
  String get sales_subtotal => 'Subtotal';

  @override
  String get sales_discount => 'Discount';

  @override
  String get sales_totalAmount => 'Total Amount';

  @override
  String get sales_paid => 'Paid';

  @override
  String get sales_balance => 'Balance';

  @override
  String get sales_archiveEmpty => 'No archived sales found';

  @override
  String get sales_archiveEmptyHint => 'Try a different search or date range';

  @override
  String get sales_archiveTitle => 'Sales Archive';

  @override
  String sales_archiveSubtitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Sales archived after $days days',
    );
    return '$_temp0';
  }

  @override
  String get sales_archivedSales => 'Archived sales';

  @override
  String sales_archiveShowing(int start, int end, int total, String more) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Showing $start to $end of $total$more sales',
    );
    return '$_temp0';
  }

  @override
  String get sales_item => 'Item';

  @override
  String get sales_searchArchiveTitle => 'Search Archived Sales';

  @override
  String get sales_archiveFullyPaidNote =>
      'Archived sales are always fully paid - sales still owing money stay in your active Sales tab regardless of age.';

  @override
  String sales_archiveCutoffNote(String date) {
    return 'Only sales before $date have reached the archive - anything newer is still in your active Sales list.';
  }

  @override
  String sales_noShelfStock(String product) {
    return '$product has no stock available on the shelf';
  }

  @override
  String get sales_saleDiscount => 'Sale Discount';

  @override
  String sales_discountAmountLabel(String currency) {
    return 'Discount Amount ($currency)';
  }

  @override
  String get sales_browseProducts => 'Browse Products';

  @override
  String get sales_browseFilterHint =>
      'Filter by name, batch no or category...';

  @override
  String get sales_filterByCategory => 'Filter by category';

  @override
  String get sales_allCategories => 'All Categories';

  @override
  String get sales_noProductsFound => 'No products found';

  @override
  String get sales_outOfStock => 'Out of stock';

  @override
  String sales_availablePrice(int quantity, String unit, String price) {
    return '$quantity $unit available · $price';
  }

  @override
  String get sales_expiredSaleBody =>
      'This product is expired. Do you still want to sell it?';

  @override
  String sales_expiredPortionLine(int quantity, String unit, String product) {
    return '• $quantity $unit of $product';
  }

  @override
  String get sales_sellAnyway => 'Sell Anyway';

  @override
  String get sales_addItemFirst => 'Add at least one item before saving';

  @override
  String get sales_partialNeedsRegistered =>
      'Select a registered client to allow a partial payment';

  @override
  String get sales_walkInPayInFull => 'Walk-in sales must be paid in full';

  @override
  String get sales_partialNeedsClient =>
      'Select a client to record a partial payment';

  @override
  String get sales_orChooseWalkIn =>
      'Or choose Walk-in Customer and collect payment in full';

  @override
  String get sales_selectPaymentMethod =>
      'Select a payment method before saving';

  @override
  String get sales_savedWithDebt => 'Sale saved and debt recorded';

  @override
  String get sales_saved => 'Sale saved';

  @override
  String get sales_saveFailed => 'Couldn\'t save the sale';

  @override
  String get sales_summary => 'Sale Summary';

  @override
  String get sales_totalItems => 'Total Items';

  @override
  String get sales_selectMethod => 'Select Method';

  @override
  String sales_amountReceivedLabel(String currency) {
    return 'Amount Received ($currency) *';
  }

  @override
  String sales_changeLabel(String currency) {
    return 'Change ($currency)';
  }

  @override
  String get sales_walkInCustomer => 'Walk-in Customer';

  @override
  String get sales_noClientSelected => 'No client selected';

  @override
  String get sales_productSearchHint =>
      'Search product by name, batch no or category...';

  @override
  String get sales_noProductsYet => 'No products added yet';

  @override
  String get sales_addProductsHint => 'Search and add products to this sale';

  @override
  String get sales_colBatchNo => 'Batch No.';

  @override
  String sales_colUnitPrice(String currency) {
    return 'Unit Price ($currency)';
  }

  @override
  String get sales_colQty => 'Qty';

  @override
  String sales_colTotal(String currency) {
    return 'Total ($currency)';
  }

  @override
  String sales_batchShort(String batch) {
    return 'Batch: $batch';
  }

  @override
  String sales_expShort(String date) {
    return 'Exp: $date';
  }

  @override
  String get sales_notesHint => 'Add any additional notes (optional)...';

  @override
  String get common_dismiss => 'Dismiss';

  @override
  String get common_privacyPolicy => 'Privacy Policy';

  @override
  String get common_termsOfService => 'Terms of Service';

  @override
  String get common_logout => 'Logout';

  @override
  String get common_logIn => 'Log in';

  @override
  String get common_inviteCode => 'Invite code';

  @override
  String get common_facilityName => 'Facility name';

  @override
  String get common_facilityNameHint => 'e.g. Ukuli';

  @override
  String get common_passwordsDoNotMatch => 'Passwords do not match';

  @override
  String common_appSystem(String appName) {
    return '$appName System';
  }

  @override
  String get common_editProfile => 'Edit Profile';

  @override
  String get login_tagline => 'Smart Business & Vet Services Monitor';

  @override
  String get login_systemOnline => 'System Online';

  @override
  String login_copyright(String appName) {
    return '© 2026 $appName System. All rights reserved.';
  }

  @override
  String get login_welcomeTo => 'Welcome to';

  @override
  String get login_stayUpdated =>
      'Stay updated with the latest news and announcements.';

  @override
  String get login_announcements => 'Announcements';

  @override
  String get login_urgent => 'URGENT';

  @override
  String get login_announcementFallbackTitle => 'Notice';

  @override
  String get login_noAnnouncements => 'No announcements';

  @override
  String get login_allCaughtUp => 'You\'re all caught up!';

  @override
  String get login_trustTitle => 'Secure. Reliable. Always Connected.';

  @override
  String get login_trustBody =>
      'Your trusted partner in animal health and business growth.';

  @override
  String get login_welcomeBack => 'Welcome back';

  @override
  String get login_logIntoFacility => 'Log into your facility';

  @override
  String get login_emailHint => 'Enter your email';

  @override
  String get login_passwordHint => 'Enter your password';

  @override
  String get login_minPasswordHint => 'Minimum 6 characters';

  @override
  String get login_rememberMe => 'Remember Me';

  @override
  String get login_forgotPassword => 'Forgot Password?';

  @override
  String get login_noAccount => 'Don\'t have an account? ';

  @override
  String get login_register => 'Register';

  @override
  String get login_loginButton => 'Login';

  @override
  String get login_newBadge => 'NEW';

  @override
  String login_credentialsTooShort(int count) {
    return 'Enter your email and a password of at least $count characters.';
  }

  @override
  String get login_slowSignIn =>
      'Signing in is taking longer than expected. Check your internet connection and try again.';

  @override
  String get login_resetNeedsEmail =>
      'Enter your email to reset your password.';

  @override
  String get login_resetSent =>
      'If an account exists for this email, a reset link has been sent. Check your inbox (and spam folder).';

  @override
  String login_resetFailed(String reason) {
    return 'Couldn\'t send the reset email. $reason';
  }

  @override
  String get register_inviteInvalid =>
      'Invalid, expired, or already-used invite code';

  @override
  String get register_inviteCheckFailed =>
      'Could not check this code - try again';

  @override
  String get register_enterFacilityNameFirst => 'Enter the facility name first';

  @override
  String get register_chooseFacilityTypeFirst =>
      'Choose the facility type first';

  @override
  String register_facilityLimit(int max) {
    return 'You\'ve reached the limit of $max facilities per account';
  }

  @override
  String get register_addFacilityFailed => 'Couldn\'t add this facility';

  @override
  String get register_pwMin8 => 'At least 8 characters';

  @override
  String get register_pwNeedsLetter => 'Add at least one letter';

  @override
  String get register_pwNeedsNumber => 'Add at least one number';

  @override
  String get register_pwTooCommon =>
      'This password is too common - choose another';

  @override
  String get register_addAtLeastOneFacility =>
      'Please add at least one facility';

  @override
  String get register_enterValidInvite => 'Enter a valid invite code';

  @override
  String get register_profileUpdated => 'Profile updated';

  @override
  String get register_accountRegistered => 'Account registered';

  @override
  String get register_verifyEmailSent =>
      'We\'ve sent a verification link to your email. Check your Spam folder if it doesn\'t appear within a few minutes.';

  @override
  String get register_enterValidInviteFirst =>
      'Enter a valid invite code first';

  @override
  String get register_assistantRegistered =>
      'Assistant registered, waiting for admin approval';

  @override
  String get register_verifyEmailAlsoSent =>
      'We\'ve also sent a verification link to your email. Check your Spam folder if it doesn\'t appear.';

  @override
  String get register_emailAlreadyRegistered =>
      'This email is already registered';

  @override
  String get register_emailExists =>
      'An account with this email already exists. If you\'re switching facilities, this email can\'t register a second time - ask your Platform Admin to add you to the new facility instead.';

  @override
  String get register_validEmailExample =>
      'Enter a valid email address, like name@example.com';

  @override
  String get register_validEmail => 'Enter a valid email address.';

  @override
  String get register_strongerPasswordField => 'Choose a stronger password';

  @override
  String get register_strongerPassword => 'Choose a stronger password.';

  @override
  String register_createFailed(String reason) {
    return 'Couldn\'t create the account. $reason';
  }

  @override
  String get register_createYourAccount => 'Create your account';

  @override
  String register_setUpApp(String appName) {
    return 'Set up $appName for your agrovet or veterinary centre in a few minutes.';
  }

  @override
  String get register_setUpCentre =>
      'Set up your agrovet or veterinary centre in a few minutes.';

  @override
  String get register_benefitAllInOne =>
      'Sales, stock, clients and debts in one place';

  @override
  String get register_benefitInvite =>
      'Invite your team with secure, one-time codes';

  @override
  String get register_benefitTrial =>
      'Every new facility starts with a trial period';

  @override
  String get register_alreadyHaveAccount => 'Already have an account?';

  @override
  String get register_createAccount => 'Create account';

  @override
  String get register_termsPrefix => 'By creating an account you agree to our ';

  @override
  String get register_termsAnd => ' and ';

  @override
  String get register_saveChanges => 'Save changes';

  @override
  String get register_fieldFullName => 'Full name';

  @override
  String get register_fieldPhone => 'Phone number';

  @override
  String get register_fieldConfirmPassword => 'Confirm password';

  @override
  String get register_enterFullName => 'Enter your full name';

  @override
  String get register_nameTooShort =>
      'Your name looks too short - enter your full name';

  @override
  String get register_enterEmail => 'Enter your email address';

  @override
  String get register_enterPhone => 'Enter your phone number';

  @override
  String get register_validPhone =>
      'Enter a valid phone number, like 0712 345 678';

  @override
  String register_pressAddToInclude(String name) {
    return 'Press Add to include \"$name\" before you register';
  }

  @override
  String get register_chooseTypeThenAdd =>
      'Choose the facility type, then press Add';

  @override
  String get register_addOneFacilityHow =>
      'Add at least one facility: enter its name, choose its type, then press Add';

  @override
  String get register_enterInviteCode => 'Enter your invite code';

  @override
  String get register_stillChecking =>
      'Still checking your invite code - try again in a moment';

  @override
  String get register_createPassword => 'Create a password';

  @override
  String get register_reenterToConfirm =>
      'Re-enter your password to confirm it';

  @override
  String register_fixFields(int count, String fields) {
    return 'Please fix $count fields: $fields.';
  }

  @override
  String register_fixFieldsMore(int count, String fields, int more) {
    return 'Please fix $count fields: $fields and $more more.';
  }

  @override
  String get register_saving => 'Saving...';

  @override
  String get register_creating => 'Creating your account...';

  @override
  String get register_personalDetails => 'Personal details';

  @override
  String get register_requiredNote => '* Required';

  @override
  String get register_title => 'Title';

  @override
  String get register_emailHint => 'name@example.com';

  @override
  String get register_phoneHint => '07XX XXX XXX';

  @override
  String get register_profilePhoto => 'Profile photo';

  @override
  String get register_tapToChangePhoto => 'Tap to change your photo';

  @override
  String get register_tapToAddPhoto => 'Optional - tap to add a photo';

  @override
  String get register_yourRole => 'Your role';

  @override
  String get register_roleCoAdminSubtitle => 'I help manage a facility';

  @override
  String get register_roleAdminSubtitle => 'I own or manage a facility';

  @override
  String get register_roleAssistantSubtitle => 'I have an invite code';

  @override
  String get register_roleLocked => 'Your role can\'t be changed here.';

  @override
  String get register_yourFacilities => 'Your facilities';

  @override
  String get register_askAdminForInvite =>
      'Ask your facility Admin for an invite code to join their team.';

  @override
  String register_joining(String facility) {
    return 'Joining: $facility';
  }

  @override
  String register_facilityTypeAndCode(String type, String code) {
    return '$type  ·  Code: $code';
  }

  @override
  String get register_addOneToContinue =>
      'Add at least one facility to continue.';

  @override
  String get register_useViewFacilities =>
      'To add or change facilities, use View Facilities.';

  @override
  String register_facilitiesAdded(int count, int max) {
    return '$count of $max facilities added';
  }

  @override
  String get register_selectType => 'Select type';

  @override
  String register_maxFacilitiesReached(int max) {
    return 'Maximum of $max facilities reached';
  }

  @override
  String get register_accountSecurity => 'Account security';

  @override
  String get register_passwordRule =>
      'At least 8 characters, with a letter and a number';

  @override
  String get register_looksGood => 'Looks good';

  @override
  String get register_reenterPassword => 'Re-enter your password';

  @override
  String get register_passwordsMatch => 'Passwords match';

  @override
  String get entry_noProfile =>
      'We couldn\'t find a profile for this account. If you have just registered, the registration did not finish - please register again. If this keeps happening, contact support.';

  @override
  String get entry_deactivated =>
      'This account has been deactivated. Ask your facility admin (or Platform Admin) to reactivate it before signing in again.';

  @override
  String get entry_notActiveYet =>
      'Your account is not active yet. Please wait for admin approval.';

  @override
  String get entry_requestNotApproved =>
      'Your request to join was not approved.';

  @override
  String entry_requestNotApprovedFrom(String facility) {
    return 'Your request to join $facility was not approved.';
  }

  @override
  String get entry_slowLoad => 'Taking longer than expected to load.';

  @override
  String get entry_timeoutExplanation =>
      'This is taking longer than expected. Check your internet connection and try again.';

  @override
  String get entry_unreachable =>
      'We couldn\'t reach the server. Check your internet connection and try again.';

  @override
  String get entry_accessRefused =>
      'Your account couldn\'t be opened because access was refused. Try again, and if it keeps happening, contact support.';

  @override
  String get entry_loadFailed =>
      'Something went wrong while loading your account details. Check your connection and try again.';

  @override
  String get entry_couldNotLoadTitle => 'Could Not Load Your Account';

  @override
  String get noFacility_enterName => 'Enter the facility name.';

  @override
  String get noFacility_chooseType => 'Choose the facility type.';

  @override
  String get noFacility_wrongPassword => 'That password isn\'t right.';

  @override
  String get noFacility_tooManyAttempts =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get noFacility_unreachable =>
      'We couldn\'t reach the server. Check your connection and try again.';

  @override
  String get noFacility_deleteFailed => 'Could not delete the account.';

  @override
  String noFacility_deleteFailedWith(String error) {
    return 'Could not delete the account: $error';
  }

  @override
  String get noFacility_aFacility => 'a facility';

  @override
  String get noFacility_cantDeleteTitle => 'Can\'t delete the account yet';

  @override
  String noFacility_stillOwns(String name) {
    return 'This account still owns \"$name\", which isn\'t on your profile. Contact support so it can be sorted out first.';
  }

  @override
  String get noFacility_deleteTitle => 'Delete your account?';

  @override
  String get noFacility_deleteWarning =>
      'This is permanent and cannot be undone. Your account and profile will be erased, and you will not be able to sign in with this email again.';

  @override
  String get noFacility_enterPasswordToConfirm =>
      'Enter your password to confirm.';

  @override
  String get noFacility_accountDeleted => 'Your account has been deleted.';

  @override
  String get noFacility_deleteAccount => 'Delete account';

  @override
  String get noFacility_adding => 'Adding facility...';

  @override
  String get noFacility_addFacility => 'Add facility';

  @override
  String get noFacility_deleteInstead => 'Delete my account instead';

  @override
  String get noFacility_codeInvalid =>
      'That code is invalid, has expired, or has already been used.';

  @override
  String noFacility_requestSent(String facility) {
    return 'Request sent to $facility. You can sign in once its admin approves you.';
  }

  @override
  String get noFacility_titleAssistant => 'You\'re not in a facility right now';

  @override
  String get noFacility_titleAdmin => 'You don\'t have a facility right now';

  @override
  String noFacility_noticeMistake(String notice) {
    return '$notice If you think that was a mistake, ask for a new invite code.';
  }

  @override
  String get noFacility_bodyAssistant =>
      'You may have been removed from your facility, or not added to one yet. Your account, name, phone number and photo are kept. To join a facility, enter an invite code from its admin.';

  @override
  String get noFacility_bodyAdmin =>
      'Your account is kept. Add a facility to carry on, or delete your account if you no longer need it.';

  @override
  String get noFacility_inviteHint => 'e.g. JK7-2P4';

  @override
  String noFacility_askingToJoin(String facility) {
    return 'You\'ll be asking to join: $facility';
  }

  @override
  String noFacility_askingToJoinWithType(String facility, String type) {
    return 'You\'ll be asking to join: $facility ($type)';
  }

  @override
  String get noFacility_sending => 'Sending your request...';

  @override
  String get noFacility_requestToJoin => 'Request to join';

  @override
  String get noFacility_approvalNote =>
      'The facility\'s admin has to approve you, as with any new assistant. Or ask your previous admin to add you back.';

  @override
  String get subscription_freeTrialTitle => 'Free Trial';

  @override
  String get subscription_onFreeTrial => 'You\'re on a free trial.';

  @override
  String subscription_trialDaysLeftEnding(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'You have $_temp0 left of your free trial, ending on $date.';
  }

  @override
  String get subscription_trialEndedTitle => 'Trial Ended';

  @override
  String get subscription_trialEndedReadOnly =>
      'Your trial has ended. The app is in read-only mode.';

  @override
  String get subscription_expiredReadOnly =>
      'Your subscription has expired. The app is in read-only mode.';

  @override
  String get subscription_trialEndedGrace =>
      'Your trial has ended. You have a few days of grace before read-only mode begins.';

  @override
  String get subscription_expiredGrace =>
      'Your subscription has expired. You have a few days of grace before read-only mode begins.';

  @override
  String get subscription_trialExpiringSoonTitle => 'Trial Expiring Soon';

  @override
  String get subscription_expiringSoonTitle => 'Subscription Expiring Soon';

  @override
  String subscription_trialExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Your trial expires in $_temp0.';
  }

  @override
  String subscription_expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Your subscription expires in $_temp0.';
  }

  @override
  String subscription_freeTrialDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'You\'re on a free trial - $_temp0 left.';
  }

  @override
  String get subscription_trialActive => 'Your trial is active.';

  @override
  String get subscription_active => 'Your subscription is active.';

  @override
  String get subscription_viewPlans => 'View Plans';

  @override
  String get subscription_renew => 'Renew';

  @override
  String get subscription_askYourAdmin => '· Ask your admin';

  @override
  String get dashboard_reassigned =>
      'You\'ve been reassigned to a different facility. Please log back in.';

  @override
  String get dashboard_vsYesterday => 'vs Yesterday';

  @override
  String get dashboard_vsLastWeek => 'vs Last Week';

  @override
  String get dashboard_vsLastMonth => 'vs Last Month';

  @override
  String get dashboard_vsLastYear => 'vs Last Year';

  @override
  String get dashboard_goodMorning => 'Good morning';

  @override
  String get dashboard_goodAfternoon => 'Good afternoon';

  @override
  String get dashboard_goodEvening => 'Good evening';

  @override
  String dashboard_greeting(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String dashboard_howFacilityIsDoing(String facility) {
    return 'Here\'s how $facility is doing today.';
  }

  @override
  String get dashboard_avatarUpdated => 'Profile avatar updated';

  @override
  String get dashboard_avatarSaveFailed => 'Couldn\'t save the profile avatar';

  @override
  String get dashboard_resetPasswordTitle => 'Reset Password';

  @override
  String dashboard_resetPasswordPrompt(String email) {
    return 'Send password reset email to $email?';
  }

  @override
  String get dashboard_sendLink => 'Send Link';

  @override
  String dashboard_resetLinkSent(String email) {
    return 'Reset link sent to $email';
  }

  @override
  String get dashboard_resetLinkFailed => 'Couldn\'t send the reset link';

  @override
  String get dashboard_expandMenu => 'Expand menu';

  @override
  String get dashboard_collapseMenu => 'Collapse menu';

  @override
  String get dashboard_searchAnything => 'Search anything...';

  @override
  String get dashboard_searchShortcut => 'Ctrl+K';

  @override
  String get dashboard_help => 'Help';

  @override
  String get dashboard_account => 'Account';
}
