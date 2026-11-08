// UI1 (3), written before the change: the facility picker at every width.
// The top bar: the brand at the left (the mark and the name, no tagline) and
// the profile menu in the right corner; the page header centred (the store
// icon in its circle above the title and its subtitle); no decorative icons
// (the tractor, rabbit and paw) and no footer line. The search, the Filter
// button and the cards stay as built (PH8b's tests). At 360x740, 390x844,
// 740x360, 768x1024 and 1200x800 in Light, Dark and Kiswahili.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;
// Until the two keys are retired from both ARB files and the generated code.
const _skipKeys = true;

// Not UI1: at 768 in Kiswahili a card's staff-and-status row (the cards
// stay as built) overflows by 37 px; this case waits for a cards batch.
const _known = {'768x1024 kiswahili': 'a card row overflows in Kiswahili at 768 (cards not in UI1)'};

const _sizes = [Size(360, 740), Size(390, 844), Size(740, 360), Size(768, 1024), Size(1200, 800)];

const _items = <Map<String, dynamic>>[
  {'facilityId': 'f1', 'facilityName': matrixLongFacilityName, 'facilityType': 'Agrovet', 'facilityTypeDetail': null},
  {'facilityId': 'f2', 'facilityName': 'Mifugo Clinic', 'facilityType': 'Vet Clinic', 'facilityTypeDetail': null},
];

/// Where the text is drawn (its glyphs, not its box; a space left at a line
/// break is not drawn, so only the words count).
Rect _ink(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: text, matching: find.byType(RichText)).first);
  Rect? rect;
  for (final word in RegExp(r'\S+').allMatches(paragraph.text.toPlainText())) {
    for (final b in paragraph.getBoxesForSelection(TextSelection(baseOffset: word.start, extentOffset: word.end))) {
      rect = rect == null ? b.toRect() : rect.expandToInclude(b.toRect());
    }
  }
  return rect!.shift(paragraph.localToGlobal(Offset.zero));
}

void main() {
  for (final size in _sizes) {
    for (final look in MatrixLook.values) {
      final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name}';
      ph5TestWidgets('$where${_known[where] == null ? '' : ' (skipped: ${_known[where]})'}: brand left, profile right, the header centred, no decoration', (tester) async {
        await pumpPh5(tester, (_) => FacilityPickerScreen(facilities: _items, role: 'admin'), size: size, look: look);
        final l10n = lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'));
        expect(tester.takeException(), isNull);

        // The bar: the Container around the app's name.
        final barFinder = find.ancestor(of: find.text(AppInfo.name), matching: find.byType(Container)).first;
        final bar = tester.getRect(barFinder);
        final padding = tester.widget<Container>(barFinder).padding!.resolve(TextDirection.ltr);
        final profile = tester.getRect(find.descendant(of: barFinder, matching: find.byType(PopupMenuButton<String>)));
        expect(profile.right, closeTo(bar.right - padding.right, 0.5), reason: 'the profile menu in the right corner');
        expect(tester.getRect(find.text(AppInfo.logoInitials)).left, greaterThanOrEqualTo(bar.left + padding.left - 0.5));
        expect(tester.getRect(find.text(AppInfo.name)).right, lessThan(profile.left), reason: 'the brand at the left');
        expect(find.text(l10n.facilityPicker_title), findsOneWidget);

        // The header: the icon above, the title and subtitle, centred on the page.
        final centre = size.width / 2;
        final icon = tester.getRect(find.byIcon(Icons.storefront_outlined).first);
        final title = _ink(tester, find.text(l10n.facilityPicker_title));
        final intro = _ink(tester, find.text(l10n.facilityPicker_intro));
        expect(icon.center.dx, closeTo(centre, 1));
        expect(title.center.dx, closeTo(centre, 1));
        expect(intro.center.dx, closeTo(centre, 1));
        expect(icon.bottom, lessThanOrEqualTo(title.top));
        expect(title.bottom, lessThanOrEqualTo(intro.top));

        for (final decoration in [Icons.agriculture_outlined, Icons.cruelty_free, Icons.pets]) {
          expect(find.byIcon(decoration), findsNothing, reason: '$decoration');
        }
        expect(find.textContaining('Reliable'), findsNothing);
        expect(find.textContaining('Inaaminika'), findsNothing);
      }, skip: _skip || _known.containsKey(where));
    }
  }

  test('the tagline and the footer line are gone from lib/ and both ARB files', () {
    const gone = [
      'facilityPicker_tagline',
      'facilityPicker_footer',
      'Manage. Care. Grow.',
      'Simamia. Hudumia. Kua.',
      'Built for Veterinary Businesses',
      'Imejengwa kwa Biashara za Mifugo',
    ];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') && !f.path.endsWith('.arb')) continue;
      final text = f.readAsStringSync();
      for (final g in gone) {
        expect(text.contains(g), isFalse, reason: '${f.path}: $g');
      }
    }
  }, skip: _skipKeys);
}
