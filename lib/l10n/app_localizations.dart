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
  /// **'Loading...'**
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
