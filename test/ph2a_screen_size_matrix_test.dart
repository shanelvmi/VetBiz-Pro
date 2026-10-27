import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';

import 'helpers/screen_size_matrix.dart';

// PH2a: the matrix helper itself catches what it should.
void main() {
  testWidgets('it sets the window size and the language, and resets them', (tester) async {
    late Size size;
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      look: MatrixLook.kiswahili,
      screen: Builder(builder: (context) {
        size = MediaQuery.sizeOf(context);
        return const SizedBox();
      }),
    );
    expect(size, const Size(390, 844));
    expect(L10n.locale.languageCode, 'sw');
    await checkCase(tester, phone: true, where: 'empty');
  });

  testWidgets('an overflow is caught', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(360, 740),
      screen: const Scaffold(body: Row(children: [SizedBox(width: 400, height: 10)])),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('text under 12 px is found; icons and a keyed badge are not', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(360, 740),
      screen: const Scaffold(
        body: Column(children: [
          Text('tiny', style: TextStyle(fontSize: 10)),
          Text('fine', style: TextStyle(fontSize: 12)),
          Icon(Icons.close, size: 8),
          KeyedSubtree(key: matrixSmallTextAllowed, child: Text('9', style: TextStyle(fontSize: 9))),
          Text.rich(TextSpan(text: 'a ', children: [TextSpan(text: 'small', style: TextStyle(fontSize: 11))])),
        ]),
      ),
    );
    expect(smallTexts(tester), ['"tiny" 10.0 px', '"small" 11.0 px']);
  });

  testWidgets('a small tap target fails on a phone', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(360, 740),
      screen: Scaffold(
        body: Center(child: SizedBox(width: 20, height: 20, child: GestureDetector(onTap: () {}, child: const Text('x')))),
      ),
    );
    final semantics = tester.ensureSemantics();
    final result = await androidTapTargetGuideline.evaluate(tester);
    expect(result.passed, isFalse);
    expect(result.reason, contains('Size(20.0, 20.0)'));
    semantics.dispose();
  });
}
