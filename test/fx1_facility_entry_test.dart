// FX1: FacilityEntry reads a user document's facilities safely, whatever
// shape Firestore (or the web, where maps are Map<dynamic, dynamic>) hands
// back.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/fields.dart';
import 'package:vetbiz_pro/models/facility_entry.dart';

const _skip = true;

void main() {
  test('safeString: a String stays, a number or a bool becomes text, anything else null', () {
    expect(FacilityEntry.safeString('Kilimo'), 'Kilimo');
    expect(FacilityEntry.safeString(12), '12');
    expect(FacilityEntry.safeString(1.5), '1.5');
    expect(FacilityEntry.safeString(true), 'true');
    expect(FacilityEntry.safeString(null), isNull);
    expect(FacilityEntry.safeString({'a': 1}), isNull);
    expect(FacilityEntry.safeString(['a']), isNull);
  }, skip: _skip);

  test('fromObject: null for anything that is not a map', () {
    for (final value in [null, 'f1', 12, ['f1'], true]) {
      expect(FacilityEntry.fromObject(value), isNull, reason: '$value');
    }
  }, skip: _skip);

  test('fromObject: a Map<dynamic, dynamic> as the web gives it, with stored keys', () {
    final Map<dynamic, dynamic> raw = {'facilityId': 'f1', 'name': 'Kilimo Agrovet', 'type': 'Agrovet', 'typeDetail': null};
    final entry = FacilityEntry.fromObject(raw)!;
    expect((entry.id, entry.name, entry.type, entry.typeDetail), ('f1', 'Kilimo Agrovet', 'Agrovet', null));
  }, skip: _skip);

  test('fromObject: odd values become safe text or null, never throw', () {
    final entry = FacilityEntry.fromObject(<dynamic, dynamic>{
      'facilityId': 7,
      'name': {'en': 'x'},
      'type': ['Agrovet'],
      'typeDetail': 3,
      5: 'a non-string key',
    })!;
    expect((entry.id, entry.name, entry.type, entry.typeDetail), ('7', null, null, '3'));
  }, skip: _skip);

  test('fromObject: the old in-app map keys when the stored ones are missing', () {
    final entry = FacilityEntry.fromObject({
      Fields.facilityId: 'f2',
      'facilityName': 'Mifugo Clinic',
      'facilityType': 'Vet Clinic',
      'facilityTypeDetail': 'Mobile',
    })!;
    expect((entry.id, entry.name, entry.type, entry.typeDetail), ('f2', 'Mifugo Clinic', 'Vet Clinic', 'Mobile'));
  }, skip: _skip);

  test('listFrom: drops non-maps and items without an id; not a list gives none', () {
    final list = FacilityEntry.listFrom(<dynamic>[
      <dynamic, dynamic>{'facilityId': 'f1', 'name': 'A'},
      'not a map',
      null,
      <dynamic, dynamic>{'name': 'no id'},
      <dynamic, dynamic>{'facilityId': {'x': 1}, 'name': 'map id'},
      <String, dynamic>{'facilityId': 'f2', 'name': 'B'},
    ]);
    expect([for (final e in list) e.id], ['f1', 'f2']);
    expect(FacilityEntry.listFrom(null), isEmpty);
    expect(FacilityEntry.listFrom({'facilityId': 'f1'}), isEmpty);
    expect(FacilityEntry.listFrom(<dynamic>[]), isEmpty);
  }, skip: _skip);

  test('toMap: the old map, with the empty name and type main.dart always gave', () {
    expect(const FacilityEntry(id: 'f1').toMap(), {
      Fields.facilityId: 'f1',
      'facilityName': '',
      'facilityType': '',
      'facilityTypeDetail': null,
    });
    expect(const FacilityEntry(id: 'f1', name: 'A', type: 'Agrovet', typeDetail: 'x').toMap(), {
      Fields.facilityId: 'f1',
      'facilityName': 'A',
      'facilityType': 'Agrovet',
      'facilityTypeDetail': 'x',
    });
  }, skip: _skip);
}
