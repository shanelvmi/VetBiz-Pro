import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

// AN2: the shared fixtures of the login page's Updates tests.

final enL10n = lookupAppLocalizations(const Locale('en'));
final swL10n = lookupAppLocalizations(const Locale('sw'));

// A real 1 x 1 PNG, so a poster can load in a test.
final testPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final testNow = DateTime(2026, 10, 26, 12);

Announcement textUpdate(
  String id, {
  String? title,
  String message = 'A short message',
  bool urgent = false,
  bool fresh = false,
  String? link,
  String? label,
}) => Announcement.fromMap(id, {
  'title': title ?? 'Title $id',
  'message': message,
  'urgent': urgent,
  'timestamp': Timestamp.fromDate(fresh ? testNow.subtract(const Duration(hours: 1)) : DateTime(2026, 1, 1)),
  if (link != null) 'linkUrl': link,
  if (label != null) 'linkLabel': label,
});

Announcement posterUpdate(String id, {bool urgent = false, bool fresh = false, String url = 'https://files.example/p.png'}) =>
    Announcement.fromMap(id, {
      'kind': 'poster',
      'title': 'Poster $id',
      'imageUrl': url,
      'urgent': urgent,
      'timestamp': Timestamp.fromDate(fresh ? testNow.subtract(const Duration(hours: 1)) : DateTime(2026, 1, 1)),
    });

ImageProvider goodImage(String url) => MemoryImage(testPng);
ImageProvider badImage(String url) => MemoryImage(Uint8List.fromList(const [1, 2, 3, 4]));

String longText(String word, int n) => List.filled(n, word).join(' ');

Widget updatesApp(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: AppTheme.build(AppColorTheme.pasture, brightness),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> pumpSlides(
  WidgetTester tester,
  List<Announcement> slides, {
  double width = 1200,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  AuthFooterLauncherForTest? launcher,
  ImageProvider Function(String)? imageFor,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // About the login column's width: half the card on wide, the card on phones.
  final column = width > 820 ? 480.0 : width - 64;
  await tester.pumpWidget(
    updatesApp(
      Center(
        child: SizedBox(
          width: column,
          child: UpdatesSlides(
            slides: slides,
            now: () => testNow,
            imageFor: imageFor ?? goodImage,
            launcher: launcher ?? (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
          ),
        ),
      ),
      locale: locale,
      brightness: brightness,
      reduceMotion: reduceMotion,
    ),
  );
  await tester.pump();
}

Rect frame(WidgetTester tester) => tester.getRect(find.byKey(UpdatesSlides.frameKey));

typedef AuthFooterLauncherForTest = Future<bool> Function(Uri url, {LaunchMode mode});

class CountingAnnouncementsFirestore implements FirebaseFirestore {
  CountingAnnouncementsFirestore(this.inner);

  final FakeFirebaseFirestore inner;
  int reads = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == Collections.publicAnnouncements) reads++;
    return inner.collection(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
