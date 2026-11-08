import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/auth_background.dart';
import 'package:vetbiz_pro/widgets/auth_card.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/auth_theme_toggle.dart';
import 'package:vetbiz_pro/widgets/profile/profile_photo_editor.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_nav_bar.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_option_card.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_header.dart';
import 'package:vetbiz_pro/widgets/wizard/wizard_step_intro.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';

import 'helpers/register_harness.dart';

// FIN1, written before the change: on phones the register wizard is ONE flat
// page, as LG1 made the login: the theme's background edge to edge, a column
// at most 420 wide with 24 px sides, the compact brand row (mark and name at
// the left, the theme toggle at the right), the step header and the heading
// centred, the fields straight on the page in the login's filled style
// (surfaceMuted, a 1 px textMuted border, 14 px radius, 52 high); no frame,
// header bar, card, accent line, welcome panel or strip. The option cards and
// the other wizard widgets keep their own look; Back and Continue stay pinned
// above the keyboard; the Sign in link is on step 1; the footer below.
// Tablets and wide windows: test/fin1_wide_register_unchanged_test.dart.
const _skip = true;

const _page = ValueKey<String>('register-phone-page');
const _brand = ValueKey<String>('register-phone-brand');

final _en = registerEn;

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f.first);

/// A box with something drawn: a fill, a border, a shadow or a gradient.
bool _decorated(Widget w) {
  final d = switch (w) {
    Container(:final decoration) => decoration,
    DecoratedBox(:final decoration) => decoration,
    _ => null,
  };
  return d is BoxDecoration && (d.color != null || d.border != null || d.boxShadow != null || d.gradient != null);
}

/// The widgets between [f] and the page column, [f] included.
List<Widget> _upToPage(WidgetTester tester, Finder f) {
  final out = <Widget>[tester.widget(f)];
  tester.element(f).visitAncestorElements((a) {
    if (a.widget.key == _page) return false;
    out.add(a.widget);
    return true;
  });
  return out;
}

bool _inside(Element e, bool Function(Widget) test) {
  var found = false;
  e.visitAncestorElements((a) {
    if (test(a.widget)) found = true;
    return !found;
  });
  return found;
}

/// The box an input draws (its fill and outline), without the kept line
/// under it.
final _fieldBoxes = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BorderContainer');

Future<void> _toStep(WidgetTester tester, {required bool assistant, required int step}) =>
    assistant ? toAssistantStep(tester, step) : toOwnerStep(tester, step);

