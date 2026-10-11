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
