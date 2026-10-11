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
}
