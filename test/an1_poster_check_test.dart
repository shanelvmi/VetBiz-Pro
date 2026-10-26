import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/upload_content_types.dart';
import 'package:vetbiz_pro/utils/poster_image_check.dart';

// AN1 (docs/design/announcements_v2.md section 3), written before the code:
// the poster validator finds the type from the bytes, then refuses a wrong
// type, more than 1 MB, a width under 1280 and a ratio off 16:9 by more than
// 3 percent, each with one clear English sentence.

Uint8List _withHeader(List<int> header, [int size = 64]) =>
    Uint8List(size)..setRange(0, header.length, header);

final _jpeg = _withHeader([0xFF, 0xD8, 0xFF, 0xE0]);
final _png = _withHeader([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final _webp = _withHeader([...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP')]);
final _gif = _withHeader(ascii.encode('GIF89a'));
final _svg = Uint8List.fromList(utf8.encode('<?xml version="1.0"?>\n<svg xmlns="http://www.w3.org/2000/svg"></svg>'));
final _bareSvg = Uint8List.fromList(utf8.encode('  <svg width="1600" height="900"></svg>'));

/// A real PNG of [width] x [height], made by the engine (decodable).
Future<Uint8List> _realPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), ui.Paint()..color = const ui.Color(0xFF336699));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  group('the type comes from the bytes, not the name', () {
    test('JPEG, PNG and WebP are recognised', () {
      expect(PosterImageCheck.typeOf(_jpeg), PosterImageType.jpeg);
      expect(PosterImageCheck.typeOf(_png), PosterImageType.png);
      expect(PosterImageCheck.typeOf(_webp), PosterImageType.webp);
    });

    test('SVG, GIF and anything else are not', () {
      for (final bytes in [_gif, _svg, _bareSvg, Uint8List(64), Uint8List(0)]) {
        expect(PosterImageCheck.typeOf(bytes), isNull);
      }
    });

    test('the stored content types and file extensions are exact (storage.rules isPosterUpload)', () {
      expect(PosterImageType.values.map((t) => t.contentType), ['image/jpeg', 'image/png', 'image/webp']);
      expect(PosterImageType.values.map((t) => t.extension), ['jpg', 'png', 'webp']);
      expect(PosterImageType.cacheControl, 'public, max-age=86400');
      expect(PosterImageType.webp.metadata.contentType, 'image/webp');
      expect(PosterImageType.webp.metadata.cacheControl, 'public, max-age=86400');
    });
  });

  group('checkFile: type and size, before decoding', () {
    test('an SVG and a GIF are refused by name', () {
      expect(PosterImageCheck.checkFile(_svg), PosterImageCheck.svgRefused);
      expect(PosterImageCheck.checkFile(_bareSvg), PosterImageCheck.svgRefused);
      expect(PosterImageCheck.checkFile(_gif), PosterImageCheck.gifRefused);
      expect(PosterImageCheck.svgRefused, contains('SVG'));
      expect(PosterImageCheck.gifRefused, contains('GIF'));
    });

    test('any other file is refused', () {
      expect(PosterImageCheck.checkFile(Uint8List.fromList(utf8.encode('<html></html>'))), PosterImageCheck.typeRefused);
      expect(PosterImageCheck.typeRefused, contains('JPG, PNG or WebP'));
    });

    test('1 MB is allowed; one byte more is refused with the size in the sentence', () {
      expect(PosterImageCheck.checkFile(_withHeader([0xFF, 0xD8, 0xFF], AppLimits.posterMaxBytes)), isNull);
      final tooBig = PosterImageCheck.checkFile(_withHeader([0xFF, 0xD8, 0xFF], (1.4 * AppLimits.posterMaxBytes).round()));
      expect(tooBig, PosterImageCheck.tooLarge((1.4 * AppLimits.posterMaxBytes).round()));
      expect(tooBig, contains('1.4 MB'));
      expect(tooBig, contains('over the 1 MB limit'));
      expect(PosterImageCheck.tooLarge(AppLimits.posterMaxBytes + 1), contains('1.1 MB'));
      expect(PosterImageCheck.checkFile(_withHeader([0xFF, 0xD8, 0xFF], AppLimits.posterMaxBytes + 1)), isNotNull);
    });

    test('JPEG, PNG and WebP within the size pass', () {
      for (final bytes in [_jpeg, _png, _webp]) {
        expect(PosterImageCheck.checkFile(bytes), isNull);
      }
    });
  });

  group('checkSize: width and ratio', () {
    test('1600 x 900 and the minimum 1280 x 720 pass', () {
      expect(PosterImageCheck.checkSize(1600, 900), isNull);
      expect(PosterImageCheck.checkSize(1280, 720), isNull);
    });

    test('narrower than 1280 is refused, even at 16:9', () {
      expect(PosterImageCheck.checkSize(1279, 719), PosterImageCheck.tooNarrow(1279));
      expect(PosterImageCheck.tooNarrow(1024), contains('1024 px'));
      expect(PosterImageCheck.tooNarrow(1024), contains('1280 px'));
    });

    test('within 3 percent of 16:9 passes; beyond it is refused', () {
      // 1600 / 900 = 1.778. 1600 / 875 = 1.829 (+2.9%), 1600 / 927 = 1.726 (-2.9%).
      expect(PosterImageCheck.checkSize(1600, 875), isNull);
      expect(PosterImageCheck.checkSize(1600, 927), isNull);
      // 1600 / 870 = 1.839 (+3.4%), 1600 / 930 = 1.720 (-3.2%), 4:3, square.
      for (final height in [870, 930, 1200, 1600]) {
        expect(PosterImageCheck.checkSize(1600, height), PosterImageCheck.wrongRatio(1600, height), reason: '$height');
      }
      expect(PosterImageCheck.wrongRatio(1600, 1200), contains('1600 x 1200 px'));
      expect(PosterImageCheck.wrongRatio(1600, 1200), contains('16:9'));
    });

    test('a zero height can not divide by zero', () {
      expect(PosterImageCheck.checkSize(1600, 0), isNotNull);
    });
  });

  group('inspect: decodes the picked bytes with decodeImageFromList', () {
    testWidgets('a real 1600 x 900 PNG passes with its size and type', (tester) async {
      await tester.runAsync(() async {
        final result = await PosterImageCheck.inspect(await _realPng(1600, 900));
        expect(result.error, isNull);
        expect(result.image!.type, PosterImageType.png);
        expect(result.image!.width, 1600);
        expect(result.image!.height, 900);
      });
    });

    testWidgets('a real 4:3 PNG and a real narrow PNG are refused after decoding', (tester) async {
      await tester.runAsync(() async {
        expect((await PosterImageCheck.inspect(await _realPng(1600, 1200))).error, PosterImageCheck.wrongRatio(1600, 1200));
        expect((await PosterImageCheck.inspect(await _realPng(640, 360))).error, PosterImageCheck.tooNarrow(640));
      });
    });

    testWidgets('an SVG is refused without being decoded; broken bytes can not be read', (tester) async {
      await tester.runAsync(() async {
        var decoded = false;
        final svg = await PosterImageCheck.inspect(_svg, decode: (_) async {
          decoded = true;
          throw StateError('not reached');
        });
        expect(svg.error, PosterImageCheck.svgRefused);
        expect(decoded, isFalse);
        expect((await PosterImageCheck.inspect(_jpeg)).error, PosterImageCheck.unreadable);
      });
    });
  });
}