/// Every step scrolled back to its top (a step's error, or a tap, may have
/// scrolled the page).
Future<void> _toTop(WidgetTester tester) async {
  for (final s in find.byType(Scrollable).evaluate()) {
    final state = (s as StatefulElement).state as ScrollableState;
    if (state.position.pixels != 0) state.position.jumpTo(0);
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final assistant in [false, true]) {
    final flow = assistant ? 'assistant' : 'owner';
    for (final step in [1, 2, 3, 4, 5]) {
      testWidgets('390x844 $flow step $step: one flat page, no frame, header bar, card, accent line or welcome strip', (tester) async {
        await pumpRegister(tester, size: const Size(390, 844));
        await _toStep(tester, assistant: assistant, step: step);
        await _toTop(tester);
        expect(find.byKey(_page), findsOneWidget);
        expect(find.byType(AuthCard), findsNothing);
        expect(find.byKey(AuthCard.surfaceKey), findsNothing);
        expect(find.byType(Card), findsNothing);
        expect(find.text(_en.register_createYourAccount), findsNothing, reason: 'the welcome strip or panel');
        expect(find.text(_en.register_setUpCentre), findsNothing, reason: 'the welcome strip');
        final header = find.byType(WizardStepHeader);
        expect(_upToPage(tester, header).where(_decorated), isEmpty, reason: 'nothing drawn around the wizard');
        // No header bar, strip or panel: no gradient but a button's own.
        final gradients = find.byWidgetPredicate((w) {
          final d = w is Container ? w.decoration : (w is DecoratedBox ? w.decoration : null);
          return d is BoxDecoration && d.gradient != null;
        });
        for (final e in gradients.evaluate()) {
          expect(_inside(e, (w) => w is ButtonStyleButton || w is WizardNavBar), isTrue, reason: 'a gradient outside a button: ${e.widget}');
        }
        // No accent line: no thin drawn strip on the page but the step's
        // own progress bar.
        for (final e in find.descendant(of: find.byKey(_page), matching: find.byWidgetPredicate(_decorated)).evaluate()) {
          if (_inside(e, (w) => w is WizardStepHeader || w is WizardOptionCard)) continue;
          final size = (e.renderObject! as RenderBox).size;
          expect(size.height > 6 || size.width < 40, isTrue, reason: 'a line drawn on the page: ${e.widget}');
        }
        // The brand row at the top: the mark, the name and the toggle.
        final brand = find.byKey(_brand);
        expect(find.descendant(of: brand, matching: find.text(AppInfo.logoMark)), findsOneWidget);
        expect(find.descendant(of: brand, matching: find.text(AppInfo.name)), findsOneWidget);
        expect(find.descendant(of: brand, matching: find.byType(AuthThemeToggle)), findsOneWidget);
        expect(_rect(tester, find.byType(AuthThemeToggle)).height, greaterThanOrEqualTo(48));
        expect(_rect(tester, brand).top, lessThan(32));
        expect(find.byType(AuthThemeToggle), findsOneWidget, reason: 'no second toggle in a header bar');
        // The column: 24 px in from the sides.
        expect(_rect(tester, header).left, 24);
        expect(_rect(tester, header).width, 390 - 48);
        // Back and Continue pinned (not in the page), the footer below.
        expect(find.descendant(of: find.byKey(_page), matching: find.byType(WizardNavBar)), findsNothing);
        expect(find.byType(WizardNavBar), findsOneWidget);
        expect(find.byType(AuthFooter), findsOneWidget);
        await finishRegister(tester);
      }, skip: _skip);
    }
  }

  testWidgets('560 wide (still a phone): the column keeps 420 at most', (tester) async {
    await pumpRegister(tester, size: const Size(560, 900));
    expect(_rect(tester, find.byType(WizardStepHeader)).width, lessThanOrEqualTo(420 - 48));
    expect(find.byKey(AuthCard.surfaceKey), findsNothing);
    await finishRegister(tester);
  }, skip: _skip);

  for (final step in [1, 2, 3, 4, 5]) {
    testWidgets('390x844 step $step: the step header and the heading are centred', (tester) async {
      await pumpRegister(tester, size: const Size(390, 844));
      await toOwnerStep(tester, step);
      await _toTop(tester);
      final centre = _rect(tester, find.byKey(_page)).center.dx;
      final header = find.byType(WizardStepHeader);
      final intro = find.byType(WizardStepIntro);
      final texts = [
        find.descendant(of: header, matching: find.text(_en.wizard_stepOf(step, 5))),
        for (final e in find.descendant(of: header, matching: find.byType(Text)).evaluate()) find.byWidget(e.widget),
        for (final e in find.descendant(of: intro, matching: find.byType(Text)).evaluate()) find.byWidget(e.widget),
      ];
      for (final t in texts) {
        expect(_rect(tester, t).center.dx, closeTo(centre, 1), reason: '${tester.widget<Text>(t.first).data}');
        expect(tester.widget<Text>(t.first).textAlign, TextAlign.center, reason: '${tester.widget<Text>(t.first).data}');
      }
      await finishRegister(tester);
    }, skip: _skip);
  }

  for (final size in const [Size(390, 844), Size(412, 915)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    for (final chosen in [false, true]) {
      testWidgets('$at step 1 (${chosen ? 'owner chosen' : 'nothing chosen'}): the content and the Continue bar without scrolling', (tester) async {
        await pumpRegister(tester, size: size, chooseOwner: chosen);
        // Choosing the owner is a tap the harness scrolls to (ensureVisible);
        // a person sees the step from its top.
        if (chosen) await _toTop(tester);
        final screen = Offset.zero & size;
        bool shown(Finder f) => screen.contains(_rect(tester, f).topLeft) && _rect(tester, f).bottom <= size.height;
        for (final s in find.byType(Scrollable).evaluate()) {
          expect(((s as StatefulElement).state as ScrollableState).position.pixels, 0);
        }
        expect(shown(find.byKey(_brand)), isTrue);
        expect(shown(find.byType(WizardStepHeader)), isTrue);
        expect(shown(find.byType(WizardStepIntro)), isTrue);
        expect(find.byType(WizardOptionCard), findsNWidgets(2));
        expect(shown(find.byType(WizardOptionCard).first), isTrue);
        expect(shown(find.byType(WizardOptionCard).last), isTrue);
        expect(shown(find.text(_en.register_alreadyHaveAccount)), isTrue, reason: 'the Sign in link');
        expect(shown(find.text(_en.products_continue).last), isTrue);
        expect(shown(find.byType(WizardNavBar)), isTrue);
        await finishRegister(tester);
      }, skip: _skip);
    }
  }

  for (final (assistant, step) in [(false, 2), (false, 3), (false, 4), (true, 2), (true, 3), (true, 4)]) {
    testWidgets('390x844 ${assistant ? 'assistant' : 'owner'} step $step: the fields are the login\'s: filled, 52 high, 1 px textMuted border, 14 px radius', (tester) async {
      await pumpRegister(tester, size: const Size(390, 844));
      await _toStep(tester, assistant: assistant, step: step);
      final colors = tester.element(find.byType(RegisterScreen)).colors;
      final decorators = find.byType(InputDecorator);
      expect(decorators, findsWidgets);
      for (final e in decorators.evaluate()) {
        final d = (e.widget as InputDecorator).decoration;
        expect(d.filled, isTrue);
        if (d.fillColor != colors.divider) expect(d.fillColor, colors.surfaceMuted, reason: 'a locked field keeps its own fill');
        final border = d.enabledBorder! as OutlineInputBorder;
        expect(border.borderSide.width, 1);
        expect(border.borderSide.color, colors.textMuted);
        expect(border.borderRadius, BorderRadius.circular(14));
        if (d.hintText != null) expect(d.hintStyle?.color, colors.textSecondary);
      }
      for (final e in _fieldBoxes.evaluate()) {
        if (_inside(e, (w) => w is TextField && (w.maxLines ?? 1) > 1)) continue;
        expect((e.renderObject! as RenderBox).size.height, 52);
      }
      await finishRegister(tester);
    }, skip: _skip);
  }

  testWidgets('the page, the fields and the texts: contrast in all four themes, Light and Dark', (tester) async {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        for (final step in [1, 2]) {
          final where = '${theme.id} ${brightness.name} step $step';
          await pumpRegister(tester, size: const Size(390, 844), theme: theme, brightness: brightness);
          await toOwnerStep(tester, step);
          final colors = tester.element(find.byType(RegisterScreen)).colors;
          final page = find.descendant(of: find.byType(AuthBackground), matching: find.byType(ColoredBox));
          expect(tester.widget<ColoredBox>(page).color, colors.background, reason: where);
          for (final e in find.byType(InputDecorator).evaluate()) {
            final border = ((e.widget as InputDecorator).decoration.enabledBorder! as OutlineInputBorder).borderSide.color;
            expect(ColorMath.contrast(border, colors.background), greaterThanOrEqualTo(3), reason: '$where field border');
          }
          for (final e in find.descendant(of: find.byKey(_page), matching: find.byType(RichText)).evaluate()) {
            // The option cards and the photo keep their own look (and fill).
            if (_inside(e, (w) => w is WizardOptionCard || w is ProfilePhotoEditor || w is Icon || w is ButtonStyleButton || w is ChoiceChip)) continue;
            final color = (e.widget as RichText).text.style?.color;
            if (color == null) continue;
            final text = (e.widget as RichText).text.toPlainText();
            if (text == AppInfo.logoMark) continue; // on its own mark
            // A kept line's invisible copies (FieldMessageSlot) draw nothing.
            if (text.trim().isEmpty || _inside(e, (w) => w is Opacity && w.opacity == 0)) continue;
            final behind = _inside(e, (w) => w is InputDecorator) ? colors.surfaceMuted : colors.background;
            expect(ColorMath.contrast(color, behind), greaterThanOrEqualTo(4.5), reason: '$where "$text"');
          }
          for (final e in find.descendant(of: find.byKey(_page), matching: find.byType(Icon)).evaluate()) {
            if (_inside(e, (w) => w is WizardOptionCard || w is ProfilePhotoEditor || w is ButtonStyleButton || w is ChoiceChip)) continue;
            final color = (e.widget as Icon).color ?? IconTheme.of(e).color;
            final behind = _inside(e, (w) => w is InputDecorator || w is IconButton) ? colors.surfaceMuted : colors.background;
            expect(ColorMath.contrast(color!, behind), greaterThanOrEqualTo(3), reason: '$where icon ${(e.widget as Icon).icon}');
          }
          await finishRegister(tester);
        }
      }
    }
  }, skip: _skip);
}
