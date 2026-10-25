/// The document app_config/support_contact: what the Platform Admin types
/// under Contact Details, shown by the Help dialog and the sign-in footer.
/// firestore.rules lets anyone read it, signed in or not.
///
/// Stored names: never rename one without moving the saved data.
class SupportContactFields {
  SupportContactFields._();

  static const String docId = 'support_contact';

  static const String email = 'email';
  static const String phone = 'phone';
  static const String whatsapp = 'whatsapp';
  static const String address = 'address';
}

/// The social networks the sign-in footer can link to, in the order their
/// icons show. [field] is the stored key in the same document.
enum SocialNetwork {
  facebook('facebook'),
  instagram('instagram'),
  x('x'),
  linkedin('linkedin'),
  youtube('youtube'),
  tiktok('tiktok');

  const SocialNetwork(this.field);

  final String field;
}
