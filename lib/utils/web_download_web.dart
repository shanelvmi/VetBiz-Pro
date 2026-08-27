import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a standard browser file download - the fallback for when
/// the Web Share API's file-sharing fails, which happens reliably on
/// desktop browsers even though the API itself is present. This still
/// gets the receipt onto the user's device (their Downloads folder),
/// just via a different, more universally-supported mechanism than
/// the native share sheet.
void downloadFileWeb(Uint8List bytes, String filename, {String mimeType = 'image/png'}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
