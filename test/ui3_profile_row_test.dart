// UI3 (3): the profile menu's third detail row (Email, Phone, then Facility)
// shows the CURRENT facility: a small "Current facility" label above the name
// alone, and the type as the small tag. The same drawer is the phone's avatar
// menu and the wide top bar's profile menu. It stays a label (no tap), as it
// was before UI3.
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/utils/facility_display.dart';
import 'package:vetbiz_pro/widgets/facility_type_tag.dart';
import 'package:vetbiz_pro/widgets/profile/profile_drawer.dart';

import 'helpers/screen_size_matrix.dart';
import 'ui3_profile_drawer_wide_test.dart' show ui3DrawerPage;

const _skip = true; // UI3: until the implementation

/// The drawer as the dashboard builds it: the facility from the provider.
Widget _wired({required bool admin}) => Consumer<FacilityProvider>(
      builder: (context, f, _) => ProfileDrawerContent(
        avatarUrl: null,
        name: 'Shanel Hassan',
        roleLabel: admin ? 'Admin' : 'Assistant',
        email: 'shanel@example.com',
        phone: '+255 712 345 678',
        facility: FacilityDisplay.name(f.selectedFacilityName),
        facilityType: f.selectedFacilityType ?? '',
        facilityTypeDetail: f.selectedFacilityTypeDetail,
        onClose: () {},
        actions: [
          ProfileDrawerAction(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () {}),
          ProfileDrawerAction(icon: Icons.power_settings_new, label: 'Sign out', onTap: () {}, destructive: true),
        ],
      ),
    );

Future<FacilityProvider> _pump(WidgetTester tester,
    {Size size = const Size(390, 844), bool admin = true, MatrixLook look = MatrixLook.light, String name = 'Mwanzo Agrovet'}) async {
  SharedPreferences.setMockInitialValues({});
  final facilities = FacilityProvider(firestore: FakeFirebaseFirestore());
  await facilities.setFacility(id: 'f1', name: name, type: 'Agrovet');
  await pumpAtSize(
    tester,
    size: size,
    look: look,
    screen: ui3DrawerPage(admin: admin, content: _wired(admin: admin)),
    wrap: (app) => ChangeNotifierProvider.value(value: facilities, child: app),
  );
  await tester.pumpAndSettle();
  return facilities;
}

void main() {
  for (final size in const [Size(390, 844), Size(1200, 800)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    group(at, () {
      testWidgets('the third detail row: "Current facility" above the name alone, the type as the tag', (tester) async {
        await _pump(tester, size: size);
        final label = find.text('Current facility');
        final name = find.text('Mwanzo Agrovet');
        expect(label, findsOneWidget);
        expect(name, findsOneWidget);
        expect(find.text('Facility'), findsNothing, reason: 'the old label is replaced');
        expect(tester.getRect(label).bottom, lessThanOrEqualTo(tester.getRect(name).top));
        // Email, Phone, then the facility: the third row.
        final ys = [for (final t in ['Email', 'Phone', 'Current facility']) tester.getTopLeft(find.text(t)).dy];
        expect(ys, [...ys]..sort());
        final tag = find.byType(FacilityTypeTag);
        expect(tag, findsOneWidget);
        expect(find.descendant(of: tag, matching: find.text('Agrovet')), findsOneWidget);
        expect(tester.getRect(tag).top, greaterThanOrEqualTo(tester.getRect(label).bottom));
        final text = tester.widget<Text>(name);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }, skip: _skip);

      testWidgets('updates at once after a facility switch', (tester) async {
        final facilities = await _pump(tester, size: size);
        await facilities.setFacility(id: 'f2', name: 'Kliniki ya Mifugo Arusha', type: 'Vet Clinic');
        await tester.pump();
        expect(find.text('Kliniki ya Mifugo Arusha'), findsOneWidget);
        expect(find.text('Mwanzo Agrovet'), findsNothing);
        expect(find.descendant(of: find.byType(FacilityTypeTag), matching: find.text('Vet Clinic')), findsOneWidget);
      }, skip: _skip);

      testWidgets('a label, as before: no tap target on the row', (tester) async {
        await _pump(tester, size: size);
        for (final t in ['Current facility', 'Mwanzo Agrovet']) {
          expect(find.ancestor(of: find.text(t), matching: find.byType(InkWell)), findsNothing, reason: t);
          expect(find.ancestor(of: find.text(t), matching: find.byType(GestureDetector)), findsNothing, reason: t);
        }
        await tester.tap(find.text('Mwanzo Agrovet'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileDrawerContent), findsOneWidget, reason: 'nothing opened, the drawer stays');
      }, skip: _skip);

      testWidgets('an assistant sees the same row', (tester) async {
        await _pump(tester, size: size, admin: false);
        expect(find.text('Current facility'), findsOneWidget);
        expect(find.text('Mwanzo Agrovet'), findsOneWidget);
        expect(find.byType(FacilityTypeTag), findsOneWidget);
      }, skip: _skip);
    });
  }

  group('no overflow with a very long facility name', () {
    for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360), Size(768, 1024), Size(1200, 800)]) {
      for (final look in MatrixLook.values) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} ${look.name}', (tester) async {
          await _pump(tester, size: size, look: look, name: matrixLongFacilityName);
          expect(tester.takeException(), isNull);
          final drawer = tester.getRect(find.byType(Drawer));
          expect(tester.getRect(find.text(matrixLongFacilityName)).right, lessThanOrEqualTo(drawer.right));
        }, skip: _skip);
      }
    }
  });

  test('the dashboard passes the current facility\'s name, type and Other words, nothing else', () {
    final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
    expect(source, contains('facility: FacilityDisplay.name(facilities.selectedFacilityName)'));
    expect(source, contains('facilityType: facilities.selectedFacilityType'));
    expect(source, contains('facilityTypeDetail: facilities.selectedFacilityTypeDetail'));
  }, skip: _skip);
}
