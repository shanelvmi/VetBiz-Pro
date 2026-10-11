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
}
