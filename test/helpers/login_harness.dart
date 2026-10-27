import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/l10n/app_localizations_en.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// AN4: the login page with a fake Firestore, in any theme, brightness,
// language and width; the Updates added as documents.

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// English with a very long welcome line (the overflow tests).
class LongWelcomeEn extends AppLocalizationsEn {
  @override
  // ignore: non_constant_identifier_names
  String get updates_welcomeLine => List.filled(40, 'Mauzo bidhaa wateja madeni').join(' ');
}

class _LongWelcomeDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LongWelcomeDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(LongWelcomeEn());

  @override
  bool shouldReload(_LongWelcomeDelegate old) => false;
}

/// Builds the login page; [settle] false leaves the Updates' first answer
/// pending (one frame only).
Future<void> pumpLogin(
  WidgetTester tester,
  FirebaseFirestore db, {
  double width = 1200,
  double height = 1000,
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool longWelcome = false,
  bool settle = true,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final ui = (await tester.runAsync(() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }))!;
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: ui,
    child: MaterialApp(
      localizationsDelegates: [if (longWelcome) const _LongWelcomeDelegate(), ...AppLocalizations.localizationsDelegates],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(theme, brightness),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      // A new route each time, as navigating does.
      home: KeyedSubtree(key: UniqueKey(), child: LoginScreen(authService: _NoAuth(), firestore: db)),
    ),
  ));
  if (!settle) return;
  await tester.pump();
  await tester.pump();
}

Future<void> addUpdate(FakeFirebaseFirestore db, String id, [Map<String, dynamic> data = const {}]) =>
    db.collection(Collections.publicAnnouncements).doc(id).set({
      'title': 'Title $id',
      'message': 'Message $id',
      'urgent': false,
      'hidden': false,
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      ...data,
    });

/// A poster (its image never loads in a test: the frame keeps its shape).
Map<String, dynamic> posterData({bool urgent = false, bool fresh = false}) => {
  'kind': 'poster',
  'imageUrl': 'https://files.example/p.png',
  'urgent': urgent,
  if (fresh) 'timestamp': Timestamp.now(),
};

/// None, one, or several (text, poster, text) Updates.
Future<FakeFirebaseFirestore> dbWithUpdates(int count) async {
  final db = FakeFirebaseFirestore();
  for (var i = 1; i <= count; i++) {
    await addUpdate(db, '$i', i == 2 ? posterData() : const {});
  }
  return db;
}
