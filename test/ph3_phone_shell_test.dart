// PH3 (2), (3) and (6): the phone shell with fake tab roots (the real
// screens need the whole signed-in app; phone_foundations.md section 10).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/screen_size_matrix.dart';

const _skip = true;

/// How many times each fake tab was built (its initState).
final _built = <String, int>{};

class _FakeTab extends StatefulWidget {
  final String name;
  const _FakeTab(this.name);
  @override
  State<_FakeTab> createState() => _FakeTabState();
}

class _FakeTabState extends State<_FakeTab> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    _built[widget.name] = (_built[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          key: ValueKey('${widget.name} list'),
          children: [
            Text('${widget.name} tab'),
            TextButton(onPressed: () => setState(() => count++), child: Text('${widget.name} count $count')),
            for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('${widget.name} row $i')),
          ],
        ),
      );
}

int _records = 0;

Future<void> _shell(WidgetTester tester, {Size size = const Size(390, 844), double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  _built.clear();
  _records = 0;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    home: PhoneShell(
      homeAppBar: AppBar(
        title: const Text('HOME BAR'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'avatar',
              icon: const Icon(Icons.person),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const Drawer(child: Text('PROFILE DRAWER')),
      home: (_) => const _FakeTab('home'),
      sales: (_) => const _FakeTab('sales'),
      products: (_) => const _FakeTab('products'),
      more: (_) => const _FakeTab('more'),
      onRecord: () => _records++,
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _barItem(String label) => find.descendant(of: find.byType(PhoneBottomBar), matching: find.text(label));
Future<void> _go(WidgetTester tester, String label) async {
  await tester.tap(_barItem(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tab is built only on its first visit, then kept', (tester) async {
    await _shell(tester);
    expect(_built, {'home': 1});
    await _go(tester, 'Sales');
    expect(_built, {'home': 1, 'sales': 1});
    await _go(tester, 'Home');
    await _go(tester, 'Sales');
    await _go(tester, 'Products');
    await _go(tester, 'More');
    expect(_built, {'home': 1, 'sales': 1, 'products': 1, 'more': 1});
  }, skip: _skip);

  testWidgets('each tab keeps its state: a counter and a scroll offset survive switching', (tester) async {
    await _shell(tester);
    await tester.tap(find.text('home count 0'));
    await tester.drag(find.byKey(const ValueKey('home list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(offset, greaterThan(0));
    await _go(tester, 'Sales');
    expect(find.text('sales tab'), findsOneWidget);
    await _go(tester, 'Home');
    expect(find.text('home count 1', skipOffstage: false), findsOneWidget);
    final scrollable = find.descendant(of: find.byKey(const ValueKey('home list')), matching: find.byType(Scrollable));
    expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
  }, skip: _skip);

  testWidgets('Home has its top bar and the avatar opens the profile drawer; no hamburger anywhere', (tester) async {
    await _shell(tester);
    expect(find.text('HOME BAR'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
    await tester.tap(find.byTooltip('avatar'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE DRAWER'), findsOneWidget);
    Navigator.of(tester.element(find.text('PROFILE DRAWER'))).pop();
    await tester.pumpAndSettle();
    await _go(tester, 'Sales');
    expect(find.text('HOME BAR'), findsNothing, reason: 'every other tab has its own AppBar');
    expect(find.byIcon(Icons.menu), findsNothing);
  }, skip: _skip);

  testWidgets('a pushed route covers the bar', (tester) async {
    await _shell(tester);
    await _go(tester, 'Sales');
    Navigator.of(tester.element(find.text('sales tab'))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a deep screen'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('a deep screen'), findsOneWidget);
    expect(find.byType(PhoneBottomBar).hitTestable(), findsNothing);
  }, skip: _skip);

  testWidgets('the bar is not drawn while the keyboard is open', (tester) async {
    await _shell(tester, keyboard: 300);
    expect(find.byType(PhoneBottomBar), findsNothing);
  }, skip: _skip);

  testWidgets('Back on Sales goes to Home; Back on Home leaves (nothing is held back)', (tester) async {
    await _shell(tester);
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _go(tester, 'Sales');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home tab').hitTestable(), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, contains('SystemNavigator.pop'));
  }, skip: _skip);

  testWidgets('the + is one 48+ target with the Record label, and opens the sheet from every tab', (tester) async {
    await _shell(tester);
    for (final tab in ['Home', 'Sales', 'Products', 'More']) {
      await _go(tester, tab);
      await tester.tap(find.bySemanticsLabel('Record'));
      await tester.pump();
    }
    expect(_records, 4);
    final size = tester.getSize(find.bySemanticsLabel('Record'));
    expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$size');
  }, skip: _skip);

  testWidgets('the selected item is marked selected for screen readers', (tester) async {
    await _shell(tester);
    await _go(tester, 'Products');
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(find.bySemanticsLabel('Products')), matchesSemantics(isSelected: true, hasSelectedState: true, isButton: true, hasTapAction: true, label: 'Products'));
    semantics.dispose();
  }, skip: _skip);

  group('the shell only on phones (AppLayout.isPhone)', () {
    for (final (size, phone) in [
      (const Size(360, 740), true),
      (const Size(390, 844), true),
      (const Size(740, 360), true),
      (const Size(768, 1024), false),
      (const Size(1024, 768), false),
      (const Size(1200, 800), false),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: ${phone ? 'the shell' : 'today\'s layout'}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: PhoneOrWide(phone: (_) => const Text('SHELL'), wide: (_) => const Text('TODAY')),
        ));
        expect(find.text(phone ? 'SHELL' : 'TODAY'), findsOneWidget);
      }, skip: _skip);
    }
  });

  screenSizeMatrix(
    'phone bottom bar',
    screen: () => Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: PhoneBottomBar(current: PhoneTab.home, onSelect: (_) {}, onRecord: () {}),
    ),
    skip: _skip ? {for (final s in matrixSizes) for (final l in MatrixLook.values) matrixCase(s, l): 'stub', matrixTextScaleCase: 'stub'} : const {},
  );
}
