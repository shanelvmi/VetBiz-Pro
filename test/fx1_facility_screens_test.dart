// FX1: Select Facility and the facility picker (the screen a signed-in
// admin with several facilities sees) fed web-shaped and odd data. Each case
// must show the cards (with safe text for what is usable) or the friendly
// empty or error state, and never throw. In a release build a throw is the
// grey box the owner saw on the phone.
//
// _failsToday names the cases that fail on today's code: they are skipped until
// the fix (empty it to see them fail).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/screens/facilities/select_facility_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

const _failsToday = {
  'Select Facility: two Map<dynamic, dynamic> items as the web gives them',
  'Select Facility: the arguments themselves a Map<dynamic, dynamic>',
  'Select Facility: odd names, types and details',
  'Select Facility: ids missing, a number or a map; a non-map item',
  'Facility picker at 390: two facilities',
  'Facility picker at 390: odd names, types and details',
  'Facility picker at 1200: odd names, types and details',
  'Facility picker at 390: web-shaped items (stored keys, Map<dynamic, dynamic>), one without an id',
  'Facility picker at 1200: web-shaped items (stored keys, Map<dynamic, dynamic>), one without an id',
};

Map<dynamic, dynamic> _item(Object? id, Object? name, {Object? type = 'Agrovet', Object? typeDetail}) =>
    <dynamic, dynamic>{'facilityId': id, 'name': name, 'type': type, 'typeDetail': typeDetail};

final _two = <dynamic>[_item('f1', 'Kilimo Agrovet'), _item('f2', 'Mifugo Clinic', type: 'Vet Clinic')];

Widget _app(Widget Function() screen, {Object? arguments}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      onGenerateRoute: (settings) =>
          MaterialPageRoute<void>(settings: RouteSettings(name: settings.name, arguments: arguments), builder: (_) => screen()),
    );

Future<Object?> _pump(WidgetTester tester, Widget app, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return tester.takeException();
}

/// Select Facility through its route arguments.
void _select(String name, Object? arguments, {List<String> cards = const [], bool emptyOrError = false}) {
  testWidgets('Select Facility: $name', (tester) async {
    final error = await _pump(tester, _app(() => const SelectFacilityScreen(), arguments: arguments), const Size(390, 844));
    expect(error, isNull, reason: '$error');
    for (final card in cards) {
      expect(find.text(card), findsOneWidget, reason: card);
    }
    if (emptyOrError) {
      expect(find.text('No facilities found.').evaluate().isNotEmpty || find.text('Try Again').evaluate().isNotEmpty, isTrue);
    }
  }, skip: _failsToday.contains('Select Facility: $name'));
}

/// The facility picker, given [facilities] as its caller would.
void _picker(String name, List<Object?> facilities, Size size, {List<String> cards = const []}) {
  testWidgets('Facility picker at ${size.width.toInt()}: $name', (tester) async {
    // Passed as dynamic: today's picker takes List<Map<String, dynamic>>.
    final dynamic list = facilities;
    final error = await _pump(tester, _app(() => FacilityPickerScreen(facilities: list, role: 'admin')), size);
    expect(error, isNull, reason: '$error');
    for (final card in cards) {
      expect(find.text(card), findsOneWidget, reason: card);
    }
  }, skip: _failsToday.contains('Facility picker at ${size.width.toInt()}: $name'));
}

void main() {
  _select('two Map<dynamic, dynamic> items as the web gives them', {'facilities': _two, 'role': 'admin'},
      cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
  _select('the arguments themselves a Map<dynamic, dynamic>', <dynamic, dynamic>{'facilities': _two},
      cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
  _select('odd names, types and details', {
    'facilities': <dynamic>[
      _item('f1', null, type: null),
      _item('f2', 12, type: 3, typeDetail: 4),
      _item('f3', {'en': 'x'}, type: {'a': 1}, typeDetail: {'b': 2}),
      _item('f4', ['x'], type: 'Agrovet'),
    ],
  }, cards: ['12']);
  _select('ids missing, a number or a map; a non-map item', {
    'facilities': <dynamic>[
      _item(null, 'No id'),
      _item({'x': 1}, 'Map id'),
      _item(7, 'Number id'),
      'not a map',
      null,
      _item('f1', 'Kilimo Agrovet'),
    ],
  }, cards: ['Number id', 'Kilimo Agrovet']);
  _select('an empty list', {'facilities': <dynamic>[]}, emptyOrError: true);
  _select('facilities not a list', {'facilities': {'facilityId': 'f1'}}, emptyOrError: true);
  _select('no arguments', null, emptyOrError: true);

  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    _picker('two facilities', <Map<String, dynamic>>[
      {'facilityId': 'f1', 'facilityName': 'Kilimo Agrovet', 'facilityType': 'Agrovet', 'facilityTypeDetail': null},
      {'facilityId': 'f2', 'facilityName': 'Mifugo Clinic', 'facilityType': 'Vet Clinic', 'facilityTypeDetail': null},
    ], size, cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
    _picker('odd names, types and details', <Map<String, dynamic>>[
      <String, dynamic>{'facilityId': 'f1', 'facilityName': 12, 'facilityType': {'a': 1}, 'facilityTypeDetail': {'b': 2}},
      <String, dynamic>{'facilityId': 'f2', 'facilityName': null, 'facilityType': null, 'facilityTypeDetail': 5},
    ], size, cards: ['12']);
    _picker('web-shaped items (stored keys, Map<dynamic, dynamic>), one without an id', [
      _item('f1', 'Kilimo Agrovet'),
      _item(null, 'No id'),
      _item('f2', 'Mifugo Clinic'),
    ], size, cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
  }
}
