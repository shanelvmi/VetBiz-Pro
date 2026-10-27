import 'dart:io';

import 'package:flutter/services.dart';

// AN5: the square test font (Ahem) draws every glyph as wide as it is tall,
// about twice real text, so a test of where a sentence wraps or whether it
// is cut needs a real font. Flutter ships Roboto (the web and Android
// default) in its own cache; `flutter test` sets FLUTTER_ROOT.

/// The family to give a theme's text so it draws in Roboto.
const realFontFamily = 'Roboto';

/// Loads Roboto (regular, medium, bold) once per test file.
Future<void> loadRealFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT is not set: run with flutter test');
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(realFontFamily);
  for (final name in const ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final file = File('$dir/$name');
    if (!file.existsSync()) throw StateError('missing ${file.path}');
    loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()))));
  }
  await loader.load();
}
