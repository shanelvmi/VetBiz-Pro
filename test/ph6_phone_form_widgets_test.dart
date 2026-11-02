// PH6 engine (lib/widgets/phone_form/): the action bar pinned above the
// keyboard, the discard check and its two answers, the picker sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/phone_form/form_action_bar.dart';
import 'package:vetbiz_pro/widgets/phone_form/phone_discard_scope.dart';
import 'package:vetbiz_pro/widgets/phone_form/picker_sheet.dart';

const _skip = false;

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, Widget home, {Size size = const Size(390, 844), bool settle = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// A first page with a button that opens a form whose dirtiness the test sets.
class _Host extends StatelessWidget {
  final ValueNotifier<bool> dirty;
  const _Host(this.dirty);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (formContext) => PhoneDiscardScope(
              kind: 'payment',
              isDirty: () => dirty.value,
              child: Scaffold(
                appBar: AppBar(title: const Text('FORM')),
                body: TextButton(onPressed: () => Navigator.of(formContext).pop(), child: const Text('SAVE')),
              ),
            ),
          )),
          child: const Text('OPEN'),
        ),
      );
}

void main() {
  group('FormActionBar', () {
    Widget form({bool busy = false}) => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: FormActionBar(
            primaryLabel: 'Record Payment',
            onPrimary: () {},
            busy: busy,
            secondaryLabel: 'Cancel',
            onSecondary: () {},
            summary: const Text('3 items'),
          ),
        );

    testWidgets('at the bottom; buttons at least 48 high; the primary takes the rest of the width', (tester) async {
      await _pump(tester, form());
      final primary = tester.getRect(_key('formActionBar-primary'));
      expect(primary.height, greaterThanOrEqualTo(48));
      expect(tester.getRect(_key('formActionBar-secondary')).height, greaterThanOrEqualTo(48));
      expect(primary.right, closeTo(390 - 16, 0.5));
      expect(tester.getRect(_key('formActionBar')).bottom, 844);
      expect(find.text('3 items'), findsOneWidget);
    }, skip: _skip);

    testWidgets('rises above a 300 px keyboard', (tester) async {
      await _pump(tester, form());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('formActionBar-primary')).bottom, lessThanOrEqualTo(844 - 300));
    }, skip: _skip);

    testWidgets('while busy both buttons are off and a spinner shows', (tester) async {
      await _pump(tester, form(busy: true), settle: false);
      expect(tester.widget<FilledButton>(_key('formActionBar-primary')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(_key('formActionBar-secondary')).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }, skip: _skip);
  });

  group('PhoneDiscardScope', () {
    Future<ValueNotifier<bool>> open(WidgetTester tester, {required bool dirty, Size size = const Size(390, 844)}) async {
      final d = ValueNotifier(dirty);
      await _pump(tester, _Host(d), size: size);
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      return d;
    }

    testWidgets('a clean form leaves without asking (the back arrow)', (tester) async {
      await open(tester, dirty: false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('FORM'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    }, skip: _skip);

    testWidgets('a dirty form asks; Keep editing stays; Discard leaves', (tester) async {
      await open(tester, dirty: true);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard this payment?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('FORM'), findsOneWidget);
      // The system back (Android's gesture, the browser's back) asks too.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('FORM'), findsNothing);
    }, skip: _skip);

    testWidgets('a save leaves without asking', (tester) async {
      await open(tester, dirty: true);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('FORM'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    }, skip: _skip);

    testWidgets('wider than a phone: no check (today\'s forms)', (tester) async {
      await open(tester, dirty: true, size: const Size(1024, 768));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('FORM'), findsNothing);
    }, skip: _skip);
  });

  group('showPickerSheet', () {
    testWidgets('a bottom sheet: 56 px rows, a check on the chosen one, search, returns the value', (tester) async {
      String? picked;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showPickerSheet<String>(
                context,
                title: 'Category',
                selected: 'Rent',
                searchHint: 'Search',
                options: const [
                  PickerOption('Fuel', 'Fuel', group: 'Transport'),
                  PickerOption('Rent', 'Rent', group: 'Premises'),
                  PickerOption('Water', 'Water', group: 'Premises'),
                ],
              ),
              child: const Text('PICK'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('PICK'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getSize(_key('pickerSheet-option-Fuel')).height, greaterThanOrEqualTo(56));
      expect(find.descendant(of: _key('pickerSheet-option-Rent'), matching: _key('pickerSheet-check')), findsOneWidget);
      expect(find.text('Premises'), findsOneWidget);
      await tester.enterText(_key('pickerSheet-search'), 'wat');
      await tester.pumpAndSettle();
      expect(_key('pickerSheet-option-Fuel'), findsNothing);
      await tester.tap(_key('pickerSheet-option-Water'));
      await tester.pumpAndSettle();
      expect(picked, 'Water');
    }, skip: _skip);
  });
}
