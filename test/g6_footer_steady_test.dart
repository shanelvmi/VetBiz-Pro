import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/login_screen.dart';
import 'package:vetbiz_pro/screens/register_screen.dart';
import 'package:vetbiz_pro/services/auth_service.dart';
import 'package:vetbiz_pro/services/support_contact_store.dart';
import 'package:vetbiz_pro/services/updates_last_known.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/auth_footer.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'g6_support_contact_store_test.dart' show FakeContactRead, sixLinks;
import 'helpers/register_harness.dart';

// G6, the owner's report "the footer bounces twice": each page read the
// support contact itself and drew no icons until that read answered, and the
// icons made the bottom row taller. Written before the fix (skipped until it
// exists). The pages read a Firestore that holds the six links (what the old
// code reads) and the app's store reads them through a fake that answers when
// the test says (what the new code reads).
const _skip = true;

class _NoAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

enum _Page { login, register }

void main() {
  late FakeContactRead read;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    read = FakeContactRead();
    SupportContactStore.debugInstance = SupportContactStore(fetch: read.call);
  });

  Future<FakeFirebaseFirestore> dbWith(Map<String, dynamic>? contact) async {
    final db = FakeFirebaseFirestore();
    if (contact != null) await db.collection(Collections.appConfig).doc(SupportContactFields.docId).set(contact);
    return db;
  }

  Widget screen(_Page page, FirebaseFirestore db) => switch (page) {
        _Page.login => LoginScreen(authService: _NoAuth(), firestore: db),
        _Page.register =>
          RegisterScreen(firestore: db, authService: FakeRegisterAuth(), membershipService: FakeRegisterMembership()),
      };

  /// Builds [page] and its FIRST frame only.
  Future<void> pumpPage(WidgetTester tester, _Page page, FirebaseFirestore db, {double width = 1200, double height = 2600}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
        // A new route each time, as navigating does.
        home: KeyedSubtree(key: UniqueKey(), child: screen(page, db)),
      ),
    ));
  }

  double footerTop(WidgetTester tester) => tester.getRect(find.byKey(AuthFooter.bandKey)).top;
  int icons(WidgetTester tester) => find.byType(FaIcon).evaluate().length;

  /// Lets the read answer, then everything settle.
  Future<void> answer(WidgetTester tester, [Map<String, dynamic>? data = sixLinks]) async {
    if (read.pending.isNotEmpty) read.answer(data);
    await tester.pumpAndSettle();
  }

  for (final page in _Page.values) {
    for (final width in [1200.0, 768.0, 390.0]) {
      testWidgets('${page.name} $width: the footer\'s top edge does not move when the contact arrives', (tester) async {
        await pumpPage(tester, page, await dbWith(sixLinks), width: width);
        final before = footerTop(tester);
        await answer(tester);
        expect(icons(tester), 6, reason: 'the icons did arrive');
        expect(footerTop(tester), before);
      }, skip: _skip);
    }
  }

  for (final width in [1200.0, 768.0, 390.0]) {
    testWidgets('$width: the bottom row is as tall with zero links as with six', (tester) async {
      await pumpPage(tester, _Page.login, await dbWith(null), width: width);
      await answer(tester, const {});
      expect(icons(tester), 0);
      final none = tester.getSize(find.byKey(AuthFooter.bottomRowKey)).height;

      SupportContactStore.debugInstance = SupportContactStore(fetch: read.call);
      await pumpPage(tester, _Page.login, await dbWith(sixLinks), width: width);
      await answer(tester);
      expect(icons(tester), 6);
      expect(tester.getSize(find.byKey(AuthFooter.bottomRowKey)).height, none);
      expect(none, greaterThanOrEqualTo(AuthFooterMetrics.tapTarget));
    }, skip: _skip);
  }

  testWidgets('login, Register, then login again: the icons are on the FIRST frame of each later page', (tester) async {
    final db = await dbWith(sixLinks);
    await pumpPage(tester, _Page.login, db);
    await answer(tester);
    expect(icons(tester), 6);

    await pumpPage(tester, _Page.register, db);
    expect(icons(tester), 6, reason: 'register, first frame');
    await tester.pumpAndSettle();

    await pumpPage(tester, _Page.login, db);
    expect(icons(tester), 6, reason: 'login again, first frame');
    await tester.pumpAndSettle();
    expect(read.reads, 1, reason: 'one read for the whole session');
  }, skip: _skip);

  testWidgets('a cold start with a persisted copy draws the icons on the first frame', (tester) async {
    SharedPreferences.setMockInitialValues({SupportContactStore.prefsKey: jsonEncode(sixLinks)});
    await tester.runAsync(() => SupportContactStore.instance.restore());
    await pumpPage(tester, _Page.login, await dbWith(sixLinks), width: 390);
    expect(icons(tester), 6);
    await answer(tester);
    expect(icons(tester), 6);
  }, skip: _skip);

  for (final page in _Page.values) {
    testWidgets('${page.name}: on a tall window the footer sits at the bottom edge', (tester) async {
      await pumpPage(tester, page, await dbWith(sixLinks), width: 1200, height: 2600);
      await answer(tester);
      expect(tester.getRect(find.byKey(AuthFooter.bandKey)).bottom, 2600);
    }, skip: _skip);
  }

  group('the Updates frame while their first answer is pending', () {
    Future<FakeFirebaseFirestore> withUpdate() async {
      final db = await dbWith(null);
      await db.collection(Collections.publicAnnouncements).doc('1').set({
        'title': 'Title 1',
        'message': 'Message 1',
        'urgent': false,
        'hidden': false,
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      return db;
    }

    for (final width in [1200.0, 390.0]) {
      testWidgets('$width: kept from the first frame when the last-known state says there were updates', (tester) async {
        UpdatesLastKnown.instance.record(true);
        await pumpPage(tester, _Page.login, await withUpdate(), width: width);
        expect(find.byKey(UpdatesCarousel.skeletonKey), findsOneWidget);
        final before = footerTop(tester);
        await answer(tester);
        expect(find.byKey(UpdatesCarousel.skeletonKey), findsNothing);
        expect(find.byType(UpdatesSlides), findsOneWidget);
        expect(footerTop(tester), before, reason: 'the Updates arrived without moving the footer');
      }, skip: _skip);
    }

    for (final had in [false, null]) {
      testWidgets('nothing kept when the last-known state is $had', (tester) async {
        if (had != null) UpdatesLastKnown.instance.record(had);
        await pumpPage(tester, _Page.login, await dbWith(null), width: 390);
        expect(find.byKey(UpdatesCarousel.skeletonKey), findsNothing);
        await answer(tester);
        expect(find.byType(UpdatesSlides), findsNothing);
      }, skip: _skip);
    }

    testWidgets('the answer is remembered for the next visit', (tester) async {
      await pumpPage(tester, _Page.login, await withUpdate(), width: 390);
      await answer(tester);
      expect(UpdatesLastKnown.instance.hadUpdates, isTrue);
      await pumpPage(tester, _Page.login, await dbWith(null), width: 390);
      await answer(tester);
      expect(UpdatesLastKnown.instance.hadUpdates, isFalse);
    }, skip: _skip);
  });
}
