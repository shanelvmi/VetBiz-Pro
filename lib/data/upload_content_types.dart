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
