// RV1 (docs/design/screen_reveal.md section 5): the phone shell's tabs
// cross-fade; each keeps its state, only the selected one takes taps and is
// seen by screen readers, a tab is still built on its first visit, the bar
// never animates, and reduced motion swaps at once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

const _skip = true; // RV1: until the implementation

final _built = <String, int>{};
final _taps = <String, int>{};

class _Tab extends StatefulWidget {
  final String name;
  const _Tab(this.name);
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    _built[widget.name] = (_built[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _taps[widget.name] = (_taps[widget.name] ?? 0) + 1;
            setState(() => count++);
          },
          child: SizedBox.expand(child: Text('${widget.name} count $count')),
        ),
      );
}

Future<void> _shell(WidgetTester tester, {bool still = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _built.clear();
  _taps.clear();
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: still),
      child: child!,
    ),
    home: PhoneShell(
      home: (_) => const _Tab('home'),
      sales: (_) => const _Tab('sales'),
      products: (_) => const _Tab('products'),
      more: (_) => const _Tab('more'),
      onRecord: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _bar(String label) => find.descendant(of: find.byType(PhoneBottomBar), matching: find.text(label));

double _opacityOf(WidgetTester tester, String name) => tester
    .widget<FadeTransition>(
        find.ancestor(of: find.textContaining('$name count', skipOffstage: false), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  testWidgets('the new tab fades in over the old one in 180 ms; the bar does not animate', (tester) async {
    await _shell(tester);
    final bar = tester.getRect(find.byType(PhoneBottomBar));
    await tester.tap(_bar('Sales'));
    await tester.pump();
    await tester.pump(AppMotion.tabFade ~/ 2);
    expect(AppMotion.tabFade, const Duration(milliseconds: 180));
    final incoming = _opacityOf(tester, 'sales'), outgoing = _opacityOf(tester, 'home');
    expect(incoming, inExclusiveRange(0, 1));
    expect(outgoing, inExclusiveRange(0, 1));
    expect(find.text('home count 0'), findsOneWidget, reason: 'the old tab is still drawn while it fades');
    final shellFades = find.descendant(of: find.byType(PhoneShell), matching: find.byType(FadeTransition));
    expect(find.ancestor(of: find.byType(PhoneBottomBar), matching: shellFades), findsNothing);
    expect(tester.getRect(find.byType(PhoneBottomBar)), bar);
    await tester.pumpAndSettle();
    expect(find.text('home count 0'), findsNothing, reason: 'offstage once the fade is over');
    expect(_opacityOf(tester, 'sales'), 1);
  }, skip: _skip);

  testWidgets('each tab keeps its state, and a tab is built on its first visit only', (tester) async {
    await _shell(tester);
    expect(_built, {'home': 1});
    await tester.tap(find.text('home count 0'));
    await tester.pump();
    await tester.tap(_bar('Sales'));
    await tester.pumpAndSettle();
    expect(_built, {'home': 1, 'sales': 1});
    await tester.tap(_bar('Home'));
    await tester.pumpAndSettle();
    expect(find.text('home count 1'), findsOneWidget);
    await tester.tap(_bar('Products'));
    await tester.pumpAndSettle();
    await tester.tap(_bar('Sales'));
    await tester.pumpAndSettle();
    expect(_built, {'home': 1, 'sales': 1, 'products': 1});
  }, skip: _skip);

  testWidgets('during the fade only the selected tab takes taps and is seen by screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _shell(tester);
    await tester.tap(_bar('Sales'));
    await tester.pump();
    await tester.pump(AppMotion.tabFade ~/ 4);
    expect(find.semantics.byLabel('home count 0'), findsNothing);
    expect(find.semantics.byLabel('sales count 0'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first) - const Offset(0, 200));
    await tester.pump();
    expect(_taps['home'], isNull);
    expect(_taps['sales'], 1);
    await tester.pumpAndSettle();
    semantics.dispose();
  }, skip: _skip);

  testWidgets('reduced motion: the tab swaps at once', (tester) async {
    await _shell(tester, still: true);
    await tester.tap(_bar('Sales'));
    await tester.pump();
    expect(find.text('home count 0'), findsNothing);
    expect(_opacityOf(tester, 'sales'), 1);
  }, skip: _skip);
}
