/// Business numbers.
///
/// [inviteCodeLength] and [inviteAlphabet] must equal INVITE_CODE_LENGTH and
/// INVITE_ALPHABET in functions/membership.js; a server test compares them
/// (added in step 2B).
class AppRules {
  AppRules._();

  static const int inviteCodeLength = 6;
  static const String inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// A subscription needs attention this many days before it ends
  /// (SubscriptionProvider.attentionThresholdDays).
  static const int subscriptionAttentionDays = 7;

  /// Shortest password the login form accepts (login_screen.dart).
  static const int minPasswordLength = 6;
}
