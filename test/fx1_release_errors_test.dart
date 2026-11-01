// FX1 (3): in a release build a widget that fails to build shows a small
// friendly card instead of Flutter's grey box, and the error prints one
// readable line; a debug build keeps Flutter's own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/release_errors.dart';
import 'package:vetbiz_pro/widgets/friendly_error_card.dart';

const _skip = false;

const _message = 'Something went wrong on this screen. Go back and try again.';

class _Broken extends StatelessWidget {
  const _Broken();
  @override
  Widget build(BuildContext context) => throw StateError('broken on purpose');
}

/// Pumps [body] with the release handling installed, then puts Flutter's
/// own handlers back (the test framework checks they are unchanged).
Future<void> _pumpReleased(WidgetTester tester, Widget body) async {
  final builder = ErrorWidget.builder;
  final onError = FlutterError.onError;
  try {
    installReleaseErrorHandling(release: true);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: body,
    ));
  } finally {
    ErrorWidget.builder = builder;
    FlutterError.onError = onError;
  }
}

void main() {
  testWidgets('in a Column: the card replaces the broken widget, the rest stays', (tester) async {
    await _pumpReleased(tester, const Scaffold(body: Column(children: [Text('above'), _Broken(), Text('below')])));
    expect(find.byType(FriendlyErrorCard), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(find.text('above'), findsOneWidget);
    expect(find.text('below'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  testWidgets('in a ListView and in a Row: sized to itself, nothing stretched', (tester) async {
    await _pumpReleased(
      tester,
      Scaffold(body: ListView(children: const [Text('first'), _Broken(), Row(children: [Text('left'), _Broken()]), Text('last')])),
    );
    expect(find.byType(FriendlyErrorCard), findsNWidgets(2));
    expect(find.text('last'), findsOneWidget);
    expect(tester.getSize(find.byType(FriendlyErrorCard).first).height, lessThan(200));
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  testWidgets('as a Scaffold body: the card, centred, no stack trace', (tester) async {
    await _pumpReleased(tester, const Scaffold(body: _Broken()));
    expect(find.text(_message), findsOneWidget);
    expect(find.textContaining('broken on purpose'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  testWidgets('the card draws even with no theme or localisations above it', (tester) async {
    await tester.pumpWidget(const FriendlyErrorCard());
    expect(find.text(_message), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  test('a debug build keeps Flutter\'s own error screen and report', () {
    final builder = ErrorWidget.builder;
    final onError = FlutterError.onError;
    installReleaseErrorHandling(release: false);
    expect(ErrorWidget.builder, same(builder));
    expect(FlutterError.onError, same(onError));
  }, skip: _skip);

  test('the console line: one line with the exception, library, widget and three frames', () {
    final stack = StackTrace.fromString('#0 first (a.dart:1)\n#1 second (b.dart:2)\n#2 third (c.dart:3)\n#3 fourth (d.dart:4)');
    final line = releaseErrorLine(FlutterErrorDetails(
      exception: StateError('broken on purpose'),
      stack: stack,
      library: 'widgets library',
      context: ErrorDescription('building FacilityPickerScreen'),
    ));
    expect(line, isNot(contains('\n')));
    for (final part in ['broken on purpose', 'widgets library', 'FacilityPickerScreen', 'first', 'second', 'third']) {
      expect(line, contains(part), reason: part);
    }
    expect(line, isNot(contains('fourth')));
  }, skip: _skip);
}
