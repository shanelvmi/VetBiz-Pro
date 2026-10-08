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

  /// Waits before each try to read the sales summary after a sale is saved
  /// (sales_screen.dart): the write can take a moment to land.
  static const List<Duration> salesSummaryRetryDelays = [
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];

  // Polling and live ticks.

  /// Checking for records added by someone else (sales, services, clients,
  /// debtors, payments screens).
  static const Duration newRecordsPoll = Duration(seconds: 45);

  /// How often the dashboard re-checks that the session is still valid.
  static const Duration sessionCheck = Duration(minutes: 10);

  /// The dashboard's live clock.
  static const Duration clockTick = Duration(seconds: 1);

  /// How often the notifications screen drops notices that have expired.
  static const Duration noticeExpiryTick = Duration(minutes: 1);

  /// Presence: how often this device says "online", and how recent that
  /// must be to count as online (presence_heartbeat.dart).
  static const Duration presenceHeartbeat = Duration(minutes: 2);
  static const Duration presenceOnlineWindow = Duration(minutes: 5);

  /// The login screen's rotating announcements.
  static const Duration loginAnnouncementRotate = Duration(seconds: 6);

  // Sessions.

  /// A platform admin is signed out after this long without activity, with
  /// a warning shortly before (platform_admin_home_screen.dart).
  static const Duration platformAdminInactivity = Duration(minutes: 15);
  static const Duration platformAdminInactivityWarning = Duration(minutes: 1);

  /// "Remind me later" on the dashboard's subscription notice.
  static const Duration subscriptionNoticeSnooze = Duration(hours: 2);

  // Refreshing a screen's summary after a change. Two values on purpose
  // (decided by the owner, Phase 2 open questions).

  /// Sales summary (sales_screen.dart).
  static const Duration salesSummaryRefresh = Duration(seconds: 2);

  /// Services summary (services_screen.dart).
  static const Duration servicesSummaryRefresh = Duration(milliseconds: 500);

  // Debounces (wait for a pause in typing).

  /// List search boxes (sales, services, clients, debtors, payments).
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Client search inside the sale and service forms.
  static const Duration clientPickerDebounce = Duration(milliseconds: 300);

  /// Looking up which facility an invite code leads to (main.dart).
  static const Duration inviteCodeLookupDebounce = Duration(milliseconds: 450);

  /// Looking up a facility while registering (register_screen.dart).
  static const Duration facilityLookupDebounce = Duration(milliseconds: 500);

  /// Pause before opening the Dashboard after picking a facility
  /// (facility_activation.dart): must clear AppEntryPoint's 220 ms
  /// switcher, see the comment there.
  static const Duration dashboardNavDelay = Duration(milliseconds: 300);

  /// How long the "Setting up..." screen gives the facility's listeners
  /// before the Dashboard shows (facility_activation.dart).
  static const Duration dashboardEntryGrace = Duration(milliseconds: 900);
}
