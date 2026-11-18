// LAY4: the wide shell's content Navigator (AppShell), pumped with stand-ins
// (no Firebase): migrated destinations open inside the shell with the
// sidebar on screen and highlighted; Back pops the content first, then Home;
// Home is kept alive; unmigrated places still open full screen; Home is told
// which place was left; the content's MediaQuery width (never under 600,
// window height).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

const _sidebarWidth = 72.0;

class _Log {
  int homeInits = 0;
  final full = <AppDestination>[];
  final returned = <AppDestination>[];
  final widths = <String, double>{};
  final heights = <String, double>{};
  final topLevel = <String, bool>{};
}

class _Home extends StatefulWidget {
  const _Home(this.log);
  final _Log log;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    widget.log.homeInits++;
  }

  @override
  Widget build(BuildContext context) {
    widget.log.widths['home'] = MediaQuery.sizeOf(context).width;
    return Column(children: [
      Text('home $count'),
      TextButton(onPressed: () => setState(() => count++), child: const Text('plus')),
    ]);
  }
}

class _Dest extends StatelessWidget {
  const _Dest(this.name, this.log);
  final String name;
  final _Log log;
  @override
  Widget build(BuildContext context) {
    log.widths[name] = MediaQuery.sizeOf(context).width;
    log.heights[name] = MediaQuery.sizeOf(context).height;
    log.topLevel[name] = ShellScope.isTopLevel(context);
    return Scaffold(
      body: Column(children: [
        Text('page $name'),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
            log.topLevel['$name-inner'] = ShellScope.isTopLevel(context);
            log.widths['$name-inner'] = MediaQuery.sizeOf(context).width;
            return Scaffold(body: Text('inner $name'));
          })),
          child: Text('open inside $name'),
        ),
      ]),
    );
  }
}

