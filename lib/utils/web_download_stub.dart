import 'dart:typed_data';

/// No-op on non-web platforms - this fallback exists specifically for
/// desktop browsers, where the Web Share API's file-sharing support is
/// well known to be unreliable even though the API itself exists.
/// Native platforms (mobile, desktop apps) already share files
/// reliably through Share.shareXFiles and the OS's own share sheet,
/// so this is never actually reached there.
void downloadFileWeb(Uint8List bytes, String filename) {}
