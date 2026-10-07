/// Network timeouts, retry delays, debounces and polling intervals.
///
/// Not animation (that is AppMotion) and not business date ranges (that is
/// AppRanges). Each value is today's, confirmed at the line named. Step 2C
/// classifies the remaining `Duration(` uses and adds them here.
class AppTimeouts {
  AppTimeouts._();

  // Signing in and deciding the first screen (main.dart).

  /// Outer bound on deciding the first screen after sign-in.
  static const Duration decideFirstScreen = Duration(seconds: 30);

  /// Reading the user's profile.
  static const Duration profileRead = Duration(seconds: 15);

  /// Re-reading a profile that wasn't there yet, and the pause before it.
  static const Duration profileRecheck = Duration(seconds: 10);
  static const Duration profileRecheckDelay = Duration(milliseconds: 700);

  /// Checking for a platform admin record.
  static const Duration platformAdminRead = Duration(seconds: 10);

  /// Waiting for registration to finish writing the facility lists.
  static const Duration facilityListRetry = Duration(seconds: 10);
  static const Duration facilityListRetryDelay = Duration(milliseconds: 800);

  /// Back-off step after an "unavailable" read (multiplied by the attempt).
  static const Duration unavailableRetryStep = Duration(milliseconds: 500);

  /// How often the signed-in user is re-checked, in case the auth stream
  /// misses a change on web.
  static const Duration authPoll = Duration(seconds: 2);

  /// The loading screen offers a way out after this long.
  static const Duration startupRecoveryOffer = Duration(seconds: 8);

  /// Login button safety net: re-enabled if nothing happened by then
  /// (login_screen.dart).
  static const Duration loginSafetyNet = Duration(seconds: 6);

  // Loading data.

  /// The user's role (user_role_provider.dart).
  static const Duration roleLoad = Duration(seconds: 10);

  /// A facility (facility_provider.dart, select_facility_screen.dart).
  static const Duration facilityLoad = Duration(seconds: 15);

  /// Signing out (force_logout.dart).
  static const Duration signOut = Duration(seconds: 10);

  /// The team list shows a fallback after this (manage_assistants_screen.dart).
  static const Duration teamLoadFallback = Duration(seconds: 8);

  /// Uploading a payment proof (subscription_screen.dart).
  static const Duration proofUpload = Duration(seconds: 25);

  // Polling.

  /// Checking for records added by someone else (sales, services, clients,
  /// debtors, payments screens).
  static const Duration newRecordsPoll = Duration(seconds: 45);

  // Debounces (wait for a pause in typing).

  /// List search boxes (sales, services, clients, debtors, payments).
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Client search inside the sale and service forms.
  static const Duration clientPickerDebounce = Duration(milliseconds: 300);

  /// Looking up which facility an invite code leads to (main.dart).
  static const Duration inviteCodeLookupDebounce = Duration(milliseconds: 450);

  /// Looking up a facility while registering (register_screen.dart).
  static const Duration facilityLookupDebounce = Duration(milliseconds: 500);
}
