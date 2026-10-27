import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/app_safe_area.dart';
import 'package:vetbiz_pro/widgets/app_sheet.dart';

// PH2b S4 and S8: showAppSheet alone (no screen uses it yet: the "+" sheet
// in PH3 and the row details in PH5 will), AdaptiveFormSize's presets, and
// the bottom safe-area helper.
const _skip = true;

const _home = Key('home');
const _content = Key('content');

/// A window of [size] (a 34 px home indicator, a keyboard of [keyboard]),
/// with a button that opens the sheet and keeps its result.
Future<List<Object?>> _host(
  WidgetTester tester,
  Size size, {
  bool fullPage = false,
  double keyboard = 0,
  int lines = 3,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final results = <Object?>[];
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: _home,
          onPressed: () async {
            results.add(await showAppSheet<String>(
              context,
              title: 'Rekodi malipo ya mteja mwenye jina refu sana',
              fullPage: fullPage,
              builder: (context) => Column(
                key: _content,
                children: [
                  for (var i = 0; i < lines; i++) SizedBox(height: 40, child: Text('Line $i')),
                  TextButton(onPressed: () => Navigator.of(context).pop('done'), child: const Text('Done')),
                ],
              ),
            ));
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(_home));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('on a phone', () {
    testWidgets('a bottom sheet with a drag handle, a rounded top and the title', (tester) async {
      await _host(tester, const Size(390, 844));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle, isTrue);
      expect(
        sheet.shape,
        const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16))),
      );
      expect(find.text('Rekodi malipo ya mteja mwenye jina refu sana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: _skip);

    testWidgets('long content: at most 92% of the height, and it scrolls', (tester) async {
      await _host(tester, const Size(390, 844), lines: 60);
      final height = tester.getSize(find.byType(BottomSheet)).height;
      expect(height, lessThanOrEqualTo(844 * AppSheetMetrics.sheetMaxHeightFactor));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: _skip);

    testWidgets('the content ends above the home indicator', (tester) async {
      await _host(tester, const Size(390, 844));
      final done = tester.getRect(find.text('Done'));
      expect(done.bottom, lessThanOrEqualTo(844 - 34));
    }, skip: _skip);

    testWidgets('the sheet rises above the keyboard', (tester) async {
      await _host(tester, const Size(390, 844), keyboard: 300);
      final done = tester.getRect(find.text('Done'));
      expect(done.bottom, lessThanOrEqualTo(844 - 300));
    }, skip: _skip);

    testWidgets('a phone on its side is still a phone', (tester) async {
      await _host(tester, const Size(844, 390));
      expect(find.byType(BottomSheet), findsOneWidget);
    }, skip: _skip);

    testWidgets('fullPage: a page with an AppBar and a back arrow', (tester) async {
      final results = await _host(tester, const Size(390, 844), fullPage: true);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
      expect(results, [null]);
    }, skip: _skip);

    testWidgets('the result comes back on pop', (tester) async {
      final results = await _host(tester, const Size(390, 844));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(results, ['done']);
    }, skip: _skip);
  });

  group('on a tablet or a computer', () {
    for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
      testWidgets('a dialog at most 560 wide and 88% high at $size', (tester) async {
        await _host(tester, size, lines: 60);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsOneWidget);
        final box = tester.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(ConstrainedBox)).first);
        expect(box.width, lessThanOrEqualTo(AppSizes.dialogLg));
        expect(box.height, lessThanOrEqualTo(size.height * AppSheetMetrics.dialogMaxHeightFactor));
        expect(tester.takeException(), isNull);
      }, skip: _skip);
    }

    testWidgets('fullPage stays a dialog on wide windows', (tester) async {
      await _host(tester, const Size(1200, 800), fullPage: true);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    }, skip: _skip);

    testWidgets('its Close button (English and Kiswahili) closes it with no result', (tester) async {
      final results = await _host(tester, const Size(1200, 800), locale: const Locale('sw'));
      final close = find.byTooltip(lookupAppLocalizations(const Locale('sw')).common_close);
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(results, [null]);
    }, skip: _skip);
  });

  test('AdaptiveFormSize: the presets keep the old numbers', () {
    expect(AdaptiveFormSize.form.resolve(const Size(1200, 800)), const Size(720, 704));
    expect(AdaptiveFormSize.form.resolve(const Size(1200, 500)), const Size(720, 480));
    expect(AdaptiveFormSize.form.resolve(const Size(2000, 800)).width, 940);
    expect(AdaptiveFormSize.formCapped.resolve(const Size(1200, 1000)), const Size(720, 820));
    expect(AdaptiveFormSize.formCapped.resolve(const Size(1200, 500)), const Size(720, 440));
    expect(AdaptiveFormSize.reportFull.resolve(const Size(2000, 800)), const Size(1100, 720));
    expect(AdaptiveFormSize.reportReview.resolve(const Size(2000, 800)).width, 900);
    expect(AdaptiveFormSize.activityLog.resolve(const Size(1200, 800)), const Size(1000, 680));
  }, skip: _skip);

  testWidgets('AppSafeArea.bottomOf is the window\'s bottom view padding, keyboard or not', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    late double bottom;
    await tester.pumpWidget(Builder(builder: (context) {
      bottom = AppSafeArea.bottomOf(context);
      return const SizedBox();
    }));
    expect(bottom, 34);
  });
}
