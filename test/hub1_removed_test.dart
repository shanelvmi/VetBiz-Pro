// HUB1 (2): the old phone navigation is gone, not just hidden: the bottom
// bar and its trough, the central "+" and its sheet, the More page, the tab
// machinery and the remembered tab, and the roles and measures only they
// used. A source test: it fails if any of them comes back in lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _skip = false;

const _deletedFiles = [
  'lib/screens/dashboard/phone_shell.dart',
  'lib/screens/dashboard/phone_bar_shape.dart',
  'lib/screens/dashboard/more_screen.dart',
  'lib/screens/dashboard/more_parts.dart',
  'lib/screens/dashboard/phone_home_rows.dart',
  'lib/screens/dashboard/record_sheet.dart',
];

/// Names that only the old navigation had.
const _gone = [
  'PhoneShell',
  'PhoneBottomBar',
  'PhoneBarPainter',
  'PhoneTab',
  'PhoneShellInsets',
  'PhoneShellMetrics',
  'bodyWithBanner',
  'showRecordSheet',
  'recordActionsFor',
  'recordMoreActionsFor',
  'MoreScreen',
  'MoreItem',
  'MoreMetrics',
  'openMoreItem',
  'HomeActionGrid',
  'HomeTile',
  'asTab',
  'rememberTab',
  'takeTabToRestore',
  'navBarFill',
  'navBarInactive',
  'tabFade',
];

void main() {
  test('the old navigation\'s files are deleted', () {
    for (final f in _deletedFiles) {
      expect(File(f).existsSync(), isFalse, reason: f);
    }
  }, skip: _skip);

  test('none of its names is left in lib/', () {
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final name in _gone) {
        if (RegExp('\\b$name\\b').hasMatch(source)) found.add('${file.path}: $name');
      }
    }
    expect(found, isEmpty);
  }, skip: _skip);
}