Widget _app(_Log log) => MaterialApp(
      home: Scaffold(
        body: AppShell(
          sidebar: (selected, onSelect) => SizedBox(
            width: _sidebarWidth,
            child: Column(children: [
              for (final d in [AppDestination.home, AppDestination.settings, AppDestination.reports, AppDestination.sales])
                TextButton(
                  key: ValueKey('sb-${d.name}'),
                  onPressed: () => onSelect(d),
                  child: Text(d == selected ? '*${d.name}' : d.name),
                ),
            ]),
          ),
          topBar: const SizedBox(height: 56, child: Text('top bar')),
          home: _Home(log),
          pageFor: (d) => switch (d) {
            AppDestination.settings => _Dest('settings', log),
            AppDestination.reports => _Dest('reports', log),
            _ => null,
          },
          onOpenFullScreen: (d) async => log.full.add(d),
          onReturnedHome: log.returned.add,
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, _Log log, {Size size = const Size(1200, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(log));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a migrated place opens inside the shell: sidebar and top bar on screen, the item selected', (tester) async {
    final log = _Log();
    await _pump(tester, log);
    expect(find.text('*home'), findsOneWidget);
    for (final name in ['settings', 'reports']) {
      await _tap(tester, 'sb-$name');
      expect(find.text('page $name'), findsOneWidget);
      expect(find.text('*$name'), findsOneWidget);
      expect(find.text('top bar'), findsOneWidget);
      expect(find.byKey(const ValueKey('sb-home')), findsOneWidget);
      expect(log.topLevel[name], isTrue, reason: 'top level: no back arrow');
    }
    expect(log.returned, isEmpty, reason: 'switching places is not a return to Home');
  });

  testWidgets('Back: the screen inside, then the place, then Home; the place stays selected under its screens',
      (tester) async {
    final log = _Log();
    await _pump(tester, log);
    await _tap(tester, 'sb-settings');
    await tester.tap(find.text('open inside settings'));
    await tester.pumpAndSettle();
    expect(find.text('inner settings'), findsOneWidget);
    expect(find.text('*settings'), findsOneWidget, reason: 'a screen above a place keeps it selected');
    expect(find.text('top bar'), findsOneWidget);
    expect(log.topLevel['settings-inner'], isFalse, reason: 'pushed above: keeps its back arrow');

    await _back(tester);
    expect(find.text('page settings'), findsOneWidget);
    expect(find.text('*settings'), findsOneWidget);
    await _back(tester);
    expect(find.text('home 0'), findsOneWidget);
    expect(find.text('*home'), findsOneWidget);
    expect(log.returned, [AppDestination.settings]);

    await _back(tester);
    expect(find.text('home 0'), findsOneWidget, reason: 'at Home, Back leaves as today');
  });

  testWidgets('Home is kept alive: Home -> Settings -> Back does not rebuild it from scratch', (tester) async {
    final log = _Log();
    await _pump(tester, log);
    await tester.tap(find.text('plus'));
    await tester.pumpAndSettle();
    expect(log.homeInits, 1);
    await _tap(tester, 'sb-settings');
    await _back(tester);
    expect(log.homeInits, 1);
    expect(find.text('home 1'), findsOneWidget, reason: 'its state survived');
    await _tap(tester, 'sb-reports');
    await _tap(tester, 'sb-home');
    expect(log.homeInits, 1);
    expect(log.returned, [AppDestination.settings, AppDestination.reports]);
  });

  testWidgets('choosing the open place again returns to its first screen', (tester) async {
    final log = _Log();
    await _pump(tester, log);
    await _tap(tester, 'sb-reports');
    await tester.tap(find.text('open inside reports'));
    await tester.pumpAndSettle();
    await _tap(tester, 'sb-reports');
    expect(find.text('page reports'), findsOneWidget);
    expect(find.text('inner reports'), findsNothing);
  });

  testWidgets('a place not migrated opens full screen, as before; the content is untouched', (tester) async {
    final log = _Log();
    await _pump(tester, log);
    await _tap(tester, 'sb-settings');
    await _tap(tester, 'sb-sales');
    expect(log.full, [AppDestination.sales]);
    expect(find.text('page settings'), findsOneWidget);
    expect(find.text('*settings'), findsOneWidget);
  });

  group('the content width', () {
    for (final (w, expected) in [(1200.0, 1128.0), (768.0, 696.0), (650.0, 600.0)]) {
      testWidgets('window $w: the places see $expected, the window height; Home sees the window', (tester) async {
        final log = _Log();
        await _pump(tester, log, size: Size(w, 800));
        expect(log.widths['home'], w);
        await _tap(tester, 'sb-settings');
        expect(log.widths['settings'], expected);
        expect(log.heights['settings'], 800, reason: 'the window height: the phone-landscape rule is untouched');
        await tester.tap(find.text('open inside settings'));
        await tester.pumpAndSettle();
        expect(log.widths['settings-inner'], expected, reason: 'screens pushed inside measure the content too');
      });
    }
  });

  group('the dashboard', () {
    final dash = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    test('the phone branch has no shell; the wide one has exactly one', () {
      final phone = dash.substring(dash.indexOf('phone: (_) => PhoneHub('), dash.indexOf('wide: (_) => Scaffold('));
      expect(phone, isNot(contains('AppShell')));
      expect(RegExp(r'child: AppShell\(').allMatches(dash).length, 1);
    });
    test('only Settings and Reports live in the shell; Home is refreshed per the registry', () {
      final pages = dash.substring(dash.indexOf('Widget? _shellPageFor('));
      final body = pages.substring(0, pages.indexOf('};'));
      expect(RegExp(r'AppDestination\.\w+ =>').allMatches(body).map((m) => m.group(0)).toList(),
          ['AppDestination.settings =>', 'AppDestination.reports =>']);
      expect(dash, contains('if (left.refreshHomeOnReturn) _refreshDashboardData();'));
      expect(dash, contains('onOpenFullScreen: _openDestination,'));
      expect(AppDestination.settings.refreshHomeOnReturn || AppDestination.reports.refreshHomeOnReturn, isFalse);
    });
  });
}
