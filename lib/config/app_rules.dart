/// Business numbers.
///
/// The ones the server or the Firestore rules also know are marked
/// "Mirrored in ..." and test-linked: functions/test/endpoints.test.js reads
/// both sides as text and fails if they differ or if either can't be found.
/// Change one side, change the other.
class AppRules {
  AppRules._();

  // Mirrored in functions/membership.js (INVITE_CODE_LENGTH).
  static const int inviteCodeLength = 6;
  // Mirrored in functions/membership.js (INVITE_ALPHABET).
  static const String inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// How long an invite code stays usable after it's created.
  // Mirrored in functions/membership.js (INVITE_VALIDITY_MS).
  static const Duration inviteValidity = Duration(hours: 48);

  /// Days after a subscription or trial ends before the facility locks.
  // Mirrored in firestore.rules (isSubscriptionLocked) and functions/index.js (kGracePeriodDays).
  static const int gracePeriodDays = 3;
  static const Duration gracePeriod = Duration(days: gracePeriodDays);

  /// A subscription needs attention this many days before it ends
  /// (SubscriptionProvider.attentionThresholdDays).
  // Mirrored in functions/index.js (kAttentionThresholdDays).
  static const int subscriptionAttentionDays = 7;

  /// How long something stays in Trash before it's purged for good.
  // Mirrored in functions/index.js (TRASH_RETENTION_DAYS).
  static const int trashRetentionDays = 30;
  static const Duration trashRetention = Duration(days: trashRetentionDays);

  /// Fallbacks for values the platform admin sets in platform_config/settings
  /// (spec principle 7): used only until that document is read, or if it
  /// has no value. The setting itself always wins.
  // Mirrored in functions/membership.js (DEFAULT_MAX_FACILITIES).
  static const int defaultMaxFacilitiesPerAdmin = 6;
  // Mirrored in functions/membership.js (DEFAULT_TRIAL_DAYS).
  static const int defaultTrialDays = 14;

  /// Activity log: the choices a facility admin has for how long logs are
  /// kept, and the default when none has been chosen.
  static const List<int> activityLogRetentionOptions = [14, 30, 60, 90];
  static const int activityLogRetentionDefaultDays = 90;

  /// When a sale or service has no receipt number, the first this-many
  /// characters of its id are shown in its place (receipts, PDFs, the daily
  /// report).
  static const int fallbackReceiptIdLength = 6;

  /// Shortest password the login form accepts (login_screen.dart).
  static const int minPasswordLength = 6;
}
