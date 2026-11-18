// LAY3 (owner, 2026-11-18): on PC and tablet the profile panel holds personal
// items only. The wide list drops Settings (in the sidebar) and Help (in the
// top bar) and gains Language, which opens the Settings rows' own sheet
// (showLanguagePicker) and stores the same code. The phone list is unchanged
// (hub4b's tests pin it; repeated here against the wide one).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/app_defaults.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/profile_actions.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/profile/profile_drawer.dart';

import 'helpers/screen_size_matrix.dart';

final _en = lookupAppLocalizations(const Locale('en'));

ProfileHandlers _handlers(List<String> tapped) => ProfileHandlers(
      editProfile: () => tapped.add('editProfile'),
      team: () => tapped.add('team'),
      facilities: () => tapped.add('facilities'),
      changePassword: () => tapped.add('changePassword'),
      language: () => tapped.add('language'),
      activityLog: () => tapped.add('activityLog'),
      settings: () => tapped.add('settings'),
      help: () => tapped.add('help'),
      signOut: () => tapped.add('signOut'),
    );

List<ProfileItem?> _items({required bool admin, required bool wide}) =>
    profileActionsFor(_en, isAdmin: admin, wide: wide, on: _handlers([])).map((a) => a.item).toList();

Future<UiSettingsProvider> _provider(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  return (await tester.runAsync(() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }))!;
}

