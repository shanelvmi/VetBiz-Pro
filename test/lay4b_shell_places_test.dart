// LAY4b: Insights (a shell place, a page at every wide width), Activity Log
// and Notifications (openInContent, Settings highlighted) inside AppShell,
// over a fake Firestore (no dashboard): 768 (rail 72), 1024 (sidebar 250)
// and 1200 (sidebar 250), plus collapsed widths, giving content 696, 774,
// 950 and 1128; text 1.3, Light and Dark, every colour theme: no overflow,
// the sidebar on screen with the right item highlighted. Back pops inside,
// then Home. The profile panel closes before the screen opens.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/activity/activity_log_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/notifications_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/fake_firestore.dart' show testUserId;
import 'helpers/notification_harness.dart' show Clock, newFeed;
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

final _shell = GlobalKey<AppShellState>();
final _scaffold = GlobalKey<ScaffoldState>();
final _returned = <AppDestination>[];

const _places = [AppDestination.home, AppDestination.insights, AppDestination.settings];

Widget _harness(FirebaseFirestore fs, double sidebar) => Scaffold(
      key: _scaffold,
      endDrawer: Drawer(
        child: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('panel-activity'),
            // As the dashboard's handler: close the panel, then open in the content.
            onPressed: () {
              Scaffold.maybeOf(context)?.closeEndDrawer();
              _shell.currentState!.openInContent(ActivityLogScreen(firestore: fs, auth: Ph8Auth()),
                  highlight: AppDestination.settings);
            },
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ),
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          key: const ValueKey('sidebar'),
          width: sidebar,
          child: Column(children: [
            for (final d in _places)
              SizedBox(
                key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'),
                height: 48,
                child: TextButton(onPressed: () => onSelect(d), child: const SizedBox.shrink()),
              ),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => d == AppDestination.insights ? InsightsScreen(firestore: fs) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: _returned.add,
      ),
    );

/// What each case opens, and the item it must highlight.
enum _Place {
  insights(AppDestination.insights),
  activityLog(AppDestination.settings),
  notifications(AppDestination.settings);

  const _Place(this.highlight);
  final AppDestination highlight;
}

Type _typeOf(_Place p) => switch (p) {
      _Place.insights => InsightsScreen,
      _Place.activityLog => ActivityLogScreen,
      _Place.notifications => NotificationsScreen,
    };

Future<void> _show(WidgetTester tester, _Place p, FirebaseFirestore fs) async {
  final shell = _shell.currentState!;
  switch (p) {
    case _Place.insights:
      shell.select(AppDestination.insights);
    case _Place.activityLog:
      shell.openInContent(ActivityLogScreen(firestore: fs, auth: Ph8Auth()), highlight: AppDestination.settings);
    case _Place.notifications:
      // A feed on the fake Firestore (the screen would build one from Firebase).
      final feed = newFeed(fs, testUserId, Clock()..now = DateTime(2026, 11, 18))..start();
      addTearDown(feed.dispose);
      shell.openInContent(NotificationsScreen(controller: feed), highlight: AppDestination.settings);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(_returned.clear);

  // Window, sidebar width: content 696, 774, 950 and 1128 (the owner's list).
  for (final (size, sidebar) in const [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ]) {
    final content = (size.width - sidebar).toInt();
    for (final theme in AppColorTheme.all) {
      for (final look in const [MatrixLook.light, MatrixLook.dark]) {
        for (final p in _Place.values) {
          ph5TestWidgets('${p.name} in the shell, content $content ${theme.id} ${look.name} text 1.3', (tester) async {
            late FirebaseFirestore store;
            await pumpPh5(tester, (fs) {
              store = fs;
              return _harness(fs, sidebar);
            }, size: size, look: look, colorTheme: theme, textScale: 1.3);
            await _show(tester, p, store);
            expect(tester.takeException(), isNull);
            final screen = find.byType(_typeOf(p));
            expect(screen, findsOneWidget);
            expect(tester.getTopLeft(screen).dx, sidebar, reason: 'beside the sidebar, not over it');
            expect(find.byKey(ValueKey('sb-${p.highlight.name}-selected')), findsOneWidget);
            // Insights is a top-level place (no back arrow); the other two
            // are screens opened above where you were (theirs stays).
            expect(find.byType(BackButton), p == _Place.insights ? findsNothing : findsOneWidget);
            if (p == _Place.insights) {
              final page = tester.widget<InsightsScreen>(screen);
              expect(page.isModal, isFalse, reason: 'a page, not the 900+ modal');
            }
          });
        }
      }
    }
  }

  for (final p in _Place.values) {
    ph5TestWidgets('${p.name}: Back pops inside, then Home', (tester) async {
      late FirebaseFirestore store;
      await pumpPh5(tester, (fs) {
        store = fs;
        return _harness(fs, 250);
      }, size: const Size(1200, 800));
      await _show(tester, p, store);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(_typeOf(p)), findsNothing);
      expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
      expect(_returned, p == _Place.insights ? [AppDestination.insights] : isEmpty);
    });
  }

  ph5TestWidgets('Insights over Settings\' Activity Log: Back returns to Insights, highlighted again', (tester) async {
    late FirebaseFirestore store;
    await pumpPh5(tester, (fs) {
      store = fs;
      return _harness(fs, 250);
    }, size: const Size(1200, 800));
    await _show(tester, _Place.insights, store);
    await _show(tester, _Place.activityLog, store);
    expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InsightsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-insights-selected')), findsOneWidget);
  });

  ph5TestWidgets('the profile panel closes first, then the log opens in the content', (tester) async {
    await pumpPh5(tester, (fs) => _harness(fs, 250), size: const Size(1200, 800));
    _scaffold.currentState!.openEndDrawer();
    await tester.pumpAndSettle();
    expect(_scaffold.currentState!.isEndDrawerOpen, isTrue);
    await tester.tap(find.byKey(const ValueKey('panel-activity')));
    await tester.pumpAndSettle();
    expect(_scaffold.currentState!.isEndDrawerOpen, isFalse, reason: 'no screen under an open panel');
    expect(find.byType(ActivityLogScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
  });

  group('the dashboard', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    test('the panel\'s Activity Log closes the panel before opening in the shell; a phone pushes as before', () {
      final handler = dash.substring(dash.indexOf('        activityLog: () {'), dash.indexOf('        settings: () =>'));
      // LAY7: in the shell it opens Settings > Business > Activity Log.
      expect(handler.indexOf('closeEndDrawer()'), lessThan(handler.indexOf('_openSettingsItem(const SettingsRequest(SettingsRequest.activityLog))')));
      expect(handler.indexOf('_openSettingsItem('), isNonNegative);
      expect(handler, contains('Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityLogScreen()));'));
      expect(dash, contains('return (page) => shell.openInContent(page, highlight: AppDestination.settings);'));
    });
    test('the bell and Home\'s Insights button go through the shell', () {
      // LAY6a added openPlace (a notification's client opens in the shell).
      expect(dash, contains('anchorKey: _bellKey, openPage: _openInShellAsSettings(), openPlace: _openInShellAs());'));
      expect(dash, contains('onInsights: () => _shellKey.currentState?.select(AppDestination.insights),'));
      expect(AppDestination.insights.refreshHomeOnReturn, isFalse, reason: 'Home is not refreshed after Insights');
    });
  });
}
