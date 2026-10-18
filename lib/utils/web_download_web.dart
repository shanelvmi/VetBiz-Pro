import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a standard browser file download - the fallback for when
/// the Web Share API's file-sharing fails, which happens reliably on
/// desktop browsers even though the API itself is present. This still
/// gets the receipt onto the user's device (their Downloads folder),
/// just via a different, more universally-supported mechanism than
/// the native share sheet.
void downloadFileWeb(Uint8List bytes, String filename, {String mimeType = 'image/png'}) {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  (web.HTMLAnchorElement()..href = url)
    ..setAttribute('download', filename)
    ..click();
  web.URL.revokeObjectURL(url);
}
