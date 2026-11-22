// UX9: the Select Facility screen redesign. A single-facility person never
// reaches it (the routing, facilityLandingFor); two facilities sit side by
// side, three or more in auto columns, one column on a phone, never wider
// than the content column; the whole card opens its facility (tap, Enter,
// Space), the ⋮ menu never does; search only above 8 facilities, no Filter;
// a logo or a two-letter tile; the Default badge and the accent only on the
// user's chosen default; skeleton cards (no spinner) while loading.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/utils/facility_landing.dart';
import 'package:vetbiz_pro/widgets/facility_pick_card.dart';
import 'package:vetbiz_pro/widgets/vetbiz_loading_indicator.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'helpers/fake_firestore.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _names = ['Kilimo Agrovet', 'Mifugo Clinic', 'Shamba Hub', 'Arusha Vet Centre', 'Moshi Agrovet',
  'Tanga Clinic', 'Dodoma Agrovet', 'Mbeya Vet', 'Iringa Agrovet'];
const _types = ['Agrovet', 'Vet Clinic', 'Other', 'Vet Hospital', 'Agrovet', 'Vet Clinic', 'Agrovet', 'Mobile Vet', 'Agrovet'];

List<Map<String, dynamic>> _items(int n) => [
      for (var i = 0; i < n; i++)
        {
          'facilityId': 'f${i + 1}',
          // The first one very long, so an ellipsis is exercised everywhere.
          'facilityName': i == 0 ? matrixLongFacilityName : _names[i],
          'facilityType': _types[i],
          'facilityTypeDetail': _types[i] == 'Other' ? 'Kituo cha mafunzo' : null,
        },
    ];

Future<void> _seed(FirebaseFirestore fs, int n, {String fullName = 'Asha Mushi', String? defaultId = 'f2'}) async {
  for (var i = 0; i < n; i++) {
    await fs.collection(Collections.facilities).doc('f${i + 1}').set({
      'name': _names[i],
      'status': 'active',
      if (i == 0) 'logoUrl': 'https://example.test/logo.png',
      if (i == 1) 'address': 'Arusha, Tanzania',
    });
  }
  await fs.collection(Collections.users).doc('a1').set({'role': 'assistant', 'facilityIds': ['f2']});
  await fs.collection(Collections.users).doc(testUserId).set({
    'role': 'admin',
    'fullName': fullName,
    if (defaultId != null) 'defaultFacilityId': defaultId,
  });
}

Future<Ph5App> _pump(WidgetTester tester, int n,
    {Size size = const Size(1200, 900),
    MatrixLook look = MatrixLook.light,
    double textScale = 1,
    String fullName = 'Asha Mushi',
    String? defaultId = 'f2',
    bool settle = true}) =>
    pumpPh5(
      tester,
      (fs) => FacilityPickerScreen(facilities: _items(n), role: 'admin', firestore: fs, uid: testUserId),
      size: size,
      look: look,
      textScale: textScale,
      settle: settle,
      seed: (fs) => _seed(fs, n, fullName: fullName, defaultId: defaultId),
    );

Finder _card(String id) => find.byKey(ValueKey('facilityPickCard-$id'));

AppLocalizations _l10n(MatrixLook look) => lookupAppLocalizations(Locale(look == MatrixLook.kiswahili ? 'sw' : 'en'));

/// The columns expected for [n] cards in a window [width] wide: the page's
/// gutter (16 on a phone, 24 elsewhere), the content capped at 1100, then
/// one column on a phone, two for two facilities, else as many 220 px
/// columns as fit.
int _expectedColumns(int n, double width) {
  final phone = width < 600;
  if (phone) return 1;
  final content = (width - 48).clamp(0, FacilityPickerMetrics.maxContentWidth).toDouble();
  final fit = ((content + 16) / (220 + 16)).floor();
  if (n == 2) return fit >= 2 ? 2 : 1;
  return fit.clamp(1, n);
}

