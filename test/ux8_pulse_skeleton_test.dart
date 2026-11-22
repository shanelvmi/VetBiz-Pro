// UX8 Fix 4: Business Pulse while its reads run (after the charts have drawn):
// the card in its final shape with skeleton bars, no spinner; the figures
// replace the bars without moving anything.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/widgets/reveal/skeleton_box.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/phone_list_harness.dart';

const _loading = ValueKey('pulse-loading');
const _content = ValueKey('pulse-content');

void main() {
  setUp(InsightsScreen.forgetLastPulse);

  for (final size in const [Size(1200, 800), Size(390, 844)]) {
    ph5TestWidgets('${size.width.toInt()}: the pulse is a skeleton, then its content, in the same place', (tester) async {
      final fs = CountingFirestore()..holdDocGets = Completer<void>();
      await pumpPh5(tester, (_) => InsightsScreen(firestore: fs), size: size, pushed: true, firestore: fs, settle: false);
      // The charts answer (query gets); the pulse still waits for its
      // snapshot (a document get).
      await ph5Settle(tester);
      await ph5SettleUntil(tester, () => find.byKey(_loading).evaluate().isNotEmpty, what: 'the pulse skeleton');
      final loading = find.byKey(_loading);
      expect(find.descendant(of: loading, matching: find.byType(CircularProgressIndicator)), findsNothing);
      expect(find.descendant(of: loading, matching: find.byType(SkeletonOf)), findsNWidgets(2));
      expect(find.descendant(of: loading, matching: find.text('Business Pulse')), findsOneWidget);
      final before = tester.getRect(loading);

      fs.holdDocGets!.complete();
      await ph5SettleUntil(tester, () => find.byKey(_content).evaluate().isNotEmpty, what: 'the pulse content');
      expect(find.byKey(_loading), findsNothing);
      expect(tester.getRect(find.byKey(_content)), before, reason: 'no layout shift');
      expect(find.descendant(of: find.byKey(_content), matching: find.byType(CircularProgressIndicator)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  ph5TestWidgets('a return visit shows the last pulse at once while it refreshes', (tester) async {
    final fs = CountingFirestore();
    await pumpPh5(tester, (_) => InsightsScreen(firestore: fs), size: const Size(1200, 800), pushed: true, firestore: fs);
    await ph5SettleUntil(tester, () => find.byKey(_content).evaluate().isNotEmpty, what: 'the first pulse');
    fs.holdDocGets = Completer<void>();
    await pumpPh5(tester, (_) => InsightsScreen(firestore: fs), size: const Size(1200, 800), pushed: true, firestore: fs, settle: false);
    await tester.pump();
    expect(find.byKey(_content), findsOneWidget, reason: 'the last value, no skeleton');
    expect(find.byKey(_loading), findsNothing);
    fs.holdDocGets!.complete();
    await ph5Settle(tester);
  });
}
