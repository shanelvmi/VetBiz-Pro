import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/utils/upload_size_check.dart';

// E4a-fix: storage.rules refuses an upload over 5 MB. The pickers scale
// images down at the source; UploadSizeCheck stops what is still too large.
void main() {
  test('the limit is 5 MB, the same number storage.rules uses', () {
    expect(AppLimits.maxUploadBytes, 5 * 1024 * 1024);
    final rules = File('storage.rules').readAsStringSync();
    expect(rules, contains('request.resource.size <= 5 * 1024 * 1024'));
  });

  test('fits: up to the limit inclusive, refused one byte over', () {
    expect(UploadSizeCheck.fits(0), isTrue);
    expect(UploadSizeCheck.fits(AppLimits.maxUploadBytes), isTrue);
    expect(UploadSizeCheck.fits(AppLimits.maxUploadBytes + 1), isFalse);
  });

  group('allow', () {
    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: AppFeedback.messengerKey,
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        home: const Scaffold(body: SizedBox.expand()),
      ));
    }

    Future<void> settleIn(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a photo within the limit passes with no message', (tester) async {
      await pumpApp(tester);
      expect(UploadSizeCheck.allow(Uint8List(AppLimits.maxUploadBytes)), isTrue);
      await settleIn(tester);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a photo over the limit is refused with the friendly error', (tester) async {
      await pumpApp(tester);
      expect(UploadSizeCheck.allow(Uint8List(AppLimits.maxUploadBytes + 1)), isFalse);
      await settleIn(tester);
      expect(find.text('This photo is too large. Choose a smaller one.'), findsOneWidget);
    });
  });

  // Every pickImage in lib/ feeds an upload (avatars, logos, product
  // images, payment proofs), so each one must scale the
  // image down with the named limits and run the size check on its bytes.
  test('every pickImage call scales down and checks the size', () {
    final problems = <String>[];
    var found = 0;
    final call = RegExp(r'\.pickImage\(');
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in call.allMatches(source)) {
        found++;
        final args = _argumentsFrom(source, match.end);
        final where = '${file.path} at offset ${match.start}';
        if (!RegExp(r'maxWidth:\s*AppLimits\.\w+ImageMaxSide').hasMatch(args)) {
          problems.add('$where: no maxWidth from AppLimits');
        }
        if (!RegExp(r'maxHeight:\s*AppLimits\.\w+ImageMaxSide').hasMatch(args)) {
          problems.add('$where: no maxHeight from AppLimits');
        }
        if (!args.contains('imageQuality: AppLimits.pickedImageQuality')) {
          problems.add('$where: no imageQuality from AppLimits');
        }
      }
      final picks = call.allMatches(source).length;
      final checks = 'UploadSizeCheck.allow('.allMatches(source).length;
      if (checks < picks) problems.add('${file.path}: $picks pickImage, $checks size checks');
    }
    // dashboard avatar, register avatar, two facility logos, business
    // logo, payment proof, product image (the login poster went in G1).
    expect(found, 7);
    expect(problems, isEmpty);
  });
}

/// The text between the call's opening parenthesis (just before [start])
/// and its matching closing one.
String _argumentsFrom(String source, int start) {
  var depth = 1;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(start, i);
  }
  return source.substring(start);
}
