import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/profile_photo_service.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/profile/profile_avatar.dart';
import 'package:vetbiz_pro/widgets/profile/profile_drawer.dart';
import 'package:vetbiz_pro/widgets/profile/profile_menu_button.dart';
import 'package:vetbiz_pro/widgets/profile/profile_photo_editor.dart';

// G2 (the owner's gap list: the profile). Written before the code:
// the photo service (one location, Remove deletes both files and clears
// avatarUrl), the top bar button (circle only on a phone, avatar + name +
// role wider), the drawer (no camera, compact rows, no overflow), the
// Edit Profile photo part, and initials when there is no photo.

const _untilG2 = 'G2: until the implementation';

class _FakeStore implements PhotoStore {
  final files = <String>{};
  Object? deleteError;

  @override
  Future<String> upload(String path, Uint8List bytes) async {
    files.add(path);
    return 'https://files.example/$path?alt=media&token=t';
  }

  @override
  Future<void> delete(String path) async {
    if (deleteError != null) throw deleteError!;
    if (!files.remove(path)) {
      throw FirebaseException(plugin: 'firebase_storage', code: 'object-not-found');
    }
  }
}

const _longName = 'Dr. Bartholomew Mwakalinga-Kilimanjaro Nyerere Mwanaisha wa Pili';
const _longEmail = 'bartholomew.mwakalinga.kilimanjaro.nyerere@example-agrovet-services.co.tz';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget child,
      {double width = 390, Brightness brightness = Brightness.light, String locale = 'en'}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, brightness),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ));
    await tester.pump();
  }

  AppColors colorsOf(WidgetTester tester, Finder f) => Theme.of(tester.element(f)).extension<AppColors>()!;

  group('the photo service', () {
    late _FakeStore store;
    late FakeFirebaseFirestore db;
    late ProfilePhotoService service;

    setUp(() async {
      store = _FakeStore();
      db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({'fullName': 'Shanel Hassan', 'avatarUrl': 'old'});
      service = ProfilePhotoService(store: store, firestore: db);
    });

    Future<Map<String, dynamic>> user() async => (await db.collection('users').doc('u1').get()).data()!;

    test('Change photo saves one jpeg at avatars/{uid}.jpg and points avatarUrl at it', () async {
      final url = await service.savePhoto('u1', Uint8List(8));
      expect(store.files, {'avatars/u1.jpg'});
      expect(url, contains('avatars/u1.jpg'));
      expect((await user())['avatarUrl'], url);
    });

    test('Remove photo deletes both files and clears avatarUrl', () async {
      store.files.add('avatars/u1.jpg');
      store.files.add('user_avatars/u1.png');
      await service.removePhoto('u1');
      expect(store.files, isEmpty);
      expect((await user()).containsKey('avatarUrl'), isFalse);
    });

    test('a file that is not there counts as removed', () async {
      store.files.add('avatars/u1.jpg'); // no legacy file
      await service.removePhoto('u1');
      expect((await user()).containsKey('avatarUrl'), isFalse);
      await service.removePhoto('u1'); // neither file now
    });

    test('any other error stops the removal and keeps avatarUrl', () async {
      store.deleteError = FirebaseException(plugin: 'firebase_storage', code: 'unauthorized');
      await expectLater(service.removePhoto('u1'), throwsA(isA<FirebaseException>()));
      expect((await user())['avatarUrl'], 'old');
    });
  });

  group('initials and the top bar button', () {
    testWidgets('no photo: initials on the primary circle', (tester) async {
      await pumpAt(tester, const ProfileAvatar(avatarUrl: null, name: 'Shanel Hassan', size: 40));
      expect(find.text('SH'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final text = tester.widget<Text>(find.text('SH'));
      expect(text.style!.color, colorsOf(tester, find.text('SH')).onPrimary);
    });

    testWidgets('below compact: the circle only; a tap opens the drawer', (tester) async {
      var taps = 0;
      await pumpAt(tester, Center(child: ProfileMenuButton(avatarUrl: null, name: 'Shanel Hassan', roleLabel: 'Owner', onTap: () => taps++)));
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.text('Shanel Hassan'), findsNothing);
      expect(find.text('Owner'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      await tester.tap(find.byType(ProfileMenuButton));
      expect(taps, 1);
    });

    testWidgets('wider: avatar, name, role and a chevron, 48 px high; a tap opens the drawer', (tester) async {
      var taps = 0;
      await pumpAt(tester, Center(child: ProfileMenuButton(avatarUrl: null, name: 'Shanel Hassan', roleLabel: 'Owner', onTap: () => taps++)),
          width: 1200);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.text('Shanel Hassan'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(tester.getSize(find.byType(ProfileMenuButton)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Shanel Hassan'));
      expect(taps, 1);
    });
  }, skip: _untilG2);

  group('the drawer', () {
    Widget drawer({String name = 'Shanel Hassan', String email = 'shanel@example.com'}) => Align(
          alignment: Alignment.centerRight,
          child: Drawer(
            child: ProfileDrawerContent(
              avatarUrl: null,
              name: name,
              roleLabel: 'Owner',
              email: email,
              phone: '+255 712 345 678',
              facility: 'Mwanaisha Agrovet and Veterinary Services Centre, Arusha',
              onClose: () {},
              actions: [
                for (final (icon, label) in [
                  (Icons.edit_outlined, 'Edit Profile'),
                  (Icons.group_outlined, 'Team Members'),
                  (Icons.store_outlined, 'View Facilities'),
                  (Icons.lock_outline, 'Change Password'),
                  (Icons.history, 'Activity Log'),
                ])
                  ProfileDrawerAction(icon: icon, label: label, onTap: () {}),
                ProfileDrawerAction(icon: Icons.logout, label: 'Sign out', onTap: () {}, destructive: true),
              ],
            ),
          ),
        );

    testWidgets('the avatar is display only: no camera button', (tester) async {
      await pumpAt(tester, drawer());
      expect(find.byIcon(Icons.camera_alt), findsNothing);
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
      expect(find.byIcon(Icons.photo_camera), findsNothing);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.descendant(of: find.byType(ProfileAvatar), matching: find.byType(InkWell)), findsNothing);
    });

    testWidgets('the details are labelled rows; the actions keep their order', (tester) async {
      await pumpAt(tester, drawer());
      for (final t in ['Email', 'Phone', 'Facility', 'shanel@example.com', '+255 712 345 678']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      final rows = find.byType(ProfileDrawerRow);
      expect(rows, findsNWidgets(6));
      final ys = [for (var i = 0; i < 6; i++) tester.getTopLeft(rows.at(i)).dy];
      expect(ys, [...ys]..sort());
      expect(tester.widget<ProfileDrawerRow>(rows.last).action.label, 'Sign out');
    });

    testWidgets('rows are no taller than 56 px at 390', (tester) async {
      await pumpAt(tester, drawer());
      final rows = find.byType(ProfileDrawerRow);
      for (var i = 0; i < 6; i++) {
        final h = tester.getSize(rows.at(i)).height;
        expect(h, lessThanOrEqualTo(56), reason: 'row $i');
        expect(h, greaterThanOrEqualTo(40), reason: 'row $i');
      }
    });

    for (final width in [360.0, 390.0]) {
      for (final b in Brightness.values) {
        for (final locale in ['en', 'sw']) {
          testWidgets('no overflow at $width, ${b.name}, $locale, with a very long name', (tester) async {
            await pumpAt(tester, drawer(name: _longName, email: _longEmail), width: width, brightness: b, locale: locale);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }, skip: _untilG2);

  group('the Edit Profile photo part', () {
    testWidgets('with a photo: Change photo and Remove photo', (tester) async {
      var changes = 0, removes = 0;
      await pumpAt(tester, ProfilePhotoEditor(
          avatarUrl: 'https://files.example/avatars/u1.jpg', previewBytes: null, name: 'Shanel Hassan',
          onChange: () => changes++, onRemove: () => removes++));
      // The photo cannot load in a test: the initials show in its place.
      await tester.tap(find.text('Change photo'));
      await tester.tap(find.text('Remove photo'));
      expect((changes, removes), (1, 1));
    });

    testWidgets('no photo: initials, Change photo, no Remove photo', (tester) async {
      await pumpAt(tester, ProfilePhotoEditor(
          avatarUrl: null, previewBytes: null, name: 'Shanel Hassan', onChange: () {}, onRemove: () {}));
      expect(find.text('SH'), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('while saving, both buttons wait', (tester) async {
      var taps = 0;
      await pumpAt(tester, ProfilePhotoEditor(
          avatarUrl: 'x', previewBytes: null, name: 'S H', onChange: () => taps++, onRemove: () => taps++, busy: true));
      await tester.tap(find.text('Change photo'), warnIfMissed: false);
      await tester.tap(find.text('Remove photo'), warnIfMissed: false);
      expect(taps, 0);
    });
  }, skip: _untilG2);

  group('one photo place', () {
    test('the dashboard has no camera and no upload of its own; one place writes the photo', () {
      final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
      for (final banned in ['Icons.camera_alt', 'user_avatars', '.pickImage(', 'pickProfileImage']) {
        expect(dash.contains(banned), isFalse, reason: 'dashboard still has $banned');
      }
      for (final path in ['lib/screens/register_screen.dart', 'lib/services/auth_service.dart']) {
        final src = File(path).readAsStringSync();
        expect(src.contains("'avatars/"), isFalse, reason: '$path writes avatars/ itself');
        expect(src.contains('.pickImage('), isFalse, reason: '$path picks a photo itself');
      }
    });
  }, skip: _untilG2);
}
