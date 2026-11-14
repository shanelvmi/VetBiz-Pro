// HUB3 (7): no test reads the real date. Since 2026-11-10 tests that built
// their dates from the real clock (or from fixed dates the code compared with
// its own real "today") failed by the calendar alone. Tests take their dates
// from test/helpers/test_clock.dart (a fixed moment, which AppClock can be
// made to read); that helper is the only file under test/ allowed to read
// the real clock.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only files allowed to read the real clock, with why.
const _allowed = {
  // The fixed test moment and the one wallClock() for non-date uses.
  'test/helpers/test_clock.dart',
};

// Built from pieces so this file does not match itself.
final _realClock = RegExp(['DateTime', r'\.now\(', '|', 'DateTime', r'\.timestamp\('].join());

void main() {
  test('no real-clock read (DateTime.now) under test/ outside the clock helper', () {
    final offenders = <String>[];
    for (final file in Directory('test').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || _allowed.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_realClock.hasMatch(lines[i])) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'read dates from test/helpers/test_clock.dart (testNow, fixTestClock, wallClock)');
  });

  test('the allowed helper exists and is the only exception', () {
    for (final path in _allowed) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(_allowed, hasLength(1));
  });
}
