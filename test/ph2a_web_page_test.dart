import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

// PH2a: the web page's own texts and the installed app's manifest
// (docs/design/phone_foundations.md risk 10, S10, and the owner's answers 3
// and 4). Seen when the link is shared, saved to a home screen or installed.
const _skip = false;

const _name = AppInfo.name;
const _description = 'Records for agrovets and veterinary centres.';

/// '#2F5D62' from a colour (alpha dropped).
String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The content of `<meta name="[name]" content="...">`.
String? _meta(String html, String name) =>
    RegExp('<meta\\s+name="${RegExp.escape(name)}"\\s+content="([^"]*)"').firstMatch(html)?.group(1);

void main() {
  final html = File('web/index.html').readAsStringSync();
  final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;

  test('the Pasture colours, read from the theme tokens', () {
    expect(_hex(AppPalette.primary), '#2F5D62');
    expect(_hex(AppPalette.background), '#FDFDF9');
  });

  group('web/index.html', () {
    test('the tab title and the iOS home screen title are the app name', () {
      expect(RegExp('<title>([^<]*)</title>').firstMatch(html)?.group(1), _name);
      expect(_meta(html, 'apple-mobile-web-app-title'), _name);
    }, skip: _skip);

    test('the description is the owner\'s sentence, the language English', () {
      expect(_meta(html, 'description'), _description);
      expect(html, contains('<html lang="en">'));
    }, skip: _skip);

    test('the browser bar takes the Pasture primary', () {
      expect(_meta(html, 'theme-color')?.toUpperCase(), _hex(AppPalette.primary));
    }, skip: _skip);

    test('no viewport-fit=cover yet (PH3 decides it on real devices)', () {
      expect(html, isNot(contains('viewport-fit')));
    });
  });

  group('web/manifest.json', () {
    test('name, short name and description', () {
      expect(manifest['name'], _name);
      expect(manifest['short_name'], _name);
      expect(manifest['description'], _description);
    }, skip: _skip);

    test('the installed app may turn (the owner\'s answer 3)', () {
      expect(manifest['orientation'], 'any');
    }, skip: _skip);

    test('the colours come from the Pasture palette', () {
      expect((manifest['theme_color'] as String).toUpperCase(), _hex(AppPalette.primary));
      expect((manifest['background_color'] as String).toUpperCase(), _hex(AppPalette.background));
    }, skip: _skip);

    test('every icon is listed with a size and type, and its file exists', () {
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons, isNotEmpty);
      final sizes = <String>{};
      for (final icon in icons) {
        final src = icon['src'] as String;
        expect(File('web/$src').existsSync(), isTrue, reason: src);
        expect(icon['type'], 'image/png', reason: src);
        final size = icon['sizes'] as String;
        expect(size, matches(RegExp(r'^\d+x\d+$')), reason: src);
        // The file's own size matches the one listed (the PNG header).
        final bytes = File('web/$src').readAsBytesSync();
        final w = bytes.buffer.asByteData().getUint32(16);
        final h = bytes.buffer.asByteData().getUint32(20);
        expect('${w}x$h', size, reason: src);
        sizes.add(size);
      }
      // An installable web app needs 192 and 512.
      expect(sizes, containsAll(['192x192', '512x512']));
    });
  });
}