/// The wide panel as the dashboard builds it, the Language row wired to the
/// shared picker.
Widget _panel({required bool admin, required UiSettingsProvider ui}) {
  final key = GlobalKey<ScaffoldState>();
  WidgetsBinding.instance.addPostFrameCallback((_) => key.currentState?.openEndDrawer());
  return Scaffold(
    key: key,
    body: const SizedBox.expand(),
    endDrawer: Drawer(
      child: Builder(
        builder: (context) => ProfileDrawerContent(
          avatarUrl: null,
          name: matrixLongClientName,
          roleLabel: admin ? 'Admin' : 'Assistant',
          email: 'mwanaisha.abdallah.mohamedi@kijiji-cha-mwembeni-juu.co.tz',
          phone: '+255 712 345 678',
          facility: matrixLongFacilityName,
          facilityType: 'Agrovet',
          onClose: () {},
          actions: profileActionsFor(
            context.l10nForTest,
            isAdmin: admin,
            wide: true,
            on: ProfileHandlers(
              editProfile: () {},
              team: () {},
              facilities: () {},
              changePassword: () {},
              language: () => showLanguagePicker(context, ui),
              activityLog: () {},
              settings: () {},
              help: () {},
              signOut: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

extension on BuildContext {
  AppLocalizations get l10nForTest => AppLocalizations.of(this)!;
}

void main() {
  group('the lists', () {
    test('phone (default, wide: false): today\'s list exactly, per role', () {
      final phone = [
        ProfileItem.editProfile,
        ProfileItem.team,
        ProfileItem.facilities,
        ProfileItem.changePassword,
        ProfileItem.activityLog,
        ProfileItem.settings,
        ProfileItem.help,
        ProfileItem.signOut,
      ];
      expect(_items(admin: true, wide: false), phone);
      expect(profileActionsFor(_en, isAdmin: true, on: _handlers([])).map((a) => a.item), phone);
      expect(_items(admin: false, wide: false), [
        ProfileItem.editProfile,
        ProfileItem.changePassword,
        ProfileItem.settings,
        ProfileItem.help,
        ProfileItem.signOut,
      ]);
    });

    test('wide, admin: Edit Profile, Team, Facilities, Change password, Language, Activity Log, Sign out', () {
      final actions = profileActionsFor(_en, isAdmin: true, wide: true, on: _handlers([]));
      expect(actions.map((a) => a.label), [
        _en.common_editProfile,
        _en.team_title,
        _en.dashboard_viewFacilities,
        _en.dashboard_changePassword,
        _en.settings_languageBoth,
        _en.export_activityLog,
        _en.common_logout,
      ]);
      expect(actions.last.destructive, isTrue);
    });

    test('wide, assistant: Edit Profile, Change password, Language, Sign out', () {
      expect(_items(admin: false, wide: true), [
        ProfileItem.editProfile,
        ProfileItem.changePassword,
        ProfileItem.language,
        ProfileItem.signOut,
      ]);
    });

    test('Settings and Help: absent in wide, present on the phone; Language only in wide', () {
      for (final admin in [true, false]) {
        final wide = _items(admin: admin, wide: true);
        final phone = _items(admin: admin, wide: false);
        expect(wide, isNot(contains(ProfileItem.settings)));
        expect(wide, isNot(contains(ProfileItem.help)));
        expect(phone, containsAll([ProfileItem.settings, ProfileItem.help]));
        expect(phone, isNot(contains(ProfileItem.language)));
      }
    });

    test('the Language row reuses the Settings row\'s label and icon and runs its own handler', () {
      final tapped = <String>[];
      final row = profileActionsFor(_en, isAdmin: false, wide: true, on: _handlers(tapped))
          .singleWhere((a) => a.item == ProfileItem.language);
      expect(row.label, _en.settings_languageBoth);
      expect(row.icon, Icons.language_outlined);
      row.onTap();
      expect(tapped, ['language']);
    });
  });

  group('the source', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final settings = File('lib/screens/settings/settings_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');

    test('the dashboard passes wide: true exactly once, in the end drawer; the phone page does not', () {
      expect(RegExp(r'wide: true').allMatches(dash).length, 1);
      final drawer = dash.substring(dash.indexOf('Widget _buildEndDrawerContent()'), dash.indexOf('ProfileHandlers _profileHandlers('));
      expect(drawer, contains('profileActionsFor(context.l10n, isAdmin: isAdmin, wide: true, on: _profileHandlers(context))'));
      expect(dash, contains('actions: profileActionsFor(pageContext.l10n, isAdmin: isAdmin, on: _profileHandlers(pageContext)),'));
      expect(dash, contains('language: () => showLanguagePicker(context, context.read<UiSettingsProvider>()),'));
    });

    test('Settings: both Language rows call the one shared picker, which stores through setLocale', () {
      expect(settings, isNot(contains('_showLanguageSelection')));
      expect(RegExp(r'showLanguagePicker\(context, uiSettings\)').allMatches(settings).length, 2);
      final picker = settings.substring(settings.indexOf('void showLanguagePicker(BuildContext context, UiSettingsProvider uiSettings) {'));
      expect(picker, contains('showModalBottomSheet('));
      expect(picker, contains('context.l10n.settings_selectLanguageBoth'));
      expect(picker, contains('AppDefaults.supportedLanguages'));
      expect(picker, contains('uiSettings.setLocale(code);'));
    });
  });

  group('the Language row in the panel', () {
    testWidgets('opens the Settings sheet over the panel; a pick stores the same code as Settings', (tester) async {
      final ui = await _provider(tester);
      expect(ui.languageCode, AppDefaults.defaultLanguage);
      await pumpAtSize(tester, screen: _panel(admin: true, ui: ui), size: const Size(1200, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.settings_languageBoth));
      await tester.pumpAndSettle();
      expect(find.text(_en.settings_selectLanguageBoth), findsOneWidget, reason: 'the Settings sheet, same title');
      for (final code in AppDefaults.supportedLanguages) {
        expect(find.text(AppDefaults.languageNames[code]!), findsOneWidget);
      }
      expect(find.byType(Drawer), findsOneWidget, reason: 'the panel stays open under the sheet');
      await tester.runAsync(() async {
        await tester.tap(find.text(AppDefaults.languageNames['sw']!));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(ui.languageCode, 'sw', reason: 'the stored value is the code, as from Settings');
    });

    for (final theme in AppColorTheme.all) {
      for (final look in MatrixLook.values) {
        for (final admin in [true, false]) {
          final name = '${theme.id} ${look.name} ${admin ? 'admin' : 'assistant'}';
          testWidgets('$name at text 1.3: rows >= 44 px, no overflow', (tester) async {
            final ui = await _provider(tester);
            for (final size in const [Size(768, 1024), Size(1200, 800)]) {
              await pumpAtSize(tester,
                  screen: _panel(admin: admin, ui: ui), size: size, look: look, textScale: 1.3, colorTheme: theme);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              // The list is lazy: scroll to its last row (Sign out) first.
              final last = find.text(look == MatrixLook.kiswahili
                  ? lookupAppLocalizations(const Locale('sw')).common_logout
                  : _en.common_logout);
              await tester.scrollUntilVisible(last, 100,
                  scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
              expect(tester.takeException(), isNull);
              final rows = find.byType(ProfileDrawerRow);
              expect(rows, findsWidgets);
              for (final e in rows.evaluate()) {
                final s = tester.getSize(find.byWidget(e.widget));
                expect(s.height, greaterThanOrEqualTo(44));
              }
            }
          });
        }
      }
    }
  });
}
