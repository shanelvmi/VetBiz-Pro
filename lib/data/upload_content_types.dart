import 'package:firebase_storage/firebase_storage.dart';

/// The content type sent with every image upload, matching the file
/// name's extension. storage.rules (E4a) refuses an upload that is not
/// `image/*`, and with no metadata the web SDK sends
/// `application/octet-stream`, so an upload without one of these fails.
class UploadContentTypes {
  UploadContentTypes._();

  /// For `.jpg` paths: avatars/, payment_proofs/, product_images/.
  static final SettableMetadata jpeg = SettableMetadata(contentType: 'image/jpeg');

  /// For `.png` paths: user_avatars/, facility_logos/.
  static final SettableMetadata png = SettableMetadata(contentType: 'image/png');
}

/// The three types an announcement poster may be (AN1). storage.rules
/// (isPosterUpload) accepts exactly these content types, so no SVG (it can
/// carry script) and no GIF. [extension] names the file.
enum PosterImageType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const PosterImageType(this.contentType, this.extension);

  final String contentType;
  final String extension;

  /// Browsers and the CDN keep a poster for a day; every upload has a new
  /// file name, so a changed poster is never served stale.
  static const String cacheControl = 'public, max-age=86400';

  /// The real content type and the cache rule, sent with the upload.
  SettableMetadata get metadata => SettableMetadata(contentType: contentType, cacheControl: cacheControl);
}
