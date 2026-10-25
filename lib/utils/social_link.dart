/// The one check for a social link (G3), used where the Platform Admin
/// saves it AND where the sign-in footer reads it: a value that slipped
/// past the form (an old save, a console edit) is checked again before it
/// is ever opened.
class SocialLink {
  SocialLink._();

  static final _scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):');
  static final _space = RegExp(r'\s');

  /// '' when [raw] is empty (allowed: the link is not set); null when it is
  /// not a usable link; otherwise the http or https address to store and open.
  /// A bare host ("facebook.com/x") or a www. address gets https:// added.
  static String? sanitize(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '';
    if (_space.hasMatch(text)) return null;
    // Anything typed with a scheme keeps it, so javascript:, data:, ftp:
    // and the rest are refused below instead of becoming https://javascript:...
    final uri = Uri.tryParse(_scheme.hasMatch(text) ? text : 'https://$text');
    // A dot in the host: a real address, not "vetbiz" or "localhost".
    if (uri == null || !isLaunchable(uri) || !uri.host.contains('.')) return null;
    return uri.toString();
  }

  /// Only http and https addresses with a host are ever launched.
  static bool isLaunchable(Uri uri) => (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}
