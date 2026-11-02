// PH6: the expired-stock dialog (Move to Stock) and the release dialog
// become full-width sheets on phones, their fields at least 48 high and
// their actions pinned at the bottom; on wider screens they stay today's
// dialogs (the wide fingerprints hold them). Each at 360x740, 390x844 and
// 740x360 in Light, Dark and Kiswahili, with a long product name.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

void main() {
  for (final (name, title, primary) in const [
    ('move-expired', 'Move to Stock', 'Move to Stock'),
    ('release', 'Release to Shelf', 'Release'),
  ]) {
    group(name, () {
      ph5TestWidgets('a full-width sheet on a phone, the actions pinned at its bottom', (tester) async {
        await pumpPh6(tester, name);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.getSize(find.byType(BottomSheet)).width, 390);
        final action = find.descendant(of: find.byType(BottomSheet), matching: find.text(primary)).last;
        expect(tester.getBottomLeft(action).dy, greaterThan(844 - 80));
        for (final field in find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).evaluate()) {
          expect((field.renderObject! as RenderBox).size.height, greaterThanOrEqualTo(48));
        }
        expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(title)), findsWidgets);
      }, skip: _skip);

      ph5TestWidgets('Cancel closes it', (tester) async {
        await pumpPh6(tester, name);
        await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Cancel')));
        await ph5Settle(tester);
        expect(find.byType(BottomSheet), findsNothing);
      }, skip: _skip);

      ph5TestWidgets('still today\'s dialog on a computer', (tester) async {
        await pumpPh6(tester, name, size: const Size(1200, 800));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      }, skip: _skip);

      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '$name ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh6(tester, name, size: size.size, look: look);
            await checkCase(tester, phone: true, where: where);
          }, skip: _skip);
        }
      }
    });
  }

  ph5TestWidgets('move-expired: a quantity over the batch shows its message in the sheet', (tester) async {
    await pumpPh6(tester, 'move-expired');
    final qty = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first;
    await tester.enterText(qty, '99');
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Move to Stock')).last);
    await ph5Settle(tester);
    expect(find.text('Enter a quantity up to 12'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  }, skip: _skip);
}
