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
}