void main() {
  group('routing: one facility never sees the picker', () {
    test('the rule: 0 none, 1 straight in, 2 or more the picker', () {
      expect(facilityLandingFor(0), FacilityLanding.none);
      expect(facilityLandingFor(1), FacilityLanding.straightIn);
      expect(facilityLandingFor(2), FacilityLanding.picker);
      expect(facilityLandingFor(9), FacilityLanding.picker);
    });

    // The two places that land a signed-in person both decide through the
    // rule, and return the picker only after the one-facility branch has
    // gone straight in (and the profile menu's switch is a separate sheet,
    // offered only with 2 or more).
    for (final (path, count) in [
      ('lib/main.dart', 'facilities.length'),
      ('lib/screens/register_screen.dart', 'facilitiesWithId.length'),
    ]) {
      test('$path: one facility goes straight in, before any picker', () {
        final source = File(path).readAsStringSync();
        final straightIn = source.indexOf('if (facilityLandingFor($count) == FacilityLanding.straightIn) {');
        expect(straightIn, greaterThan(0));
        final pickers = RegExp(r'FacilityPickerScreen\(').allMatches(source).map((m) => m.start).toList();
        expect(pickers, hasLength(1));
        expect(pickers.single, greaterThan(straightIn));
        // The straight-in branch activates the one facility and does not
        // fall through to the picker.
        final branch = source.substring(straightIn, pickers.single);
        expect(branch, contains('activateFacilityAndGoToDashboard('));
        expect(branch.contains(RegExp(r'return const VetBizLoadingPage\(\);|\} else \{')), isTrue);
      });
    }
    test('nothing else builds the picker', () {
      final builders = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart') && !f.path.endsWith('facility_picker_screen.dart') && f.readAsStringSync().contains('FacilityPickerScreen(')) f.path.replaceAll('\\', '/'),
      ]..sort();
      expect(builders, ['lib/main.dart', 'lib/screens/register_screen.dart']);
    });
  });

  group('layouts', () {
    const widths = [360.0, 768.0, 1200.0, 1920.0];
    final looks = [
      ('en 1.0', MatrixLook.light, 1.0),
      ('en 1.3', MatrixLook.light, 1.3),
      ('sw 1.3', MatrixLook.kiswahili, 1.3),
    ];
    for (final n in [2, 3, 5, 9]) {
      for (final width in widths) {
        for (final (name, look, scale) in looks) {
          ph5TestWidgets('$n facilities at ${width.toInt()} $name: columns, never wider than the content, no overflow',
              (tester) async {
            await _pump(tester, n, size: Size(width, 900), look: look, textScale: scale);
            expect(tester.takeException(), isNull);
            final rects = [for (var i = 1; i <= n; i++) tester.getRect(_card('f$i'))];
            final columns = _expectedColumns(n, width);
            final firstRow = rects.where((r) => (r.top - rects.first.top).abs() < 0.5).length;
            expect(firstRow, columns, reason: 'columns');
            for (final r in rects) {
              expect(r.width, lessThanOrEqualTo(FacilityPickerMetrics.maxContentWidth));
              expect(r.left, greaterThanOrEqualTo(16));
              expect(r.right, lessThanOrEqualTo(width - 16));
              expect(r.width, closeTo(rects.first.width, 0.5), reason: 'equal columns');
            }
            // The column is centred and never stretched across the window.
            final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
            if (width >= 1200) {
              expect(left, closeTo((width - FacilityPickerMetrics.maxContentWidth) / 2, 1));
            }
          });
        }
      }
    }
  });

  group('the card', () {
    Widget host(Widget child, {VoidCallback? onSetDefault}) => MaterialApp(
          theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
        );
    FacilityPickCard card({required VoidCallback onOpen, VoidCallback? onSetDefault, bool isDefault = false}) =>
        FacilityPickCard(
          name: 'Mifugo Clinic',
          type: 'Vet Clinic',
          status: 'active',
          staffCount: 2,
          isDefault: isDefault,
          onOpen: onOpen,
          onSetDefault: onSetDefault,
        );

    testWidgets('the whole card opens it: the name, the location, the corner', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(card(onOpen: () => opened++, onSetDefault: () {})));
      final en = lookupAppLocalizations(const Locale('en'));
      for (final target in [find.text('Mifugo Clinic'), find.text(en.facilityPicker_locationNotSet), find.text(en.facilityPicker_openFacility)]) {
        await tester.tap(target);
        await tester.pump();
      }
      expect(opened, 3);
      final rect = tester.getRect(find.byType(FacilityPickCard));
      await tester.tapAt(rect.bottomLeft + const Offset(4, -4));
      await tester.pump();
      expect(opened, 4);
      expect(rect.height, greaterThanOrEqualTo(44));
    });

    testWidgets('the ⋮ menu offers Set as Default and never opens the facility', (tester) async {
      var opened = 0;
      var defaulted = 0;
      await tester.pumpWidget(host(card(onOpen: () => opened++, onSetDefault: () => defaulted++)));
      final menu = find.byKey(const ValueKey('facilityPickCard-menu'));
      expect(tester.getSize(menu).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(menu).height, greaterThanOrEqualTo(44));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(opened, 0);
      await tester.tap(find.text(lookupAppLocalizations(const Locale('en')).facilityPicker_setAsDefault));
      await tester.pumpAndSettle();
      expect(defaulted, 1);
      expect(opened, 0);
    });

    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('keyboard: ${key.keyLabel.isEmpty ? 'Space' : key.keyLabel} on the focused card opens it', (tester) async {
        var opened = 0;
        await tester.pumpWidget(host(card(onOpen: () => opened++)));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final inkWell = tester.widget<InkWell>(find.byKey(const ValueKey('facilityPickCard-tap')));
        expect(inkWell.onTap, isNotNull);
        expect(Focus.of(tester.element(find.text('Mifugo Clinic'))).hasFocus, isTrue, reason: 'the card took focus');
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(opened, 1);
      });
    }

    testWidgets('hover shows a state on PC', (tester) async {
      await tester.pumpWidget(host(card(onOpen: () {})));
      final inkWell = tester.widget<InkWell>(find.byKey(const ValueKey('facilityPickCard-tap')));
      // InkWell draws the theme's hover and focus overlays; nothing turns them off.
      expect(inkWell.hoverColor, isNot(Colors.transparent));
      expect(inkWell.focusColor, isNot(Colors.transparent));
      expect(inkWell.canRequestFocus, isTrue);
    });

    test('initials: two letters', () {
      expect(facilityInitials('Mifugo Clinic'), 'MC');
      expect(facilityInitials('Kilimo'), 'KI');
      expect(facilityInitials('  arusha   vet centre '), 'AV');
      expect(facilityInitials(''), '');
    });
  });

  group('the screen', () {
    ph5TestWidgets('logo vs initials; the Default badge and the accent only on the chosen default', (tester) async {
      await _pump(tester, 3);
      expect(find.descendant(of: _card('f1'), matching: find.byKey(const ValueKey('facilityPickCard-logo'))), findsOneWidget);
      expect(find.descendant(of: _card('f2'), matching: find.text('MC')), findsOneWidget);
      expect(find.descendant(of: _card('f3'), matching: find.text('SH')), findsOneWidget);

      final badge = find.byKey(const ValueKey('facilityPickCard-default'));
      expect(badge, findsOneWidget);
      expect(find.descendant(of: _card('f2'), matching: badge), findsOneWidget);
      expect(find.text(_l10n(MatrixLook.light).facilityPicker_default), findsOneWidget);
      expect(find.text('Last used'), findsNothing);

      final primary = tester.element(_card('f2')).colors.primary;
      Color side(String id) =>
          ((tester.widget<Material>(find.descendant(of: _card(id), matching: find.byType(Material)).first).shape!
                  as RoundedRectangleBorder)
              .side
              .color);
      expect(side('f2'), primary);
      expect(side('f1'), isNot(primary));
      expect(side('f3'), isNot(primary));

      // The Default card has no menu (nothing to offer); the others keep it.
      final menu = find.byKey(const ValueKey('facilityPickCard-menu'));
      expect(find.descendant(of: _card('f2'), matching: menu), findsNothing);
      expect(find.descendant(of: _card('f1'), matching: menu), findsOneWidget);
      expect(find.descendant(of: _card('f3'), matching: menu), findsOneWidget);

      // What the screen already reads: the location, the staff count, the status.
      final en = _l10n(MatrixLook.light);
      expect(find.descendant(of: _card('f2'), matching: find.text('Arusha, Tanzania')), findsOneWidget);
      expect(find.descendant(of: _card('f2'), matching: find.text(en.facilityPicker_staffCount(1))), findsOneWidget);
      expect(find.descendant(of: _card('f1'), matching: find.text(en.facilityPicker_locationNotSet)), findsOneWidget);
    });

    ph5TestWidgets('no default chosen: no badge, no accent', (tester) async {
      await _pump(tester, 3, defaultId: null);
      expect(find.byKey(const ValueKey('facilityPickCard-default')), findsNothing);
    });

    ph5TestWidgets('Set as Default from the ⋮ menu moves the badge and saves the same field', (tester) async {
      final app = await _pump(tester, 3);
      await tester.tap(find.descendant(of: _card('f3'), matching: find.byKey(const ValueKey('facilityPickCard-menu'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(MatrixLook.light).facilityPicker_setAsDefault));
      await tester.pumpAndSettle();
      await ph5Settle(tester);
      final user = await tester.runAsync(() => app.fs.collection(Collections.users).doc(testUserId).get());
      expect(user!.data()!['defaultFacilityId'], 'f3');
      expect(find.descendant(of: _card('f3'), matching: find.byKey(const ValueKey('facilityPickCard-default'))), findsOneWidget);
    });

    ph5TestWidgets('the welcome line uses the full name', (tester) async {
      await _pump(tester, 2);
      expect(find.text(_l10n(MatrixLook.light).facilityPicker_welcomeBack('Asha Mushi')), findsOneWidget);
      expect(find.text(_l10n(MatrixLook.light).facilityPicker_title), findsOneWidget);
    });

    ph5TestWidgets('no name: the title only, no "Welcome back, "', (tester) async {
      await _pump(tester, 2, fullName: '');
      expect(find.byKey(const ValueKey('facilityPicker-welcome')), findsNothing);
      expect(find.textContaining('Welcome back'), findsNothing);
      expect(find.text(_l10n(MatrixLook.light).facilityPicker_title), findsOneWidget);
    });

    for (final n in [2, 3, 8]) {
      ph5TestWidgets('$n facilities: no search, no Filter', (tester) async {
        await _pump(tester, n);
        final en = _l10n(MatrixLook.light);
        expect(find.byType(TextField), findsNothing);
        expect(find.text(en.facilityPicker_filter), findsNothing);
        expect(find.byIcon(Icons.filter_list), findsNothing);
      });
    }

    ph5TestWidgets('9 facilities: a search box, no Filter; it finds by name and by type', (tester) async {
      await _pump(tester, 9);
      final en = _l10n(MatrixLook.light);
      expect(find.byKey(const ValueKey('facilityPicker-search')), findsOneWidget);
      expect(find.text(en.facilityPicker_filter), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsNothing);
      await tester.enterText(find.byType(TextField), 'tanga');
      await tester.pump();
      expect(find.byType(FacilityPickCard), findsOneWidget);
      expect(_card('f6'), findsOneWidget);
      await tester.enterText(find.byType(TextField), en.facilityTypeLabel('Mobile Vet'));
      await tester.pump();
      expect(_card('f8'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.byType(FacilityPickCard), findsNothing);
      expect(find.text(en.clients_noMatches), findsOneWidget);
    });

    ph5TestWidgets('loading: skeleton cards in the same count, no spinner', (tester) async {
      await _pump(tester, 3, settle: false);
      expect(find.byType(FacilityPickCardSkeleton), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(VetBizLoadingPage), findsNothing);
      expect(find.byType(FacilityPickCard), findsNothing);
      await ph5Settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(FacilityPickCardSkeleton), findsNothing);
      expect(find.byType(FacilityPickCard), findsNWidgets(3));
    });

    test('flat: the card and the screen use no gradient and no shadow', () {
      for (final path in ['lib/widgets/facility_pick_card.dart', 'lib/screens/facilities/facility_picker_screen.dart']) {
        final source = File(path).readAsStringSync();
        expect(source.contains(RegExp(r'Gradient\(|BoxShadow\(|elevation:')), isFalse, reason: path);
      }
    });
  });
}
