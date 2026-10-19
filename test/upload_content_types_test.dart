import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/upload_content_types.dart';

// storage.rules (E4a) refuses any upload whose content type is not image/*,
// and an upload with no metadata arrives as application/octet-stream. So
// every putData in the app must pass one of these.
void main() {
  test('the two upload content types are images', () {
    expect(UploadContentTypes.jpeg.contentType, 'image/jpeg');
    expect(UploadContentTypes.png.contentType, 'image/png');
  });

  test('every putData in lib/ sends an UploadContentTypes value', () {
    final missing = <String>[];
    var found = 0;
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('putData(')) continue;
        found++;
        if (!lines[i].contains('UploadContentTypes.')) missing.add('${file.path}:${i + 1}');
      }
    }
    expect(found, greaterThan(0));
    expect(missing, isEmpty);
  });
}
