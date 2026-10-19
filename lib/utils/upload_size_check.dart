import 'dart:typed_data';

import '../config/app_limits.dart';
import '../l10n/l10n.dart';
import '../ui/feedback/app_feedback.dart';

/// The safety net behind the pickers' maxWidth and imageQuality (E4a-fix).
/// storage.rules refuses an upload over [AppLimits.maxUploadBytes], and a
/// refused upload only shows a generic error, so a picked image that is
/// still too large after scaling is stopped here, with a sentence that
/// tells the person what to do.
class UploadSizeCheck {
  UploadSizeCheck._();

  /// Whether [byteCount] bytes are within the upload limit.
  static bool fits(int byteCount) => byteCount <= AppLimits.maxUploadBytes;

  /// True when [bytes] may be uploaded. Otherwise shows the error and
  /// returns false: the caller then neither keeps nor uploads them.
  static bool allow(Uint8List bytes) {
    if (fits(bytes.lengthInBytes)) return true;
    AppFeedback.error(L10n.current.error_photoTooLarge);
    return false;
  }
}
