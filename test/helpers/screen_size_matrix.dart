import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// PH2a: the overflow matrix (docs/design/phone_foundations.md section 10).
// A screen is pumped at five window sizes, each in Light, Dark and
// Kiswahili, and once at 360 with the text scaled to 1.3. Every case fails
// on any exception (a RenderFlex overflow lands there); on the phone sizes
// it also checks Android's 48 x 48 tap targets and that no text is drawn
// under 12 px (the owner's answer 1: body 14, secondary 12, badges smaller).

/// One window size.
class MatrixSize {
  final String label;
  final Size size;
  final bool phone;

  const MatrixSize(this.label, this.size, {this.phone = false});
}

const matrixSizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('768x1024', Size(768, 1024)),
  MatrixSize('1024x768', Size(1024, 768)),
  MatrixSize('1200x800', Size(1200, 800)),
];

enum MatrixLook { light, dark, kiswahili }

/// Seed data as long as real names get, and an 8-digit amount.
const matrixLongProductName = "Dawa ya Minyoo kwa Ng'ombe, Mbuzi na Kondoo (Albendazole 10%) Chupa ya Lita Moja";
const matrixLongClientName = 'Mwanaisha Abdallah Mohamedi Shabani wa Kijiji cha Mwembeni Juu';
const matrixLongFacilityName = 'Kituo cha Huduma za Mifugo na Pembejeo za Kilimo Mwanzo Mpya';
const matrixBigAmount = 12345678.0;

/// The smallest text allowed on a phone, and the text scale tried once.
const matrixMinTextPx = 12.0;
const matrixLargeTextScale = 1.3;

/// A widget wrapped in this key may draw text under 12 px (a badge's count).
const matrixSmallTextAllowed = ValueKey('matrix-small-text-allowed');

/// Builds the providers around the app, after any async set-up (a provider
/// that loads first, seeded documents). Called once per case.
typedef MatrixPrepare = Future<Widget Function(Widget app)> Function(WidgetTester tester);

/// The case names [screenSizeMatrix] gives, for its [skip] map: for example
/// '360x740 kiswahili', '1200x800 dark', '360x740 text 1.3'.
String matrixCase(MatrixSize s, MatrixLook look) => '${s.label} ${look.name}';
const matrixTextScaleCase = '360x740 text 1.3';

/// Pumps [screen] at [size] in [look], [textScale] times the text.
Future<void> pumpAtSize(
  WidgetTester tester, {
  required Widget screen,
  required Size size,
  MatrixLook look = MatrixLook.light,
  double textScale = 1,
  Widget Function(Widget app)? wrap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = Locale(look == MatrixLook.kiswahili ? 'sw' : 'en');
  final before = L10n.locale;
  L10n.setLocale(locale);
  addTearDown(() => L10n.setLocale(before));

  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.build(AppColorTheme.pasture, look == MatrixLook.dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: screen,
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  // Let first answers (fake Firestore, providers) arrive.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every text drawn under [min] px (icons and [matrixSmallTextAllowed]
/// subtrees aside), as '"text" 11.0 px'.
List<String> smallTexts(WidgetTester tester, {double min = matrixMinTextPx}) {
  final out = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    var allowed = false;
    element.visitAncestorElements((a) {
      if (a.widget is Icon || a.widget.key == matrixSmallTextAllowed) {
        allowed = true;
        return false;
      }
      return true;
    });
    if (allowed) continue;
    final paragraph = element.renderObject! as RenderParagraph;
    void visit(InlineSpan span, double inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        if (text.isNotEmpty && size < min) out.add('"$text" $size px');
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, size);
        }
      }
    }

    // Flutter's own default size when nothing sets one.
    visit(paragraph.text, 14);
  }
  return out;
}

/// The checks for one case: no exception anywhere; on a phone, 48 x 48 tap
/// targets and no text under 12 px.
Future<void> checkCase(WidgetTester tester, {required bool phone, required String where}) async {
  final error = tester.takeException();
  expect(error, isNull, reason: '$where: $error');
  if (!phone) return;
  final semantics = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: where);
  semantics.dispose();
  expect(smallTexts(tester), isEmpty, reason: '$where: text under $matrixMinTextPx px');
}

/// Declares the matrix for one screen: 5 sizes x 3 looks, and the text at
/// 1.3 once at 360. [skip] maps a case name ([matrixCase],
/// [matrixTextScaleCase]) to the real layout reason it fails today; it is
/// then skipped with that reason in its name, for a later batch to fix.
void screenSizeMatrix(
  String name, {
  required Widget Function() screen,
  MatrixPrepare? prepare,
  Map<String, String> skip = const {},
}) {
  group('$name size matrix', () {
    Future<void> run(WidgetTester tester, MatrixSize s, MatrixLook look, double scale, String where) async {
      final wrap = prepare == null ? null : await prepare(tester);
      await pumpAtSize(tester, screen: screen(), size: s.size, look: look, textScale: scale, wrap: wrap);
      await checkCase(tester, phone: s.phone, where: '$name $where');
    }

    String title(String where) => skip[where] == null ? where : '$where (skipped: ${skip[where]})';

    for (final s in matrixSizes) {
      for (final look in MatrixLook.values) {
        final where = matrixCase(s, look);
        testWidgets(title(where), (tester) => run(tester, s, look, 1, where), skip: skip.containsKey(where));
      }
    }
    testWidgets(
      title(matrixTextScaleCase),
      (tester) => run(tester, matrixSizes.first, MatrixLook.light, matrixLargeTextScale, matrixTextScaleCase),
      skip: skip.containsKey(matrixTextScaleCase),
    );
  });
}
