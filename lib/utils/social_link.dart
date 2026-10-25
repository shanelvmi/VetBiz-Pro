/// The one check for a social link (G3), used where the Platform Admin
/// saves it AND where the sign-in footer reads it: a value that slipped
/// past the form (an old save, a console edit) is checked again before it
/// is ever opened.
class SocialLink {
  SocialLink._();

  /// '' when [raw] is empty (allowed: the link is not set); null when it is
  /// not a usable link; otherwise the http or https address to store and open.
  /// A bare host ("facebook.com/x") or a www. address gets https:// added.
  static String? sanitize(String? raw) {
    throw UnimplementedError('G3: SocialLink.sanitize');
  }

  /// Only http and https addresses with a host are ever launched.
  static bool isLaunchable(Uri uri) {
    throw UnimplementedError('G3: SocialLink.isLaunchable');
  }
}
