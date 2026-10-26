import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../config/app_limits.dart';
import '../data/upload_content_types.dart';

/// A picked poster that passed [PosterImageCheck.inspect]: the bytes to
/// upload, their real type and their size in pixels.
class PosterImage {
  const PosterImage({required this.bytes, required this.type, required this.width, required this.height});

  final Uint8List bytes;
  final PosterImageType type;
  final int width;
  final int height;
}

/// Either a [PosterImage] or the sentence that says why it was refused.
class PosterCheckResult {
  const PosterCheckResult.ok(PosterImage this.image) : error = null;
  const PosterCheckResult.refused(String this.error) : image = null;

  final PosterImage? image;
  final String? error;
}

/// The one check for an announcement poster (AN1, docs/design/announcements_v2.md
/// section 3), run on the picked bytes before anything is uploaded.
/// storage.rules refuses the same types and sizes, but its refusal is only a
/// generic error. The sentences are English: the operator console is (spec 2.8).
class PosterImageCheck {
  PosterImageCheck._();

  static const String svgRefused = 'This file is an SVG. Choose a JPG, PNG or WebP image.';
  static const String gifRefused = 'This file is a GIF. Choose a JPG, PNG or WebP image.';
  static const String typeRefused = 'This file is not a JPG, PNG or WebP image.';
  static const String unreadable = 'This image could not be read. Choose another JPG, PNG or WebP file.';

  static String tooLarge(int byteCount) =>
      // Rounded up, so 1 MB and one byte reads 1.1 MB, not 1.0.
      'This image is ${(byteCount / (1024 * 1024) * 10).ceil() / 10} MB, over the '
      '${AppLimits.posterMaxBytes ~/ (1024 * 1024)} MB limit. Save it as JPG or WebP at a lower quality.';

  static String tooNarrow(int width) =>
      'This image is $width px wide. A poster must be at least ${AppLimits.posterMinWidth} px wide '
      '(${AppLimits.posterWidth.round()} x ${_heightFor(AppLimits.posterWidth.round())} px is best).';

  static String wrongRatio(int width, int height) =>
      'This image is $width x $height px, not 16:9. Crop it to 16:9, for example '
      '${AppLimits.posterWidth.round()} x ${_heightFor(AppLimits.posterWidth.round())} px.';

  static int _heightFor(int width) => (width / AppLimits.posterAspectRatio).round();

  static final _riff = ascii.encode('RIFF');
  static final _webp = ascii.encode('WEBP');
  static final _gif = ascii.encode('GIF8');
  static final _svgTag = RegExp(r'<svg[\s>]', caseSensitive: false);

  static bool _startsWith(Uint8List bytes, List<int> prefix, [int at = 0]) {
    if (bytes.length < at + prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[at + i] != prefix[i]) return false;
    }
    return true;
  }

  /// The type the bytes really are (their first bytes, not the file name),
  /// or null when they are none of the three allowed.
  static PosterImageType? typeOf(Uint8List bytes) {
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return PosterImageType.jpeg;
    if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return PosterImageType.png;
    if (_startsWith(bytes, _riff) && _startsWith(bytes, _webp, 8)) return PosterImageType.webp;
    return null;
  }

  static bool _isSvg(Uint8List bytes) {
    // An SVG is text: look for its tag near the start.
    final head = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    return _svgTag.hasMatch(utf8.decode(head, allowMalformed: true));
  }

  /// The type and the size, checked before decoding. Null when they pass.
  static String? checkFile(Uint8List bytes) {
    if (typeOf(bytes) == null) {
      if (_startsWith(bytes, _gif)) return gifRefused;
      if (_isSvg(bytes)) return svgRefused;
      return typeRefused;
    }
    if (bytes.lengthInBytes > AppLimits.posterMaxBytes) return tooLarge(bytes.lengthInBytes);
    return null;
  }

  /// The width and the 16:9 ratio. Null when they pass.
  static String? checkSize(int width, int height) {
    if (width < AppLimits.posterMinWidth) return tooNarrow(width);
    if (height <= 0) return wrongRatio(width, height);
    final off = (width / height / AppLimits.posterAspectRatio - 1).abs();
    if (off > AppLimits.posterRatioTolerance) return wrongRatio(width, height);
    return null;
  }

  /// Checks the picked [bytes]: type and size first (an SVG is never
  /// decoded), then decodes them ([decode] is decodeImageFromList; a fake in
  /// tests) for the width and the ratio.
  static Future<PosterCheckResult> inspect(Uint8List bytes, {Future<ui.Image> Function(Uint8List)? decode}) async {
    final fileProblem = checkFile(bytes);
    if (fileProblem != null) return PosterCheckResult.refused(fileProblem);
    final int width;
    final int height;
    try {
      final image = await (decode ?? decodeImageFromList)(bytes);
      width = image.width;
      height = image.height;
      image.dispose();
    } catch (_) {
      return const PosterCheckResult.refused(unreadable);
    }
    final sizeProblem = checkSize(width, height);
    if (sizeProblem != null) return PosterCheckResult.refused(sizeProblem);
    return PosterCheckResult.ok(PosterImage(bytes: bytes, type: typeOf(bytes)!, width: width, height: height));
  }
}
