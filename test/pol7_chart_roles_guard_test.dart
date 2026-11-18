// POL7 guard: the nine chartN roles stay defined (other code and the role
// tests read them), but no screen colours a category with them any more:
// no file under lib/ outside lib/theme and lib/ui/polish reads chart1 to
// chart9. Baseline: zero. A chart takes its colours from ChartPalette.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no chart1 to chart9 reads outside lib/theme and lib/ui/polish', () {
    final read = RegExp(r'\.chart[1-9]\b');
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/theme/') || path.startsWith('lib/ui/polish/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (read.hasMatch(code)) found.add('$path:${i + 1}');
      }
    }
    expect(found, isEmpty, reason: 'chartN read outside the theme: use ChartPalette or a state role');
  });
}
