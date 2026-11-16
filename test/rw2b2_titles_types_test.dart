import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/constants/facility_types.dart';
import 'package:vetbiz_pro/constants/person_titles.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final sw = lookupAppLocalizations(const Locale('sw'));

  group('titles', () {
    test('one list, in the owner\'s order', () {
      expect(kPersonTitles, ['Mr.', 'Mrs.', 'Ms.', 'Miss', 'Dr.', 'Prof.']);
      expect(kPersonTitles, contains(kDefaultPersonTitle));
    });

    test('every title round-trips through a stored fullName (Edit Profile)', () {
      for (final t in kPersonTitles) {
        final split = splitPersonTitle('$t Asha Mwita');
        expect(split.title, t, reason: t);
        expect(split.name, 'Asha Mwita', reason: t);
      }
    });

    test('names saved before RW2b2 still split as before; no title, no guess', () {
      expect(splitPersonTitle('Mrs. Neema Juma'), (title: 'Mrs.', name: 'Neema Juma'));
      expect(splitPersonTitle('Mr. Juma'), (title: 'Mr.', name: 'Juma'));
      expect(splitPersonTitle('Ms. Neema'), (title: 'Ms.', name: 'Neema'));
      // A name that only starts with the letters of a title is not one.
      expect(splitPersonTitle('Missana Juma'), (title: null, name: 'Missana Juma'));
      expect(splitPersonTitle('Asha Mwita'), (title: null, name: 'Asha Mwita'));
    });
  });

  group('the facility type as shown', () {
    test('stored values are unchanged; Ambulatory Vet shows as Ambulatory services', () {
      expect(kFacilityTypes, ['Agrovet', 'Vet Clinic', 'Vet Hospital', 'Ambulatory Vet', 'Other']);
      expect(kFacilityTypeOther, 'Other');
      expect(en.facilityTypeDisplay('Ambulatory Vet'), 'Ambulatory services');
      expect(sw.facilityTypeDisplay('Ambulatory Vet'), sw.facilityType_ambulatoryVet);
    });

    test('Other with its own words shows them; without, it shows Other', () {
      expect(en.facilityTypeDisplay('Other', 'Pet shop'), 'Pet shop');
      expect(sw.facilityTypeDisplay('Other', 'Pet shop'), 'Pet shop');
      expect(en.facilityTypeDisplay('Other'), en.facilityType_other);
      expect(en.facilityTypeDisplay('Other', ''), en.facilityType_other);
      expect(en.facilityTypeDisplay('Other', '   '), en.facilityType_other);
    });

    test('any other type ignores a detail; unknown and empty come back unchanged', () {
      expect(en.facilityTypeDisplay('Agrovet', 'Pet shop'), 'Agrovet');
      expect(en.facilityTypeDisplay('Vet Clinic'), 'Vet Clinic');
      expect(en.facilityTypeDisplay('Lab'), 'Lab');
      expect(en.facilityTypeDisplay(''), '');
      expect(en.facilityTypeDisplay(null), '');
    });
  });

  group('typeDetail: the server\'s rule (cleanTypeDetail)', () {
    test('valid, counted after trimming', () {
      for (final ok in ['Pet shop & feeds', '  Dairy co-op, St. Mary\'s 2  ', 'Duka la mifugo', 'ab', 'a' * AppLimits.typeDetailMax]) {
        expect(typeDetailIssue(ok), isNull, reason: ok);
      }
      expect(AppLimits.typeDetailMin, 2);
      expect(AppLimits.typeDetailMax, 40);
    });

    test('empty, too short, too long, bad characters', () {
      expect(typeDetailIssue(''), TypeDetailIssue.required);
      expect(typeDetailIssue('   '), TypeDetailIssue.required);
      expect(typeDetailIssue('a'), TypeDetailIssue.length);
      expect(typeDetailIssue(' a '), TypeDetailIssue.length);
      expect(typeDetailIssue('a' * (AppLimits.typeDetailMax + 1)), TypeDetailIssue.length);
      for (final bad in ['Pet/shop', '<b>x</b>', 'Shop!', 'x\ny', 'Pets 100%']) {
        expect(typeDetailIssue(bad), TypeDetailIssue.characters, reason: bad);
      }
    });
  });

  group('what the server receives and returns', () {
    test('typeDetail is sent only for Other, trimmed', () {
      expect(MembershipService.facilityPayload({'name': 'Mwanza Pets', 'type': 'Other', 'typeDetail': ' Pet shop ', 'code': 'X'}),
          {'name': 'Mwanza Pets', 'type': 'Other', 'typeDetail': 'Pet shop'});
      expect(MembershipService.facilityPayload({'name': 'Ukuli', 'type': 'Agrovet', 'typeDetail': 'Pet shop'}),
          {'name': 'Ukuli', 'type': 'Agrovet'});
      expect(MembershipService.facilityPayload({'name': 'Ukuli', 'type': 'Other'}), {'name': 'Ukuli', 'type': 'Other'});
    });

    test('an invite\'s detail is read when there is one', () {
      final withDetail = InviteCheck.fromResult({'valid': true, 'facilityName': 'Ukuli', 'facilityType': 'Other', 'facilityTypeDetail': 'Pet shop'});
      expect(withDetail.facilityTypeDetail, 'Pet shop');
      final old = InviteCheck.fromResult({'valid': true, 'facilityName': 'Ukuli', 'facilityType': 'Ambulatory Vet'});
      expect(old.facilityType, 'Ambulatory Vet');
      expect(old.facilityTypeDetail, isNull);
    });
  });
}
