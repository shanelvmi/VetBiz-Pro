/// A document in public_announcements (AN1, docs/design/announcements_v2.md):
/// written by the Platform Admin's Announcements tab, read by the login page,
/// the dashboard bell and the notifications screen. firestore.rules lets
/// anyone read it and only a Platform Admin write it.
///
/// Stored names: never rename one without moving the saved data.
class AnnouncementFields {
  AnnouncementFields._();

  static const String kind = 'kind';
  static const String title = 'title';
  static const String message = 'message';
  static const String imageUrl = 'imageUrl';

  /// The poster's Storage path, so the file can be deleted with it.
  static const String imagePath = 'imagePath';
  static const String imageWidth = 'imageWidth';
  static const String imageHeight = 'imageHeight';
  static const String audience = 'audience';
  static const String linkUrl = 'linkUrl';
  static const String linkLabel = 'linkLabel';
  static const String urgent = 'urgent';
  static const String hidden = 'hidden';
  static const String timestamp = 'timestamp';

  /// The Storage folder for posters (storage.rules: announcement_posters/).
  static const String posterFolder = 'announcement_posters';
}

/// What an announcement shows: written text, or a poster image (its words
/// are in the image). [key] is the stored value.
enum AnnouncementKind {
  text('text'),
  poster('poster');

  const AnnouncementKind(this.key);

  final String key;

  /// A document from before AN1 has no kind: it is text. So is an unknown one.
  static AnnouncementKind fromStored(Object? value) =>
      values.firstWhere((k) => k.key == value, orElse: () => text);
}

/// Who sees an announcement: everyone, or only people using the app in
/// English or in Kiswahili. [key] is the stored value.
enum AnnouncementAudience {
  all('all'),
  en('en'),
  sw('sw');

  const AnnouncementAudience(this.key);

  final String key;

  /// A document from before AN1 has no audience: everyone. So does an unknown one.
  static AnnouncementAudience fromStored(Object? value) =>
      values.firstWhere((a) => a.key == value, orElse: () => all);
}
