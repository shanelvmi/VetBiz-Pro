// LAY4: the real Settings and Reports inside AppShell (a fake Firestore, no
// dashboard): at 768 (rail 72), 1024 (sidebar 250) and 1200 (sidebar 250)
// at text 1.3, Light and Dark, every colour theme: no overflow, the sidebar
// on screen with the place selected, and no back arrow at the top level.
// Also: Settings' side panel follows the content width (owner, 2026-11-18),
// Back from a place returns to Home, and where a snack bar lands.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/ui/feedback/app_feedback.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

final _shell = GlobalKey<AppShellState>();

double _sidebarFor(Size size, {bool collapsed = false}) => size.width >= 1024 && !collapsed ? 250 : 72;

Widget? _pageFor(AppDestination d, FirebaseFirestore fs) => switch (d) {
      AppDestination.settings => SettingsScreen(firestore: fs, auth: Ph8Auth()),
      AppDestination.reports => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
      _ => null,
    };

Widget _harness(FirebaseFirestore fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          key: const ValueKey('sidebar'),
          width: sidebar,
          child: Column(children: [
            for (final d in [AppDestination.home, AppDestination.settings, AppDestination.reports])
              SizedBox(
                key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'),
                height: 48,
                child: TextButton(onPressed: () => onSelect(d), child: const SizedBox.shrink()),
              ),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => _pageFor(d, fs),
        onOpenFullScreen: (_) async {},
        onReturnedHome: (_) {},
      ),
    );

Future<void> _open(WidgetTester tester, AppDestination d) async {
  _shell.currentState!.select(d);
  await tester.pumpAndSettle();
}

Type _typeOf(AppDestination d) => d == AppDestination.settings ? SettingsScreen : ViewReportsScreen;

void main() {
  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    for (final theme in AppColorTheme.all) {
      for (final look in const [MatrixLook.light, MatrixLook.dark]) {
        for (final d in const [AppDestination.settings, AppDestination.reports]) {
          ph5TestWidgets('${d.name} in the shell, $at ${theme.id} ${look.name} text 1.3', (tester) async {
            await pumpPh5(tester, (fs) => _harness(fs, _sidebarFor(size)),
                size: size, look: look, colorTheme: theme, textScale: 1.3);
            await _open(tester, d);
            expect(tester.takeException(), isNull);
            expect(find.byType(_typeOf(d)), findsOneWidget);
            expect(find.byKey(ValueKey('sb-${d.name}-selected')), findsOneWidget, reason: 'the place is selected');
            // The place itself has no back arrow, and since LAY7 (#23) neither has
            // a pane embedded in Settings' side panel (Subscription, for an admin).
            expect(find.byType(BackButton), findsNothing, reason: 'top level and panes: no back arrow');
            final left = tester.getTopLeft(find.byType(_typeOf(d))).dx;
            expect(left, _sidebarFor(size), reason: 'beside the sidebar, not over it');
          });
        }
      }
    }
  }

  group('Settings follows the content width (side panel from 900)', () {
    for (final (size, collapsed, panel) in const [
      (Size(768, 1024), false, false),
      (Size(1024, 768), false, false),
      (Size(1024, 768), true, true),
      (Size(1200, 800), false, true),
    ]) {
      ph5TestWidgets('${size.width.toInt()} ${collapsed ? 'collapsed' : 'open'}: side panel $panel', (tester) async {
        await pumpPh5(tester, (fs) => _harness(fs, _sidebarFor(size, collapsed: collapsed)), size: size);
        await _open(tester, AppDestination.settings);
        // The side panel embeds the first section (Subscription, for an admin).
        expect(find.byType(SubscriptionScreen), panel ? findsOneWidget : findsNothing);
      });
    }
  });

  ph5TestWidgets('Back from Reports returns to Home; Settings then opens fresh at its top level', (tester) async {
    await pumpPh5(tester, (fs) => _harness(fs, 250), size: const Size(1200, 800));
    await _open(tester, AppDestination.reports);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
    await _open(tester, AppDestination.settings);
    expect(find.byKey(const ValueKey('sb-settings-selected')), findsOneWidget);
  });

  // The app's snack bars all go through AppFeedback (R11): floating, 400 wide,
  // centred on the window's bottom (the dashboard's Scaffold), not on the
  // content area. They never reach the sidebar or the rail.
  for (final size in const [Size(600, 800), Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    ph5TestWidgets('a snack bar from inside the shell at ${size.width.toInt()} stays off the sidebar', (tester) async {
      await pumpPh5(tester, (fs) => _harness(fs, _sidebarFor(size)), size: size);
      await _open(tester, AppDestination.settings);
      AppFeedback.info('saved');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final card = find.ancestor(of: find.text('saved'), matching: find.byType(Material)).first;
      final toast = tester.getRect(card);
      final sidebar = tester.getRect(find.byKey(const ValueKey('sidebar')));
      expect(toast.width, lessThanOrEqualTo(400), reason: 'the toast card itself');
      expect(toast.overlaps(sidebar), isFalse, reason: 'toast $toast, sidebar $sidebar');
      AppFeedback.messengerKey.currentState?.clearSnackBars();
      await tester.pumpAndSettle();
    });
  }
}
