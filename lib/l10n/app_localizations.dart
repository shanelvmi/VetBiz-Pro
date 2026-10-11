import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// The word for the app's display language (Settings, Language picker).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get common_language;

  /// Save button, everywhere.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// Cancel button in dialogs and forms.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// Delete button or menu item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// Edit button or menu item.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// Remove button (takes an item off a list).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get common_remove;

  /// Close button or tooltip (dialogs, messages).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// OK button that acknowledges a dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// Yes answer in a confirmation.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get common_yes;

  /// No answer in a confirmation.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get common_no;

  /// Confirm button in a confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// Done button that closes a finished step.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// Apply button for filters and settings.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get common_apply;

  /// Reset button for filters and forms.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get common_reset;

  /// Refresh button or tooltip that reloads data.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get common_refresh;

  /// Retry action on an error message.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// Try Again button on a failed screen or load.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get common_tryAgain;

  /// Undo action after something was moved to Trash.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get common_undo;

  /// Details action on an error message (shows the technical text) and Details dialog title.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get common_details;

  /// View Details button or menu item.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get common_viewDetails;

  /// Copy button (copies text).
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get common_copy;

  /// Share button.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get common_share;

  /// Print button.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get common_print;

  /// Search field hint or button.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_search;

  /// Add button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get common_add;

  /// Clear button (empties a field or filter).
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get common_clear;

  /// Change button (picks a different value).
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get common_change;

  /// Call button (phones a client).
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get common_call;

  /// Tooltip of the three-dot menu.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get common_moreActions;

  /// Shown while something loads.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get common_loading;

  /// Marks a form field that may be left empty.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get common_optional;

  /// The no-filter choice in a filter list.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get common_all;

  /// Date label or column heading.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get common_date;

  /// Amount label or column heading.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get common_amount;

  /// Total label or column heading.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get common_total;

  /// Status label or column heading.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get common_status;

  /// Type label or column heading.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get common_type;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get common_email;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get common_password;

  /// Notes field label or heading.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get common_notes;

  /// Second line of an error message when nothing more specific is known (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get error_generic;

  /// Second line of an error message: permission denied (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get error_noPermission;

  /// Second line of an error message: no network (FriendlyError, sign-in).
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get error_noConnection;

  /// Second line of an error message: timed out (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'That took too long. Try again.'**
  String get error_tooSlow;

  /// Second line of an error message: the record was deleted (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'That item no longer exists.'**
  String get error_notFound;

  /// Second line of an error message: a duplicate (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'That already exists.'**
  String get error_alreadyExists;

  /// Second line of an error message: rate limited (FriendlyError).
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment and try again.'**
  String get error_rateLimited;

  /// Sign-in error for a wrong password OR an unknown email (one message on purpose, so it does not reveal which emails are registered).
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get login_wrongCredentials;

  /// Sign-in error: the account was disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact your admin.'**
  String get login_accountDisabled;

  /// Sign-in error: too many failed attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get login_tooManyAttempts;

  /// Sign-in error when Firebase gives no message of its own.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Try again.'**
  String get login_signInFailed;

  /// The word Facility, as a fallback name when a facility has none.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get common_facility;

  /// Sign out button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get common_signOut;

  /// Hides the technical text shown by Details.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get common_hideDetails;

  /// Title of the custom date range dialog (Payments, Transactions).
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get dateRange_title;

  /// Label above the start date in the date range dialog.
  ///
  /// In en, this message translates to:
  /// **'Start Date:'**
  String get dateRange_start;

  /// Label above the end date in the date range dialog.
  ///
  /// In en, this message translates to:
  /// **'End Date:'**
  String get dateRange_end;

  /// Heading of the error shown when a list fails to load (FirestoreErrorView).
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get error_couldNotLoad;

  /// Error shown when a Firestore query needs an index (FirestoreErrorView).
  ///
  /// In en, this message translates to:
  /// **'This view needs a one-time database index to be created first.'**
  String get error_indexNeeded;

  /// Button that opens Firebase Console to create a missing index (FirestoreErrorView).
  ///
  /// In en, this message translates to:
  /// **'Create Missing Index'**
  String get error_createIndex;

  /// Small text under Create Missing Index (FirestoreErrorView).
  ///
  /// In en, this message translates to:
  /// **'This opens Firebase Console with the exact index needed already filled in.'**
  String get error_createIndexHint;

  /// Heading of the maintenance screen.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be right back'**
  String get maintenance_title;

  /// Maintenance screen text when the platform admin set no message of their own.
  ///
  /// In en, this message translates to:
  /// **'We\'re currently performing scheduled maintenance. Please try again shortly.'**
  String get maintenance_defaultMessage;

  /// Age of a notification under one minute.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get time_justNow;

  /// Age of a notification in minutes (short form).
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String time_minutesAgo(int count);

  /// Age of a notification in hours (short form).
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String time_hoursAgo(int count);

  /// Age of a notification in days (short form).
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String time_daysAgo(int count);

  /// Label above the payment method chips.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payments_method;

  /// Upper-case heading of the categories list in the product catalog side panel.
  ///
  /// In en, this message translates to:
  /// **'CATEGORIES'**
  String get products_categoriesHeading;

  /// Upper-case heading of the stock status list in the product catalog side panel.
  ///
  /// In en, this message translates to:
  /// **'STOCK STATUS'**
  String get products_stockStatusHeading;

  /// Row that shows every product (product catalog side panel).
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get products_allProducts;

  /// Stock status filter: no filter (product catalog side panel).
  ///
  /// In en, this message translates to:
  /// **'All Status'**
  String get products_statusAll;

  /// Stock status filter: in stock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get products_statusInStock;

  /// Stock status filter: low stock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get products_statusLowStock;

  /// Stock status filter: should be reordered soon.
  ///
  /// In en, this message translates to:
  /// **'Reorder Soon'**
  String get products_statusReorderSoon;

  /// Stock status filter: none left.
  ///
  /// In en, this message translates to:
  /// **'Depleted'**
  String get products_statusDepleted;

  /// Stock status filter: past its expiry date.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get products_statusExpired;

  /// Badge on a summary card when there was nothing in the previous period to compare with.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get summary_trendNew;

  /// Title of the full loading screen after sign-in.
  ///
  /// In en, this message translates to:
  /// **'Loading your account...'**
  String get loading_accountTitle;

  /// Second line of the full loading screen after sign-in.
  ///
  /// In en, this message translates to:
  /// **'Preparing your facility data and services'**
  String get loading_accountSubtitle;

  /// Shown while the dashboard opens for a chosen facility.
  ///
  /// In en, this message translates to:
  /// **'Setting up {facilityName}...'**
  String facilities_settingUp(String facilityName);

  /// Stands for the facility name in "Setting up ..." when it has none.
  ///
  /// In en, this message translates to:
  /// **'your facility'**
  String get facilities_yourFacility;

  /// Title of the dialog shown when a locked facility tries to record a sale or service.
  ///
  /// In en, this message translates to:
  /// **'Subscription Expired'**
  String get subscription_expiredTitle;

  /// Subscription Expired dialog text for an assistant.
  ///
  /// In en, this message translates to:
  /// **'This facility\'s subscription has expired, so new sales and services can\'t be recorded right now. You can still view all existing data. Please ask your admin to renew the subscription.'**
  String get subscription_expiredAssistant;

  /// Subscription Expired dialog text for an admin.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired, so new sales and services can\'t be recorded right now. You can still view all your existing data. Submit a payment to restore full access.'**
  String get subscription_expiredAdmin;

  /// Button in the Subscription Expired dialog (admins).
  ///
  /// In en, this message translates to:
  /// **'Go to Subscription'**
  String get subscription_goTo;

  /// Product category: product form, category filters and lists (stored value 'Antibiotic').
  ///
  /// In en, this message translates to:
  /// **'Antibiotic'**
  String get productCategory_antibiotic;

  /// Product category: product form, category filters and lists (stored value 'Anthelmintics').
  ///
  /// In en, this message translates to:
  /// **'Anthelmintics'**
  String get productCategory_anthelmintics;

  /// Product category: product form, category filters and lists (stored value 'Vitamin & Supplements').
  ///
  /// In en, this message translates to:
  /// **'Vitamin & Supplements'**
  String get productCategory_vitaminsSupplements;

  /// Product category: product form, category filters and lists (stored value 'Hormones & Reproductive').
  ///
  /// In en, this message translates to:
  /// **'Hormones & Reproductive'**
  String get productCategory_hormonesReproductive;

  /// Product category: product form, category filters and lists (stored value 'Vaccines').
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get productCategory_vaccines;

  /// Product category: product form, category filters and lists (stored value 'Disinfectant').
  ///
  /// In en, this message translates to:
  /// **'Disinfectant'**
  String get productCategory_disinfectant;

  /// Product category: product form, category filters and lists (stored value 'Feeds').
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get productCategory_feeds;

  /// Product category: product form, category filters and lists (stored value 'Anti-inflammatory').
  ///
  /// In en, this message translates to:
  /// **'Anti-inflammatory'**
  String get productCategory_antiInflammatory;

  /// Product category: product form, category filters and lists (stored value 'Ectoparasiticides').
  ///
  /// In en, this message translates to:
  /// **'Ectoparasiticides'**
  String get productCategory_ectoparasiticides;

  /// Product category: product form, category filters and lists (stored value 'Wound Management').
  ///
  /// In en, this message translates to:
  /// **'Wound Management'**
  String get productCategory_woundManagement;

  /// Product category: product form, category filters and lists (stored value 'Surgical Supplies').
  ///
  /// In en, this message translates to:
  /// **'Surgical Supplies'**
  String get productCategory_surgicalSupplies;

  /// Product category: product form, category filters and lists (stored value 'Farm Tools & Equipment').
  ///
  /// In en, this message translates to:
  /// **'Farm Tools & Equipment'**
  String get productCategory_farmToolsEquipment;

  /// Product category: product form, category filters and lists (stored value 'Seeds').
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get productCategory_seeds;

  /// Product category: product form, category filters and lists (stored value 'Fertilizers').
  ///
  /// In en, this message translates to:
  /// **'Fertilizers'**
  String get productCategory_fertilizers;

  /// Product category: product form, category filters and lists (stored value 'Crop Pesticides').
  ///
  /// In en, this message translates to:
  /// **'Crop Pesticides'**
  String get productCategory_cropPesticides;

  /// Product category: product form, category filters and lists (stored value 'Miscellaneous').
  ///
  /// In en, this message translates to:
  /// **'Miscellaneous'**
  String get productCategory_miscellaneous;

  /// Product category shown for a product saved with no category (not stored): filters and lists.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get productCategory_uncategorized;

  /// Product department filter chip (Products, Stock Store): the 'Vet' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get productGroup_vet;

  /// Product department filter chip and side panel: the 'Agro' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Agro'**
  String get productGroup_agro;

  /// Product catalog side panel: long name of the 'Vet' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Veterinary'**
  String get productGroup_veterinary;

  /// Product type (form): product form and product lists (stored value 'Injectable').
  ///
  /// In en, this message translates to:
  /// **'Injectable'**
  String get productType_injectable;

  /// Product type (form): product form and product lists (stored value 'Oral Liquid').
  ///
  /// In en, this message translates to:
  /// **'Oral Liquid'**
  String get productType_oralLiquid;

  /// Product type (form): product form and product lists (stored value 'Powder').
  ///
  /// In en, this message translates to:
  /// **'Powder'**
  String get productType_powder;

  /// Product type (form): product form and product lists (stored value 'Tablet/Bolus').
  ///
  /// In en, this message translates to:
  /// **'Tablet/Bolus'**
  String get productType_tabletBolus;

  /// Product type (form): product form and product lists (stored value 'Topical').
  ///
  /// In en, this message translates to:
  /// **'Topical'**
  String get productType_topical;

  /// Product type (form): product form and product lists (stored value 'Intramammary').
  ///
  /// In en, this message translates to:
  /// **'Intramammary'**
  String get productType_intramammary;

  /// Product type (form): product form and product lists (stored value 'Spray').
  ///
  /// In en, this message translates to:
  /// **'Spray'**
  String get productType_spray;

  /// Product type (form): product form and product lists (stored value 'Granules').
  ///
  /// In en, this message translates to:
  /// **'Granules'**
  String get productType_granules;

  /// Product type (form): product form and product lists (stored value 'Wettable Powder').
  ///
  /// In en, this message translates to:
  /// **'Wettable Powder'**
  String get productType_wettablePowder;

  /// Product type (form): product form and product lists (stored value 'Emulsifiable Concentrate').
  ///
  /// In en, this message translates to:
  /// **'Emulsifiable Concentrate'**
  String get productType_emulsifiableConcentrate;

  /// Product type (form): product form and product lists (stored value 'Seed').
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get productType_seed;

  /// Product type (form): product form and product lists (stored value 'Fertilizer').
  ///
  /// In en, this message translates to:
  /// **'Fertilizer'**
  String get productType_fertilizer;

  /// Product type (form): product form and product lists (stored value 'Feed').
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get productType_feed;

  /// Product type (form): product form and product lists (stored value 'Equipment').
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get productType_equipment;

  /// Product type (form): product form and product lists (stored value 'Other').
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get productType_other;

  /// Product unit: product form unit picker (stored value 'pcs').
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unit_pcs;

  /// Product unit: product form unit picker (stored value 'kg').
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unit_kg;

  /// Product unit: product form unit picker (stored value 'g').
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unit_g;

  /// Product unit: product form unit picker (stored value 'litres').
  ///
  /// In en, this message translates to:
  /// **'litres'**
  String get unit_litres;

  /// Product unit: product form unit picker (stored value 'ml').
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unit_ml;

  /// Product unit: product form unit picker (stored value 'vials').
  ///
  /// In en, this message translates to:
  /// **'vials'**
  String get unit_vials;

  /// Product unit: product form unit picker (stored value 'ampoules').
  ///
  /// In en, this message translates to:
  /// **'ampoules'**
  String get unit_ampoules;

  /// Product unit: product form unit picker (stored value 'bottles').
  ///
  /// In en, this message translates to:
  /// **'bottles'**
  String get unit_bottles;

  /// Product unit: product form unit picker (stored value 'sachets').
  ///
  /// In en, this message translates to:
  /// **'sachets'**
  String get unit_sachets;

  /// Product unit: product form unit picker (stored value 'sacks').
  ///
  /// In en, this message translates to:
  /// **'sacks'**
  String get unit_sacks;

  /// Product unit: product form unit picker (stored value 'bags').
  ///
  /// In en, this message translates to:
  /// **'bags'**
  String get unit_bags;

  /// Product unit: product form unit picker (stored value 'boxes').
  ///
  /// In en, this message translates to:
  /// **'boxes'**
  String get unit_boxes;

  /// Product unit: product form unit picker (stored value 'cartons').
  ///
  /// In en, this message translates to:
  /// **'cartons'**
  String get unit_cartons;

  /// Product unit: product form unit picker (stored value 'packs').
  ///
  /// In en, this message translates to:
  /// **'packs'**
  String get unit_packs;

  /// Product unit: product form unit picker (stored value 'strips').
  ///
  /// In en, this message translates to:
  /// **'strips'**
  String get unit_strips;

  /// Product unit: product form unit picker (stored value 'tablets').
  ///
  /// In en, this message translates to:
  /// **'tablets'**
  String get unit_tablets;

  /// Product unit: product form unit picker (stored value 'tubes').
  ///
  /// In en, this message translates to:
  /// **'tubes'**
  String get unit_tubes;

  /// Product unit: product form unit picker (stored value 'rolls').
  ///
  /// In en, this message translates to:
  /// **'rolls'**
  String get unit_rolls;

  /// Product unit: product form unit picker (stored value 'pairs').
  ///
  /// In en, this message translates to:
  /// **'pairs'**
  String get unit_pairs;

  /// Product unit: product form unit picker (stored value 'others').
  ///
  /// In en, this message translates to:
  /// **'others'**
  String get unit_others;

  /// Service category: service form, Services filters and lists (stored value 'Surgical').
  ///
  /// In en, this message translates to:
  /// **'Surgical'**
  String get serviceCategory_surgical;

  /// Service category: service form, Services filters and lists (stored value 'Treatment').
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get serviceCategory_treatment;

  /// Service category: service form, Services filters and lists (stored value 'Management').
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get serviceCategory_management;

  /// Service category: service form, Services filters and lists (stored value 'Consultation').
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get serviceCategory_consultation;

  /// Service category: service form, Services filters and lists (stored value 'Diagnostics').
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get serviceCategory_diagnostics;

  /// Service category: service form, Services filters and lists (stored value 'Preventive').
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get serviceCategory_preventive;

  /// Service category: service form, Services filters and lists (stored value 'Other').
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get serviceCategory_other;

  /// Facility type: registration, Facilities screen, facility picker filter (stored value 'Agrovet').
  ///
  /// In en, this message translates to:
  /// **'Agrovet'**
  String get facilityType_agrovet;

  /// Facility type: registration, Facilities screen, facility picker filter (stored value 'Vet Clinic').
  ///
  /// In en, this message translates to:
  /// **'Vet Clinic'**
  String get facilityType_vetClinic;

  /// Facility type: registration, Facilities screen, facility picker filter (stored value 'Vet Hospital').
  ///
  /// In en, this message translates to:
  /// **'Vet Hospital'**
  String get facilityType_vetHospital;

  /// Facility type: registration, Facilities screen, facility picker filter (stored value 'Ambulatory Vet').
  ///
  /// In en, this message translates to:
  /// **'Ambulatory Vet'**
  String get facilityType_ambulatoryVet;

  /// Facility type: registration, Facilities screen, facility picker filter (stored value 'Other').
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get facilityType_other;

  /// Payment method: payment chips and menus, payment filters (stored value 'Cash').
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethod_cash;

  /// Payment method: payment chips and menus, payment filters (stored value 'M-Pesa').
  ///
  /// In en, this message translates to:
  /// **'M-Pesa'**
  String get paymentMethod_mPesa;

  /// Payment method: payment chips and menus, payment filters (stored value 'Mixx by Yas').
  ///
  /// In en, this message translates to:
  /// **'Mixx by Yas'**
  String get paymentMethod_mixxByYas;

  /// Payment method: payment chips and menus, payment filters (stored value 'HaloPesa').
  ///
  /// In en, this message translates to:
  /// **'HaloPesa'**
  String get paymentMethod_haloPesa;

  /// Payment method: payment chips and menus, payment filters (stored value 'Airtel Money').
  ///
  /// In en, this message translates to:
  /// **'Airtel Money'**
  String get paymentMethod_airtelMoney;

  /// Payment method: payment chips and menus, payment filters (stored value 'Bank Transfer').
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentMethod_bankTransfer;

  /// Payment method: payment chips and menus, payment filters (stored value 'Tigo Pesa').
  ///
  /// In en, this message translates to:
  /// **'Tigo Pesa'**
  String get paymentMethod_tigoPesa;

  /// Payment method: payment chips and menus, payment filters (stored value 'On Credit').
  ///
  /// In en, this message translates to:
  /// **'On Credit'**
  String get paymentMethod_onCredit;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Account').
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get activityType_account;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Debtors').
  ///
  /// In en, this message translates to:
  /// **'Debtors'**
  String get activityType_debtors;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Products').
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get activityType_products;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Inventory Move').
  ///
  /// In en, this message translates to:
  /// **'Inventory Move'**
  String get activityType_inventoryMove;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Sales').
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get activityType_sales;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Sale').
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get activityType_sale;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Services').
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get activityType_services;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Transactions').
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get activityType_transactions;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Trash').
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get activityType_trash;

  /// Activity type: Activity Log filter chips and entry badges, activity lists (stored value 'Report Draft Deleted').
  ///
  /// In en, this message translates to:
  /// **'Report Draft Deleted'**
  String get activityType_reportDraftDeleted;

  /// Restock frequency: Facility settings dropdown (stored value 'Weekly').
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get restockFrequency_weekly;

  /// Restock frequency: Facility settings dropdown (stored value 'Every 2 Weeks').
  ///
  /// In en, this message translates to:
  /// **'Every 2 Weeks'**
  String get restockFrequency_everyTwoWeeks;

  /// Restock frequency: Facility settings dropdown (stored value 'Monthly').
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get restockFrequency_monthly;

  /// Restock frequency: Facility settings dropdown (stored value 'Rarely').
  ///
  /// In en, this message translates to:
  /// **'Rarely'**
  String get restockFrequency_rarely;

  /// User role (stored value 'admin'): team list, dashboard profile, registration.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get role_admin;

  /// User role (stored value 'assistant'): team list, dashboard profile, registration.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get role_assistant;

  /// Shown role of a promoted assistant (stored as 'admin' with previousRole 'assistant'): team list, dashboard, registration.
  ///
  /// In en, this message translates to:
  /// **'Co-admin'**
  String get role_coAdmin;

  /// A team member's status (stored value 'pending'): team list cards and badges.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get userStatus_pending;

  /// A team member's status (stored value 'active'): team list cards and badges.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get userStatus_active;

  /// A team member's status (stored value 'deactivated'): team list cards and badges.
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get userStatus_deactivated;

  /// A team member's status (stored value 'rejected'): team list cards and badges.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get userStatus_rejected;

  /// A step in a team member's history (stored value 'approved'): team member panel.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get membershipAction_approved;

  /// A step in a team member's history (stored value 'rejected'): team member panel.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get membershipAction_rejected;

  /// A step in a team member's history (stored value 'deactivated'): team member panel.
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get membershipAction_deactivated;

  /// A step in a team member's history (stored value 'reactivated'): team member panel.
  ///
  /// In en, this message translates to:
  /// **'Reactivated'**
  String get membershipAction_reactivated;

  /// A facility's status (stored value 'Active', any case): Facilities screen and picker.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get facilityStatus_active;

  /// A facility's status (stored value 'Inactive', any case): Facilities screen and picker.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get facilityStatus_inactive;

  /// A facility's status (stored value 'pending', any case): Facilities screen and picker.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get facilityStatus_pending;

  /// A subscription payment's review status (stored value 'pending'): Subscription history.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get submissionStatus_pending;

  /// A subscription payment's review status (stored value 'approved'): Subscription history.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get submissionStatus_approved;

  /// A subscription payment's review status (stored value 'rejected'): Subscription history.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get submissionStatus_rejected;

  /// Subscription plan name (plan id 'daily'): Subscription screen and history.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get plan_daily;

  /// Subscription plan name (plan id 'weekly'): Subscription screen and history.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get plan_weekly;

  /// Subscription plan name (plan id 'monthly'): Subscription screen and history.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get plan_monthly;

  /// Subscription plan name (plan id 'yearly'): Subscription screen and history.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get plan_yearly;

  /// Client type: client form type tiles, Clients type filter and badges (stored value 'Farmer').
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get clientType_farmer;

  /// Client type: client form type tiles, Clients type filter and badges (stored value 'Vet').
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get clientType_vet;

  /// Client type: client form type tiles, Clients type filter and badges (stored value 'Wholesaler').
  ///
  /// In en, this message translates to:
  /// **'Wholesaler'**
  String get clientType_wholesaler;

  /// Client type: client form type tiles, Clients type filter and badges (stored value 'Retailer').
  ///
  /// In en, this message translates to:
  /// **'Retailer'**
  String get clientType_retailer;

  /// Client type shown for a client saved with no type (not offered in the form): Clients badges and filter.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get clientType_other;

  /// Farmer type: client form dropdown (stored value 'Crop Producer').
  ///
  /// In en, this message translates to:
  /// **'Crop Producer'**
  String get farmerSubType_cropProducer;

  /// Farmer type: client form dropdown (stored value 'Animal Keeper').
  ///
  /// In en, this message translates to:
  /// **'Animal Keeper'**
  String get farmerSubType_animalKeeper;

  /// Animal species: client form animal picker and chips (stored value 'Cattle').
  ///
  /// In en, this message translates to:
  /// **'Cattle'**
  String get animal_cattle;

  /// Animal species: client form animal picker and chips (stored value 'Goat').
  ///
  /// In en, this message translates to:
  /// **'Goat'**
  String get animal_goat;

  /// Animal species: client form animal picker and chips (stored value 'Sheep').
  ///
  /// In en, this message translates to:
  /// **'Sheep'**
  String get animal_sheep;

  /// Animal species: client form animal picker and chips (stored value 'Pig').
  ///
  /// In en, this message translates to:
  /// **'Pig'**
  String get animal_pig;

  /// Animal species: client form animal picker and chips (stored value 'Donkey').
  ///
  /// In en, this message translates to:
  /// **'Donkey'**
  String get animal_donkey;

  /// Animal species: client form animal picker and chips (stored value 'Chicken').
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get animal_chicken;

  /// Animal species: client form animal picker and chips (stored value 'Duck').
  ///
  /// In en, this message translates to:
  /// **'Duck'**
  String get animal_duck;

  /// Animal species: client form animal picker and chips (stored value 'Turkey').
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get animal_turkey;

  /// Animal species: client form animal picker and chips (stored value 'Guinea Fowl').
  ///
  /// In en, this message translates to:
  /// **'Guinea Fowl'**
  String get animal_guineaFowl;

  /// Animal species: client form animal picker and chips (stored value 'Bees').
  ///
  /// In en, this message translates to:
  /// **'Bees'**
  String get animal_bees;

  /// Animal species: client form animal picker and chips (stored value 'Dog').
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get animal_dog;

  /// Animal species: client form animal picker and chips (stored value 'Cat').
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get animal_cat;

  /// Animal species: client form animal picker and chips (stored value 'Rabbit').
  ///
  /// In en, this message translates to:
  /// **'Rabbit'**
  String get animal_rabbit;

  /// Heading in the client form's animal picker: the 'Livestock' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Livestock'**
  String get animalGroup_livestock;

  /// Heading in the client form's animal picker: the 'Poultry' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Poultry'**
  String get animalGroup_poultry;

  /// Heading in the client form's animal picker: the 'Other' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get animalGroup_other;

  /// Vet practice type: client form dropdown (stored value 'Clinic').
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get vetPractice_clinic;

  /// Vet practice type: client form dropdown (stored value 'Consultant').
  ///
  /// In en, this message translates to:
  /// **'Consultant'**
  String get vetPractice_consultant;

  /// Vet practice type: client form dropdown (stored value 'Hospital').
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get vetPractice_hospital;

  /// Vet practice type: client form dropdown (stored value 'Ambulatory').
  ///
  /// In en, this message translates to:
  /// **'Ambulatory'**
  String get vetPractice_ambulatory;

  /// A client's status: client form chips, Clients status filter and badges (stored value 'Active').
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clientStatus_active;

  /// A client's status: client form chips, Clients status filter and badges (stored value 'Inactive').
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get clientStatus_inactive;

  /// A sale's or service's payment status: Sales and Services status filters and badges (stored value 'Paid').
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentStatus_paid;

  /// A sale's or service's payment status: Sales and Services status filters and badges (stored value 'Partial').
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get paymentStatus_partial;

  /// A sale's or service's payment status: Sales and Services status filters and badges (stored value 'Unpaid').
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get paymentStatus_unpaid;

  /// Why a batch is moved back to the Stock Store or off Sellable: move dialog dropdown (stored value 'Expired').
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get moveReason_expired;

  /// Why a batch is moved back to the Stock Store or off Sellable: move dialog dropdown (stored value 'Deteriorated').
  ///
  /// In en, this message translates to:
  /// **'Deteriorated'**
  String get moveReason_deteriorated;

  /// Why a batch is moved back to the Stock Store or off Sellable: move dialog dropdown (stored value 'Other (specify)').
  ///
  /// In en, this message translates to:
  /// **'Other (specify)'**
  String get moveReason_other;

  /// Heading in the client form's crop picker: the 'Food Crops' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Food Crops'**
  String get cropGroup_foodCrops;

  /// Heading in the client form's crop picker: the 'Cash Crops' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Cash Crops'**
  String get cropGroup_cashCrops;

  /// Heading in the client form's crop picker: the 'Vegetables' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get cropGroup_vegetables;

  /// Heading in the client form's crop picker: the 'Fruits' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get cropGroup_fruits;

  /// Crop: client form crop picker and chips (stored value 'Maize').
  ///
  /// In en, this message translates to:
  /// **'Maize'**
  String get crop_maize;

  /// Crop: client form crop picker and chips (stored value 'Rice').
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get crop_rice;

  /// Crop: client form crop picker and chips (stored value 'Wheat').
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get crop_wheat;

  /// Crop: client form crop picker and chips (stored value 'Cassava').
  ///
  /// In en, this message translates to:
  /// **'Cassava'**
  String get crop_cassava;

  /// Crop: client form crop picker and chips (stored value 'Sorghum').
  ///
  /// In en, this message translates to:
  /// **'Sorghum'**
  String get crop_sorghum;

  /// Crop: client form crop picker and chips (stored value 'Millet').
  ///
  /// In en, this message translates to:
  /// **'Millet'**
  String get crop_millet;

  /// Crop: client form crop picker and chips (stored value 'Beans').
  ///
  /// In en, this message translates to:
  /// **'Beans'**
  String get crop_beans;

  /// Crop: client form crop picker and chips (stored value 'Bananas').
  ///
  /// In en, this message translates to:
  /// **'Bananas'**
  String get crop_bananas;

  /// Crop: client form crop picker and chips (stored value 'Sweet Potatoes').
  ///
  /// In en, this message translates to:
  /// **'Sweet Potatoes'**
  String get crop_sweetPotatoes;

  /// Crop: client form crop picker and chips (stored value 'Irish Potatoes').
  ///
  /// In en, this message translates to:
  /// **'Irish Potatoes'**
  String get crop_irishPotatoes;

  /// Crop: client form crop picker and chips (stored value 'Groundnuts').
  ///
  /// In en, this message translates to:
  /// **'Groundnuts'**
  String get crop_groundnuts;

  /// Crop: client form crop picker and chips (stored value 'Coffee').
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get crop_coffee;

  /// Crop: client form crop picker and chips (stored value 'Cotton').
  ///
  /// In en, this message translates to:
  /// **'Cotton'**
  String get crop_cotton;

  /// Crop: client form crop picker and chips (stored value 'Tobacco').
  ///
  /// In en, this message translates to:
  /// **'Tobacco'**
  String get crop_tobacco;

  /// Crop: client form crop picker and chips (stored value 'Cashew Nuts').
  ///
  /// In en, this message translates to:
  /// **'Cashew Nuts'**
  String get crop_cashewNuts;

  /// Crop: client form crop picker and chips (stored value 'Sisal').
  ///
  /// In en, this message translates to:
  /// **'Sisal'**
  String get crop_sisal;

  /// Crop: client form crop picker and chips (stored value 'Tea').
  ///
  /// In en, this message translates to:
  /// **'Tea'**
  String get crop_tea;

  /// Crop: client form crop picker and chips (stored value 'Pyrethrum').
  ///
  /// In en, this message translates to:
  /// **'Pyrethrum'**
  String get crop_pyrethrum;

  /// Crop: client form crop picker and chips (stored value 'Sugarcane').
  ///
  /// In en, this message translates to:
  /// **'Sugarcane'**
  String get crop_sugarcane;

  /// Crop: client form crop picker and chips (stored value 'Cloves').
  ///
  /// In en, this message translates to:
  /// **'Cloves'**
  String get crop_cloves;

  /// Crop: client form crop picker and chips (stored value 'Sesame').
  ///
  /// In en, this message translates to:
  /// **'Sesame'**
  String get crop_sesame;

  /// Crop: client form crop picker and chips (stored value 'Sunflower').
  ///
  /// In en, this message translates to:
  /// **'Sunflower'**
  String get crop_sunflower;

  /// Crop: client form crop picker and chips (stored value 'Tomatoes').
  ///
  /// In en, this message translates to:
  /// **'Tomatoes'**
  String get crop_tomatoes;

  /// Crop: client form crop picker and chips (stored value 'Onions').
  ///
  /// In en, this message translates to:
  /// **'Onions'**
  String get crop_onions;

  /// Crop: client form crop picker and chips (stored value 'Cabbage').
  ///
  /// In en, this message translates to:
  /// **'Cabbage'**
  String get crop_cabbage;

  /// Crop: client form crop picker and chips (stored value 'Okra').
  ///
  /// In en, this message translates to:
  /// **'Okra'**
  String get crop_okra;

  /// Crop: client form crop picker and chips (stored value 'Mangoes').
  ///
  /// In en, this message translates to:
  /// **'Mangoes'**
  String get crop_mangoes;

  /// Crop: client form crop picker and chips (stored value 'Oranges').
  ///
  /// In en, this message translates to:
  /// **'Oranges'**
  String get crop_oranges;

  /// Crop: client form crop picker and chips (stored value 'Avocado').
  ///
  /// In en, this message translates to:
  /// **'Avocado'**
  String get crop_avocado;

  /// Crop: client form crop picker and chips (stored value 'Watermelon').
  ///
  /// In en, this message translates to:
  /// **'Watermelon'**
  String get crop_watermelon;

  /// Heading in Add Transaction's expense category picker: the 'Administration' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get expenseGroup_administration;

  /// Heading in Add Transaction's expense category picker: the 'Premises & Utilities' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Premises & Utilities'**
  String get expenseGroup_premisesUtilities;

  /// Heading in Add Transaction's expense category picker: the 'Operations' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get expenseGroup_operations;

  /// Heading in Add Transaction's expense category picker: the 'Transport' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get expenseGroup_transport;

  /// Heading in Add Transaction's expense category picker: the 'Business' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get expenseGroup_business;

  /// Heading in Add Transaction's expense category picker: the 'Other' group (not stored).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseGroup_other;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Meals & Refreshments').
  ///
  /// In en, this message translates to:
  /// **'Meals & Refreshments'**
  String get expenseCategory_mealsRefreshments;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Salaries & Wages').
  ///
  /// In en, this message translates to:
  /// **'Salaries & Wages'**
  String get expenseCategory_salariesWages;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Office Supplies').
  ///
  /// In en, this message translates to:
  /// **'Office Supplies'**
  String get expenseCategory_officeSupplies;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Electricity').
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get expenseCategory_electricity;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Water').
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get expenseCategory_water;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Rent').
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get expenseCategory_rent;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Drugs & Medicines').
  ///
  /// In en, this message translates to:
  /// **'Drugs & Medicines'**
  String get expenseCategory_drugsMedicines;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Veterinary Supplies').
  ///
  /// In en, this message translates to:
  /// **'Veterinary Supplies'**
  String get expenseCategory_veterinarySupplies;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Fuel').
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get expenseCategory_fuel;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Vehicle Maintenance').
  ///
  /// In en, this message translates to:
  /// **'Vehicle Maintenance'**
  String get expenseCategory_vehicleMaintenance;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Marketing').
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get expenseCategory_marketing;

  /// Expense category: Add Transaction picker, Transactions list and details (stored value 'Licences & Registration').
  ///
  /// In en, this message translates to:
  /// **'Licences & Registration'**
  String get expenseCategory_licencesRegistration;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Commission Income').
  ///
  /// In en, this message translates to:
  /// **'Commission Income'**
  String get incomeCategory_commission;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Delivery Income').
  ///
  /// In en, this message translates to:
  /// **'Delivery Income'**
  String get incomeCategory_delivery;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Training Income').
  ///
  /// In en, this message translates to:
  /// **'Training Income'**
  String get incomeCategory_training;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Consultancy Income').
  ///
  /// In en, this message translates to:
  /// **'Consultancy Income'**
  String get incomeCategory_consultancy;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Rental Income').
  ///
  /// In en, this message translates to:
  /// **'Rental Income'**
  String get incomeCategory_rental;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Interest Income').
  ///
  /// In en, this message translates to:
  /// **'Interest Income'**
  String get incomeCategory_interest;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Refunds Received').
  ///
  /// In en, this message translates to:
  /// **'Refunds Received'**
  String get incomeCategory_refundsReceived;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Discounts Received').
  ///
  /// In en, this message translates to:
  /// **'Discounts Received'**
  String get incomeCategory_discountsReceived;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Asset Disposal Income').
  ///
  /// In en, this message translates to:
  /// **'Asset Disposal Income'**
  String get incomeCategory_assetDisposal;

  /// Income category: Add Transaction picker, Transactions list and details (stored value 'Other Income').
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get incomeCategory_other;

  /// Payment method, short: filter names and table headers (Payments, Subscription history).
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get common_method;

  /// A filter showing its name and chosen value, e.g. 'Type: Sales', 'Method: All'.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String common_filterValue(String label, String value);

  /// A total next to a list (amount already formatted, e.g. TSh 12,000).
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String common_totalValue(String amount);

  /// Today: metric card and day heading.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get common_today;

  /// Yesterday: day heading in a list grouped by day.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get common_yesterday;

  /// Page-size choice under a paged list.
  ///
  /// In en, this message translates to:
  /// **'{count} per page'**
  String common_perPage(int count);

  /// The current page under a paged list.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String common_page(int page);

  /// Message when tapping a phone number could not open the phone app.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the dialer'**
  String get common_dialerFailed;

  /// Button that prints a receipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get common_printReceipt;

  /// Button under an empty filtered list.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get common_resetFilters;

  /// Label of an optional notes field.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get common_notesOptional;

  /// Name of a notifications panel (read by screen readers).
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get common_notifications;

  /// Payments screen title.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments_title;

  /// Payments screen title when opened for one client.
  ///
  /// In en, this message translates to:
  /// **'Payments - {clientName}'**
  String payments_titleForClient(String clientName);

  /// Payments screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'All payments received across your business'**
  String get payments_subtitle;

  /// Payments type filter: payments for sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get payments_typeSales;

  /// Payments type filter: payments for services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get payments_typeServices;

  /// Payments type filter: debt repayments.
  ///
  /// In en, this message translates to:
  /// **'Debt Repayments'**
  String get payments_typeDebtRepayments;

  /// Payments type filter: other income.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get payments_typeOtherIncome;

  /// Payments method filter before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'All Methods'**
  String get payments_allMethods;

  /// Payments search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search payer, reference, invoice...'**
  String get payments_searchHint;

  /// Banner when new payments arrived while the list was open.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new entry available} other{{count} new entries available}}'**
  String payments_newEntries(int count);

  /// Payments list when the chosen dates have none.
  ///
  /// In en, this message translates to:
  /// **'No payments in this period.'**
  String get payments_emptyPeriod;

  /// Payments table header.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get payments_colDateTime;

  /// Payments table header and detail label: who paid.
  ///
  /// In en, this message translates to:
  /// **'Payer'**
  String get payments_payer;

  /// Payments table header and detail label: what the payment was for.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get payments_source;

  /// Payments table header: receipt or invoice number.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get payments_reference;

  /// Payments table header and detail label: staff member who recorded it.
  ///
  /// In en, this message translates to:
  /// **'Recorded By'**
  String get payments_recordedBy;

  /// Payments metric card.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get payments_thisWeek;

  /// Payments metric card.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get payments_thisMonth;

  /// Number of payments under a metric card. English is always 'payments', as before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} payments}}'**
  String payments_paymentCount(int count);

  /// Payments metric card: money still owed.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get payments_outstanding;

  /// Number of open debts under the Outstanding card. English is always 'debts', as before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} debts}}'**
  String payments_debtCount(int count);

  /// Title of the payment detail panel, and the payment section of the Subscription form.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get payments_detailsTitle;

  /// Badge on the payment detail panel.
  ///
  /// In en, this message translates to:
  /// **'Payment Received'**
  String get payments_received;

  /// Message when a payment has no receipt to print.
  ///
  /// In en, this message translates to:
  /// **'No receipt available for this payment'**
  String get payments_noReceipt;

  /// Subscription screen title.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription_title;

  /// Subscription status: in a free trial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get subscription_statusTrial;

  /// Subscription status: trial with no end date set.
  ///
  /// In en, this message translates to:
  /// **'Trial - no subscription set up yet'**
  String get subscription_statusTrialNoSetup;

  /// Subscription status: paid and active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscription_statusActive;

  /// Subscription status: expired, still usable for a few days.
  ///
  /// In en, this message translates to:
  /// **'Payment overdue - grace period'**
  String get subscription_statusGrace;

  /// Subscription status: expired and read-only.
  ///
  /// In en, this message translates to:
  /// **'Locked - subscription expired'**
  String get subscription_statusLocked;

  /// Under the subscription status (date already formatted).
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}'**
  String subscription_expiredOn(String date);

  /// Under the subscription status (date already formatted).
  ///
  /// In en, this message translates to:
  /// **'Trial expires on {date}'**
  String subscription_trialExpiresOn(String date);

  /// Under the subscription status (date already formatted).
  ///
  /// In en, this message translates to:
  /// **'Renews / expires on {date}'**
  String subscription_renewsOn(String date);

  /// Shown when the subscription is locked.
  ///
  /// In en, this message translates to:
  /// **'Your account is in read-only mode. Submit a payment below to restore full access - your data is safe and untouched.'**
  String get subscription_readOnly;

  /// Promotion banner, discount on all plans (percent already formatted).
  ///
  /// In en, this message translates to:
  /// **'{percent}% off every plan - applied automatically below.'**
  String subscription_promoAllPlans(String percent);

  /// Promotion banner, discount on some plans (percent already formatted).
  ///
  /// In en, this message translates to:
  /// **'{percent}% off select plans - applied automatically below.'**
  String subscription_promoSomePlans(String percent);

  /// Subscription form heading.
  ///
  /// In en, this message translates to:
  /// **'Choose a Plan'**
  String get subscription_choosePlan;

  /// Subscription form: the payment reference field.
  ///
  /// In en, this message translates to:
  /// **'Transaction / Confirmation Code'**
  String get subscription_referenceLabel;

  /// Subscription form: hint for the payment reference.
  ///
  /// In en, this message translates to:
  /// **'e.g. the M-Pesa confirmation code'**
  String get subscription_referenceHint;

  /// Subscription form: button to attach a payment screenshot.
  ///
  /// In en, this message translates to:
  /// **'Attach Proof (optional)'**
  String get subscription_attachProof;

  /// Subscription form: after a screenshot is attached.
  ///
  /// In en, this message translates to:
  /// **'Proof attached'**
  String get subscription_proofAttached;

  /// Subscription form: a payment is already waiting.
  ///
  /// In en, this message translates to:
  /// **'Your last payment is still under review. Please wait for it to be approved or rejected before submitting another.'**
  String get subscription_pendingWarning;

  /// Subscription form: the plan has no price yet.
  ///
  /// In en, this message translates to:
  /// **'Pricing for this plan isn\'t available right now. Please try again shortly or contact support.'**
  String get subscription_priceUnavailableWarning;

  /// Subscription submit button while a payment waits.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Review'**
  String get subscription_awaitingReview;

  /// Subscription submit button when the plan has no price.
  ///
  /// In en, this message translates to:
  /// **'Pricing Unavailable'**
  String get subscription_pricingUnavailable;

  /// Subscription submit button.
  ///
  /// In en, this message translates to:
  /// **'Submit Payment for Review'**
  String get subscription_submitForReview;

  /// Subscription screen heading over the latest payments.
  ///
  /// In en, this message translates to:
  /// **'Recent Submissions'**
  String get subscription_recentSubmissions;

  /// Subscription screen: no payments submitted yet.
  ///
  /// In en, this message translates to:
  /// **'No submissions yet.'**
  String get subscription_noSubmissionsYetDot;

  /// Link to the full Subscription history.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get subscription_viewAll;

  /// Message when Submit is pressed without a reference.
  ///
  /// In en, this message translates to:
  /// **'Enter the payment reference / confirmation code'**
  String get subscription_enterReference;

  /// Message after a payment is submitted.
  ///
  /// In en, this message translates to:
  /// **'Payment submitted'**
  String get subscription_submitted;

  /// Second line of the message after a payment is submitted.
  ///
  /// In en, this message translates to:
  /// **'It will be reviewed and confirmed shortly'**
  String get subscription_submittedDetail;

  /// Message when submitting a payment failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit the payment'**
  String get subscription_submitFailed;

  /// Why a payment was rejected (text typed by the reviewer).
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String subscription_rejectReason(String reason);

  /// A rejected payment with no reason.
  ///
  /// In en, this message translates to:
  /// **'No reason was given'**
  String get subscription_noReason;

  /// Subscription history screen title.
  ///
  /// In en, this message translates to:
  /// **'Subscription History'**
  String get subscription_historyTitle;

  /// Subscription history subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your payments and their review status'**
  String get subscription_historySubtitle;

  /// Subscription history failed to load (error already in friendly words).
  ///
  /// In en, this message translates to:
  /// **'Could not load history: {error}'**
  String subscription_historyLoadError(String error);

  /// Subscription history, empty.
  ///
  /// In en, this message translates to:
  /// **'No submissions yet'**
  String get subscription_noSubmissionsYet;

  /// Subscription history, empty: second line.
  ///
  /// In en, this message translates to:
  /// **'Payments you submit will be listed here.'**
  String get subscription_noSubmissionsHint;

  /// Subscription history summary card.
  ///
  /// In en, this message translates to:
  /// **'Total Submissions'**
  String get subscription_totalSubmissions;

  /// Subscription history summary card hint.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get subscription_allPayments;

  /// Subscription history: card hint and a waiting payment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get subscription_awaitingReviewLower;

  /// Subscription history: Rejected card hint.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get subscription_notAccepted;

  /// Subscription history search hint.
  ///
  /// In en, this message translates to:
  /// **'Search by plan, method, reference or reason...'**
  String get subscription_searchHint;

  /// Subscription history: plan filter and column header.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get subscription_plan;

  /// Subscription history: filters hide everything.
  ///
  /// In en, this message translates to:
  /// **'No submissions match your filters'**
  String get subscription_noMatches;

  /// Subscription history column header: when it was sent.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get subscription_colSubmitted;

  /// Subscription history: when a payment was rejected (date already formatted).
  ///
  /// In en, this message translates to:
  /// **'Rejected {date}'**
  String subscription_rejectedOn(String date);

  /// Subscription history pagination with nothing to show.
  ///
  /// In en, this message translates to:
  /// **'No submissions'**
  String get subscription_noSubmissions;

  /// Subscription history pagination.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1 submission} other{Showing {start} to {end} of {total} submissions}}'**
  String subscription_showingRange(int total, int start, int end);

  /// Stock Store screen title.
  ///
  /// In en, this message translates to:
  /// **'Stock Store'**
  String get store_title;

  /// Stock Store subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your inventory'**
  String get store_subtitle;

  /// Stock Store metric card: value of what is in the store.
  ///
  /// In en, this message translates to:
  /// **'Store Stock Value'**
  String get store_stockValue;

  /// Stock Store search hint.
  ///
  /// In en, this message translates to:
  /// **'Search stock, brand or batch...'**
  String get store_searchHint;

  /// Stock Store: how many products the filters show.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product in stock} other{{count} products in stock}}'**
  String store_productsInStock(int count);

  /// Stock Store with no products at all.
  ///
  /// In en, this message translates to:
  /// **'No products in stock store'**
  String get store_empty;

  /// Metric card (Stock Store, Products).
  ///
  /// In en, this message translates to:
  /// **'Total Products'**
  String get products_totalProducts;

  /// Product stock status: in stock and not near expiry.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get products_statusActive;

  /// Product stock status: never had stock.
  ///
  /// In en, this message translates to:
  /// **'Not Stocked'**
  String get products_statusNotStocked;

  /// Product stock status: no expiry date recorded.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get products_statusUnknown;

  /// Product stock status: expires within 30 days.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get products_statusExpiringSoon;

  /// Title of the delete-product dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get products_confirmDeleteTitle;

  /// Delete-product dialog text.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this product?'**
  String get products_confirmDeleteBody;

  /// Message after deleting a product (with Undo).
  ///
  /// In en, this message translates to:
  /// **'Product moved to Trash'**
  String get products_movedToTrash;

  /// Message when deleting a product failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the product'**
  String get products_deleteFailed;

  /// Message after Undo restores a product.
  ///
  /// In en, this message translates to:
  /// **'Product restored'**
  String get products_restored;

  /// Message when restoring a product failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the product'**
  String get products_restoreFailed;

  /// Product list: filters hide everything.
  ///
  /// In en, this message translates to:
  /// **'No products match your filters'**
  String get products_noMatches;

  /// Badge: the shelf needs restocking from the store.
  ///
  /// In en, this message translates to:
  /// **'Restock Shelf'**
  String get products_restockShelf;

  /// Product card label: quantity in the store.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get products_stock;

  /// Product card label: selling price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get products_price;

  /// Button and tooltip: move stock from the store to the shelf.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get products_release;

  /// Product menu item.
  ///
  /// In en, this message translates to:
  /// **'Add New Batch'**
  String get products_addNewBatch;

  /// Product menu item.
  ///
  /// In en, this message translates to:
  /// **'View Batches'**
  String get products_viewBatches;

  /// Tooltip of the stock alerts bell.
  ///
  /// In en, this message translates to:
  /// **'Stock Alerts'**
  String get products_stockAlerts;

  /// Button that opens the add-product form.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get products_addProduct;

  /// Product list pagination. English always says 'products', as before.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{Showing {start} to {end} of {total} products}}'**
  String products_showingRange(int total, int start, int end);

  /// Stock Store card line (unit already in the current language).
  ///
  /// In en, this message translates to:
  /// **'Sellable: {quantity} {unit} • Batch: {batch}'**
  String products_sellableBatch(String quantity, String unit, String batch);

  /// Product card: buying price (already formatted).
  ///
  /// In en, this message translates to:
  /// **'Buy: {price}'**
  String products_buyPrice(String price);

  /// Product card: expiry date (already formatted).
  ///
  /// In en, this message translates to:
  /// **'Expiry: {date}'**
  String products_expiryDate(String date);

  /// A batch named by its number, in the expired-stock warning.
  ///
  /// In en, this message translates to:
  /// **'Batch {batchNo}'**
  String store_batchName(String batchNo);

  /// A batch with no number, in the expired-stock warning.
  ///
  /// In en, this message translates to:
  /// **'an unlabeled batch'**
  String get store_unlabeledBatch;

  /// Title of the expired-stock warning when releasing to the shelf.
  ///
  /// In en, this message translates to:
  /// **'Expired Stock'**
  String get store_expiredStockTitle;

  /// Expired-stock warning text.
  ///
  /// In en, this message translates to:
  /// **'This product is expired. Do you still want to release it to the shelf?'**
  String get store_expiredStockBody;

  /// One line of the expired-stock warning (unit already in the current language).
  ///
  /// In en, this message translates to:
  /// **'• {quantity} {unit} from {batch}'**
  String store_expiredPortionLine(String quantity, String unit, String batch);

  /// Expired-stock warning: release regardless.
  ///
  /// In en, this message translates to:
  /// **'Release Anyway'**
  String get store_releaseAnyway;

  /// Title of the release dialog.
  ///
  /// In en, this message translates to:
  /// **'Release to Shelf'**
  String get store_releaseTitle;

  /// Release dialog (unit already in the current language).
  ///
  /// In en, this message translates to:
  /// **'Available stock: {quantity} {unit}'**
  String store_availableStock(String quantity, String unit);

  /// Release dialog quantity field.
  ///
  /// In en, this message translates to:
  /// **'Quantity to release'**
  String get store_quantityToRelease;

  /// Release dialog notes hint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Quality checked, ready for sale'**
  String get store_notesHint;

  /// Message when the release quantity is out of range.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity from 1 to {max}'**
  String store_quantityRange(String max);

  /// Message after releasing stock (unit already in the current language).
  ///
  /// In en, this message translates to:
  /// **'Released {quantity} {unit} of {product} to the shelf'**
  String store_released(String quantity, String unit, String product);

  /// Message when releasing stock failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t release the product'**
  String get store_releaseFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
