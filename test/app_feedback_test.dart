import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';

/// PHASE2_FEEDBACK_SPEC section 11, 2D-0 tests.
void main() {
  Future<void> pumpApp(WidgetTester tester, {Size size = const Size(1200, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: AppFeedback.messengerKey,
      theme: AppTheme.build(AppColorTheme.kilimanjaro, Brightness.light),
      home: const Scaffold(body: SizedBox.expand()),
    ));
  }

  // Let the SnackBar's own entrance animation and the card's fade finish.
  Future<void> settleIn(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('does nothing (and does not throw) before the app is up', (tester) async {
    AppFeedback.success('Too early');
    AppFeedback.error('Too early', error: Exception('x'));
    await tester.pump();
    expect(find.text('Too early'), findsNothing);
  });

  testWidgets('one at a time: a new message replaces the current one', (tester) async {
    await pumpApp(tester);
    AppFeedback.success('Product saved');
    await settleIn(tester);
    expect(find.text('Product saved'), findsOneWidget);

    AppFeedback.info('Recalculating smart defaults…');
    await settleIn(tester);
    expect(find.text('Product saved'), findsNothing);
    expect(find.text('Recalculating smart defaults…'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('each type dismisses itself after its own time', (tester) async {
    await pumpApp(tester);
    final cases = <(void Function(), String, Duration)>[
      (() => AppFeedback.success('S'), 'S', AppMotion.toastSuccess),
      (() => AppFeedback.info('I'), 'I', AppMotion.toastInfo),
      (() => AppFeedback.warning('W'), 'W', AppMotion.toastWarning),
      (() => AppFeedback.error('E'), 'E', AppMotion.toastError),
      (() => AppFeedback.undo('U', onUndo: () {}), 'U', AppMotion.toastUndo),
    ];
    for (final (show, text, duration) in cases) {
      show();
      await tester.pump();
      await tester.pump(duration - const Duration(milliseconds: 100));
      expect(find.text(text), findsOneWidget, reason: '$text still up just before $duration');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing, reason: '$text gone after $duration');
    }
  });

  testWidgets('Undo runs the callback and dismisses the message', (tester) async {
    await pumpApp(tester);
    var undone = 0;
    AppFeedback.undo('Product moved to Trash', onUndo: () => undone++);
    await settleIn(tester);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Product moved to Trash'), findsNothing);
  });

  testWidgets('an error never shows raw exception text; Details reveals it', (tester) async {
    await pumpApp(tester);
    AppFeedback.error("Couldn't save the product", error: Exception('[cloud_firestore/permission-denied] x'));
    await settleIn(tester);
    expect(find.text("Couldn't save the product"), findsOneWidget);
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('[cloud_firestore/permission-denied] x'), findsOneWidget);
  });

  testWidgets('Retry runs the callback', (tester) async {
    await pumpApp(tester);
    var retried = 0;
    AppFeedback.error("Couldn't submit the payment", error: Exception('x'), onRetry: () => retried++);
    await settleIn(tester);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, 1);
    expect(find.text("Couldn't submit the payment"), findsNothing);
  });

  testWidgets('the close button dismisses', (tester) async {
    await pumpApp(tester);
    AppFeedback.warning('Select a client to record a partial payment');
    await settleIn(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Select a client to record a partial payment'), findsNothing);
  });

  testWidgets('a message with an action stays while the pointer is over it', (tester) async {
    await pumpApp(tester);
    AppFeedback.undo('Product moved to Trash', onUndo: () {});
    await settleIn(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Product moved to Trash')));
    await tester.pump(AppMotion.toastUndo * 2);
    expect(find.text('Product moved to Trash'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(AppMotion.toastUndo + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Product moved to Trash'), findsNothing);
  });

  // The card is the nearest Material around the message (the SnackBar itself
  // spans the screen and centres it).
  Finder card(String text) => find.ancestor(of: find.text(text), matching: find.byType(Material)).first;

  testWidgets('width: a 400 card on wide screens, full width less margins on a phone', (tester) async {
    await pumpApp(tester);
    AppFeedback.success('Wide');
    await settleIn(tester);
    expect(tester.getSize(card('Wide')).width, 400);

    await pumpApp(tester, size: const Size(390, 800));
    AppFeedback.success('Narrow');
    await settleIn(tester);
    expect(tester.getSize(card('Narrow')).width, 390 - 2 * 12);
  });
}
