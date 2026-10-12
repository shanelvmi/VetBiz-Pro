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
}
