// UX8 Fix 1: on PC/tablet a page lives in the shell's content Navigator
// (AppShell), while showDialog puts its dialog on the root Navigator. An
// action that popped with the page's context (Navigator.pop(context)) closed
// the page's navigator, not the dialog: Cancel dimmed back and the dialog
// stayed. Guarded two ways:
// - Manage Account's four dialogs, in a nested Navigator built like the
//   shell's: Cancel closes the dialog and the page stays;
// - every showDialog / showGeneralDialog call in lib/: an action inside the
//   call pops with the dialog's own builder context (or rootNavigator: true).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/settings/manage_account_screen.dart';

import 'helpers/phone_list_harness.dart';
import 'ph8a_seams_test.dart' show Ph8Auth;

/// The shell's content Navigator: a Pages navigator inside the app's own.
class _InShell extends StatelessWidget {
  const _InShell(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Navigator(
          pages: [MaterialPage<void>(key: const ValueKey('shell-page'), child: child)],
          onDidRemovePage: (_) {},
        ),
      );
}

/// The dialog calls in [source] whose actions pop with some other context.
List<String> wrongPops(String path, String source) {
  final calls = RegExp(r'\b(showDialog|showGeneralDialog)\b\s*(<[^(]*>)?\s*\(');
  final pop = RegExp(r'Navigator\.pop\(\s*(\w+)|Navigator\.of\(\s*(\w+)([^)]*)\)\s*\.(?:pop|maybePop)');
  final out = <String>[];
  for (final m in calls.allMatches(source)) {
    // A declaration (Future<T?> showDialog...) is not a call.
    if (source.substring(m.start < 30 ? 0 : m.start - 30, m.start).contains('Future')) continue;
    var depth = 0, end = m.end - 1;
    for (; end < source.length; end++) {
      if (source[end] == '(') depth++;
      if (source[end] == ')' && --depth == 0) break;
    }
    final body = source.substring(m.end - 1, end);
    // Inner builders (StatefulBuilder) may rename the context: any of them counts.
    final names = RegExp(r'builder\s*:\s*\(\s*(\w+)').allMatches(body).map((b) => b.group(1)).toSet();
    for (final p in pop.allMatches(body)) {
      // A page closed on purpose after the dialog says so on its line.
      final lineEnd = body.indexOf('\n', p.end);
      if (body.substring(p.end, lineEnd < 0 ? body.length : lineEnd).contains('UX8: the page, on purpose')) continue;
      final name = p.group(1) ?? p.group(2)!;
      if (!names.contains(name) && !(p.group(3) ?? '').contains('rootNavigator: true')) {
        out.add('$path:${'\n'.allMatches(source.substring(0, m.start)).length + 1} pops with $name');
      }
    }
  }
  return out;
}

void main() {
  ph5TestWidgets('Manage Account at 1200x800 in the shell: Cancel closes each dialog', (tester) async {
    await pumpPh5(tester, (fs) => _InShell(ManageAccountScreen(firestore: fs, auth: Ph8Auth())),
        size: const Size(1200, 800));
    final tiles = find.descendant(of: find.byType(ManageAccountScreen), matching: find.byType(ListTile));
    // The titles first: a tile may rebuild (a spinner) while its dialog runs.
    final titles = [
      for (final t in tester.widgetList<ListTile>(tiles))
        if (t.onTap != null) (t.title! as Text).data!,
    ];
    var opened = 0;
    for (final i in titles) {
      final tile = find.widgetWithText(ListTile, i).first;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await ph5Settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'tile $i opens a dialog');
      opened++;
      // Cancel (or OK on the "cannot" notice) is the first action.
      final first = find.descendant(of: find.byType(AlertDialog), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first;
      await tester.tap(first);
      await ph5Settle(tester);
      expect(find.byType(AlertDialog), findsNothing, reason: 'tile $i: Cancel closes the dialog');
      expect(find.byType(ManageAccountScreen), findsOneWidget, reason: 'tile $i: the page stays');
    }
    // Sign out all, wipe data, deactivate, delete.
    expect(opened, 4);
  });

  test('every dialog in lib/ pops with its own context', () {
    final wrong = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.dart')) wrong.addAll(wrongPops(f.path, f.readAsStringSync()));
    }
    expect(wrong, isEmpty);
  });

  test('the scan catches the old Manage Account / Clients shape', () {
    const bad = '''
      showDialog<bool>(context: context, builder: (_) => AlertDialog(actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
      ]));''';
    expect(wrongPops('x', bad), hasLength(1));
    expect(wrongPops('x', bad.replaceAll('(_)', '(context)')), isEmpty);
  });
}
