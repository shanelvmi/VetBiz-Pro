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

  /// Error toast when a picked photo is still over the upload size limit (5 MB) after scaling down; nothing is uploaded.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large. Choose a smaller one.'**
  String get error_photoTooLarge;

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

  /// Number of payments under a metric card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment} other{{count} payments}}'**
  String payments_paymentCount(int count);

  /// Payments metric card: money still owed.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get payments_outstanding;

  /// Number of open debts under the Outstanding card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 debt} other{{count} debts}}'**
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

  /// Product list pagination.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1 product} other{Showing {start} to {end} of {total} products}}'**
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

  /// Shown when a name is missing (who recorded an entry).
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get common_unknown;

  /// Pagination bar: which rows of the list are shown.
  ///
  /// In en, this message translates to:
  /// **'Showing {start} to {end}'**
  String common_showingRange(int start, int end);

  /// Phone number label or column header.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get common_phone;

  /// Address label or column header.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get common_address;

  /// Name label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get common_name;

  /// Description column header or label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get common_description;

  /// Category column header or label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get common_category;

  /// Error under a form field left empty.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get common_required;

  /// A form field's label with the required-field star.
  ///
  /// In en, this message translates to:
  /// **'{label} *'**
  String common_requiredLabel(String label);

  /// Export button (downloads the list as a file).
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get common_export;

  /// Table column header for the row's action buttons.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get common_actions;

  /// Heading of a summary section.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get common_summary;

  /// Notes section when there are none.
  ///
  /// In en, this message translates to:
  /// **'No notes added'**
  String get common_noNotes;

  /// Dropdown choice meaning nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get common_none;

  /// Search box hint in a picker.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get common_searchEllipsis;

  /// Message (or its second line) when no facility is chosen.
  ///
  /// In en, this message translates to:
  /// **'No facility selected'**
  String get common_noFacility;

  /// Message when a web link could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get common_linkFailed;

  /// Second line of the could-not-open-link message.
  ///
  /// In en, this message translates to:
  /// **'Copy it from the error log instead'**
  String get common_linkFailedDetail;

  /// Dialog title when printing with no receipt printer connected.
  ///
  /// In en, this message translates to:
  /// **'No Printer Connected'**
  String get common_noPrinterTitle;

  /// Dialog text when no receipt printer is connected.
  ///
  /// In en, this message translates to:
  /// **'Connect a Bluetooth receipt printer in Printer Settings first.'**
  String get common_noPrinterBody;

  /// Button that opens Printer Settings.
  ///
  /// In en, this message translates to:
  /// **'Go to Printer Settings'**
  String get common_goToPrinterSettings;

  /// Message after a receipt was printed.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to printer'**
  String get common_receiptSentToPrinter;

  /// Message when printing a receipt failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t print the receipt'**
  String get common_printFailed;

  /// Second line when the printer refused the receipt.
  ///
  /// In en, this message translates to:
  /// **'The printer did not accept it'**
  String get common_printFailedDetail;

  /// Transaction type (stored as "expense"); "Other Income" uses payments_typeOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionType_expense;

  /// Transactions screen title.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions_title;

  /// Transactions screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'All income and expense transactions'**
  String get transactions_subtitle;

  /// Button and form title for a new transaction.
  ///
  /// In en, this message translates to:
  /// **'Record Transaction'**
  String get transactions_record;

  /// Form title when editing a transaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get transactions_edit;

  /// Save button when editing a transaction.
  ///
  /// In en, this message translates to:
  /// **'Update Transaction'**
  String get transactions_update;

  /// Transactions metric card: total expenses in the period.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get transactions_expenses;

  /// Transactions metric card: other income minus expenses.
  ///
  /// In en, this message translates to:
  /// **'Other Income vs Expenses'**
  String get transactions_incomeVsExpenses;

  /// Transactions search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search by description, category...'**
  String get transactions_searchHint;

  /// Number of transactions shown, beside the filters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String transactions_count(int count);

  /// Transactions list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No transactions.'**
  String get transactions_empty;

  /// Transactions list when the type filter has none; type is the type's label.
  ///
  /// In en, this message translates to:
  /// **'No transactions for {type}.'**
  String transactions_emptyForType(String type);

  /// Delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get transactions_deleteTitle;

  /// Delete confirmation text; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'\"{description}\" - {amount}\n\nYou can restore it from Trash.'**
  String transactions_deleteBody(String description, String amount);

  /// Message after deleting, with Undo.
  ///
  /// In en, this message translates to:
  /// **'Transaction moved to Trash'**
  String get transactions_movedToTrash;

  /// Message when deleting failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the transaction'**
  String get transactions_deleteFailed;

  /// Message after Undo restored the transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction restored'**
  String get transactions_restored;

  /// Message when Undo failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the transaction'**
  String get transactions_restoreFailed;

  /// Details panel title and the form's first section heading.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactions_detailsTitle;

  /// End of the transactions list.
  ///
  /// In en, this message translates to:
  /// **'Showing all recent transactions'**
  String get transactions_allShown;

  /// Button at the end of the transactions list.
  ///
  /// In en, this message translates to:
  /// **'Load more transactions'**
  String get transactions_loadMore;

  /// Message when the transaction form is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in all required fields correctly'**
  String get transactions_fillRequired;

  /// Message when no payment method is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select how this transaction was paid'**
  String get transactions_selectPaymentMethod;

  /// Message after editing a transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get transactions_updated;

  /// Message when editing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the transaction'**
  String get transactions_updateFailed;

  /// Message after recording a transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved'**
  String get transactions_saved;

  /// Message when recording failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the transaction'**
  String get transactions_saveFailed;

  /// Category field before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select category...'**
  String get transactions_selectCategory;

  /// Description field hint.
  ///
  /// In en, this message translates to:
  /// **'What was this for?'**
  String get transactions_descriptionHint;

  /// Note field label.
  ///
  /// In en, this message translates to:
  /// **'Reference/Note (optional)'**
  String get transactions_noteLabel;

  /// Note field hint.
  ///
  /// In en, this message translates to:
  /// **'Add any additional information'**
  String get transactions_noteHint;

  /// Form section heading.
  ///
  /// In en, this message translates to:
  /// **'Amount & Payment'**
  String get transactions_amountPayment;

  /// Amount field label; currency is the currency symbol.
  ///
  /// In en, this message translates to:
  /// **'Amount ({currency}) *'**
  String transactions_amountRequired(String currency);

  /// Payment method field before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select method'**
  String get transactions_selectMethod;

  /// Category picker when the search matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get transactions_noCategories;

  /// Category picker title.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get transactions_selectCategoryTitle;

  /// Category picker search hint.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get transactions_searchCategories;

  /// What a debt came from (stored as "Service").
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get debtSource_service;

  /// Debtors screen title.
  ///
  /// In en, this message translates to:
  /// **'Active Debts'**
  String get debtors_title;

  /// Debtors screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Track and manage all outstanding debts'**
  String get debtors_subtitle;

  /// Banner when new debtors arrived while the list was open.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new debtor available} other{{count} new debtors available}}'**
  String debtors_newRecords(int count);

  /// Debtors list when nobody owes anything.
  ///
  /// In en, this message translates to:
  /// **'No outstanding debts'**
  String get debtors_emptyNone;

  /// Debtors list when the search finds nobody.
  ///
  /// In en, this message translates to:
  /// **'No debtors match your search'**
  String get debtors_emptySearch;

  /// Debtors metric card title.
  ///
  /// In en, this message translates to:
  /// **'Total Debtors'**
  String get debtors_totalDebtors;

  /// Under the Total Debtors metric.
  ///
  /// In en, this message translates to:
  /// **'With outstanding balance'**
  String get debtors_withBalance;

  /// Debtors metric, table header and details row: everything a debtor owes.
  ///
  /// In en, this message translates to:
  /// **'Total Owed'**
  String get debtors_totalOwed;

  /// Under the Total Owed metric.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get debtors_outstandingBalance;

  /// Debtors metric card title.
  ///
  /// In en, this message translates to:
  /// **'Overdue Debtors'**
  String get debtors_overdueDebtors;

  /// Under the Overdue Debtors metric; days is the facility's overdue limit.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Over 1 day} other{Over {days} days}}'**
  String debtors_overDays(int days);

  /// Debtors metric card title.
  ///
  /// In en, this message translates to:
  /// **'Paid This Month'**
  String get debtors_paidThisMonth;

  /// Under the Paid This Month metric.
  ///
  /// In en, this message translates to:
  /// **'From debt payments'**
  String get debtors_fromDebtPayments;

  /// Button and form title for recording a debt payment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get debtors_recordPayment;

  /// Debt status badge and status filter choice: past the overdue limit.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get debtors_overdue;

  /// Debt status badge and status filter choice: not overdue yet.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get debtors_current;

  /// Debtors table header (how long overdue) and the overdue-range filter's label.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get debtors_colOverdue;

  /// Overdue-range filter choice.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} days overdue'**
  String debtors_rangeDays(int from, int to);

  /// Last overdue-range filter choice.
  ///
  /// In en, this message translates to:
  /// **'{from}+ days overdue'**
  String debtors_rangeDaysPlus(int from);

  /// Debtors search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search debtor by name...'**
  String get debtors_searchHint;

  /// Debtors table header and the payment form's debtor field.
  ///
  /// In en, this message translates to:
  /// **'Debtor'**
  String get debtors_debtor;

  /// Debtors table header.
  ///
  /// In en, this message translates to:
  /// **'Oldest Debt Since'**
  String get debtors_oldestDebtSince;

  /// How many days a debtor is overdue, in the table.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String debtors_daysCount(int count);

  /// Button, tooltip and dialog title for reminding a debtor.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get debtors_sendReminder;

  /// Button and tooltip that open a debtor's payments.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get debtors_paymentHistory;

  /// Pagination bar when the list is empty.
  ///
  /// In en, this message translates to:
  /// **'No debtors'**
  String get debtors_none;

  /// Details panel title.
  ///
  /// In en, this message translates to:
  /// **'Debtor Details'**
  String get debtors_detailsTitle;

  /// Details panel row.
  ///
  /// In en, this message translates to:
  /// **'Overdue Amount'**
  String get debtors_overdueAmount;

  /// Details panel row: date of the latest debt.
  ///
  /// In en, this message translates to:
  /// **'Last Transaction'**
  String get debtors_lastTransaction;

  /// Details panel heading with the number of debts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Debts ({count})'**
  String debtors_outstandingDebts(int count);

  /// Button and dialog title for a note on a debtor.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get debtors_addNote;

  /// One debt in the details panel: invoice number and date.
  ///
  /// In en, this message translates to:
  /// **'Invoice: {invoice} • {date}'**
  String debtors_invoiceLine(String invoice, String date);

  /// Button that pays one debt.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get debtors_pay;

  /// Message when the export failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export the active debts'**
  String get debtors_exportFailed;

  /// Add Note field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Promised to pay by Friday'**
  String get debtors_noteHint;

  /// Message when saving a note failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the note'**
  String get debtors_noteSaveFailed;

  /// Send Reminder dialog text; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'Remind {name} about their {amount} balance via:'**
  String debtors_reminderBody(String name, String amount);

  /// Send Reminder dialog: send by text message.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get debtors_viaSms;

  /// Send Reminder dialog: send by WhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get debtors_viaWhatsApp;

  /// Message when WhatsApp could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open WhatsApp'**
  String get debtors_whatsAppFailed;

  /// Message when the text-message app could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Messages'**
  String get debtors_messagesFailed;

  /// Message when opening the reminder failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reminder'**
  String get debtors_reminderFailed;

  /// Payment form: debtor field left empty.
  ///
  /// In en, this message translates to:
  /// **'Choose the debtor this payment is for'**
  String get debtors_errChooseDebtor;

  /// Payment form: the typed name matches no debtor.
  ///
  /// In en, this message translates to:
  /// **'No debtor found with the name \"{name}\"'**
  String debtors_errNoMatch(String name);

  /// Payment form: too little typed to search.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 letters of the debtor\'s name'**
  String get debtors_errTooShort;

  /// Payment form: a name was typed but not picked from the list.
  ///
  /// In en, this message translates to:
  /// **'Choose a debtor from the suggestions'**
  String get debtors_errPickSuggestion;

  /// Payment form header: the debtor's name.
  ///
  /// In en, this message translates to:
  /// **'Client: {name}'**
  String debtors_clientLabel(String name);

  /// Payment form header, before the amount (shown in red after it).
  ///
  /// In en, this message translates to:
  /// **'Total owed:'**
  String get debtors_totalOwedLabel;

  /// Message when no payment method is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select how this payment was made'**
  String get debtors_selectPaymentMethod;

  /// Message when the session has ended.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to record this payment'**
  String get debtors_signInAgain;

  /// Message when no debtor is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a client'**
  String get debtors_selectClient;

  /// Message after recording a payment; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'Payment of {amount} recorded for {name}'**
  String debtors_paymentRecorded(String amount, String name);

  /// Message when recording a payment failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the payment'**
  String get debtors_paymentSaveFailed;

  /// Payment form: debtor field hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get debtors_debtorSearchHint;

  /// Payment form: under the debtor field.
  ///
  /// In en, this message translates to:
  /// **'Only clients who currently owe money are listed'**
  String get debtors_debtorHelper;

  /// Payment form: what this one debt still owes; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'Amount owed: {amount}'**
  String debtors_amountOwed(String amount);

  /// Payment form: amount field label.
  ///
  /// In en, this message translates to:
  /// **'Payment Amount'**
  String get debtors_paymentAmount;

  /// Payment form: amount left empty.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get debtors_errEnterAmount;

  /// Payment form: amount is zero.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get debtors_errValidAmount;

  /// Payment form: amount above what this debt owes.
  ///
  /// In en, this message translates to:
  /// **'Cannot pay more than owed'**
  String get debtors_errMoreThanOwed;

  /// Payment form: amount above everything the debtor owes.
  ///
  /// In en, this message translates to:
  /// **'Cannot pay more than total owed'**
  String get debtors_errMoreThanTotal;

  /// Payment form save button.
  ///
  /// In en, this message translates to:
  /// **'Save Payment'**
  String get debtors_savePayment;

  /// Clients screen title.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients_title;

  /// Clients screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage all your clients in one place'**
  String get clients_subtitle;

  /// Button and form title for a new client.
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get clients_add;

  /// Form title when editing a client.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get clients_edit;

  /// Clients metric card title.
  ///
  /// In en, this message translates to:
  /// **'Total Clients'**
  String get clients_total;

  /// Beside the Total Clients metric.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get clients_allTime;

  /// Clients metric card title.
  ///
  /// In en, this message translates to:
  /// **'New This Month'**
  String get clients_newThisMonth;

  /// Clients metric card: the client type with most clients.
  ///
  /// In en, this message translates to:
  /// **'Most Active Type'**
  String get clients_mostActiveType;

  /// Beside the Most Active Type metric; percent is a whole number.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of clients'**
  String clients_percentOfClients(String percent);

  /// Clients metric card: the newest client.
  ///
  /// In en, this message translates to:
  /// **'Last Added'**
  String get clients_lastAdded;

  /// Clients search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, address...'**
  String get clients_searchHint;

  /// Delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete Client'**
  String get clients_deleteTitle;

  /// Message when deleting failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the client'**
  String get clients_deleteFailed;

  /// Delete client dialog text.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" moves to Trash. You can undo this now or restore it from Trash for 30 days.'**
  String clients_deleteToTrashBody(String name);

  /// Message after deleting a client (with Undo).
  ///
  /// In en, this message translates to:
  /// **'Client moved to Trash'**
  String get clients_movedToTrash;

  /// Message after Undo restores a client.
  ///
  /// In en, this message translates to:
  /// **'Client restored'**
  String get clients_restored;

  /// Message when Undo could not restore a client.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the client'**
  String get clients_restoreFailed;

  /// Why deleting a client was refused; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'This client still owes {amount}. Settle or remove the debts first.'**
  String clients_deleteRefusedOwes(String amount);

  /// Message when sharing the client card failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the client card'**
  String get clients_shareFailed;

  /// Details panel title.
  ///
  /// In en, this message translates to:
  /// **'Client Details'**
  String get clients_detailsTitle;

  /// Details label and form section heading.
  ///
  /// In en, this message translates to:
  /// **'Client Type'**
  String get clients_clientType;

  /// Table header and details label: when the client was added.
  ///
  /// In en, this message translates to:
  /// **'Joined On'**
  String get clients_joinedOn;

  /// Details label: the client's number of payments.
  ///
  /// In en, this message translates to:
  /// **'Total Transactions'**
  String get clients_totalTransactions;

  /// Details label: what the client has paid in total.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get clients_totalSpent;

  /// Button that saves or shares the client card image.
  ///
  /// In en, this message translates to:
  /// **'Save / Share'**
  String get clients_saveShare;

  /// Note under the search box while searching.
  ///
  /// In en, this message translates to:
  /// **'Searching by name (across all types)'**
  String get clients_searchingNote;

  /// Banner when new clients arrived while the list was open.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new client available} other{{count} new clients available}}'**
  String clients_newRecords(int count);

  /// Clients list when the search finds nobody.
  ///
  /// In en, this message translates to:
  /// **'No clients match \"{query}\"'**
  String clients_emptySearch(String query);

  /// Clients list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No clients found'**
  String get clients_empty;

  /// Clients table header.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clients_client;

  /// Clients list error when a database index is missing.
  ///
  /// In en, this message translates to:
  /// **'This filter needs a one-time database index to be created first.'**
  String get clients_indexNeeded;

  /// Clients list error; error is FriendlyError's sentence.
  ///
  /// In en, this message translates to:
  /// **'Could not load clients: {error}'**
  String clients_loadError(String error);

  /// Button that opens the console to create the missing index.
  ///
  /// In en, this message translates to:
  /// **'Create Index'**
  String get clients_createIndex;

  /// Under the Create Index button.
  ///
  /// In en, this message translates to:
  /// **'This takes a minute or two to finish building after you create it - then try this filter again.'**
  String get clients_indexBuildingHint;

  /// Pagination bar when the list is empty.
  ///
  /// In en, this message translates to:
  /// **'No clients'**
  String get clients_none;

  /// Client form: no type chosen.
  ///
  /// In en, this message translates to:
  /// **'Select at least one client type'**
  String get clients_errSelectType;

  /// Message when saving a client failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the client'**
  String get clients_saveFailed;

  /// Message after adding a client.
  ///
  /// In en, this message translates to:
  /// **'Client added'**
  String get clients_added;

  /// Message after editing a client.
  ///
  /// In en, this message translates to:
  /// **'Client updated'**
  String get clients_updated;

  /// Duplicate-client dialog title.
  ///
  /// In en, this message translates to:
  /// **'Client already exists'**
  String get clients_duplicateTitle;

  /// Duplicate-client dialog, matched by phone.
  ///
  /// In en, this message translates to:
  /// **'A client with this phone number already exists:'**
  String get clients_duplicateByPhone;

  /// Duplicate-client dialog, matched by name.
  ///
  /// In en, this message translates to:
  /// **'A client with a similar name already exists:'**
  String get clients_duplicateByName;

  /// Duplicate-client dialog: the existing client has no phone.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get clients_noPhone;

  /// Duplicate-client dialog advice. action: "add" when adding, "edit" when editing; match: "phone" or "name".
  ///
  /// In en, this message translates to:
  /// **'To avoid duplicate clients, {action, select, add{this client was not saved} other{your changes were not saved}}. If it is the same person, use the existing client from the Clients list. If it is a different person, {match, select, phone{enter a different phone number} other{change the name slightly}} and try again.'**
  String clients_duplicateBody(String action, String match);

  /// Client form section heading.
  ///
  /// In en, this message translates to:
  /// **'Client Information'**
  String get clients_infoSection;

  /// Client form: name hint.
  ///
  /// In en, this message translates to:
  /// **'Enter client name'**
  String get clients_nameHint;

  /// Client form: phone hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 07XX XXX XXX'**
  String get clients_phoneHint;

  /// Client form: address hint.
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get clients_addressHint;

  /// Client form: notes hint.
  ///
  /// In en, this message translates to:
  /// **'Any additional information about the client...'**
  String get clients_notesHint;

  /// Client form side card heading.
  ///
  /// In en, this message translates to:
  /// **'Quick Summary'**
  String get clients_quickSummary;

  /// Client form tip card.
  ///
  /// In en, this message translates to:
  /// **'You can update this client\'s animal species or crops anytime by editing their profile.'**
  String get clients_tip;

  /// Client form section heading for a crop producer.
  ///
  /// In en, this message translates to:
  /// **'Crop Information (Optional)'**
  String get clients_cropInfo;

  /// Client form section heading for a farmer.
  ///
  /// In en, this message translates to:
  /// **'Animal Information (Optional)'**
  String get clients_animalInfo;

  /// Under the crop section heading.
  ///
  /// In en, this message translates to:
  /// **'Add crops grown by this client if available.'**
  String get clients_cropHint;

  /// Under the animal section heading.
  ///
  /// In en, this message translates to:
  /// **'Add animals owned by this client if available.'**
  String get clients_animalHint;

  /// Under the section heading before a farmer type is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a farmer type below to add crops or animals.'**
  String get clients_farmerTypeHint;

  /// Client form: farmer type field label.
  ///
  /// In en, this message translates to:
  /// **'Farmer Type'**
  String get clients_farmerType;

  /// Button that opens the crop picker.
  ///
  /// In en, this message translates to:
  /// **'Add Crops'**
  String get clients_addCrops;

  /// Button that opens the animal picker.
  ///
  /// In en, this message translates to:
  /// **'Add Animals'**
  String get clients_addAnimals;

  /// Crop picker title.
  ///
  /// In en, this message translates to:
  /// **'Select Crops'**
  String get clients_selectCrops;

  /// Animal picker title.
  ///
  /// In en, this message translates to:
  /// **'Select Animal Species'**
  String get clients_selectAnimals;

  /// Crop or animal picker when the search matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get clients_noMatches;

  /// Client form section heading (vet or business details).
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get clients_additionalDetails;

  /// Client form: a vet client's practice type.
  ///
  /// In en, this message translates to:
  /// **'Practice Type'**
  String get clients_practiceType;

  /// Client form: business name field label.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get clients_businessName;

  /// Client form: business name hint.
  ///
  /// In en, this message translates to:
  /// **'Enter business name'**
  String get clients_businessNameHint;

  /// Save button when editing a client.
  ///
  /// In en, this message translates to:
  /// **'Update Client'**
  String get clients_update;

  /// Save button when adding a client.
  ///
  /// In en, this message translates to:
  /// **'Save Client'**
  String get clients_save;

  /// Try again button (lower-case "again"), for example after a load error.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get common_tryAgainLower;

  /// Restore button or tooltip (brings an item back from Trash).
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get common_restore;

  /// Screen text when no facility is chosen (with a full stop).
  ///
  /// In en, this message translates to:
  /// **'No facility selected.'**
  String get common_noFacilityDot;

  /// Shown in a team member's row while a change is being saved.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get team_working;

  /// Message after a status change; action is the stored action key.
  ///
  /// In en, this message translates to:
  /// **'{action, select, approved{{name} approved} rejected{{name} rejected} deactivated{{name} deactivated} reactivated{{name} reactivated} other{{name} {action}}}'**
  String team_actionDone(String name, String action);

  /// Message when a status change failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the assistant'**
  String get team_updateFailed;

  /// Message after removing an assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant removed from this facility'**
  String get team_removed;

  /// Message when removing failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the assistant'**
  String get team_removeFailed;

  /// Warning after deactivating or removing an assistant when the server saved the change but could not switch off their sign-in (Firebase Auth); they may still be signed in.
  ///
  /// In en, this message translates to:
  /// **'The assistant was deactivated, but their sign-in could not be switched off. Reactivate and deactivate again.'**
  String get team_signInSwitchFailed;

  /// Message after moving an assistant to another facility.
  ///
  /// In en, this message translates to:
  /// **'Assistant reassigned'**
  String get team_reassigned;

  /// Message when moving failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reassign the assistant'**
  String get team_reassignFailed;

  /// Stands in for a missing name in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'this assistant'**
  String get team_thisAssistant;

  /// Stands in for a missing name at the start of a sentence.
  ///
  /// In en, this message translates to:
  /// **'This assistant'**
  String get team_thisAssistantCap;

  /// Stands in for a missing name in the Reject dialog.
  ///
  /// In en, this message translates to:
  /// **'this person'**
  String get team_thisPerson;

  /// Stands in for a missing name in the Deactivate co-admin dialog.
  ///
  /// In en, this message translates to:
  /// **'this co-admin'**
  String get team_thisCoAdmin;

  /// Reassign dialog title.
  ///
  /// In en, this message translates to:
  /// **'Move {name}'**
  String team_moveTitle(String name);

  /// Reassign dialog text.
  ///
  /// In en, this message translates to:
  /// **'Choose the facility they should work in. They keep their account and their approval.'**
  String get team_moveBody;

  /// Reassign dialog when there is nowhere to move them.
  ///
  /// In en, this message translates to:
  /// **'You don\'t run any other facility to move them to.'**
  String get team_noOtherFacility;

  /// Picker title when the admin runs several facilities.
  ///
  /// In en, this message translates to:
  /// **'Invite Assistant To...'**
  String get team_inviteTo;

  /// A facility whose name is missing.
  ///
  /// In en, this message translates to:
  /// **'Unknown facility'**
  String get team_unknownFacility;

  /// Actions cell on your own row.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get team_you;

  /// Actions cell on the facility owner's row (seen by a co-admin).
  ///
  /// In en, this message translates to:
  /// **'Facility admin'**
  String get team_facilityAdmin;

  /// Button that approves a waiting assistant.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get team_approve;

  /// Button (and confirm button) that rejects a waiting assistant.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get team_reject;

  /// Button that pauses a team member's access.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get team_deactivate;

  /// Button that gives a paused team member access again.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get team_reactivate;

  /// Button that moves an assistant to another facility.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get team_reassign;

  /// Button that removes a paused assistant from the facility.
  ///
  /// In en, this message translates to:
  /// **'Remove from Facility'**
  String get team_removeFromFacility;

  /// Confirm button in the remove dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove from facility'**
  String get team_removeFromFacilityConfirm;

  /// Deactivate co-admin dialog title.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {name}?'**
  String team_deactivateTitle(String name);

  /// Deactivate co-admin dialog text.
  ///
  /// In en, this message translates to:
  /// **'They\'ll be signed out straight away and can\'t log in until you reactivate them. This doesn\'t change their role - only the platform administrator can do that.'**
  String get team_deactivateBody;

  /// Message when changing a co-admin's status failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the status'**
  String get team_updateStatusFailed;

  /// Facility cell of an admin who runs several facilities.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} facilities}}'**
  String team_facilityCount(int count);

  /// Remove dialog title.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from {facility}?'**
  String team_removeTitle(String name, String facility);

  /// Remove dialog, first point.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be part of {facility}, and won\'t see its records.'**
  String team_removePoint1(String name, String facility);

  /// Remove dialog, second point.
  ///
  /// In en, this message translates to:
  /// **'What {name} recorded stays in {facility}\'s history.'**
  String team_removePoint2(String name, String facility);

  /// Remove dialog, third point.
  ///
  /// In en, this message translates to:
  /// **'Their account is kept. When they next sign in they can enter an invite code to join a facility again.'**
  String get team_removePoint3;

  /// Reject dialog title.
  ///
  /// In en, this message translates to:
  /// **'Reject {name}?'**
  String team_rejectTitle(String name);

  /// Reject dialog, first point.
  ///
  /// In en, this message translates to:
  /// **'{name} is removed from {facility} and is no longer waiting for approval.'**
  String team_rejectPoint1(String name, String facility);

  /// Reject dialog, second point.
  ///
  /// In en, this message translates to:
  /// **'When they next sign in they\'ll see the request wasn\'t approved, and be asked for an invite code - they can join again with a new one.'**
  String get team_rejectPoint2;

  /// Reject dialog, third point.
  ///
  /// In en, this message translates to:
  /// **'They aren\'t sent a message. Tell them yourself if you\'d like them to know.'**
  String get team_rejectPoint3;

  /// Team screen title.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get team_title;

  /// Team screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your team\'s access and status'**
  String get team_subtitle;

  /// Button, tooltip and dialog title for inviting an assistant.
  ///
  /// In en, this message translates to:
  /// **'Invite Assistant'**
  String get team_inviteAssistant;

  /// Team screen when no admin is signed in.
  ///
  /// In en, this message translates to:
  /// **'No logged in admin user found'**
  String get team_noAdmin;

  /// Team screen when the admin has no facilities.
  ///
  /// In en, this message translates to:
  /// **'No facilities found for your account.'**
  String get team_noFacilities;

  /// Under the Total card.
  ///
  /// In en, this message translates to:
  /// **'Across your facilities'**
  String get team_acrossFacilities;

  /// Under the Active card.
  ///
  /// In en, this message translates to:
  /// **'Have access'**
  String get team_haveAccess;

  /// Under the Deactivated card.
  ///
  /// In en, this message translates to:
  /// **'Access paused'**
  String get team_accessPaused;

  /// Card title: assistants waiting for approval.
  ///
  /// In en, this message translates to:
  /// **'Waiting Approval'**
  String get team_waitingApproval;

  /// Under the Waiting Approval card.
  ///
  /// In en, this message translates to:
  /// **'Need your decision'**
  String get team_needDecision;

  /// Team search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone or facility...'**
  String get team_searchHint;

  /// Team list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No team members yet'**
  String get team_emptyTitle;

  /// Under the empty team list.
  ///
  /// In en, this message translates to:
  /// **'Use Invite Assistant to add your first team member.'**
  String get team_emptyHint;

  /// Team list (cards) when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No assistants yet'**
  String get team_noAssistants;

  /// Team list when the filters match nobody.
  ///
  /// In en, this message translates to:
  /// **'No team members match your filters'**
  String get team_noMatches;

  /// Team table header.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get team_colUserName;

  /// Team table header.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get team_colRole;

  /// Details panel: a date or value that was never saved.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get team_notRecorded;

  /// History: when the account was created.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get team_registered;

  /// Details panel title.
  ///
  /// In en, this message translates to:
  /// **'Team Member Details'**
  String get team_detailsTitle;

  /// Details panel: your own name.
  ///
  /// In en, this message translates to:
  /// **'{name}  (you)'**
  String team_nameYou(String name);

  /// Details panel label.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get team_joined;

  /// Details panel, under Joined.
  ///
  /// In en, this message translates to:
  /// **'Asked to join again: {date}'**
  String team_askedAgain(String date);

  /// Details panel label: when the assistant was approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get team_approvedLabel;

  /// Details panel: not approved yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get team_waitingForApproval;

  /// Details panel: who made a change.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String team_byName(String name);

  /// Details panel: an approval with no date.
  ///
  /// In en, this message translates to:
  /// **'Approved before approvals were recorded'**
  String get team_approvedBeforeRecords;

  /// Details panel label.
  ///
  /// In en, this message translates to:
  /// **'Last status change'**
  String get team_lastStatusChange;

  /// Details panel: who changed the status, with their stored role.
  ///
  /// In en, this message translates to:
  /// **'by {name} ({role})'**
  String team_byNameRole(String name, String role);

  /// Details panel label.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get team_lastActive;

  /// Details panel heading.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get team_history;

  /// One history line: date and who did it.
  ///
  /// In en, this message translates to:
  /// **'{when}  ·  by {name}'**
  String team_historyLine(String when, String name);

  /// Details panel note.
  ///
  /// In en, this message translates to:
  /// **'Use the buttons on this person\'s card to approve, reject or remove them.'**
  String get team_useCardButtons;

  /// Pagination bar when the list is empty.
  ///
  /// In en, this message translates to:
  /// **'No assistants'**
  String get team_noAssistantsPage;

  /// Pagination bar.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1 assistant} other{Showing {start} to {end} of {total} assistants}}'**
  String team_showingRange(int start, int end, int total);

  /// Invite dialog while loading.
  ///
  /// In en, this message translates to:
  /// **'Checking for an existing invite...'**
  String get invite_checking;

  /// Invite dialog error; error is a friendly sentence.
  ///
  /// In en, this message translates to:
  /// **'Could not check for an existing invite: {error}'**
  String invite_checkFailed(String error);

  /// Invite dialog while creating a code.
  ///
  /// In en, this message translates to:
  /// **'Generating your invite code...'**
  String get invite_generating;

  /// Invite dialog error.
  ///
  /// In en, this message translates to:
  /// **'Could not generate an invite: {error}'**
  String invite_generateFailed(String error);

  /// Invite dialog while revoking.
  ///
  /// In en, this message translates to:
  /// **'Revoking the code...'**
  String get invite_revoking;

  /// Invite dialog error.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke: {error}'**
  String invite_revokeFailed(String error);

  /// Invite dialog, above an active code.
  ///
  /// In en, this message translates to:
  /// **'Share this code with the person you\'re hiring - they\'ll enter it when registering as an Assistant.'**
  String get invite_shareHint;

  /// Invite dialog: when the code stops working.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String invite_expires(String date);

  /// Message after copying the code.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get invite_copied;

  /// Button that cancels the active code.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get invite_revoke;

  /// Button that replaces the active code.
  ///
  /// In en, this message translates to:
  /// **'Generate a new one instead'**
  String get invite_generateNew;

  /// Invite dialog when there is no active code.
  ///
  /// In en, this message translates to:
  /// **'Generate a one-time code for the person you\'re hiring - it works for 48 hours or until used once, whichever comes first.'**
  String get invite_generateHint;

  /// Button that creates a code.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Code'**
  String get invite_generate;

  /// Settings screen title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// Settings item that opens Subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription & Billing'**
  String get settings_subscriptionBilling;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Account & Data'**
  String get settings_accountData;

  /// Settings item that opens the export screen.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get settings_exportData;

  /// Settings item and Business Hours screen title.
  ///
  /// In en, this message translates to:
  /// **'Business Hours'**
  String get hours_title;

  /// Settings item and Manage Account screen title.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get account_title;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settings_general;

  /// Settings item and printer screen title.
  ///
  /// In en, this message translates to:
  /// **'Printer & Receipt Settings'**
  String get printer_title;

  /// Settings item and the help dialog title.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settings_helpSupport;

  /// Settings item and the app info dialog title.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get settings_appInfo;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settings_preferences;

  /// Settings item and the UI Settings dialog title.
  ///
  /// In en, this message translates to:
  /// **'UI Settings'**
  String get uiSettings_title;

  /// Beside the UI Settings item.
  ///
  /// In en, this message translates to:
  /// **'Theme & layout'**
  String get settings_themeLayout;

  /// Settings item showing the currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settings_currency;

  /// Settings item for the language; both languages on purpose, so it can be found in either.
  ///
  /// In en, this message translates to:
  /// **'Language / Lugha'**
  String get settings_languageBoth;

  /// Language picker heading; both languages on purpose.
  ///
  /// In en, this message translates to:
  /// **'SELECT LANGUAGE / CHAGUA LUGHA'**
  String get settings_selectLanguageBoth;

  /// Footer of the Settings list.
  ///
  /// In en, this message translates to:
  /// **'{appName} - v{version}'**
  String settings_versionLine(String appName, String version);

  /// Wide Settings screen before anything is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a setting from the left'**
  String get settings_selectPane;

  /// App info dialog label.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get settings_appName;

  /// App info dialog label.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settings_version;

  /// App info dialog label.
  ///
  /// In en, this message translates to:
  /// **'Built For'**
  String get settings_builtFor;

  /// App info dialog value.
  ///
  /// In en, this message translates to:
  /// **'Veterinary & agrovet business management'**
  String get settings_builtForValue;

  /// UI Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'COLOUR THEME'**
  String get uiSettings_colourTheme;

  /// UI Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get uiSettings_appearance;

  /// UI Settings option: System, Light or Dark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get uiSettings_darkMode;

  /// Dark Mode choice: follow the device's own light or dark setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get uiSettings_themeModeSystem;

  /// Dark Mode choice: always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get uiSettings_themeModeLight;

  /// Dark Mode choice: always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get uiSettings_themeModeDark;

  /// UI Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'LAYOUT'**
  String get uiSettings_layout;

  /// UI Settings option.
  ///
  /// In en, this message translates to:
  /// **'Layout Fixed Mode'**
  String get uiSettings_layoutFixed;

  /// Under Layout Fixed Mode.
  ///
  /// In en, this message translates to:
  /// **'Keeps the sidebar open and hides its collapse button on large screens.'**
  String get uiSettings_layoutFixedHint;

  /// UI Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get uiSettings_system;

  /// UI Settings option.
  ///
  /// In en, this message translates to:
  /// **'System Refresh'**
  String get uiSettings_systemRefresh;

  /// Under System Refresh.
  ///
  /// In en, this message translates to:
  /// **'Reloads your data and takes you back to the start. You stay signed in.'**
  String get uiSettings_systemRefreshHint;

  /// Under the UI Settings title.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get uiSettings_savedOnDevice;

  /// System Refresh confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Refresh the app?'**
  String get uiSettings_refreshTitle;

  /// System Refresh confirmation text.
  ///
  /// In en, this message translates to:
  /// **'This reloads your data and takes you back to the start. You stay signed in, but anything you haven\'t saved will be lost.'**
  String get uiSettings_refreshBody;

  /// Colour theme name (id "pasture").
  ///
  /// In en, this message translates to:
  /// **'Pasture'**
  String get uiSettings_themePasture;

  /// Colour theme name (id "clinic").
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get uiSettings_themeClinic;

  /// Colour theme name (id "harvest").
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get uiSettings_themeHarvest;

  /// Colour theme name (id "ledger").
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get uiSettings_themeLedger;

  /// Message after saving.
  ///
  /// In en, this message translates to:
  /// **'Business hours saved'**
  String get hours_saved;

  /// Message when saving failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the business hours'**
  String get hours_saveFailed;

  /// Business Hours screen intro; the quoted names are other screens' English texts until those are translated.
  ///
  /// In en, this message translates to:
  /// **'Sets when the \"Generate Today\'s Report\" button becomes active in View Reports.'**
  String get hours_intro;

  /// Business Hours row title.
  ///
  /// In en, this message translates to:
  /// **'Weekdays (Mon–Fri)'**
  String get hours_weekdays;

  /// Business Hours row title.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get hours_saturday;

  /// Business Hours row title.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get hours_sunday;

  /// Business Hours override switch.
  ///
  /// In en, this message translates to:
  /// **'Allow anytime'**
  String get hours_allowAnytime;

  /// Under the override switch.
  ///
  /// In en, this message translates to:
  /// **'Emergency override - makes the report button active regardless of the schedule above. Turn this on for an early closure, and back off once things return to normal.'**
  String get hours_allowAnytimeHint;

  /// Save button.
  ///
  /// In en, this message translates to:
  /// **'Save Business Hours'**
  String get hours_save;

  /// Switch label on a day row.
  ///
  /// In en, this message translates to:
  /// **'Closed all day'**
  String get hours_closedAllDay;

  /// Button showing the closing time.
  ///
  /// In en, this message translates to:
  /// **'Closes at {time}'**
  String hours_closesAt(String time);

  /// Day row when the day is closed.
  ///
  /// In en, this message translates to:
  /// **'No closing time needed - closed all day.'**
  String get hours_noClosingTime;

  /// Message after uploading a logo.
  ///
  /// In en, this message translates to:
  /// **'Logo updated'**
  String get profile_logoUpdated;

  /// Message when uploading failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the logo'**
  String get profile_logoFailed;

  /// Shown when the facility has no name.
  ///
  /// In en, this message translates to:
  /// **'Your facility'**
  String get profile_yourFacility;

  /// Business Profile screen title.
  ///
  /// In en, this message translates to:
  /// **'Business Profile'**
  String get profile_title;

  /// Under the logo.
  ///
  /// In en, this message translates to:
  /// **'This logo appears on the dashboard, receipts, and anywhere your facility is shown throughout the app.'**
  String get profile_logoHint;

  /// Button when a logo exists.
  ///
  /// In en, this message translates to:
  /// **'Change Logo'**
  String get profile_changeLogo;

  /// Button when there is no logo.
  ///
  /// In en, this message translates to:
  /// **'Upload Logo'**
  String get profile_uploadLogo;

  /// Rebuild dialog title.
  ///
  /// In en, this message translates to:
  /// **'Rebuild Client Search Index'**
  String get searchIndex_title;

  /// Rebuild dialog text.
  ///
  /// In en, this message translates to:
  /// **'This makes clients added before search was available show up correctly when searched by name, and lets the app spot a new client whose phone number or name matches one you already have. It only needs to be run once - clients that are already up to date are left alone.'**
  String get searchIndex_body;

  /// Rebuild result when nothing changed.
  ///
  /// In en, this message translates to:
  /// **'Nothing to update - every client is already searchable.'**
  String get searchIndex_nothing;

  /// Rebuild result.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Done. 1 client updated and now searchable.} other{Done. {count} clients updated and now searchable.}}'**
  String searchIndex_done(int count);

  /// Rebuild error; error is a friendly sentence.
  ///
  /// In en, this message translates to:
  /// **'Could not complete: {error}'**
  String searchIndex_failed(String error);

  /// Button that starts the rebuild.
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get searchIndex_run;

  /// Printer screen when Bluetooth is missing (checking the connection).
  ///
  /// In en, this message translates to:
  /// **'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t connect to a printer from a web browser.'**
  String get printer_unavailableConnect;

  /// Printer screen when Bluetooth is missing (listing devices).
  ///
  /// In en, this message translates to:
  /// **'Bluetooth printing isn\'t available on this platform. This screen needs a real Android or iOS build with Bluetooth hardware - it can\'t list paired devices from a web browser.'**
  String get printer_unavailableList;

  /// Message after connecting a printer.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String printer_connected(String name);

  /// Message when a printer refused to connect.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to {name}'**
  String printer_connectFailedNamed(String name);

  /// Message when connecting failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the printer'**
  String get printer_connectFailed;

  /// Message when disconnecting failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disconnect the printer'**
  String get printer_disconnectFailed;

  /// Message after a test print.
  ///
  /// In en, this message translates to:
  /// **'Test page sent to printer'**
  String get printer_testSent;

  /// Message when the test print failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t print the test page'**
  String get printer_testFailed;

  /// A saved printer with no name.
  ///
  /// In en, this message translates to:
  /// **'Saved printer'**
  String get printer_savedPrinter;

  /// Saved printer status.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get printer_statusConnected;

  /// Saved printer status.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get printer_statusNotConnected;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get printer_disconnect;

  /// Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Forget this printer'**
  String get printer_forget;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Paired Devices'**
  String get printer_paired;

  /// Under Paired Devices.
  ///
  /// In en, this message translates to:
  /// **'Pair your printer in your device\'s Bluetooth settings first - this list only shows devices already paired there.'**
  String get printer_pairHint;

  /// Paired list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No paired devices found.'**
  String get printer_noPaired;

  /// Button that connects a device.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get printer_connect;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Print Options'**
  String get printer_printOptions;

  /// Option label.
  ///
  /// In en, this message translates to:
  /// **'Paper Size'**
  String get printer_paperSize;

  /// Paper size choice; width is the stored size ("58" or "80").
  ///
  /// In en, this message translates to:
  /// **'{width}mm'**
  String printer_paperWidth(String width);

  /// Option label.
  ///
  /// In en, this message translates to:
  /// **'Auto-print receipt after each sale'**
  String get printer_autoPrint;

  /// Test print button while sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get printer_sending;

  /// Test print button.
  ///
  /// In en, this message translates to:
  /// **'Send Test Print'**
  String get printer_sendTest;

  /// Under the test button when nothing is connected.
  ///
  /// In en, this message translates to:
  /// **'Connect a printer above before testing.'**
  String get printer_connectFirst;

  /// Trash tab and export dataset: performed services.
  ///
  /// In en, this message translates to:
  /// **'Service Records'**
  String get common_serviceRecords;

  /// Message after restoring.
  ///
  /// In en, this message translates to:
  /// **'Item restored'**
  String get trash_restored;

  /// Message when restoring failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the item'**
  String get trash_restoreFailed;

  /// Permanent delete confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever?'**
  String get trash_deleteForeverTitle;

  /// Permanent delete confirmation text.
  ///
  /// In en, this message translates to:
  /// **'\"{label}\" will be permanently deleted. This cannot be undone.'**
  String trash_deleteForeverBody(String label);

  /// Button and tooltip that delete an item for good.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get trash_deleteForever;

  /// Message after a permanent delete.
  ///
  /// In en, this message translates to:
  /// **'Permanently deleted'**
  String get trash_deleted;

  /// Message when a permanent delete failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the item permanently'**
  String get trash_deleteFailed;

  /// Trash tab with nothing in it.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trash_empty;

  /// Warning above a Trash tab.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item will be permanently deleted within {days} days. Restore now if you still need it.} other{{count} items will be permanently deleted within {days} days. Restore now if you still need them.}}'**
  String trash_expiringBanner(int count, int days);

  /// Item whose time in Trash is up.
  ///
  /// In en, this message translates to:
  /// **'Deleting soon'**
  String get trash_deletingSoon;

  /// Item deleted for good tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Expires tomorrow'**
  String get trash_expiresTomorrow;

  /// Days until the item is deleted for good.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Expires in 1 day} other{Expires in {count} days}}'**
  String trash_expiresIn(int count);

  /// Who deleted the item (date unknown).
  ///
  /// In en, this message translates to:
  /// **'Deleted by {name}'**
  String trash_deletedBy(String name);

  /// Who deleted the item and when.
  ///
  /// In en, this message translates to:
  /// **'Deleted by {name} on {date}'**
  String trash_deletedByOn(String name, String date);

  /// Export screen title.
  ///
  /// In en, this message translates to:
  /// **'Export Center'**
  String get export_title;

  /// Export section heading.
  ///
  /// In en, this message translates to:
  /// **'1. Select Dataset Category'**
  String get export_step1;

  /// Export section heading.
  ///
  /// In en, this message translates to:
  /// **'2. Scope & Date Range Filtering'**
  String get export_step2;

  /// Export section heading.
  ///
  /// In en, this message translates to:
  /// **'3. Output Document Layout'**
  String get export_step3;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Sales & Transactions'**
  String get export_salesTransactions;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Sales (incl. archived) and transaction history'**
  String get export_salesTransactionsHint;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Services performed (incl. archived), by client and category'**
  String get export_serviceRecordsHint;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Product Inventory Catalog'**
  String get export_productCatalog;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Current stock levels, costs, and SKU list'**
  String get export_productCatalogHint;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Client Directory & Balances'**
  String get export_clientDirectory;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Client contacts and current outstanding balances'**
  String get export_clientDirectoryHint;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Debtors / Outstanding Balances'**
  String get export_debtors;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Itemized list of everything currently owed'**
  String get export_debtorsHint;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Payments Ledger'**
  String get export_paymentsLedger;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Every payment collected - sales, services, debts, other income'**
  String get export_paymentsLedgerHint;

  /// Export dataset name.
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get export_activityLog;

  /// Export dataset description.
  ///
  /// In en, this message translates to:
  /// **'Who did what, and when'**
  String get export_activityLogHint;

  /// Message after an export; dataset is its label.
  ///
  /// In en, this message translates to:
  /// **'Exported {dataset}'**
  String export_done(String dataset);

  /// Message when an export failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export {dataset}'**
  String export_failed(String dataset);

  /// Date picker heading.
  ///
  /// In en, this message translates to:
  /// **'Select Start Date'**
  String get export_selectStart;

  /// Date picker heading.
  ///
  /// In en, this message translates to:
  /// **'Select End Date'**
  String get export_selectEnd;

  /// Date range dialog title.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get export_dateRange;

  /// Date range choice.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get export_last7;

  /// Date range choice.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get export_last30;

  /// Date range choice.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get export_lastMonth;

  /// Date range choice.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get export_thisYear;

  /// Date range choice: no dates.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get export_allTime;

  /// Date range choice that opens the date pickers.
  ///
  /// In en, this message translates to:
  /// **'Custom Range...'**
  String get export_customRange;

  /// Date scope for datasets without dates.
  ///
  /// In en, this message translates to:
  /// **'Not applicable - this is a current snapshot'**
  String get export_notApplicable;

  /// Date scope before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Please select a date range below'**
  String get export_pickRange;

  /// Date scope when All Time is chosen.
  ///
  /// In en, this message translates to:
  /// **'All Records (No Filters Applied)'**
  String get export_allRecords;

  /// Date scope: the chosen dates.
  ///
  /// In en, this message translates to:
  /// **'{start}  to  {end}'**
  String export_rangeLine(String start, String end);

  /// Date scope label.
  ///
  /// In en, this message translates to:
  /// **'Date Selection Scope'**
  String get export_scope;

  /// Button that opens the date range dialog.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get export_modify;

  /// File format choice.
  ///
  /// In en, this message translates to:
  /// **'Excel Workbook (.xlsx)'**
  String get export_xlsx;

  /// File format description.
  ///
  /// In en, this message translates to:
  /// **'Bolded headers, multiple sheets, real dates - opens clean, ready to keep'**
  String get export_xlsxHint;

  /// File format choice.
  ///
  /// In en, this message translates to:
  /// **'CSV (Plain Text)'**
  String get export_csv;

  /// File format description.
  ///
  /// In en, this message translates to:
  /// **'Universal, simple text - opens in Excel, Sheets, or any editor'**
  String get export_csvHint;

  /// Under the export button with no dates chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a date range above before exporting.'**
  String get export_pickRangeFirst;

  /// Message when exporting with no dates chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a date range before exporting'**
  String get export_pickRangeWarning;

  /// Export button.
  ///
  /// In en, this message translates to:
  /// **'Generate & Export Data'**
  String get export_generate;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Log Out of All Devices?'**
  String get account_logoutAllTitle;

  /// Confirmation text.
  ///
  /// In en, this message translates to:
  /// **'This will clear active sessions and log you out on all other phones, tablets, or computers currently signed into your account.'**
  String get account_logoutAllBody;

  /// Confirm button.
  ///
  /// In en, this message translates to:
  /// **'Log Out Everywhere'**
  String get account_logoutEverywhere;

  /// Message when signing out elsewhere failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear other sessions'**
  String get account_logoutAllFailed;

  /// Stands in for a missing facility name.
  ///
  /// In en, this message translates to:
  /// **'this facility'**
  String get account_thisFacility;

  /// Wipe confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Wipe All Data?'**
  String get account_wipeTitle;

  /// Wipe confirmation, first line.
  ///
  /// In en, this message translates to:
  /// **'Business data for \"{facility}\" will be permanently wiped.'**
  String account_wipeFacility(String facility);

  /// Wipe confirmation text.
  ///
  /// In en, this message translates to:
  /// **'All records of sales, products, clients, and transactions for this facility are erased. Other facilities you have are not affected. Your login credentials remain unaffected.'**
  String get account_wipeBody;

  /// Wipe confirm button.
  ///
  /// In en, this message translates to:
  /// **'Wipe Data'**
  String get account_wipe;

  /// Typed confirmation title before a wipe.
  ///
  /// In en, this message translates to:
  /// **'Confirm Action'**
  String get account_confirmTitle;

  /// Typed confirmation; word is the English word that must be typed.
  ///
  /// In en, this message translates to:
  /// **'Please type \"{word}\" to finalize clearing all records:'**
  String account_typeErase(String word);

  /// Message after a wipe.
  ///
  /// In en, this message translates to:
  /// **'All business data permanently wiped'**
  String get account_wiped;

  /// Message when a wipe failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear the records'**
  String get account_wipeFailed;

  /// Dialog title for a Platform Admin account.
  ///
  /// In en, this message translates to:
  /// **'Cannot Deactivate'**
  String get account_cannotDeactivateTitle;

  /// Dialog text for a Platform Admin account.
  ///
  /// In en, this message translates to:
  /// **'This account has Platform Admin access, so it can\'t be deactivated - not by you, and not by anyone else. This keeps the platform from ever being locked out of its own oversight tools.'**
  String get account_cannotDeactivateBody;

  /// Dialog title and Manage Account item.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Account'**
  String get account_deactivateTitle;

  /// Deactivate confirmation text.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate your account? You\'ll be signed out immediately, and will need your facility admin (or Platform Admin) to reactivate it before you can sign back in.'**
  String get account_deactivateBody;

  /// Typed confirmation title before deactivating.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deactivation'**
  String get account_confirmDeactivation;

  /// Typed confirmation; word is the English word that must be typed.
  ///
  /// In en, this message translates to:
  /// **'Type \"{word}\" to confirm:'**
  String account_typeToConfirm(String word);

  /// Shown on the sign-in screen after deactivating.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deactivated.'**
  String get account_deactivated;

  /// Message when deactivating failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t deactivate the account'**
  String get account_deactivateFailed;

  /// Dialog title, button and Manage Account item.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get account_deleteTitle;

  /// Delete account dialog text.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account is permanent and cannot be undone. All your data will be erased.'**
  String get account_deleteWarning;

  /// Message after deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted'**
  String get account_deleted;

  /// Message when deleting failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account'**
  String get account_deleteFailed;

  /// Delete Account item while checking whether it is allowed.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get account_checking;

  /// Delete Account item for a Platform Admin.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin accounts can\'t be deleted from here.'**
  String get account_platformAdminNoDelete;

  /// Delete Account item for an owner; "View Facilities" is the screen's English name until it is translated.
  ///
  /// In en, this message translates to:
  /// **'Delete all facilities you own in View Facilities first.'**
  String get account_deleteOwnedFirst;

  /// Delete Account item.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account. This action cannot be undone.'**
  String get account_deleteHint;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get account_dangerZone;

  /// Under Danger Zone.
  ///
  /// In en, this message translates to:
  /// **'These actions affect your account and business data. Review carefully before proceeding.'**
  String get account_dangerHint;

  /// Manage Account item.
  ///
  /// In en, this message translates to:
  /// **'Log Out of All Devices'**
  String get account_logoutAll;

  /// Under Log Out of All Devices.
  ///
  /// In en, this message translates to:
  /// **'Disconnect your active profile session from all other active platforms.'**
  String get account_logoutAllHint;

  /// Manage Account item.
  ///
  /// In en, this message translates to:
  /// **'Wipe All Business Data'**
  String get account_wipeAll;

  /// Under Wipe All Business Data while it runs.
  ///
  /// In en, this message translates to:
  /// **'Erase in progress - please wait, this may take a moment...'**
  String get account_wipeInProgress;

  /// Under Wipe All Business Data.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete records of transactions, sales, and products while keeping your log in profile.'**
  String get account_wipeHint;

  /// Under Deactivate Account.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disable your account. Can be reactivated later.'**
  String get account_deactivateHint;

  /// Shown in place of a client name when a record has none.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get common_walkIn;

  /// Banner when new services arrived while the list was open.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new service available} other{{count} new services available}}'**
  String services_newRecords(int count);

  /// Services list, empty.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get services_empty;

  /// Services list, empty after a search or filter.
  ///
  /// In en, this message translates to:
  /// **'No services match your filters'**
  String get services_emptyFiltered;

  /// Services metric card.
  ///
  /// In en, this message translates to:
  /// **'Total Services'**
  String get services_totalServices;

  /// Services metric card and the details panel.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount'**
  String get services_paidAmount;

  /// Services metric card: everything not paid in cash.
  ///
  /// In en, this message translates to:
  /// **'Digital Payments'**
  String get services_digitalPayments;

  /// Under each services metric card, and a date filter choice.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get services_last30;

  /// Services date filter choice.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get services_last7;

  /// Services date filter choice.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get services_thisMonth;

  /// Under the Service Records title.
  ///
  /// In en, this message translates to:
  /// **'Track all services provided to your clients'**
  String get services_subtitle;

  /// Button that opens the visit form, and the form's title for a new visit.
  ///
  /// In en, this message translates to:
  /// **'Record Visit'**
  String get services_recordVisit;

  /// Button that opens the services archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get services_archive;

  /// Search box on the services list and archive.
  ///
  /// In en, this message translates to:
  /// **'Search service by client, category, note...'**
  String get services_searchHint;

  /// Services table column.
  ///
  /// In en, this message translates to:
  /// **'Service / Category'**
  String get services_colServiceCategory;

  /// Services table column: who provided the service.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get services_colProvider;

  /// Pagination bar when the list is empty.
  ///
  /// In en, this message translates to:
  /// **'No services'**
  String get services_none;

  /// Message after deleting a service.
  ///
  /// In en, this message translates to:
  /// **'Service moved to Trash'**
  String get services_movedToTrash;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the service'**
  String get services_deleteFailed;

  /// Details panel title.
  ///
  /// In en, this message translates to:
  /// **'Service Details'**
  String get services_detailsTitle;

  /// Details panel section.
  ///
  /// In en, this message translates to:
  /// **'Payment Information'**
  String get services_paymentInfo;

  /// Details panel row: the mobile money or bank reference.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get services_transactionId;

  /// Details panel row.
  ///
  /// In en, this message translates to:
  /// **'Paid On'**
  String get services_paidOn;

  /// Who provided the service (details panel, visit form).
  ///
  /// In en, this message translates to:
  /// **'Provided By'**
  String get services_providedBy;

  /// Details panel row and visit form field.
  ///
  /// In en, this message translates to:
  /// **'Service Date'**
  String get services_serviceDate;

  /// Details panel row.
  ///
  /// In en, this message translates to:
  /// **'Created On'**
  String get services_createdOn;

  /// Shown when an archived service has no name.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get services_fallbackName;

  /// Archive screen title.
  ///
  /// In en, this message translates to:
  /// **'Services Archive'**
  String get services_archiveTitle;

  /// Under the archive title.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Services archived after 1 day} other{Services archived after {days} days}}'**
  String services_archiveSubtitle(int days);

  /// Archive, empty.
  ///
  /// In en, this message translates to:
  /// **'No archived services found'**
  String get services_archiveEmpty;

  /// Archive, empty.
  ///
  /// In en, this message translates to:
  /// **'Try a different search, category, or date range'**
  String get services_archiveEmptyHint;

  /// Archive banner with the chosen dates.
  ///
  /// In en, this message translates to:
  /// **'Period: {start} – {end}'**
  String services_archivePeriod(String start, String end);

  /// Archive banner with no dates chosen.
  ///
  /// In en, this message translates to:
  /// **'Archived services'**
  String get services_archivedServices;

  /// Archive banner: how many match.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 found} other{{count} found}}'**
  String services_foundCount(int count);

  /// Archive pagination; more is "+" when more can be loaded, else empty.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1{more} service} other{Showing {start} to {end} of {total}{more} services}}'**
  String services_archiveShowing(int start, int end, int total, String more);

  /// Archive pagination.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String services_pageOf(int page, int total);

  /// Archive row: the service's notes.
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String services_notesValue(String notes);

  /// Archive search dialog title.
  ///
  /// In en, this message translates to:
  /// **'Search Archived Services'**
  String get services_searchArchiveTitle;

  /// Archive search dialog.
  ///
  /// In en, this message translates to:
  /// **'Search By:'**
  String get services_searchBy;

  /// Archive search dialog choice.
  ///
  /// In en, this message translates to:
  /// **'Specific Month'**
  String get services_specificMonth;

  /// Archive search dialog.
  ///
  /// In en, this message translates to:
  /// **'Only services before {date} have reached the archive.'**
  String services_archiveCutoffNote(String date);

  /// Archive search dialog.
  ///
  /// In en, this message translates to:
  /// **'Select Month:'**
  String get services_selectMonth;

  /// Visit form title when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit Visit'**
  String get services_editVisit;

  /// Visit form field label.
  ///
  /// In en, this message translates to:
  /// **'Select Client *'**
  String get services_selectClientRequired;

  /// Visit form client field.
  ///
  /// In en, this message translates to:
  /// **'Search or select client...'**
  String get services_clientSearchHint;

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Please select a client'**
  String get services_errSelectClient;

  /// Tooltip on the visit form's add-client button.
  ///
  /// In en, this message translates to:
  /// **'Add New Client'**
  String get services_addNewClient;

  /// Visit form section.
  ///
  /// In en, this message translates to:
  /// **'Visit Details'**
  String get services_visitDetails;

  /// Visit form field.
  ///
  /// In en, this message translates to:
  /// **'Service Name'**
  String get services_serviceName;

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Enter service name'**
  String get services_errServiceName;

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Enter provider'**
  String get services_errProvider;

  /// Visit form section: items used during the visit.
  ///
  /// In en, this message translates to:
  /// **'Expenses (Items Used)'**
  String get services_itemsUsed;

  /// Visit form button.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get services_addItem;

  /// Visit form field.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get services_itemName;

  /// Visit form validation for an item.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get services_errItemName;

  /// Visit form, under an item name with no product match.
  ///
  /// In en, this message translates to:
  /// **'No matching product - will be recorded as a plain expense.'**
  String get services_noMatchingProduct;

  /// Visit form product suggestion; unit is the product unit label.
  ///
  /// In en, this message translates to:
  /// **'Sellable: {quantity} {unit}'**
  String services_sellableQty(String quantity, String unit);

  /// Visit form, under an item matched to a product.
  ///
  /// In en, this message translates to:
  /// **'In stock - will deduct, no expense recorded'**
  String get services_inStockDeduct;

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Enter price'**
  String get services_errPrice;

  /// Visit form; amount is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'Total Items Cost: {amount}'**
  String services_totalItemsCost(String amount);

  /// Visit form section.
  ///
  /// In en, this message translates to:
  /// **'Visit Summary'**
  String get services_visitSummary;

  /// Visit form field label.
  ///
  /// In en, this message translates to:
  /// **'Total Amount ({currency}) *'**
  String services_totalAmountRequired(String currency);

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Enter total amount'**
  String get services_errTotalAmount;

  /// Visit form field label.
  ///
  /// In en, this message translates to:
  /// **'Total Paid ({currency}) *'**
  String services_totalPaidRequired(String currency);

  /// Visit form validation.
  ///
  /// In en, this message translates to:
  /// **'Enter paid amount'**
  String get services_errPaidAmount;

  /// Visit form field for non-cash payments.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID (optional)'**
  String get services_transactionIdOptional;

  /// Visit form warning.
  ///
  /// In en, this message translates to:
  /// **'Total Paid cannot exceed Total Amount'**
  String get services_errPaidOverTotal;

  /// Message after saving an edit.
  ///
  /// In en, this message translates to:
  /// **'Service updated'**
  String get services_updated;

  /// Message after recording a visit.
  ///
  /// In en, this message translates to:
  /// **'Service added'**
  String get services_added;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the service'**
  String get services_saveFailed;

  /// Visit form save button when editing.
  ///
  /// In en, this message translates to:
  /// **'Update Visit'**
  String get services_updateVisit;

  /// Visit form client search, no results.
  ///
  /// In en, this message translates to:
  /// **'No client found'**
  String get services_noClientFound;

  /// Error message on the receipt preview.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the receipt'**
  String get receipt_shareFailed;

  /// Error message on the receipt preview.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the PDF'**
  String get receipt_pdfFailed;

  /// Receipt preview screen title.
  ///
  /// In en, this message translates to:
  /// **'Receipt Preview'**
  String get receipt_previewTitle;

  /// Receipt format choice: thermal printer.
  ///
  /// In en, this message translates to:
  /// **'Receipt (Thermal)'**
  String get receipt_formatThermal;

  /// Receipt format choice: A4 page.
  ///
  /// In en, this message translates to:
  /// **'A4 Format'**
  String get receipt_formatA4;

  /// Receipt preview button.
  ///
  /// In en, this message translates to:
  /// **'Share / Save'**
  String get receipt_shareSave;

  /// Receipt preview side panel title.
  ///
  /// In en, this message translates to:
  /// **'Receipt Details'**
  String get receipt_details;

  /// Receipt preview side panel row.
  ///
  /// In en, this message translates to:
  /// **'Receipt Number'**
  String get receipt_number;

  /// Receipt preview side panel row.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get receipt_customer;

  /// Receipt preview side panel section.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get receipt_quickActions;

  /// Receipt preview side panel note.
  ///
  /// In en, this message translates to:
  /// **'This receipt shows the final amount paid for the selected transaction. You can print or share it for your records.'**
  String get receipt_infoNote;

  /// Receipt preview side panel status.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get receipt_statusPartiallyPaid;

  /// Receipt preview side panel status.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get receipt_statusBalanceDue;

  /// Receipt preview side panel status.
  ///
  /// In en, this message translates to:
  /// **'Paid in Full'**
  String get receipt_statusPaidInFull;

  /// Shown when a value is missing (not applicable).
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get common_notApplicable;

  /// Past Reports time filter choice.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get reports_thisYear;

  /// Past Reports screen title and the button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Past Reports'**
  String get reports_pastTitle;

  /// Under the Past Reports title.
  ///
  /// In en, this message translates to:
  /// **'Every daily closing report for this facility'**
  String get reports_pastSubtitle;

  /// Past Reports, empty.
  ///
  /// In en, this message translates to:
  /// **'No reports generated yet.'**
  String get reports_noneYet;

  /// Past Reports, empty after a search.
  ///
  /// In en, this message translates to:
  /// **'No reports match your search.'**
  String get reports_noMatch;

  /// Button under the Past Reports list.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get reports_loadMore;

  /// Past Reports search box.
  ///
  /// In en, this message translates to:
  /// **'Search reports...'**
  String get reports_searchHint;

  /// Past Reports summary stat.
  ///
  /// In en, this message translates to:
  /// **'Reports generated'**
  String get reports_generatedCount;

  /// Past Reports summary stat.
  ///
  /// In en, this message translates to:
  /// **'Loaded period'**
  String get reports_loadedPeriod;

  /// Past Reports summary stat: date of the latest report.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get reports_latest;

  /// Past Reports row; amount is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{amount} total revenue - generated by {name}'**
  String reports_rowSummary(String amount, String name);

  /// Past Reports row badge for a draft.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get reports_notSubmitted;

  /// Past Reports row badge for a submitted report.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get reports_completed;

  /// Report header.
  ///
  /// In en, this message translates to:
  /// **'Submitted by {name}'**
  String reports_submittedBy(String name);

  /// Report header and status for a draft.
  ///
  /// In en, this message translates to:
  /// **'Draft - not yet submitted'**
  String get reports_draftNotSubmitted;

  /// Button that prints or downloads the report PDF.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get reports_pdf;

  /// Full report dialog title.
  ///
  /// In en, this message translates to:
  /// **'Full Report'**
  String get reports_fullReport;

  /// Full report heading.
  ///
  /// In en, this message translates to:
  /// **'Daily Closing Report'**
  String get reports_dailyClosingReport;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Daily Summary'**
  String get reports_dailySummary;

  /// Report stat.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get reports_totalSales;

  /// Report stat.
  ///
  /// In en, this message translates to:
  /// **'Service Revenue'**
  String get reports_serviceRevenue;

  /// Report stat.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get reports_totalRevenue;

  /// Report stat.
  ///
  /// In en, this message translates to:
  /// **'New Debt Today'**
  String get reports_newDebtToday;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded today.'**
  String get reports_noSalesToday;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Veterinary Services'**
  String get reports_vetServices;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No services provided today.'**
  String get reports_noServicesToday;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Product Movement'**
  String get reports_productMovement;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No product movement today.'**
  String get reports_noMovementToday;

  /// Full report product line; unit is the product unit label.
  ///
  /// In en, this message translates to:
  /// **'Sold: {sold} {unit}  |  Closing: {closing} {unit}'**
  String reports_movementLine(int sold, int closing, String unit);

  /// Full report product line with an adjustment (adjustment carries its sign).
  ///
  /// In en, this message translates to:
  /// **'Sold: {sold} {unit}  |  Adjusted: {adjustment} {unit}  |  Closing: {closing} {unit}'**
  String reports_movementLineAdjusted(
    int sold,
    String adjustment,
    int closing,
    String unit,
  );

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Expected vs Physical Stock'**
  String get reports_expectedVsPhysical;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No watch-listed products for this facility.'**
  String get reports_noWatchlisted;

  /// Report, stock section of a draft.
  ///
  /// In en, this message translates to:
  /// **'Physical counts have not been submitted yet.'**
  String get reports_countsNotSubmitted;

  /// Full report stock line; physical is "-" when not counted.
  ///
  /// In en, this message translates to:
  /// **'Expected: {expected}  |  Physical: {physical}'**
  String reports_expectedPhysical(int expected, String physical);

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Debt Activity'**
  String get reports_debtActivity;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No debt activity today.'**
  String get reports_noDebtActivity;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Expenses Recorded'**
  String get reports_expensesRecorded;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded today.'**
  String get reports_noExpensesToday;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Payment Reconciliation'**
  String get reports_paymentReconciliation;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded today.'**
  String get reports_noPaymentsToday;

  /// Payment reconciliation row.
  ///
  /// In en, this message translates to:
  /// **'Expected balance'**
  String get reports_expectedBalance;

  /// Payment reconciliation row.
  ///
  /// In en, this message translates to:
  /// **'Physical balance counted'**
  String get reports_physicalBalance;

  /// Reconciliation row and status.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get reports_variance;

  /// Full report reconciliation; amount is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{amount} - VARIANCE'**
  String reports_varianceValue(String amount);

  /// Full report reconciliation; amount is pre-formatted.
  ///
  /// In en, this message translates to:
  /// **'{amount} - Match'**
  String reports_matchValue(String amount);

  /// Reconciliation row: the reason for a variance.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reports_reason;

  /// Full report reconciliation; method is the payment method label.
  ///
  /// In en, this message translates to:
  /// **'No income via {method} today - outflow only, no count needed.'**
  String reports_outflowOnly(String method);

  /// Full report reconciliation of a draft.
  ///
  /// In en, this message translates to:
  /// **'Not yet submitted.'**
  String get reports_notYetSubmitted;

  /// Report section and tab.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get reports_paymentMethods;

  /// Payment methods, empty category.
  ///
  /// In en, this message translates to:
  /// **'No sales today.'**
  String get reports_noSalesShort;

  /// Payment methods, empty category.
  ///
  /// In en, this message translates to:
  /// **'No services today.'**
  String get reports_noServicesShort;

  /// Payment methods, empty category.
  ///
  /// In en, this message translates to:
  /// **'No repayments today.'**
  String get reports_noRepaymentsShort;

  /// Payment methods, empty category.
  ///
  /// In en, this message translates to:
  /// **'No other income today.'**
  String get reports_noOtherIncomeShort;

  /// Report section.
  ///
  /// In en, this message translates to:
  /// **'Daily Closing Declaration'**
  String get reports_declaration;

  /// Declaration of a submitted report.
  ///
  /// In en, this message translates to:
  /// **'Confirmed - I have reviewed today\'s transactions and that the cash and stock figures entered represent the closing figures for my shift.'**
  String get reports_declarationConfirmed;

  /// Declaration of a draft.
  ///
  /// In en, this message translates to:
  /// **'Not yet confirmed.'**
  String get reports_notConfirmed;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit the report'**
  String get reports_submitFailed;

  /// Review dialog title.
  ///
  /// In en, this message translates to:
  /// **'Review & Submit'**
  String get reports_reviewSubmit;

  /// Review dialog intro.
  ///
  /// In en, this message translates to:
  /// **'Sales, services, transactions, and debt activity have already been calculated automatically. Count the items below and enter what you actually find before submitting.'**
  String get reports_reviewIntro;

  /// Review dialog section.
  ///
  /// In en, this message translates to:
  /// **'Physical Stock Count'**
  String get reports_physicalStockCount;

  /// Review dialog stock section.
  ///
  /// In en, this message translates to:
  /// **'Watch-listed products only - count these before submitting.'**
  String get reports_watchlistedHint;

  /// Review dialog: the expected closing count.
  ///
  /// In en, this message translates to:
  /// **'Expected: {count}'**
  String reports_expectedValue(int count);

  /// Review dialog count field hint.
  ///
  /// In en, this message translates to:
  /// **'Physical count'**
  String get reports_physicalCount;

  /// Review dialog; variance carries its sign.
  ///
  /// In en, this message translates to:
  /// **'{variance} variance'**
  String reports_varianceCount(String variance);

  /// Count matches the expected value.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get reports_match;

  /// Review dialog field hint.
  ///
  /// In en, this message translates to:
  /// **'Reason for variance (e.g. damaged, unable to locate)'**
  String get reports_varianceReasonHint;

  /// Review dialog validation.
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason for the variance.'**
  String get reports_errVarianceReason;

  /// Review dialog payment section.
  ///
  /// In en, this message translates to:
  /// **'Count what you actually have for each method used today - mobile money balance, bank balance, and cash in the drawer.'**
  String get reports_countEachMethod;

  /// Review dialog, a method with only outflow.
  ///
  /// In en, this message translates to:
  /// **'Amount paid out'**
  String get reports_amountPaidOut;

  /// Review dialog; method is the payment method label.
  ///
  /// In en, this message translates to:
  /// **'No income came in via {method} today - just an outflow. No physical count needed here.'**
  String reports_noIncomeVia(String method);

  /// Review dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Physical balance counted *'**
  String get reports_physicalBalanceRequired;

  /// Review dialog; amount is pre-formatted with its sign.
  ///
  /// In en, this message translates to:
  /// **'{method} variance: {amount}'**
  String reports_methodVariance(String method, String amount);

  /// Review dialog field hint.
  ///
  /// In en, this message translates to:
  /// **'Reason for {method} variance'**
  String reports_methodVarianceReason(String method);

  /// Review dialog.
  ///
  /// In en, this message translates to:
  /// **'{method} matches'**
  String reports_methodMatches(String method);

  /// Review dialog declaration checkbox.
  ///
  /// In en, this message translates to:
  /// **'I confirm that I have reviewed today\'s transactions and that the cash and stock figures entered above represent the closing figures for my shift.'**
  String get reports_confirmDeclaration;

  /// Review dialog: why Submit is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enter a physical count for every watch-listed product'**
  String get reports_blockedCounts;

  /// Review dialog: why Submit is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enter the physical balance for every payment method'**
  String get reports_blockedBalances;

  /// Review dialog: why Submit is disabled.
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason for the variance found'**
  String get reports_blockedReason;

  /// Review dialog: why Submit is disabled.
  ///
  /// In en, this message translates to:
  /// **'Confirm the closing declaration to submit'**
  String get reports_blockedDeclaration;

  /// Review dialog submit button.
  ///
  /// In en, this message translates to:
  /// **'Submit Daily Closing'**
  String get reports_submitDailyClosing;

  /// Report tab.
  ///
  /// In en, this message translates to:
  /// **'Stock Reconciliation'**
  String get reports_tabStock;

  /// Report tab.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get reports_tabDebt;

  /// Report tab.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get reports_tabProducts;

  /// Report summary tile.
  ///
  /// In en, this message translates to:
  /// **'Outstanding New Debt'**
  String get reports_outstandingNewDebt;

  /// Report summary tile.
  ///
  /// In en, this message translates to:
  /// **'Services Performed'**
  String get reports_servicesPerformed;

  /// Report summary tile.
  ///
  /// In en, this message translates to:
  /// **'Products Sold'**
  String get reports_productsSold;

  /// Report summary tile: units sold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}}'**
  String reports_unitsCount(int count);

  /// Report summary tile.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue Today'**
  String get reports_totalRevenueToday;

  /// Report summary footer.
  ///
  /// In en, this message translates to:
  /// **'Generated at {time} by {name}'**
  String reports_generatedAtBy(String time, String name);

  /// Report summary footer.
  ///
  /// In en, this message translates to:
  /// **'Submitted at {time}'**
  String reports_submittedAt(String time);

  /// Report product preview.
  ///
  /// In en, this message translates to:
  /// **'Sold: {count}'**
  String reports_soldCount(int count);

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reports_colTime;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get reports_colReceipt;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get reports_colItems;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get reports_colPayment;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get reports_colService;

  /// Report table column: how many times.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get reports_colNumber;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reports_colRevenue;

  /// Report total row.
  ///
  /// In en, this message translates to:
  /// **'Total Service Revenue'**
  String get reports_totalServiceRevenue;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get reports_colProduct;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get reports_colUnit;

  /// Report table column: opening amount.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get reports_colOpening;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get reports_colAdded;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Adjusted'**
  String get reports_colAdjusted;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get reports_colSold;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Expected Closing'**
  String get reports_colExpectedClosing;

  /// Report total row.
  ///
  /// In en, this message translates to:
  /// **'Total Units Sold'**
  String get reports_totalUnitsSold;

  /// Report products tab note.
  ///
  /// In en, this message translates to:
  /// **'System-tracked - only products with movement today, or watch-listed products, are shown.'**
  String get reports_systemTracked;

  /// Report stock tab note.
  ///
  /// In en, this message translates to:
  /// **'Watch-listed products only.'**
  String get reports_watchlistedOnly;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get reports_colExpected;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Physical'**
  String get reports_colPhysical;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get reports_colDifference;

  /// Report stock row.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reports_reasonValue(String reason);

  /// Report debt tab row.
  ///
  /// In en, this message translates to:
  /// **'New debt today'**
  String get reports_newDebtTodayLower;

  /// Report debt tab row.
  ///
  /// In en, this message translates to:
  /// **'Repayments collected'**
  String get reports_repaymentsCollected;

  /// Report debt tab row.
  ///
  /// In en, this message translates to:
  /// **'Outstanding change'**
  String get reports_outstandingChange;

  /// Report debt tab section.
  ///
  /// In en, this message translates to:
  /// **'By Customer'**
  String get reports_byCustomer;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'New Debt'**
  String get reports_colNewDebt;

  /// Report table column.
  ///
  /// In en, this message translates to:
  /// **'Repayment'**
  String get reports_colRepayment;

  /// Report table column: closing amount.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get reports_colClosing;

  /// Report total row.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get reports_totalExpenses;

  /// Report transactions tab section.
  ///
  /// In en, this message translates to:
  /// **'All Transactions'**
  String get reports_allTransactions;

  /// Report transactions tab note.
  ///
  /// In en, this message translates to:
  /// **'Income and expenses recorded directly, separate from sales and service revenue.'**
  String get reports_transactionsNote;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded today.'**
  String get reports_noTransactionsToday;

  /// Report activity tab note.
  ///
  /// In en, this message translates to:
  /// **'Everything recorded today, in order.'**
  String get reports_everythingToday;

  /// Report activity tab of an assistant's draft.
  ///
  /// In en, this message translates to:
  /// **'Not included - this draft was generated by an assistant, who can only see their own activity. Delete the draft and generate it again for the full log.'**
  String get reports_activityNotIncluded;

  /// Report, empty section.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded today.'**
  String get reports_noActivityToday;

  /// Report activity tab when the report has no stored activity log (made before the log moved to its own admin-only record).
  ///
  /// In en, this message translates to:
  /// **'No activity log was saved with this report.'**
  String get reports_activityLogNotSaved;

  /// Report activity table column: who did it.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get reports_colBy;

  /// Report payment methods tab section.
  ///
  /// In en, this message translates to:
  /// **'Combined - All Payment Methods'**
  String get reports_combinedAll;

  /// Report payment methods tab note.
  ///
  /// In en, this message translates to:
  /// **'Sales, services, debt repayments, and other income together, by how it was actually received.'**
  String get reports_combinedNote;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the report'**
  String get reports_generateFailed;

  /// Delete draft dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft?'**
  String get reports_deleteDraftTitle;

  /// Delete draft dialog body.
  ///
  /// In en, this message translates to:
  /// **'This clears today\'s draft report so it can be regenerated from scratch. It doesn\'t affect any of the underlying sales, services, or transactions - only this working snapshot.'**
  String get reports_deleteDraftBody;

  /// Delete draft button and action.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft'**
  String get reports_deleteDraft;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the draft'**
  String get reports_deleteDraftFailed;

  /// Error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the report'**
  String get reports_shareFailed;

  /// Reports screen title.
  ///
  /// In en, this message translates to:
  /// **'View Reports'**
  String get reports_viewTitle;

  /// Under the reports screen title.
  ///
  /// In en, this message translates to:
  /// **'Daily closing report for this facility'**
  String get reports_viewSubtitle;

  /// Reports screen button when today's report is submitted.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Report - Submitted'**
  String get reports_todaySubmitted;

  /// Reports screen button for a draft.
  ///
  /// In en, this message translates to:
  /// **'Continue Closing'**
  String get reports_continueClosing;

  /// Reports screen button.
  ///
  /// In en, this message translates to:
  /// **'Generate Today\'s Report'**
  String get reports_generateToday;

  /// Reports screen button, facility closed all day.
  ///
  /// In en, this message translates to:
  /// **'Generate Today\'s Report (closed today)'**
  String get reports_generateClosedToday;

  /// Reports screen button before closing time.
  ///
  /// In en, this message translates to:
  /// **'Generate Today\'s Report (at {time})'**
  String reports_generateAt(String time);

  /// Reports screen button, no closing time set.
  ///
  /// In en, this message translates to:
  /// **'Generate Today\'s Report (after closing time)'**
  String get reports_generateAfterClosing;

  /// Reports screen, no report yet.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Generate Today\'s Report\" above to get started.'**
  String get reports_tapGenerate;

  /// Reports screen, no report yet.
  ///
  /// In en, this message translates to:
  /// **'This facility is marked closed today.'**
  String get reports_closedToday;

  /// Reports screen, no report yet.
  ///
  /// In en, this message translates to:
  /// **'Available at {time}.'**
  String reports_availableAt(String time);

  /// Reports screen, no report yet.
  ///
  /// In en, this message translates to:
  /// **'Available once today\'s closing time is reached.'**
  String get reports_availableOnceClosing;

  /// Reports screen, no report yet.
  ///
  /// In en, this message translates to:
  /// **'No report generated yet today'**
  String get reports_noneToday;

  /// Reports screen heading.
  ///
  /// In en, this message translates to:
  /// **'Daily Closing Report - Today\'s Report'**
  String get reports_todayHeading;

  /// Quick action.
  ///
  /// In en, this message translates to:
  /// **'View Full Report'**
  String get reports_viewFull;

  /// Quick action subtitle.
  ///
  /// In en, this message translates to:
  /// **'See all sections in detail'**
  String get reports_viewFullHint;

  /// Quick action.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get reports_downloadPdf;

  /// Quick action subtitle.
  ///
  /// In en, this message translates to:
  /// **'Get a printable report'**
  String get reports_downloadPdfHint;

  /// Quick action subtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear today\'s draft to restart'**
  String get reports_deleteDraftHint;

  /// Quick action.
  ///
  /// In en, this message translates to:
  /// **'Share with Admin'**
  String get reports_shareWithAdmin;

  /// Quick action subtitle.
  ///
  /// In en, this message translates to:
  /// **'Send report to your admin'**
  String get reports_shareWithAdminHint;

  /// Reports screen panel.
  ///
  /// In en, this message translates to:
  /// **'Accountability'**
  String get reports_accountability;

  /// Accountability row label.
  ///
  /// In en, this message translates to:
  /// **'Submitted by'**
  String get reports_submittedByLabel;

  /// Declaration panel of a draft.
  ///
  /// In en, this message translates to:
  /// **'This declaration is confirmed as part of Submit Daily Closing, once physical stock and cash counts have been entered.'**
  String get reports_declarationPending;

  /// Declaration panel note.
  ///
  /// In en, this message translates to:
  /// **'The report will be saved in the system and available for you and the admin to view or download at any time.'**
  String get reports_savedNote;

  /// Message after adding a batch that matched an existing one.
  ///
  /// In en, this message translates to:
  /// **'Added to the existing batch with this number and expiry'**
  String get batch_mergedIntoExisting;

  /// Message after adding a new batch.
  ///
  /// In en, this message translates to:
  /// **'New batch added'**
  String get batch_added;

  /// Error message when adding a batch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the batch'**
  String get batch_addFailed;

  /// Add New Batch, under the product name.
  ///
  /// In en, this message translates to:
  /// **'Choose where this delivery goes - this is recorded as its own batch, separate from any existing stock.'**
  String get batch_addIntro;

  /// Add New Batch field label.
  ///
  /// In en, this message translates to:
  /// **'Batch No (optional)'**
  String get batch_batchNoOptional;

  /// Add New Batch field label.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get batch_expiryDate;

  /// Add New Batch, heading over the destination choice.
  ///
  /// In en, this message translates to:
  /// **'Add This Stock To'**
  String get batch_addStockTo;

  /// Add New Batch, under the Stock Store choice.
  ///
  /// In en, this message translates to:
  /// **'Needs a separate \"Release\" step before it can be sold'**
  String get batch_storeHint;

  /// Add New Batch destination choice.
  ///
  /// In en, this message translates to:
  /// **'Sellable (straight to the shelf)'**
  String get batch_sellableOption;

  /// Add New Batch, under the Sellable choice.
  ///
  /// In en, this message translates to:
  /// **'Ready to sell immediately'**
  String get batch_sellableHint;

  /// Add New Batch field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity Received'**
  String get batch_quantityReceived;

  /// Add New Batch quantity validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get batch_validQuantity;

  /// Add New Batch field label with the currency symbol.
  ///
  /// In en, this message translates to:
  /// **'Buy Price ({currency})'**
  String batch_buyPriceLabel(String currency);

  /// Add New Batch save button and the dialog's screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Add Batch'**
  String get batch_addBatch;

  /// Action that moves sellable stock of a batch back to the Stock Store (Products wording).
  ///
  /// In en, this message translates to:
  /// **'Move to Stock'**
  String get batch_moveToStock;

  /// The same action, as worded in the Stock Store and Product Alerts.
  ///
  /// In en, this message translates to:
  /// **'Remove from Sellable'**
  String get batch_removeFromSellable;

  /// Move to Stock dialog text. batchPart and expiryPart are the texts below, or empty.
  ///
  /// In en, this message translates to:
  /// **'{product}{batchPart}{expiryPart}. Up to {quantity} {unit} can move back to Stock Store.'**
  String batch_moveIntro(
    String product,
    String batchPart,
    String expiryPart,
    int quantity,
    String unit,
  );

  /// Part of batch_moveIntro (starts with a space).
  ///
  /// In en, this message translates to:
  /// **' - Batch {batchNo}'**
  String batch_moveBatchPart(String batchNo);

  /// Part of batch_moveIntro (starts with a space).
  ///
  /// In en, this message translates to:
  /// **' (expired {date})'**
  String batch_moveExpiredPart(String date);

  /// Part of batch_moveIntro (starts with a space).
  ///
  /// In en, this message translates to:
  /// **' (expires {date})'**
  String batch_moveExpiresPart(String date);

  /// Move to Stock dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity to move ({unit})'**
  String batch_quantityToMove(String unit);

  /// Move to Stock dialog note label when the reason is Other.
  ///
  /// In en, this message translates to:
  /// **'Note (required for Other)'**
  String get batch_noteRequiredOther;

  /// Move to Stock dialog note label.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get batch_noteOptional;

  /// Move to Stock dialog validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity up to {max}'**
  String batch_quantityUpTo(int max);

  /// Move to Stock dialog validation.
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get batch_selectReason;

  /// Move to Stock dialog validation when the reason is Other.
  ///
  /// In en, this message translates to:
  /// **'Describe the reason in the note below'**
  String get batch_describeReason;

  /// Message after Move to Stock.
  ///
  /// In en, this message translates to:
  /// **'Moved {quantity} {unit} back to Stock Store'**
  String batch_movedBack(int quantity, String unit);

  /// Message after Remove from Sellable.
  ///
  /// In en, this message translates to:
  /// **'Removed {quantity} {unit} from Sellable'**
  String batch_removedFromSellable(int quantity, String unit);

  /// Error message when Move to Stock fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move the stock'**
  String get batch_moveFailed;

  /// Adjust dialog title for a batch with no number.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled Batch'**
  String get batch_unlabeledTitle;

  /// Adjust dialog, current quantities.
  ///
  /// In en, this message translates to:
  /// **'Currently: {stock} store · {sellable} sellable'**
  String batch_currently(int stock, int sellable);

  /// Adjust dialog choice.
  ///
  /// In en, this message translates to:
  /// **'Add to it'**
  String get batch_modeAdd;

  /// Adjust dialog choice.
  ///
  /// In en, this message translates to:
  /// **'Correct to'**
  String get batch_modeSet;

  /// Adjust dialog, explains Add to it.
  ///
  /// In en, this message translates to:
  /// **'Adds this amount on top of what\'s already there (a top-up delivery).'**
  String get batch_modeAddHint;

  /// Adjust dialog, explains Correct to.
  ///
  /// In en, this message translates to:
  /// **'Sets the exact amount on file right now (fixing a miscount).'**
  String get batch_modeSetHint;

  /// Adjust dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Add to Store Qty'**
  String get batch_addStoreQty;

  /// Adjust dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Correct Store Qty to'**
  String get batch_setStoreQty;

  /// Adjust dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Add to Sellable Qty'**
  String get batch_addSellableQty;

  /// Adjust dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Correct Sellable Qty to'**
  String get batch_setSellableQty;

  /// Adjust dialog error with the technical error text.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String batch_saveFailed(String error);

  /// Delete batch dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete Expired Batch?'**
  String get batch_deleteExpiredTitle;

  /// Delete batch dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete This Batch?'**
  String get batch_deleteTitle;

  /// Delete batch dialog warning.
  ///
  /// In en, this message translates to:
  /// **'This batch has not expired - it still has good, sellable stock.'**
  String get batch_notExpiredWarning;

  /// Delete batch dialog text. batch is store_batchName or batch_thisUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes {batch} and subtracts its {stock} store and {sellable} sellable units from this product\'s totals. This cannot be undone.'**
  String batch_deleteBody(String batch, int stock, int sellable);

  /// Part of batch_deleteBody.
  ///
  /// In en, this message translates to:
  /// **'this unlabeled batch'**
  String get batch_thisUnlabeled;

  /// Delete batch dialog error with the technical error text.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String batch_deleteFailed(String error);

  /// View Batches button.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get batch_editDetails;

  /// View Batches section heading.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get batch_batches;

  /// View Batches load error with the technical error text.
  ///
  /// In en, this message translates to:
  /// **'Could not load batches: {error}'**
  String batch_loadFailed(String error);

  /// View Batches, empty.
  ///
  /// In en, this message translates to:
  /// **'No batches recorded yet.'**
  String get batch_noneYet;

  /// View Batches row title for a batch with no number.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled batch'**
  String get batch_unlabeled;

  /// View Batches row badge.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock - 0 available'**
  String get batch_outOfStock;

  /// View Batches row. price is already formatted.
  ///
  /// In en, this message translates to:
  /// **'Store: {stock} · Shelf: {sellable} · {price}'**
  String batch_rowQuantities(int stock, int sellable, String price);

  /// View Batches row and Product Alerts details.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String batch_expiredOn(String date);

  /// View Batches row.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String batch_expiresOn(String date);

  /// View Batches row button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete expired batch'**
  String get batch_deleteExpiredTooltip;

  /// View Batches row button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete batch'**
  String get batch_deleteTooltip;

  /// View Batches row button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Adjust quantity'**
  String get batch_adjustQuantity;

  /// Product Alerts kind name.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get alerts_outOfStock;

  /// Alerts bell dropdown line (out of stock and low stock).
  ///
  /// In en, this message translates to:
  /// **'{product} - Shelf: {sellable} · Store: {stock}'**
  String alerts_messageStock(String product, int sellable, int stock);

  /// Alerts bell dropdown line.
  ///
  /// In en, this message translates to:
  /// **'{product} - expired {date} · {quantity} {unit} on hand'**
  String alerts_messageExpired(
    String product,
    String date,
    int quantity,
    String unit,
  );

  /// Alerts bell dropdown line. when is alerts_today or alerts_inDays.
  ///
  /// In en, this message translates to:
  /// **'{product} - expires {when} ({date}) · {quantity} {unit} on hand'**
  String alerts_messageExpiring(
    String product,
    String when,
    String date,
    int quantity,
    String unit,
  );

  /// Part of alerts_messageExpiring.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get alerts_today;

  /// Part of alerts_messageExpiring.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{in 1 day} other{in {days} days}}'**
  String alerts_inDays(int days);

  /// Alerts bell dropdown line (restock shelf).
  ///
  /// In en, this message translates to:
  /// **'{product} - {sellable} on shelf · {stock} in store'**
  String alerts_messageRestock(String product, int sellable, int stock);

  /// Product Alerts title (screen and bell dropdown).
  ///
  /// In en, this message translates to:
  /// **'Product Alerts'**
  String get alerts_title;

  /// Product Alerts subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stock and expiry problems that need action'**
  String get alerts_subtitle;

  /// Bell dropdown link when not all alerts are shown.
  ///
  /// In en, this message translates to:
  /// **'View all {count} alerts'**
  String alerts_viewAllCount(int count);

  /// Bell dropdown link.
  ///
  /// In en, this message translates to:
  /// **'View all alerts'**
  String get alerts_viewAll;

  /// Product Alerts, empty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get alerts_allCaughtUp;

  /// Product Alerts, empty.
  ///
  /// In en, this message translates to:
  /// **'No stock alerts right now.'**
  String get alerts_noneNow;

  /// Product Alerts card hint.
  ///
  /// In en, this message translates to:
  /// **'Below minimum level'**
  String get alerts_hintLowStock;

  /// Product Alerts card hint.
  ///
  /// In en, this message translates to:
  /// **'Nothing left'**
  String get alerts_hintDepleted;

  /// Product Alerts card hint.
  ///
  /// In en, this message translates to:
  /// **'Store has stock'**
  String get alerts_hintRestockShelf;

  /// Product Alerts card hint.
  ///
  /// In en, this message translates to:
  /// **'Within 30 days'**
  String get alerts_hintExpiringSoon;

  /// Product Alerts card hint.
  ///
  /// In en, this message translates to:
  /// **'Still on hand'**
  String get alerts_hintExpired;

  /// Product Alerts row action.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get alerts_restock;

  /// Product Alerts row action.
  ///
  /// In en, this message translates to:
  /// **'Move to shelf'**
  String get alerts_moveToShelf;

  /// Product Alerts action tooltip for assistants.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can move stock to the shelf'**
  String get alerts_adminOnlyMove;

  /// Product Alerts row action.
  ///
  /// In en, this message translates to:
  /// **'View batches'**
  String get alerts_viewBatches;

  /// Product Alerts row action.
  ///
  /// In en, this message translates to:
  /// **'Remove expired'**
  String get alerts_removeExpired;

  /// Product Alerts details, first line.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String alerts_inStock(int count);

  /// Product Alerts details, second line.
  ///
  /// In en, this message translates to:
  /// **'Min. required: {count}'**
  String alerts_minRequired(int count);

  /// Product Alerts details, first line.
  ///
  /// In en, this message translates to:
  /// **'{count} on shelf'**
  String alerts_onShelf(int count);

  /// Product Alerts details, second line.
  ///
  /// In en, this message translates to:
  /// **'Shelf minimum: {count}'**
  String alerts_shelfMinimum(int count);

  /// Product Alerts details.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get alerts_expiresToday;

  /// Product Alerts details.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expires in 1 day} other{Expires in {days} days}}'**
  String alerts_expiresInDays(int days);

  /// Product Alerts details, second line.
  ///
  /// In en, this message translates to:
  /// **'{date} · {quantity} {unit} on hand'**
  String alerts_dateOnHand(String date, int quantity, String unit);

  /// Product Alerts details, second line.
  ///
  /// In en, this message translates to:
  /// **'{quantity} {unit} on hand'**
  String alerts_onHand(int quantity, String unit);

  /// Product Alerts search box.
  ///
  /// In en, this message translates to:
  /// **'Search by product, category or alert...'**
  String get alerts_searchHint;

  /// Product Alerts, nothing after filtering.
  ///
  /// In en, this message translates to:
  /// **'No alerts match your filters'**
  String get alerts_noMatches;

  /// Product Alerts table column.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alerts_colAlert;

  /// Product Alerts table column.
  ///
  /// In en, this message translates to:
  /// **'Store / Shelf'**
  String get alerts_colStoreShelf;

  /// Product Alerts table column.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get alerts_colAction;

  /// Product Alerts row.
  ///
  /// In en, this message translates to:
  /// **'Store: {count}'**
  String alerts_storeQty(int count);

  /// Product Alerts row.
  ///
  /// In en, this message translates to:
  /// **'Shelf: {count}'**
  String alerts_shelfQty(int count);

  /// Product Alerts narrow card.
  ///
  /// In en, this message translates to:
  /// **'Store: {stock}  ·  Shelf: {sellable}'**
  String alerts_storeShelfQty(int stock, int sellable);

  /// Product Alerts footer when empty.
  ///
  /// In en, this message translates to:
  /// **'No alerts'**
  String get alerts_none;

  /// Product Alerts footer.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1 alert} other{Showing {start} to {end} of {total} alerts}}'**
  String alerts_showingRange(int start, int end, int total);

  /// Message while smart defaults are recalculated.
  ///
  /// In en, this message translates to:
  /// **'Recalculating smart defaults…'**
  String get products_smartDefaultsRunning;

  /// Message after recalculating smart defaults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated smart defaults for 1 product with enough usage history} other{Updated smart defaults for {count} products with enough usage history}}'**
  String products_smartDefaultsUpdated(int count);

  /// Message when no product could be recalculated.
  ///
  /// In en, this message translates to:
  /// **'No products have enough sales/service history yet to compute smart defaults'**
  String get products_smartDefaultsNone;

  /// Error message when recalculating fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t recalculate smart defaults'**
  String get products_smartDefaultsFailed;

  /// Sellable Products metric card.
  ///
  /// In en, this message translates to:
  /// **'Shelf Stock Value'**
  String get products_shelfStockValue;

  /// Error message when the watchlist toggle fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the watchlist'**
  String get products_watchlistFailed;

  /// Delete product dialog text.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String products_confirmDeleteNamed(String name);

  /// Sellable Products, empty.
  ///
  /// In en, this message translates to:
  /// **'No sellable products'**
  String get products_noSellable;

  /// Sellable Products, empty hint.
  ///
  /// In en, this message translates to:
  /// **'Release products from Stock Store'**
  String get products_releaseFromStore;

  /// Product card label over the sellable quantity.
  ///
  /// In en, this message translates to:
  /// **'Sellable'**
  String get products_sellable;

  /// Tooltip on the Sell button when nothing is sellable.
  ///
  /// In en, this message translates to:
  /// **'Out of stock - nothing sellable'**
  String get products_nothingSellable;

  /// Product card button.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get products_sell;

  /// Product card menu item.
  ///
  /// In en, this message translates to:
  /// **'Remove from Watchlist'**
  String get products_removeFromWatchlist;

  /// Product card menu item.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get products_addToWatchlist;

  /// Sellable Products screen title.
  ///
  /// In en, this message translates to:
  /// **'Sellable Products'**
  String get products_sellableTitle;

  /// Sellable Products screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Products ready for sale'**
  String get products_sellableSubtitle;

  /// Sellable Products app bar button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Recalculate smart defaults from usage history'**
  String get products_recalculateTooltip;

  /// Sellable Products search box.
  ///
  /// In en, this message translates to:
  /// **'Search product, brand or batch...'**
  String get products_searchHint;

  /// Product card line.
  ///
  /// In en, this message translates to:
  /// **'Stock: {quantity} {unit} • Batch: {batch}'**
  String products_stockBatch(int quantity, String unit, String batch);

  /// Tooltip on the watchlist badge.
  ///
  /// In en, this message translates to:
  /// **'Watch-listed for daily reports'**
  String get products_watchlisted;

  /// Add/Edit Product warning when no facility is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a facility first'**
  String get products_selectFacilityFirst;

  /// Add/Edit Product error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the image'**
  String get products_imageUploadFailed;

  /// Add/Edit Product photo box.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get products_addPhoto;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Batch No'**
  String get products_batchNo;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get products_expiry;

  /// Add/Edit Product type field placeholder and dialog title.
  ///
  /// In en, this message translates to:
  /// **'Select Type'**
  String get products_selectType;

  /// Add/Edit Product validation.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get products_selectCategoryError;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get products_supplier;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Buying Price ({currency})'**
  String products_buyingPriceLabel(String currency);

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Selling Price ({currency})'**
  String products_sellingPriceLabel(String currency);

  /// Add/Edit Product price validation.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than 0'**
  String get products_greaterThanZero;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get products_quantity;

  /// Add/Edit Product quantity validation.
  ///
  /// In en, this message translates to:
  /// **'Cannot be negative'**
  String get products_cannotBeNegative;

  /// New product destination dialog title.
  ///
  /// In en, this message translates to:
  /// **'Where should this product go?'**
  String get products_destinationTitle;

  /// New product destination choice.
  ///
  /// In en, this message translates to:
  /// **'Sellable Product Catalog'**
  String get products_destinationCatalog;

  /// New product destination choice hint.
  ///
  /// In en, this message translates to:
  /// **'Available for sales and transactions'**
  String get products_destinationCatalogHint;

  /// New product destination choice hint.
  ///
  /// In en, this message translates to:
  /// **'Stored but not sellable yet'**
  String get products_destinationStoreHint;

  /// New product destination dialog button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get products_continue;

  /// Add/Edit Product warning.
  ///
  /// In en, this message translates to:
  /// **'Product name already exists'**
  String get products_nameExists;

  /// Message after adding a product to the catalog.
  ///
  /// In en, this message translates to:
  /// **'Product added to Sellable Catalog'**
  String get products_addedToCatalog;

  /// Message after adding a product to the Stock Store.
  ///
  /// In en, this message translates to:
  /// **'Product added to Stock Store'**
  String get products_addedToStore;

  /// Message after editing a product.
  ///
  /// In en, this message translates to:
  /// **'Product updated'**
  String get products_updated;

  /// Error message when saving a product fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the product'**
  String get products_saveFailed;

  /// Add/Edit Product title when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get products_editProduct;

  /// Add/Edit Product save button when editing.
  ///
  /// In en, this message translates to:
  /// **'Update Product'**
  String get products_updateProduct;

  /// Add/Edit Product save button when adding.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get products_saveProduct;

  /// Add/Edit Product section heading.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get products_basicInfo;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get products_productName;

  /// Add/Edit Product validation.
  ///
  /// In en, this message translates to:
  /// **'Product name is required'**
  String get products_nameRequired;

  /// Add Product, a product with the same name exists.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String products_alreadyExistsNamed(String name);

  /// Add Product, under the duplicate name warning.
  ///
  /// In en, this message translates to:
  /// **'Adding new stock for it, or updating its quantity? Open it below - you can edit its details and quantity right there.'**
  String get products_openBelowHint;

  /// Add Product, duplicate name button.
  ///
  /// In en, this message translates to:
  /// **'Open This Product'**
  String get products_openThisProduct;

  /// Add Product, similar names warning.
  ///
  /// In en, this message translates to:
  /// **'Similar products already exist'**
  String get products_similarExist;

  /// Add Product, open a similar product.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get products_open;

  /// Add/Edit Product section heading.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get products_details;

  /// Edit Product, heading over the quantities.
  ///
  /// In en, this message translates to:
  /// **'Current Quantity'**
  String get products_currentQuantity;

  /// Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Store Qty'**
  String get products_storeQty;

  /// Add/Edit Product number validation.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get products_invalid;

  /// Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Shelf Qty'**
  String get products_shelfQty;

  /// Edit Product, under the quantities.
  ///
  /// In en, this message translates to:
  /// **'Editing these corrects the actual quantity on hand right now.'**
  String get products_quantityEditHint;

  /// Edit Product, when the product has several batches.
  ///
  /// In en, this message translates to:
  /// **'This product has {count} separate batches - manage them individually for accuracy.'**
  String products_manyBatchesHint(int count);

  /// Edit Product button.
  ///
  /// In en, this message translates to:
  /// **'Manage Batches'**
  String get products_manageBatches;

  /// Edit Product button.
  ///
  /// In en, this message translates to:
  /// **'Add New Batch (new delivery, different expiry)'**
  String get products_addNewBatchLong;

  /// Add/Edit Product section heading.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Stock'**
  String get products_pricingStock;

  /// Add/Edit Product section heading.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get products_additionalInfo;

  /// Add/Edit Product field label.
  ///
  /// In en, this message translates to:
  /// **'Minimum Stock Level'**
  String get products_minStockLevel;

  /// Add/Edit Product field hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5 (defaults to {count} if left blank)'**
  String products_minStockHint(int count);

  /// Add/Edit Product switch.
  ///
  /// In en, this message translates to:
  /// **'Track in Daily Reports'**
  String get products_trackInReports;

  /// Add/Edit Product switch hint.
  ///
  /// In en, this message translates to:
  /// **'Watch-listed products need a physical stock count before the daily closing report can be submitted.'**
  String get products_trackInReportsHint;

  /// Banner when new sales arrived while the list was open.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new sale available} other{{count} new sales available}}'**
  String sales_newRecords(int count);

  /// Sales list, empty.
  ///
  /// In en, this message translates to:
  /// **'No sales yet'**
  String get sales_empty;

  /// Sales list, empty after a search.
  ///
  /// In en, this message translates to:
  /// **'No sales match your filters'**
  String get sales_emptyFiltered;

  /// Sales metric card: money collected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get sales_collected;

  /// Sales metric card: money still owed (an amount, not a status).
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sales_pending;

  /// Sales and Sales Archive search box.
  ///
  /// In en, this message translates to:
  /// **'Search sale by product, client, invoice...'**
  String get sales_searchHint;

  /// Sales filter label and table column.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get sales_paymentStatus;

  /// Sales filter label, table column and details field.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get sales_seller;

  /// Sales screen title.
  ///
  /// In en, this message translates to:
  /// **'Sales Records'**
  String get sales_title;

  /// Sales screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Track and manage all sales transactions'**
  String get sales_subtitle;

  /// Sales screen button.
  ///
  /// In en, this message translates to:
  /// **'Record Sale'**
  String get sales_recordSale;

  /// Sales table column.
  ///
  /// In en, this message translates to:
  /// **'Invoice No.'**
  String get sales_invoiceNo;

  /// Sales table: the first item of a sale.
  ///
  /// In en, this message translates to:
  /// **'{name} × {quantity}'**
  String sales_firstItem(String name, String quantity);

  /// Sales table and details: how many items a sale has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String sales_itemCount(int count);

  /// Sales footer when empty.
  ///
  /// In en, this message translates to:
  /// **'No sales'**
  String get sales_none;

  /// Error message when deleting a sale fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the sale'**
  String get sales_deleteFailed;

  /// Sale details panel title.
  ///
  /// In en, this message translates to:
  /// **'Sale Details'**
  String get sales_details;

  /// Sale details: an item's quantity.
  ///
  /// In en, this message translates to:
  /// **'× {quantity}'**
  String sales_quantityTimes(String quantity);

  /// Sale details totals row.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get sales_subtotal;

  /// Sale details totals row.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get sales_discount;

  /// Sale details totals row.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get sales_totalAmount;

  /// Sale details totals row: the amount paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get sales_paid;

  /// Sale details totals row.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get sales_balance;

  /// Sales Archive, empty.
  ///
  /// In en, this message translates to:
  /// **'No archived sales found'**
  String get sales_archiveEmpty;

  /// Sales Archive, empty.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or date range'**
  String get sales_archiveEmptyHint;

  /// Sales Archive title.
  ///
  /// In en, this message translates to:
  /// **'Sales Archive'**
  String get sales_archiveTitle;

  /// Sales Archive subtitle.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Sales archived after 1 day} other{Sales archived after {days} days}}'**
  String sales_archiveSubtitle(int days);

  /// Sales Archive banner without dates.
  ///
  /// In en, this message translates to:
  /// **'Archived sales'**
  String get sales_archivedSales;

  /// Sales Archive footer. more is '+' when more pages may exist, or empty.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{Showing {start} to {end} of 1{more} sale} other{Showing {start} to {end} of {total}{more} sales}}'**
  String sales_archiveShowing(int start, int end, int total, String more);

  /// Sale details: an item with no name.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get sales_item;

  /// Sales Archive search dialog title.
  ///
  /// In en, this message translates to:
  /// **'Search Archived Sales'**
  String get sales_searchArchiveTitle;

  /// Sales Archive search dialog note.
  ///
  /// In en, this message translates to:
  /// **'Archived sales are always fully paid - sales still owing money stay in your active Sales tab regardless of age.'**
  String get sales_archiveFullyPaidNote;

  /// Sales Archive search dialog note.
  ///
  /// In en, this message translates to:
  /// **'Only sales before {date} have reached the archive - anything newer is still in your active Sales list.'**
  String sales_archiveCutoffNote(String date);

  /// Record Sale message when a product has nothing on the shelf.
  ///
  /// In en, this message translates to:
  /// **'{product} has no stock available on the shelf'**
  String sales_noShelfStock(String product);

  /// Record Sale discount dialog title.
  ///
  /// In en, this message translates to:
  /// **'Sale Discount'**
  String get sales_saleDiscount;

  /// Record Sale discount dialog field label.
  ///
  /// In en, this message translates to:
  /// **'Discount Amount ({currency})'**
  String sales_discountAmountLabel(String currency);

  /// Record Sale button and the product browser title.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get sales_browseProducts;

  /// Product browser search box.
  ///
  /// In en, this message translates to:
  /// **'Filter by name, batch no or category...'**
  String get sales_browseFilterHint;

  /// Product browser category button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get sales_filterByCategory;

  /// Product browser category choice.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get sales_allCategories;

  /// Product browser, nothing found.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get sales_noProductsFound;

  /// Product browser row.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get sales_outOfStock;

  /// Product browser and search suggestion row. price is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{quantity} {unit} available · {price}'**
  String sales_availablePrice(int quantity, String unit, String price);

  /// Expired stock warning when selling.
  ///
  /// In en, this message translates to:
  /// **'This product is expired. Do you still want to sell it?'**
  String get sales_expiredSaleBody;

  /// Expired stock warning, one line per product.
  ///
  /// In en, this message translates to:
  /// **'• {quantity} {unit} of {product}'**
  String sales_expiredPortionLine(int quantity, String unit, String product);

  /// Expired stock warning button.
  ///
  /// In en, this message translates to:
  /// **'Sell Anyway'**
  String get sales_sellAnyway;

  /// Record Sale warning.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item before saving'**
  String get sales_addItemFirst;

  /// Record Sale warning (walk-in with a partial payment).
  ///
  /// In en, this message translates to:
  /// **'Select a registered client to allow a partial payment'**
  String get sales_partialNeedsRegistered;

  /// Record Sale warning, second line.
  ///
  /// In en, this message translates to:
  /// **'Walk-in sales must be paid in full'**
  String get sales_walkInPayInFull;

  /// Record Sale warning (no client with a partial payment).
  ///
  /// In en, this message translates to:
  /// **'Select a client to record a partial payment'**
  String get sales_partialNeedsClient;

  /// Record Sale warning, second line.
  ///
  /// In en, this message translates to:
  /// **'Or choose Walk-in Customer and collect payment in full'**
  String get sales_orChooseWalkIn;

  /// Record Sale warning.
  ///
  /// In en, this message translates to:
  /// **'Select a payment method before saving'**
  String get sales_selectPaymentMethod;

  /// Message after saving a sale on credit.
  ///
  /// In en, this message translates to:
  /// **'Sale saved and debt recorded'**
  String get sales_savedWithDebt;

  /// Message after saving a sale.
  ///
  /// In en, this message translates to:
  /// **'Sale saved'**
  String get sales_saved;

  /// Error message when saving a sale fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the sale'**
  String get sales_saveFailed;

  /// Record Sale section heading.
  ///
  /// In en, this message translates to:
  /// **'Sale Summary'**
  String get sales_summary;

  /// Record Sale summary row.
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get sales_totalItems;

  /// Record Sale payment method placeholder.
  ///
  /// In en, this message translates to:
  /// **'Select Method'**
  String get sales_selectMethod;

  /// Record Sale field label.
  ///
  /// In en, this message translates to:
  /// **'Amount Received ({currency}) *'**
  String sales_amountReceivedLabel(String currency);

  /// Record Sale field label: money given back.
  ///
  /// In en, this message translates to:
  /// **'Change ({currency})'**
  String sales_changeLabel(String currency);

  /// Record Sale client choice for a customer with no record (not saved; a walk-in sale has no client name).
  ///
  /// In en, this message translates to:
  /// **'Walk-in Customer'**
  String get sales_walkInCustomer;

  /// Record Sale, under Walk-in Customer.
  ///
  /// In en, this message translates to:
  /// **'No client selected'**
  String get sales_noClientSelected;

  /// Record Sale product search box.
  ///
  /// In en, this message translates to:
  /// **'Search product by name, batch no or category...'**
  String get sales_productSearchHint;

  /// Record Sale, empty item list.
  ///
  /// In en, this message translates to:
  /// **'No products added yet'**
  String get sales_noProductsYet;

  /// Record Sale, empty item list.
  ///
  /// In en, this message translates to:
  /// **'Search and add products to this sale'**
  String get sales_addProductsHint;

  /// Record Sale items table column.
  ///
  /// In en, this message translates to:
  /// **'Batch No.'**
  String get sales_colBatchNo;

  /// Record Sale items table column.
  ///
  /// In en, this message translates to:
  /// **'Unit Price ({currency})'**
  String sales_colUnitPrice(String currency);

  /// Record Sale items table column.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get sales_colQty;

  /// Record Sale items table column.
  ///
  /// In en, this message translates to:
  /// **'Total ({currency})'**
  String sales_colTotal(String currency);

  /// Record Sale item card.
  ///
  /// In en, this message translates to:
  /// **'Batch: {batch}'**
  String sales_batchShort(String batch);

  /// Record Sale item card.
  ///
  /// In en, this message translates to:
  /// **'Exp: {date}'**
  String sales_expShort(String date);

  /// Record Sale notes box.
  ///
  /// In en, this message translates to:
  /// **'Add any additional notes (optional)...'**
  String get sales_notesHint;

  /// Tooltip on the close button of an error alert.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get common_dismiss;

  /// Link to the privacy policy (login footer, register terms line).
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get common_privacyPolicy;

  /// Link to the terms of service (login footer, register terms line).
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get common_termsOfService;

  /// Button that signs the person out (loading, error and no-facility screens).
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get common_logout;

  /// Button on the register screen that goes to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get common_logIn;

  /// Field label for an invite code (register, no-facility screen).
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get common_inviteCode;

  /// Field label for a new facility's name.
  ///
  /// In en, this message translates to:
  /// **'Facility name'**
  String get common_facilityName;

  /// Example in the facility name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ukuli'**
  String get common_facilityNameHint;

  /// Register: the two passwords differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get common_passwordsDoNotMatch;

  /// App title in the login and register top bar.
  ///
  /// In en, this message translates to:
  /// **'{appName} System'**
  String common_appSystem(String appName);

  /// Edit Profile screen title.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get common_editProfile;

  /// Login top bar, under the app title.
  ///
  /// In en, this message translates to:
  /// **'Smart Business & Vet Services Monitor'**
  String get login_tagline;

  /// Login top bar status pill.
  ///
  /// In en, this message translates to:
  /// **'System Online'**
  String get login_systemOnline;

  /// Login footer.
  ///
  /// In en, this message translates to:
  /// **'© 2026 {appName} System. All rights reserved.'**
  String login_copyright(String appName);

  /// Login welcome card, above the app name.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get login_welcomeTo;

  /// Login welcome card.
  ///
  /// In en, this message translates to:
  /// **'Stay updated with the latest news and announcements.'**
  String get login_stayUpdated;

  /// Login announcements card title.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get login_announcements;

  /// Login announcement chip for an urgent announcement.
  ///
  /// In en, this message translates to:
  /// **'URGENT'**
  String get login_urgent;

  /// Login announcement title when the announcement has none.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get login_announcementFallbackTitle;

  /// Login announcements card, empty.
  ///
  /// In en, this message translates to:
  /// **'No announcements'**
  String get login_noAnnouncements;

  /// Login announcements card, empty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get login_allCaughtUp;

  /// Login trust footer.
  ///
  /// In en, this message translates to:
  /// **'Secure. Reliable. Always Connected.'**
  String get login_trustTitle;

  /// Login trust footer.
  ///
  /// In en, this message translates to:
  /// **'Your trusted partner in animal health and business growth.'**
  String get login_trustBody;

  /// Login form title.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get login_welcomeBack;

  /// Login form subtitle.
  ///
  /// In en, this message translates to:
  /// **'Log into your facility'**
  String get login_logIntoFacility;

  /// Login email field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get login_emailHint;

  /// Login password field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get login_passwordHint;

  /// Login checkbox: keep the email for next time.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get login_rememberMe;

  /// Login link that sends a password reset email.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get login_forgotPassword;

  /// Login, before the Register link (ends with a space).
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get login_noAccount;

  /// Login link to the register screen.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get login_register;

  /// Login button.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login_loginButton;

  /// Badge on an announcement less than two days old.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get login_newBadge;

  /// Login error: email or password empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get login_credentialsTooShort;

  /// Login error when sign-in has not finished after a few seconds.
  ///
  /// In en, this message translates to:
  /// **'Signing in is taking longer than expected. Check your internet connection and try again.'**
  String get login_slowSignIn;

  /// Login: Forgot Password pressed with no email.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset your password.'**
  String get login_resetNeedsEmail;

  /// Login: after Forgot Password (the same whether or not the account exists).
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a reset link has been sent. Check your inbox (and spam folder).'**
  String get login_resetSent;

  /// Login: the reset email could not be sent; reason is a FriendlyError message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset email. {reason}'**
  String login_resetFailed(String reason);

  /// Register: the invite code typed was not accepted.
  ///
  /// In en, this message translates to:
  /// **'Invalid, expired, or already-used invite code'**
  String get register_inviteInvalid;

  /// Register: the invite code lookup failed.
  ///
  /// In en, this message translates to:
  /// **'Could not check this code - try again'**
  String get register_inviteCheckFailed;

  /// Register: Add pressed with no facility name.
  ///
  /// In en, this message translates to:
  /// **'Enter the facility name first'**
  String get register_enterFacilityNameFirst;

  /// Register: Add pressed with no facility type.
  ///
  /// In en, this message translates to:
  /// **'Choose the facility type first'**
  String get register_chooseFacilityTypeFirst;

  /// Register: Add pressed at the facility limit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the limit of {max} facilities per account'**
  String register_facilityLimit(int max);

  /// Register: adding a facility to the list failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add this facility'**
  String get register_addFacilityFailed;

  /// Register password check.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get register_pwMin8;

  /// Register password check.
  ///
  /// In en, this message translates to:
  /// **'Add at least one letter'**
  String get register_pwNeedsLetter;

  /// Register password check.
  ///
  /// In en, this message translates to:
  /// **'Add at least one number'**
  String get register_pwNeedsNumber;

  /// Register password check.
  ///
  /// In en, this message translates to:
  /// **'This password is too common - choose another'**
  String get register_pwTooCommon;

  /// Register error: an owner with no facility.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one facility'**
  String get register_addAtLeastOneFacility;

  /// Register error: no valid invite code.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid invite code'**
  String get register_enterValidInvite;

  /// Edit Profile: saved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get register_profileUpdated;

  /// Register: owner account created.
  ///
  /// In en, this message translates to:
  /// **'Account registered'**
  String get register_accountRegistered;

  /// Register: second line after an owner account is created.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification link to your email. Check your Spam folder if it doesn\'t appear within a few minutes.'**
  String get register_verifyEmailSent;

  /// Register error: assistant with no valid invite code.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid invite code first'**
  String get register_enterValidInviteFirst;

  /// Register: assistant account created.
  ///
  /// In en, this message translates to:
  /// **'Assistant registered, waiting for admin approval'**
  String get register_assistantRegistered;

  /// Register: second line after an assistant account is created.
  ///
  /// In en, this message translates to:
  /// **'We\'ve also sent a verification link to your email. Check your Spam folder if it doesn\'t appear.'**
  String get register_verifyEmailAlsoSent;

  /// Register: email field error.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get register_emailAlreadyRegistered;

  /// Register error: the email is already used.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. If you\'re switching facilities, this email can\'t register a second time - ask your Platform Admin to add you to the new facility instead.'**
  String get register_emailExists;

  /// Register: email field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address, like name@example.com'**
  String get register_validEmailExample;

  /// Register error: the email was refused.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get register_validEmail;

  /// Register: password field error.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password'**
  String get register_strongerPasswordField;

  /// Register error: the password was refused as weak.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password.'**
  String get register_strongerPassword;

  /// Register error; reason is a FriendlyError message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the account. {reason}'**
  String register_createFailed(String reason);

  /// Register welcome panel title.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get register_createYourAccount;

  /// Register welcome panel.
  ///
  /// In en, this message translates to:
  /// **'Set up {appName} for your agrovet or veterinary centre in a few minutes.'**
  String register_setUpApp(String appName);

  /// Register welcome strip (narrow screens).
  ///
  /// In en, this message translates to:
  /// **'Set up your agrovet or veterinary centre in a few minutes.'**
  String get register_setUpCentre;

  /// Register welcome panel benefit.
  ///
  /// In en, this message translates to:
  /// **'Sales, stock, clients and debts in one place'**
  String get register_benefitAllInOne;

  /// Register welcome panel benefit.
  ///
  /// In en, this message translates to:
  /// **'Invite your team with secure, one-time codes'**
  String get register_benefitInvite;

  /// Register welcome panel benefit.
  ///
  /// In en, this message translates to:
  /// **'Every new facility starts with a trial period'**
  String get register_benefitTrial;

  /// Register welcome panel, above Log in.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get register_alreadyHaveAccount;

  /// Register submit button.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register_createAccount;

  /// Register terms line, before the Terms of Service link (ends with a space).
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to our '**
  String get register_termsPrefix;

  /// Register terms line, between the two links (spaces on both sides).
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get register_termsAnd;

  /// Edit Profile submit button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get register_saveChanges;

  /// Register field label (also named in the fix-these-fields message).
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get register_fieldFullName;

  /// Register field label (also named in the fix-these-fields message).
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get register_fieldPhone;

  /// Register field label (also named in the fix-these-fields message).
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get register_fieldConfirmPassword;

  /// Register name field hint and error.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get register_enterFullName;

  /// Register name field error.
  ///
  /// In en, this message translates to:
  /// **'Your name looks too short - enter your full name'**
  String get register_nameTooShort;

  /// Register email field error.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get register_enterEmail;

  /// Register phone field error.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get register_enterPhone;

  /// Register phone field error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number, like 0712 345 678'**
  String get register_validPhone;

  /// Register facility error: name and type filled but Add not pressed.
  ///
  /// In en, this message translates to:
  /// **'Press Add to include \"{name}\" before you register'**
  String register_pressAddToInclude(String name);

  /// Register facility error.
  ///
  /// In en, this message translates to:
  /// **'Choose the facility type, then press Add'**
  String get register_chooseTypeThenAdd;

  /// Register facility error.
  ///
  /// In en, this message translates to:
  /// **'Add at least one facility: enter its name, choose its type, then press Add'**
  String get register_addOneFacilityHow;

  /// Register invite code field hint and error.
  ///
  /// In en, this message translates to:
  /// **'Enter your invite code'**
  String get register_enterInviteCode;

  /// Register invite code field error.
  ///
  /// In en, this message translates to:
  /// **'Still checking your invite code - try again in a moment'**
  String get register_stillChecking;

  /// Register password field hint and error.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get register_createPassword;

  /// Register confirm field error.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password to confirm it'**
  String get register_reenterToConfirm;

  /// Register alert naming the fields with problems (count is 2 or more; fields is a comma list of field labels).
  ///
  /// In en, this message translates to:
  /// **'Please fix {count} fields: {fields}.'**
  String register_fixFields(int count, String fields);

  /// As register_fixFields, when more than three fields have problems.
  ///
  /// In en, this message translates to:
  /// **'Please fix {count} fields: {fields} and {more} more.'**
  String register_fixFieldsMore(int count, String fields, int more);

  /// Edit Profile button while saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get register_saving;

  /// Register button while creating the account.
  ///
  /// In en, this message translates to:
  /// **'Creating your account...'**
  String get register_creating;

  /// Register section title.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get register_personalDetails;

  /// Register section note: fields marked * are required.
  ///
  /// In en, this message translates to:
  /// **'* Required'**
  String get register_requiredNote;

  /// Register field label for Mr./Mrs./Ms./Dr. (the choices themselves are saved in the name and stay as typed).
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get register_title;

  /// Register email field example.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get register_emailHint;

  /// Register phone field example.
  ///
  /// In en, this message translates to:
  /// **'07XX XXX XXX'**
  String get register_phoneHint;

  /// Register avatar picker.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get register_profilePhoto;

  /// Register avatar picker.
  ///
  /// In en, this message translates to:
  /// **'Tap to change your photo'**
  String get register_tapToChangePhoto;

  /// Register avatar picker.
  ///
  /// In en, this message translates to:
  /// **'Optional - tap to add a photo'**
  String get register_tapToAddPhoto;

  /// Register section title.
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get register_yourRole;

  /// Register role card, Co-admin.
  ///
  /// In en, this message translates to:
  /// **'I help manage a facility'**
  String get register_roleCoAdminSubtitle;

  /// Register role card, Admin.
  ///
  /// In en, this message translates to:
  /// **'I own or manage a facility'**
  String get register_roleAdminSubtitle;

  /// Register role card, Assistant.
  ///
  /// In en, this message translates to:
  /// **'I have an invite code'**
  String get register_roleAssistantSubtitle;

  /// Edit Profile, under the role cards.
  ///
  /// In en, this message translates to:
  /// **'Your role can\'t be changed here.'**
  String get register_roleLocked;

  /// Register section title (owner).
  ///
  /// In en, this message translates to:
  /// **'Your facilities'**
  String get register_yourFacilities;

  /// Register, assistant facility section.
  ///
  /// In en, this message translates to:
  /// **'Ask your facility Admin for an invite code to join their team.'**
  String get register_askAdminForInvite;

  /// Register, the facility an invite code leads to (facility is "name (type)").
  ///
  /// In en, this message translates to:
  /// **'Joining: {facility}'**
  String register_joining(String facility);

  /// Register facility tile: its type and its code.
  ///
  /// In en, this message translates to:
  /// **'{type}  ·  Code: {code}'**
  String register_facilityTypeAndCode(String type, String code);

  /// Register, owner facility section, empty.
  ///
  /// In en, this message translates to:
  /// **'Add at least one facility to continue.'**
  String get register_addOneToContinue;

  /// Edit Profile, owner facility section (View Facilities is the menu item's name).
  ///
  /// In en, this message translates to:
  /// **'To add or change facilities, use View Facilities.'**
  String get register_useViewFacilities;

  /// Register, owner facility section.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} facilities added'**
  String register_facilitiesAdded(int count, int max);

  /// Register facility type dropdown hint.
  ///
  /// In en, this message translates to:
  /// **'Select type'**
  String get register_selectType;

  /// Register Add button tooltip at the limit.
  ///
  /// In en, this message translates to:
  /// **'Maximum of {max} facilities reached'**
  String register_maxFacilitiesReached(int max);

  /// Register section title.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get register_accountSecurity;

  /// Register password helper before typing.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with a letter and a number'**
  String get register_passwordRule;

  /// Register password helper when the password is acceptable.
  ///
  /// In en, this message translates to:
  /// **'Looks good'**
  String get register_looksGood;

  /// Register confirm field hint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get register_reenterPassword;

  /// Register confirm field helper.
  ///
  /// In en, this message translates to:
  /// **'Passwords match'**
  String get register_passwordsMatch;

  /// Shown on the login screen after signing out an account with no profile.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a profile for this account. If you have just registered, the registration did not finish - please register again. If this keeps happening, contact support.'**
  String get entry_noProfile;

  /// Shown on the login screen after signing out a deactivated account.
  ///
  /// In en, this message translates to:
  /// **'This account has been deactivated. Ask your facility admin (or Platform Admin) to reactivate it before signing in again.'**
  String get entry_deactivated;

  /// Shown on the login screen after signing out an assistant waiting for approval.
  ///
  /// In en, this message translates to:
  /// **'Your account is not active yet. Please wait for admin approval.'**
  String get entry_notActiveYet;

  /// No-facility screen notice for a rejected assistant (facility name unknown).
  ///
  /// In en, this message translates to:
  /// **'Your request to join was not approved.'**
  String get entry_requestNotApproved;

  /// No-facility screen notice for a rejected assistant.
  ///
  /// In en, this message translates to:
  /// **'Your request to join {facility} was not approved.'**
  String entry_requestNotApprovedFrom(String facility);

  /// Loading screen, after a while.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than expected to load.'**
  String get entry_slowLoad;

  /// Account loading error screen: timed out.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than expected. Check your internet connection and try again.'**
  String get entry_timeoutExplanation;

  /// Account loading error screen: server unreachable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the server. Check your internet connection and try again.'**
  String get entry_unreachable;

  /// Account loading error screen: permission denied.
  ///
  /// In en, this message translates to:
  /// **'Your account couldn\'t be opened because access was refused. Try again, and if it keeps happening, contact support.'**
  String get entry_accessRefused;

  /// Account loading error screen: any other error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while loading your account details. Check your connection and try again.'**
  String get entry_loadFailed;

  /// Account loading error screen title.
  ///
  /// In en, this message translates to:
  /// **'Could Not Load Your Account'**
  String get entry_couldNotLoadTitle;

  /// No-facility screen: Add facility pressed with no name.
  ///
  /// In en, this message translates to:
  /// **'Enter the facility name.'**
  String get noFacility_enterName;

  /// No-facility screen: Add facility pressed with no type.
  ///
  /// In en, this message translates to:
  /// **'Choose the facility type.'**
  String get noFacility_chooseType;

  /// Delete-account dialog error.
  ///
  /// In en, this message translates to:
  /// **'That password isn\'t right.'**
  String get noFacility_wrongPassword;

  /// Delete-account dialog error.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get noFacility_tooManyAttempts;

  /// Delete-account dialog error.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the server. Check your connection and try again.'**
  String get noFacility_unreachable;

  /// Delete-account dialog error.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account.'**
  String get noFacility_deleteFailed;

  /// Delete-account dialog error; error is the raw error text (kept as before).
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account: {error}'**
  String noFacility_deleteFailedWith(String error);

  /// Stands in for a missing facility name in noFacility_stillOwns.
  ///
  /// In en, this message translates to:
  /// **'a facility'**
  String get noFacility_aFacility;

  /// Dialog title: the account still owns a facility.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete the account yet'**
  String get noFacility_cantDeleteTitle;

  /// Dialog body: the account still owns a facility.
  ///
  /// In en, this message translates to:
  /// **'This account still owns \"{name}\", which isn\'t on your profile. Contact support so it can be sorted out first.'**
  String noFacility_stillOwns(String name);

  /// Delete-account dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get noFacility_deleteTitle;

  /// Delete-account dialog body.
  ///
  /// In en, this message translates to:
  /// **'This is permanent and cannot be undone. Your account and profile will be erased, and you will not be able to sign in with this email again.'**
  String get noFacility_deleteWarning;

  /// Delete-account dialog error.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm.'**
  String get noFacility_enterPasswordToConfirm;

  /// Shown on the login screen after deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get noFacility_accountDeleted;

  /// Delete-account dialog button.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get noFacility_deleteAccount;

  /// No-facility screen button while adding.
  ///
  /// In en, this message translates to:
  /// **'Adding facility...'**
  String get noFacility_adding;

  /// No-facility screen button.
  ///
  /// In en, this message translates to:
  /// **'Add facility'**
  String get noFacility_addFacility;

  /// No-facility screen link.
  ///
  /// In en, this message translates to:
  /// **'Delete my account instead'**
  String get noFacility_deleteInstead;

  /// No-facility screen: invite code not accepted.
  ///
  /// In en, this message translates to:
  /// **'That code is invalid, has expired, or has already been used.'**
  String get noFacility_codeInvalid;

  /// Shown on the login screen after asking to join a facility.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {facility}. You can sign in once its admin approves you.'**
  String noFacility_requestSent(String facility);

  /// No-facility screen title (assistant).
  ///
  /// In en, this message translates to:
  /// **'You\'re not in a facility right now'**
  String get noFacility_titleAssistant;

  /// No-facility screen title (owner).
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a facility right now'**
  String get noFacility_titleAdmin;

  /// No-facility screen notice box; notice is entry_requestNotApproved or entry_requestNotApprovedFrom.
  ///
  /// In en, this message translates to:
  /// **'{notice} If you think that was a mistake, ask for a new invite code.'**
  String noFacility_noticeMistake(String notice);

  /// No-facility screen body (assistant).
  ///
  /// In en, this message translates to:
  /// **'You may have been removed from your facility, or not added to one yet. Your account, name, phone number and photo are kept. To join a facility, enter an invite code from its admin.'**
  String get noFacility_bodyAssistant;

  /// No-facility screen body (owner).
  ///
  /// In en, this message translates to:
  /// **'Your account is kept. Add a facility to carry on, or delete your account if you no longer need it.'**
  String get noFacility_bodyAdmin;

  /// No-facility screen invite code example.
  ///
  /// In en, this message translates to:
  /// **'e.g. JK7-2P4'**
  String get noFacility_inviteHint;

  /// No-facility screen: the facility the code leads to (no type known).
  ///
  /// In en, this message translates to:
  /// **'You\'ll be asking to join: {facility}'**
  String noFacility_askingToJoin(String facility);

  /// No-facility screen: the facility the code leads to, with its type.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be asking to join: {facility} ({type})'**
  String noFacility_askingToJoinWithType(String facility, String type);

  /// No-facility screen button while sending.
  ///
  /// In en, this message translates to:
  /// **'Sending your request...'**
  String get noFacility_sending;

  /// No-facility screen button.
  ///
  /// In en, this message translates to:
  /// **'Request to join'**
  String get noFacility_requestToJoin;

  /// No-facility screen, under Request to join.
  ///
  /// In en, this message translates to:
  /// **'The facility\'s admin has to approve you, as with any new assistant. Or ask your previous admin to add you back.'**
  String get noFacility_approvalNote;

  /// Title of the live free-trial row in Notifications.
  ///
  /// In en, this message translates to:
  /// **'Free Trial'**
  String get subscription_freeTrialTitle;

  /// Free-trial message when no end date is known (Notifications row and Dashboard banner).
  ///
  /// In en, this message translates to:
  /// **'You\'re on a free trial.'**
  String get subscription_onFreeTrial;

  /// Free-trial row in Notifications: days left and the end date.
  ///
  /// In en, this message translates to:
  /// **'You have {count, plural, =1{1 day} other{{count} days}} left of your free trial, ending on {date}.'**
  String subscription_trialDaysLeftEnding(int count, String date);

  /// Notifications row title when the trial has run out.
  ///
  /// In en, this message translates to:
  /// **'Trial Ended'**
  String get subscription_trialEndedTitle;

  /// Notifications row and Dashboard banner: trial over, facility locked.
  ///
  /// In en, this message translates to:
  /// **'Your trial has ended. The app is in read-only mode.'**
  String get subscription_trialEndedReadOnly;

  /// Notifications row and Dashboard banner: subscription over, facility locked.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired. The app is in read-only mode.'**
  String get subscription_expiredReadOnly;

  /// Notifications row and Dashboard banner: trial over, in the grace days.
  ///
  /// In en, this message translates to:
  /// **'Your trial has ended. You have a few days of grace before read-only mode begins.'**
  String get subscription_trialEndedGrace;

  /// Notifications row and Dashboard banner: subscription over, in the grace days.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired. You have a few days of grace before read-only mode begins.'**
  String get subscription_expiredGrace;

  /// Notifications row title: the trial ends within a few days.
  ///
  /// In en, this message translates to:
  /// **'Trial Expiring Soon'**
  String get subscription_trialExpiringSoonTitle;

  /// Notifications row title: the subscription ends within a few days.
  ///
  /// In en, this message translates to:
  /// **'Subscription Expiring Soon'**
  String get subscription_expiringSoonTitle;

  /// Notifications row and Dashboard banner: days until the trial ends.
  ///
  /// In en, this message translates to:
  /// **'Your trial expires in {count, plural, =1{1 day} other{{count} days}}.'**
  String subscription_trialExpiresIn(int count);

  /// Notifications row and Dashboard banner: days until the subscription ends.
  ///
  /// In en, this message translates to:
  /// **'Your subscription expires in {count, plural, =1{1 day} other{{count} days}}.'**
  String subscription_expiresIn(int count);

  /// Dashboard banner during the free trial.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a free trial - {count, plural, =1{1 day} other{{count} days}} left.'**
  String subscription_freeTrialDaysLeft(int count);

  /// Dashboard banner: trial with no end date.
  ///
  /// In en, this message translates to:
  /// **'Your trial is active.'**
  String get subscription_trialActive;

  /// Dashboard banner: subscription with no end date.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active.'**
  String get subscription_active;

  /// Dashboard banner link (admin, free trial).
  ///
  /// In en, this message translates to:
  /// **'View Plans'**
  String get subscription_viewPlans;

  /// Dashboard banner link (admin).
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get subscription_renew;

  /// Dashboard banner, for an assistant.
  ///
  /// In en, this message translates to:
  /// **'· Ask your admin'**
  String get subscription_askYourAdmin;

  /// Shown on the login screen after the assistant was moved to another facility.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been reassigned to a different facility. Please log back in.'**
  String get dashboard_reassigned;

  /// Next to a trend: compared with yesterday (Dashboard cards, Insights).
  ///
  /// In en, this message translates to:
  /// **'vs Yesterday'**
  String get dashboard_vsYesterday;

  /// Next to a Dashboard card trend.
  ///
  /// In en, this message translates to:
  /// **'vs Last Week'**
  String get dashboard_vsLastWeek;

  /// Next to a Dashboard card trend.
  ///
  /// In en, this message translates to:
  /// **'vs Last Month'**
  String get dashboard_vsLastMonth;

  /// Next to a Dashboard card trend.
  ///
  /// In en, this message translates to:
  /// **'vs Last Year'**
  String get dashboard_vsLastYear;

  /// Dashboard greeting before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboard_goodMorning;

  /// Dashboard greeting before 5 pm.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboard_goodAfternoon;

  /// Dashboard greeting from 5 pm.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboard_goodEvening;

  /// Dashboard greeting line: the greeting and the user's name.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String dashboard_greeting(String greeting, String name);

  /// Under the Dashboard greeting.
  ///
  /// In en, this message translates to:
  /// **'Here\'s how {facility} is doing today.'**
  String dashboard_howFacilityIsDoing(String facility);

  /// Message after a new profile picture is saved.
  ///
  /// In en, this message translates to:
  /// **'Profile avatar updated'**
  String get dashboard_avatarUpdated;

  /// Error after a profile picture failed to save.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the profile avatar'**
  String get dashboard_avatarSaveFailed;

  /// Title of the profile panel's change-password dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get dashboard_resetPasswordTitle;

  /// Change-password dialog question.
  ///
  /// In en, this message translates to:
  /// **'Send password reset email to {email}?'**
  String dashboard_resetPasswordPrompt(String email);

  /// Change-password dialog button.
  ///
  /// In en, this message translates to:
  /// **'Send Link'**
  String get dashboard_sendLink;

  /// Message after the reset email was sent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent to {email}'**
  String dashboard_resetLinkSent(String email);

  /// Error when the reset email could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset link'**
  String get dashboard_resetLinkFailed;

  /// Tooltip of the sidebar toggle when collapsed.
  ///
  /// In en, this message translates to:
  /// **'Expand menu'**
  String get dashboard_expandMenu;

  /// Tooltip of the sidebar toggle when open.
  ///
  /// In en, this message translates to:
  /// **'Collapse menu'**
  String get dashboard_collapseMenu;

  /// Placeholder of the top bar search box (phone layout).
  ///
  /// In en, this message translates to:
  /// **'Search anything...'**
  String get dashboard_searchAnything;

  /// Keyboard shortcut shown in the top bar search box.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+K'**
  String get dashboard_searchShortcut;

  /// Tooltip of the top bar help button.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get dashboard_help;

  /// Top bar profile button when the user has no name.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get dashboard_account;

  /// Tooltip of the Dashboard period picker.
  ///
  /// In en, this message translates to:
  /// **'Change period'**
  String get dashboard_changePeriod;

  /// Dashboard card title.
  ///
  /// In en, this message translates to:
  /// **'Total Product Value'**
  String get dashboard_totalProductValue;

  /// Dashboard card subtitle: a current balance, not a period total.
  ///
  /// In en, this message translates to:
  /// **'as of now'**
  String get dashboard_asOfNow;

  /// Dashboard card title with the chosen period.
  ///
  /// In en, this message translates to:
  /// **'Total Sales ({period})'**
  String dashboard_totalSales(String period);

  /// Dashboard card title with the chosen period.
  ///
  /// In en, this message translates to:
  /// **'Total Collected ({period})'**
  String dashboard_totalCollected(String period);

  /// Dashboard card title with the chosen period.
  ///
  /// In en, this message translates to:
  /// **'Net Profit ({period})'**
  String dashboard_netProfit(String period);

  /// Dashboard card title with the chosen period.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses ({period})'**
  String dashboard_totalExpenses(String period);

  /// Dashboard card title: debt still owed.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Payment'**
  String get dashboard_outstandingPayment;

  /// Dashboard card title with the chosen period.
  ///
  /// In en, this message translates to:
  /// **'Completed Services ({period})'**
  String dashboard_completedServices(String period);

  /// Dashboard section title.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboard_recentActivity;

  /// Dashboard Recent Activity button: opens the activity log.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get dashboard_viewAll;

  /// Dashboard Recent Activity when empty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get dashboard_noActivityYet;

  /// Dashboard Recent Activity when loading failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load recent activity.'**
  String get dashboard_recentActivityLoadFailed;

  /// Dashboard chart title.
  ///
  /// In en, this message translates to:
  /// **'Sales & Revenue Overview'**
  String get dashboard_salesRevenueOverview;

  /// Dashboard chart: change against the period before.
  ///
  /// In en, this message translates to:
  /// **'{percent}% vs last period'**
  String dashboard_vsLastPeriod(String percent);

  /// Dashboard chart when empty.
  ///
  /// In en, this message translates to:
  /// **'No activity in this period.'**
  String get dashboard_noActivityInPeriod;

  /// Dashboard chart series, Today at a Glance count and Insights metric.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get dashboard_sales;

  /// Dashboard chart series: debt repayments collected.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get dashboard_collections;

  /// Dashboard chart series and Today at a Glance count.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get dashboard_services;

  /// Dashboard chart legend: a series and the currency symbol.
  ///
  /// In en, this message translates to:
  /// **'{label} ({currency})'**
  String dashboard_seriesWithCurrency(String label, String currency);

  /// Placeholder of the top bar search box.
  ///
  /// In en, this message translates to:
  /// **'Search products or clients...'**
  String get dashboard_searchProductsOrClients;

  /// Top bar search result under a client's name.
  ///
  /// In en, this message translates to:
  /// **'Client • {phone}'**
  String dashboard_searchClient(String phone);

  /// Dashboard strip title.
  ///
  /// In en, this message translates to:
  /// **'Today at a Glance'**
  String get dashboard_todayAtAGlance;

  /// Today at a Glance label after the number of debts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Outstanding Debt} other{Outstanding Debts}}'**
  String dashboard_outstandingDebts(int count);

  /// Net Profit card: profit already collected in cash.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get dashboard_profitEarned;

  /// Net Profit card: profit sold on credit, not yet paid.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get dashboard_profitPending;

  /// Tooltip of the Net Profit card's info icon.
  ///
  /// In en, this message translates to:
  /// **'Earned: already collected in cash.\nPending: sold on credit, not yet paid.'**
  String get dashboard_profitHelp;

  /// Quick action card under Record Sale.
  ///
  /// In en, this message translates to:
  /// **'Create a new sale'**
  String get dashboard_createNewSale;

  /// Quick action card under Record Visit.
  ///
  /// In en, this message translates to:
  /// **'Add a new service record'**
  String get dashboard_addServiceRecord;

  /// Quick action card under Add Product.
  ///
  /// In en, this message translates to:
  /// **'Add new product to store'**
  String get dashboard_addProductToStore;

  /// Help dialog: the email link could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your email app'**
  String get dashboard_emailAppFailed;

  /// Help dialog title.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get dashboard_contactSupport;

  /// Help dialog text.
  ///
  /// In en, this message translates to:
  /// **'For help or support please reach out to {appName} platform admin.'**
  String dashboard_supportIntro(String appName);

  /// Sidebar: the facility name followed by its type.
  ///
  /// In en, this message translates to:
  /// **'{name} {type}'**
  String dashboard_facilityNameType(String name, String type);

  /// Profile panel label before the name.
  ///
  /// In en, this message translates to:
  /// **'Full Name: '**
  String get dashboard_fullNameLabel;

  /// Profile panel label before the email.
  ///
  /// In en, this message translates to:
  /// **'Email: '**
  String get dashboard_emailLabel;

  /// Profile panel label before the phone number.
  ///
  /// In en, this message translates to:
  /// **'Phone: '**
  String get dashboard_phoneLabel;

  /// Profile panel label before the role.
  ///
  /// In en, this message translates to:
  /// **'Role: '**
  String get dashboard_roleLabel;

  /// Profile panel button (admin).
  ///
  /// In en, this message translates to:
  /// **'View Facilities'**
  String get dashboard_viewFacilities;

  /// Profile panel button.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get dashboard_changePassword;

  /// Profile panel logout dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get dashboard_logoutConfirm;

  /// Sidebar item: opens the Stock Store.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get nav_stock;

  /// Sidebar item: opens Sellable Products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get nav_products;

  /// Sidebar item: opens Sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get nav_sales;

  /// Sidebar item: opens Services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get nav_services;

  /// Sidebar item: opens Active Debts.
  ///
  /// In en, this message translates to:
  /// **'Debtors'**
  String get nav_debtors;

  /// Sidebar item: opens Reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get nav_reports;

  /// Sidebar item (platform admins only): opens the operator console.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin'**
  String get nav_platformAdmin;

  /// Insights screen title and the Dashboard button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights_title;

  /// Business Pulse metric.
  ///
  /// In en, this message translates to:
  /// **'Service revenue'**
  String get insights_serviceRevenue;

  /// Business Pulse metric.
  ///
  /// In en, this message translates to:
  /// **'Outstanding payments'**
  String get insights_outstandingPayments;

  /// Business Pulse headline: weekly sales falling.
  ///
  /// In en, this message translates to:
  /// **'Keep an eye on sales this week.'**
  String get insights_watchSales;

  /// Business Pulse headline: nothing recorded.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded yet.'**
  String get insights_noActivity;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Sales are trending upward.'**
  String get insights_salesTrendingUp;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Services are gaining momentum.'**
  String get insights_servicesGaining;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Strong business activity today.'**
  String get insights_strongActivity;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Business is picking up.'**
  String get insights_pickingUp;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Business is steady.'**
  String get insights_steady;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'A quieter day so far.'**
  String get insights_quieter;

  /// Business Pulse headline.
  ///
  /// In en, this message translates to:
  /// **'Customer activity is slowing.'**
  String get insights_slowing;

  /// Business Pulse line about debts.
  ///
  /// In en, this message translates to:
  /// **'No outstanding payments.'**
  String get insights_noOutstanding;

  /// Business Pulse line about debts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding payments are rising - worth following up.'**
  String get insights_outstandingRising;

  /// Business Pulse line about debts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding payments are stable.'**
  String get insights_outstandingStable;

  /// Business Pulse line about debts.
  ///
  /// In en, this message translates to:
  /// **'Outstanding payments are improving.'**
  String get insights_outstandingImproving;

  /// Insights card title.
  ///
  /// In en, this message translates to:
  /// **'Business Pulse'**
  String get insights_businessPulse;

  /// Insights screen when loading failed; error is a friendly message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load insights. {error}'**
  String insights_loadFailed(String error);

  /// Insights chart title.
  ///
  /// In en, this message translates to:
  /// **'Sales - Last 14 Days'**
  String get insights_salesLast14;

  /// Insights chart title.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Products - Last 30 Days'**
  String get insights_topProductsLast30;

  /// Insights chart title.
  ///
  /// In en, this message translates to:
  /// **'Services by Type - Last 30 Days'**
  String get insights_servicesByTypeLast30;

  /// Insights sales chart summary.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount} over 14 days'**
  String insights_totalOver14(String amount);

  /// Insights products chart summary.
  ///
  /// In en, this message translates to:
  /// **'Top seller: {name} · {amount}'**
  String insights_topSeller(String name, String amount);

  /// Insights services chart summary.
  ///
  /// In en, this message translates to:
  /// **'Most requested: {name} - {amount}'**
  String insights_mostRequested(String name, String amount);

  /// Insights sales chart when empty.
  ///
  /// In en, this message translates to:
  /// **'No sales in the last 14 days.'**
  String get insights_noSales14;

  /// Insights products chart when empty.
  ///
  /// In en, this message translates to:
  /// **'No sales in the last 30 days.'**
  String get insights_noSales30;

  /// Insights services chart when empty.
  ///
  /// In en, this message translates to:
  /// **'No services in the last 30 days.'**
  String get insights_noServices30;

  /// Notifications screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'All updates and alerts from your facility'**
  String get notifications_subtitle;

  /// Notifications when loading failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load alerts: {error}'**
  String notifications_loadFailed(String error);

  /// Notifications category card.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get notifications_catCritical;

  /// Notifications category card.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get notifications_catStock;

  /// Notifications category card.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get notifications_catPayments;

  /// Notifications category card.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get notifications_catDebts;

  /// Notifications category card.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notifications_catSystem;

  /// Notifications category card (everything else).
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notifications_catUpdates;

  /// Notifications category card: how many are unread.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notifications_unreadCount(int count);

  /// Notifications category card with nothing unread.
  ///
  /// In en, this message translates to:
  /// **'All read'**
  String get notifications_allRead;

  /// Notifications search box.
  ///
  /// In en, this message translates to:
  /// **'Search notifications...'**
  String get notifications_searchHint;

  /// Notifications screen button.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifications_markAllRead;

  /// Notifications dropdown button.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifications_markAllAsRead;

  /// Notifications status filter choice.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifications_unread;

  /// Notifications status filter choice and status chip.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notifications_read;

  /// Notifications status chip of an unread notification.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notifications_statusNew;

  /// Tooltip of the Notifications date filter's clear button.
  ///
  /// In en, this message translates to:
  /// **'Clear date range'**
  String get notifications_clearDateRange;

  /// Notifications when there are none.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifications_empty;

  /// Notifications when there are none.
  ///
  /// In en, this message translates to:
  /// **'New updates from your facility will appear here.'**
  String get notifications_emptyHint;

  /// Notifications when the filters hide everything.
  ///
  /// In en, this message translates to:
  /// **'No notifications match your filters'**
  String get notifications_noMatches;

  /// Notifications table column.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notifications_colNotification;

  /// Under the Notifications table.
  ///
  /// In en, this message translates to:
  /// **'Showing {start} to {end} of {total, plural, =1{1 notification} other{{total} notifications}}'**
  String notifications_showingRange(int start, int end, int total);

  /// Notifications section: subscription and trial notices.
  ///
  /// In en, this message translates to:
  /// **'Your Plan'**
  String get notifications_yourPlan;

  /// Notifications section.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get notifications_needsAttention;

  /// Notifications section.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notifications_earlier;

  /// Notifications section.
  ///
  /// In en, this message translates to:
  /// **'Urgent Announcements'**
  String get notifications_urgentAnnouncements;

  /// Notifications dropdown link to the full screen.
  ///
  /// In en, this message translates to:
  /// **'View all notifications'**
  String get notifications_viewAll;

  /// Notifications dropdown with nothing to show.
  ///
  /// In en, this message translates to:
  /// **'No urgent announcements, subscription issues, or stock alerts right now.'**
  String get notifications_allCaughtUpHint;

  /// Notifications table: category of one notification.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get notifications_catPayment;

  /// Notifications table: category of one notification.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get notifications_catDebt;

  /// Notifications table: category of one notification.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get notifications_catUpdate;

  /// Select Facility screen: loading the facilities timed out.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than expected. Check your connection and try again.'**
  String get selectFacility_slowLoad;

  /// Select Facility screen: loading failed; error is the friendly reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your facilities. {error}'**
  String selectFacility_loadFailed(String error);

  /// Select Facility screen title.
  ///
  /// In en, this message translates to:
  /// **'Select Facility'**
  String get selectFacility_title;

  /// Select Facility screen button after choosing one.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get selectFacility_proceed;

  /// Select Facility card: a facility with no name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get selectFacility_unnamed;

  /// Select Facility card hint: this one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectFacility_selected;

  /// Select Facility card hint on hover.
  ///
  /// In en, this message translates to:
  /// **'Click to select'**
  String get selectFacility_clickToSelect;

  /// Facilities and Select Facility screens: the account has no facility.
  ///
  /// In en, this message translates to:
  /// **'No facilities found.'**
  String get facilities_noneFound;

  /// Facility picker top bar, under the app name.
  ///
  /// In en, this message translates to:
  /// **'Manage. Care. Grow.'**
  String get facilityPicker_tagline;

  /// Facility picker profile menu item.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get facilityPicker_logOut;

  /// Facility picker heading.
  ///
  /// In en, this message translates to:
  /// **'Select Your Facility'**
  String get facilityPicker_title;

  /// Facility picker, under the heading.
  ///
  /// In en, this message translates to:
  /// **'Choose the facility you want to manage. You can switch between your facilities at any time from the top menu.'**
  String get facilityPicker_intro;

  /// Facility picker search field.
  ///
  /// In en, this message translates to:
  /// **'Search facility by name, location or type...'**
  String get facilityPicker_searchHint;

  /// Facility picker type filter: no filter.
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get facilityPicker_allTypes;

  /// Facility picker type filter button when nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get facilityPicker_filter;

  /// Facility picker card: a facility with no name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Facility'**
  String get facilityPicker_unnamedFacility;

  /// Facility picker card: no facility type.
  ///
  /// In en, this message translates to:
  /// **'Type not set'**
  String get facilityPicker_typeNotSet;

  /// Facility picker card: no address.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get facilityPicker_locationNotSet;

  /// Facility picker card: how many people work there.
  ///
  /// In en, this message translates to:
  /// **'{count} Staff'**
  String facilityPicker_staffCount(int count);

  /// Facility picker card button.
  ///
  /// In en, this message translates to:
  /// **'Open Facility'**
  String get facilityPicker_openFacility;

  /// Facility picker card menu item.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get facilityPicker_setAsDefault;

  /// Facility picker card badge on the default facility.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get facilityPicker_default;

  /// Facility picker footer.
  ///
  /// In en, this message translates to:
  /// **'Secure  •  Reliable  •  Built for Veterinary Businesses'**
  String get facilityPicker_footer;

  /// Facility ownership (stored value 'Owned'): Edit Facility dropdown and About card.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get facilityOwnership_owned;

  /// Facility ownership (stored value 'Rented'): Edit Facility dropdown and About card.
  ///
  /// In en, this message translates to:
  /// **'Rented'**
  String get facilityOwnership_rented;

  /// Facilities screen: loading failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load facilities'**
  String get facilities_loadFailed;

  /// Facilities screen: dialog when the account has the most facilities allowed.
  ///
  /// In en, this message translates to:
  /// **'Facility Limit Reached'**
  String get facilities_limitTitle;

  /// Facilities screen: facility limit dialog.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the limit of {max} facilities per account. Contact support if you need more.'**
  String facilities_limitMessage(int max);

  /// Facilities screen: top bar button and Add dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add Facility'**
  String get facilities_addTitle;

  /// Add Facility dialog, under the logo picker.
  ///
  /// In en, this message translates to:
  /// **'Logo (optional)'**
  String get facilities_logoOptional;

  /// Add and Edit Facility dialogs: name field.
  ///
  /// In en, this message translates to:
  /// **'Facility Name'**
  String get facilities_nameLabel;

  /// Add and Edit Facility dialogs: name or type missing.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and select a type'**
  String get facilities_nameAndTypeRequired;

  /// Add Facility dialog button while saving.
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get facilities_adding;

  /// Message after adding a facility.
  ///
  /// In en, this message translates to:
  /// **'Facility added'**
  String get facilities_added;

  /// Edit Facility dialog title and More Actions menu item.
  ///
  /// In en, this message translates to:
  /// **'Edit Facility'**
  String get facilities_editTitle;

  /// Edit Facility dialog, under the logo.
  ///
  /// In en, this message translates to:
  /// **'Tap to change logo'**
  String get facilities_tapToChangeLogo;

  /// Edit Facility dialog button.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get facilities_removeLogo;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Business Email (optional)'**
  String get facilities_businessEmailOptional;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Business Phone (optional)'**
  String get facilities_businessPhoneOptional;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get facilities_addressOptional;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get facilities_descriptionOptional;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Tagline (optional)'**
  String get facilities_taglineOptional;

  /// Edit Facility dialog: example tagline.
  ///
  /// In en, this message translates to:
  /// **'e.g. Agrovet & Animal Care'**
  String get facilities_taglineHint;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'License Number (optional)'**
  String get facilities_licenseOptional;

  /// Edit Facility dialog field (Tax Identification Number).
  ///
  /// In en, this message translates to:
  /// **'TIN (optional)'**
  String get facilities_tinOptional;

  /// Edit Facility dialog: TIN field hint.
  ///
  /// In en, this message translates to:
  /// **'Tax Identification Number'**
  String get facilities_tinHint;

  /// Edit Facility dialog field.
  ///
  /// In en, this message translates to:
  /// **'Ownership (optional)'**
  String get facilities_ownershipOptional;

  /// Edit Facility dialog: restock frequency field.
  ///
  /// In en, this message translates to:
  /// **'How often do you typically restock?'**
  String get facilities_restockQuestion;

  /// Edit Facility dialog: under the restock frequency field.
  ///
  /// In en, this message translates to:
  /// **'Used to suggest smart stock-level defaults from your sales history'**
  String get facilities_restockHelper;

  /// Edit Facility dialog: saving failed; error is the friendly reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the changes. {error}'**
  String facilities_saveFailed(String error);

  /// Message after editing a facility.
  ///
  /// In en, this message translates to:
  /// **'Facility updated'**
  String get facilities_updated;

  /// Shown while Delete Facility checks for assistants.
  ///
  /// In en, this message translates to:
  /// **'Checking that no assistants remain…'**
  String get facilities_checkingAssistants;

  /// Dialog title: the facility still has assistants.
  ///
  /// In en, this message translates to:
  /// **'Cannot Delete Facility'**
  String get facilities_cannotDeleteTitle;

  /// Cannot Delete Facility dialog: how many assistants remain.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This facility still has 1 assistant assigned. Remove or reassign them first, then try again.} other{This facility still has {count} assistants assigned. Remove or reassign all of them first, then try again.}}'**
  String facilities_cannotDeleteMessage(int count);

  /// Delete dialog title and More Actions menu item.
  ///
  /// In en, this message translates to:
  /// **'Delete Facility'**
  String get facilities_deleteTitle;

  /// Delete Facility dialog: what is deleted.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes \"{name}\" and everything in it - products, sales, clients, debts, payments, and history. This cannot be undone.'**
  String facilities_deleteWarning(String name);

  /// Delete Facility dialog: warning when it is the account's only facility.
  ///
  /// In en, this message translates to:
  /// **'This is your only facility. Deleting it leaves your account with no facility - you will stay signed in, and can then add a new one or delete your account.'**
  String get facilities_onlyFacilityWarning;

  /// Delete Facility dialog: name is the exact text to type (the facility's name, never translated).
  ///
  /// In en, this message translates to:
  /// **'Type \"{name}\" to confirm:'**
  String facilities_typeToConfirm(String name);

  /// Delete Facility dialog: deleting failed; error is the friendly reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the facility. {error}'**
  String facilities_deleteFailed(String error);

  /// Message after deleting a facility.
  ///
  /// In en, this message translates to:
  /// **'Facility deleted'**
  String get facilities_deleted;

  /// Facilities screen title and breadcrumb.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get facilities_title;

  /// Facilities screen, under the title.
  ///
  /// In en, this message translates to:
  /// **'Manage all your veterinary facilities and branches'**
  String get facilities_subtitle;

  /// Facilities screen detail area: nothing matches.
  ///
  /// In en, this message translates to:
  /// **'No facilities match your filters. Try a different search or status.'**
  String get facilities_noMatchFilters;

  /// Facilities list search field.
  ///
  /// In en, this message translates to:
  /// **'Search facilities...'**
  String get facilities_searchHint;

  /// Facilities list: nothing matches the status filter.
  ///
  /// In en, this message translates to:
  /// **'No facilities match this filter.'**
  String get facilities_noMatchFilter;

  /// Facilities list and header: the name with its type, e.g. Ukuli Agrovet.
  ///
  /// In en, this message translates to:
  /// **'{name} {type}'**
  String facilities_nameWithType(String name, String type);

  /// Facility detail: tooltip of the More Actions menu.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get facilities_moreActionsTooltip;

  /// Facility detail: menu button.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get facilities_moreActions;

  /// Facility detail: More Actions menu item.
  ///
  /// In en, this message translates to:
  /// **'Switch to This Facility'**
  String get facilities_switchToThis;

  /// Facility detail header: who manages it.
  ///
  /// In en, this message translates to:
  /// **'{name} (Manager)'**
  String facilities_managerLine(String name);

  /// Facility detail header: when the facility was created.
  ///
  /// In en, this message translates to:
  /// **'Joined on {date}'**
  String facilities_joinedOn(String date);

  /// Facility detail header label.
  ///
  /// In en, this message translates to:
  /// **'Facility Code'**
  String get facilities_code;

  /// Facility detail header label.
  ///
  /// In en, this message translates to:
  /// **'License No.'**
  String get facilities_licenseNo;

  /// Facility detail: a value not filled in (license, ownership).
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get facilities_notSet;

  /// Facility activity list: an entry with no type.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get facilities_activityFallback;

  /// Facility metric card link.
  ///
  /// In en, this message translates to:
  /// **'View Products'**
  String get facilities_viewProducts;

  /// Facility metric card link.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get facilities_viewAll;

  /// Facility metric card.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Items'**
  String get facilities_lowStockItems;

  /// Facility metric card link.
  ///
  /// In en, this message translates to:
  /// **'View Items'**
  String get facilities_viewItems;

  /// Facility metric card.
  ///
  /// In en, this message translates to:
  /// **'Expired Items'**
  String get facilities_expiredItems;

  /// Facility metric card.
  ///
  /// In en, this message translates to:
  /// **'Total Sales (This Month)'**
  String get facilities_totalSalesThisMonth;

  /// Facility metric card link.
  ///
  /// In en, this message translates to:
  /// **'View Report'**
  String get facilities_viewReport;

  /// Facility detail tab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get facilities_tabOverview;

  /// Facility detail tab.
  ///
  /// In en, this message translates to:
  /// **'Inventory Summary'**
  String get facilities_tabInventory;

  /// Facility detail tab.
  ///
  /// In en, this message translates to:
  /// **'Sales Summary'**
  String get facilities_tabSales;

  /// Facility detail, Team Members tab.
  ///
  /// In en, this message translates to:
  /// **'Manage this facility\'s team from the Team Members screen.'**
  String get facilities_teamTabMessage;

  /// Facility detail, Team Members tab button.
  ///
  /// In en, this message translates to:
  /// **'Open Team Members'**
  String get facilities_openTeamMembers;

  /// Facility detail, Inventory Summary tab.
  ///
  /// In en, this message translates to:
  /// **'No products in this facility yet.'**
  String get facilities_noProducts;

  /// Facility detail, Inventory Summary card title.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get facilities_byCategory;

  /// Facility detail, Needs Attention card.
  ///
  /// In en, this message translates to:
  /// **'Nothing low on stock or expired right now.'**
  String get facilities_nothingNeedsAttention;

  /// Facility detail, Sales Summary card title.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get facilities_recentSales;

  /// Facility detail, Sales Summary card.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded yet.'**
  String get facilities_noSalesYet;

  /// Facility detail, Recent Sales: a sale with no client.
  ///
  /// In en, this message translates to:
  /// **'Walk-in sale'**
  String get facilities_walkInSale;

  /// Facility detail, Sales Summary: number of sales in the month.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sale} other{{count} sales}}'**
  String facilities_saleCount(int count);

  /// Facility detail, Settings tab card title.
  ///
  /// In en, this message translates to:
  /// **'Facility Actions'**
  String get facilities_actionsTitle;

  /// Facility detail, Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings specific to this facility. For your account, notifications, printer, currency, and app-wide preferences, use the main Settings screen.'**
  String get facilities_actionsIntro;

  /// Facility detail, Settings tab action.
  ///
  /// In en, this message translates to:
  /// **'Edit Facility Details'**
  String get facilities_editDetails;

  /// Facility detail, Settings tab: under Edit Facility Details.
  ///
  /// In en, this message translates to:
  /// **'Name, type, logo, contact info, license, and more.'**
  String get facilities_editDetailsHint;

  /// Facility detail, Settings tab action.
  ///
  /// In en, this message translates to:
  /// **'Deactivate This Facility'**
  String get facilities_deactivateThis;

  /// Facility detail, Settings tab action.
  ///
  /// In en, this message translates to:
  /// **'Reactivate This Facility'**
  String get facilities_reactivateThis;

  /// Facility detail, Settings tab: under Deactivate.
  ///
  /// In en, this message translates to:
  /// **'Marks this facility as inactive. It stays in your list but is flagged as not operating.'**
  String get facilities_deactivateHint;

  /// Facility detail, Settings tab: under Reactivate.
  ///
  /// In en, this message translates to:
  /// **'Marks this facility as active again.'**
  String get facilities_reactivateHint;

  /// Facility detail, Settings tab action.
  ///
  /// In en, this message translates to:
  /// **'Delete This Facility'**
  String get facilities_deleteThis;

  /// Facility detail, Settings tab: under Delete.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes this facility and its data. This cannot be undone.'**
  String get facilities_deleteThisHint;

  /// Facility detail, Settings tab card title.
  ///
  /// In en, this message translates to:
  /// **'Activity Log Retention'**
  String get facilities_retentionTitle;

  /// Facility detail, Settings tab: retention in days.
  ///
  /// In en, this message translates to:
  /// **'Logs older than this are automatically deleted for this facility. Currently: {count} days.'**
  String facilities_retentionText(int count);

  /// Facility detail, Settings tab card title.
  ///
  /// In en, this message translates to:
  /// **'Debt Overdue Threshold'**
  String get facilities_overdueTitle;

  /// Facility detail, Settings tab: overdue threshold in days.
  ///
  /// In en, this message translates to:
  /// **'An unpaid debt is considered overdue once it is older than this many days. Currently: {count} days.'**
  String facilities_overdueText(int count);

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Facility?'**
  String get facilities_deactivateConfirmTitle;

  /// Dialog title.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Facility?'**
  String get facilities_reactivateConfirmTitle;

  /// Deactivate Facility dialog.
  ///
  /// In en, this message translates to:
  /// **'{name} will be marked Inactive. It stays in your facilities list but is flagged as not operating.'**
  String facilities_deactivateConfirm(String name);

  /// Reactivate Facility dialog.
  ///
  /// In en, this message translates to:
  /// **'{name} will be marked Active again.'**
  String facilities_reactivateConfirm(String name);

  /// Message after changing the status; status is the status label.
  ///
  /// In en, this message translates to:
  /// **'Facility marked {status}'**
  String facilities_markedStatus(String status);

  /// Retention dialog title.
  ///
  /// In en, this message translates to:
  /// **'Keep Logs For'**
  String get facilities_keepLogsFor;

  /// Retention dialog: confirm a shorter window.
  ///
  /// In en, this message translates to:
  /// **'Delete Older Logs Now?'**
  String get facilities_deleteOlderLogsTitle;

  /// Retention dialog: confirm a shorter window.
  ///
  /// In en, this message translates to:
  /// **'Logs are currently kept for {current} days. Switching to {selected} days will permanently delete every log older than {selected} days right now - not just going forward. This cannot be undone.'**
  String facilities_deleteOlderLogsMessage(int current, int selected);

  /// Retention dialog button.
  ///
  /// In en, this message translates to:
  /// **'Delete and switch to {count} days'**
  String facilities_deleteAndSwitch(int count);

  /// Retention saved, old logs not deleted yet (the reason follows).
  ///
  /// In en, this message translates to:
  /// **'Saved. Logs older than {count} days will be hidden, but couldn\'t be deleted yet'**
  String facilities_retentionSavedNotDeleted(int count);

  /// Retention saved and old logs deleted.
  ///
  /// In en, this message translates to:
  /// **'Logs will now be kept for {days} days, {count, plural, =1{1 older log} other{{count} older logs}} deleted'**
  String facilities_retentionSavedDeleted(int days, int count);

  /// Retention saved.
  ///
  /// In en, this message translates to:
  /// **'Logs will now be kept for {count} days'**
  String facilities_retentionSaved(int count);

  /// Retention or overdue setting not saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the setting'**
  String get facilities_saveSettingFailed;

  /// Overdue threshold dialog title.
  ///
  /// In en, this message translates to:
  /// **'Overdue After'**
  String get facilities_overdueAfterTitle;

  /// Overdue threshold saved.
  ///
  /// In en, this message translates to:
  /// **'Debts are now overdue after {count} days'**
  String facilities_overdueSaved(int count);

  /// Facility detail, Overview card title.
  ///
  /// In en, this message translates to:
  /// **'About this facility'**
  String get facilities_aboutTitle;

  /// Facility detail, About card row.
  ///
  /// In en, this message translates to:
  /// **'Facility Type'**
  String get facilities_facilityType;

  /// Facility detail, About card row.
  ///
  /// In en, this message translates to:
  /// **'Ownership'**
  String get facilities_ownership;

  /// Facility detail, About card row.
  ///
  /// In en, this message translates to:
  /// **'Created By'**
  String get facilities_createdBy;

  /// Facility detail, About card row.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get facilities_lastUpdated;

  /// Facility detail, Recent Activity link.
  ///
  /// In en, this message translates to:
  /// **'View all activity'**
  String get facilities_viewAllActivity;

  /// Activity Log app bar, line under the title.
  ///
  /// In en, this message translates to:
  /// **'Every recorded action for this facility'**
  String get activity_subtitle;

  /// Activity Log search box hint.
  ///
  /// In en, this message translates to:
  /// **'Search logs...'**
  String get activity_searchHint;

  /// Activity Log, admin button that opens the retention dialog.
  ///
  /// In en, this message translates to:
  /// **'Keeping logs for {count} days'**
  String activity_keepingLogsFor(int count);

  /// Activity Log, empty list.
  ///
  /// In en, this message translates to:
  /// **'No activity logs found'**
  String get activity_empty;

  /// Activity Log, empty list, second line.
  ///
  /// In en, this message translates to:
  /// **'Logs auto-delete after {count} days'**
  String activity_autoDeleteAfter(int count);

  /// Activity Log, nothing matches the chip and search.
  ///
  /// In en, this message translates to:
  /// **'No logs match the selected filters.'**
  String get activity_noMatch;

  /// Activity Log, note shown to assistants above the list.
  ///
  /// In en, this message translates to:
  /// **'You see your own activity, and anything about you. Other team matters are only visible to admins.'**
  String get activity_scopeNote;

  /// Activity Log summary chip: a type (or All) and how many logs it has.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count}'**
  String activity_filterChip(String label, int count);

  /// Activity Log retention: saved, but the delete failed (title).
  ///
  /// In en, this message translates to:
  /// **'Saved - logs older than {count} days are now hidden'**
  String activity_retentionSavedHidden(int count);

  /// Activity Log retention: second line after a failed delete; problem is the reason.
  ///
  /// In en, this message translates to:
  /// **'They could not be deleted yet: {problem}'**
  String activity_retentionNotDeletedDetail(String problem);

  /// Activity Log retention: second line, how many old logs were deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 older log deleted} other{{count} older logs deleted}}'**
  String activity_olderLogsDeleted(int count);

  /// Activity Log retention: the save failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the log retention setting'**
  String get activity_saveRetentionFailed;

  /// Reason old logs could not be deleted (ActivityLogRetention.explainFailure); shown after "They could not be deleted yet:" and in the facility retention message.
  ///
  /// In en, this message translates to:
  /// **'the security rules don\'t currently allow deleting logs'**
  String get activity_retentionNoPermission;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get products_sortNameAsc;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Name (Z-A)'**
  String get products_sortNameDesc;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Price (Low-High)'**
  String get products_sortPriceLowHigh;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Price (High-Low)'**
  String get products_sortPriceHighLow;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Stock (Low-High)'**
  String get products_sortStockLowHigh;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Stock (High-Low)'**
  String get products_sortStockHighLow;

  /// Product sort menu (Sellable Products, Stock Store).
  ///
  /// In en, this message translates to:
  /// **'Expiry (Soonest First)'**
  String get products_sortExpirySoonest;

  /// Payments list: description of a payment that came from a sale.
  ///
  /// In en, this message translates to:
  /// **'Sale payment'**
  String get payments_sourceSale;

  /// Payments list: description of a payment that came from a service.
  ///
  /// In en, this message translates to:
  /// **'Service payment'**
  String get payments_sourceService;

  /// Payments list: description of a debt repayment.
  ///
  /// In en, this message translates to:
  /// **'Debt repayment'**
  String get payments_sourceDebtRepayment;

  /// MembershipService.errorMessage: server unreachable or too slow.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server - check your connection and try again.'**
  String get membership_unreachable;

  /// MembershipService.errorMessage: the sign-in has expired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again and retry.'**
  String get membership_signInAgain;

  /// MembershipService.errorMessage: any other server error with no message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get membership_generic;

  /// Login screen message after a forced sign-out: an admin deactivated the account.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deactivated by an admin.'**
  String get session_deactivatedByAdmin;

  /// Login screen message after a forced sign-out: the session was revoked elsewhere.
  ///
  /// In en, this message translates to:
  /// **'You were signed out because your account was signed out from another device.'**
  String get session_signedOutElsewhere;

  /// Delete sale dialog title (moves the sale to Trash).
  ///
  /// In en, this message translates to:
  /// **'Delete this sale?'**
  String get sales_deleteThisTitle;

  /// Delete sale dialog text when no money was received.
  ///
  /// In en, this message translates to:
  /// **'{invoice} moves to Trash and its stock goes back on the shelf. If it was sold on credit, the client\'s debt is removed too. You can undo this now or restore it from Trash for 30 days.'**
  String sales_deleteToTrashBody(String invoice);

  /// Delete sale dialog text when money was received; paid is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'{invoice} moves to Trash and its stock goes back on the shelf. If it was sold on credit, the client\'s debt is removed too. Money already received ({paid}) stays in your payments. You can undo this now or restore it from Trash for 30 days.'**
  String sales_deleteToTrashBodyPaid(String invoice, String paid);

  /// Message after deleting a sale (with Undo).
  ///
  /// In en, this message translates to:
  /// **'Sale moved to Trash'**
  String get sales_movedToTrash;

  /// Message after a sale is restored (Undo or Trash).
  ///
  /// In en, this message translates to:
  /// **'Sale restored'**
  String get sales_restored;

  /// Second line after a sale is restored.
  ///
  /// In en, this message translates to:
  /// **'Stock, debt and client balance are updated.'**
  String get sales_restoredDetail;

  /// Title when a sale cannot be restored; the reason is the second line.
  ///
  /// In en, this message translates to:
  /// **'Can\'t restore this sale'**
  String get sales_cantRestore;

  /// Delete service dialog title (moves the service to Trash).
  ///
  /// In en, this message translates to:
  /// **'Delete this service?'**
  String get services_deleteThisTitle;

  /// Delete service dialog text when no money was received.
  ///
  /// In en, this message translates to:
  /// **'{invoice} moves to Trash, its stock goes back, and its debt and its expense are removed until you restore it. You can undo this now or restore it from Trash for 30 days.'**
  String services_deleteToTrashBody(String invoice);

  /// Delete service dialog text when money was received; paid is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'{invoice} moves to Trash, its stock goes back, and its debt and its expense are removed until you restore it. Money already received ({paid}) stays in your payments. You can undo this now or restore it from Trash for 30 days.'**
  String services_deleteToTrashBodyPaid(String invoice, String paid);

  /// Message after a service is restored (Undo or Trash).
  ///
  /// In en, this message translates to:
  /// **'Service restored'**
  String get services_restored;

  /// Second line after a service is restored.
  ///
  /// In en, this message translates to:
  /// **'Stock, debt, expense and client balance are updated.'**
  String get services_restoredDetail;

  /// Title when a service cannot be restored; the reason is the second line.
  ///
  /// In en, this message translates to:
  /// **'Can\'t restore this service'**
  String get services_cantRestore;

  /// Extra line after restoring a sale or service deleted by the old version.
  ///
  /// In en, this message translates to:
  /// **'This item was deleted before the update. Check its stock afterwards.'**
  String get trash_restoredOldCopy;

  /// Why a restore was refused: the stock does not cover a product. product is the stored item name.
  ///
  /// In en, this message translates to:
  /// **'Not enough {product} in stock: {needed} needed, {available} left. Add stock first.'**
  String trash_restoreNotEnoughStock(String product, int needed, int available);

  /// Why a restore was refused: the client was deleted.
  ///
  /// In en, this message translates to:
  /// **'The client no longer exists.'**
  String get trash_restoreClientGone;

  /// Why a restore was refused: a product was deleted. product is the stored item name.
  ///
  /// In en, this message translates to:
  /// **'{product} no longer exists.'**
  String trash_restoreProductGone(String product);
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
