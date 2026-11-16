// STAB1: the guard that a normal run never writes a fixture
// (test/helpers/fixture_guard.dart, wired in flutter_test_config.dart).
// Its comparison, the list of fixtures it watches, and that every writer of a
// fixture under test/ is behind an explicit record define.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixture_guard.dart';

void main() {
  test('a changed, added or removed fixture is reported; an unchanged one is not', () {
    expect(changedFixtures({'a': '1', 'b': '2'}, {'a': '1', 'b': '2'}), isEmpty);
    expect(changedFixtures({'a': '1', 'b': '2'}, {'a': '1', 'b': '3'}), ['b']);
    expect(changedFixtures({'a': null}, {'a': '1'}), ['a']);
    expect(changedFixtures({'a': '1'}, {'a': null}), ['a']);
  });

  test('a normal run is not a record run, and every watched fixture exists', () {
    expect(recordingFixtures, isFalse, reason: 'no ..._RECORD define in a normal run');
    for (final path in fixtureFiles) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every fixture the tests name is watched', () {
    final named = <String>{};
    for (final f in Directory('test').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in RegExp(r"const _fixture = '([^']+\.json)'").allMatches(f.readAsStringSync())) {
        named.add(m.group(1)!);
      }
    }
    named.remove('test/fixtures/stab1_lock_probe.json'); // the lock test's name, never written
    expect(named.difference(fixtureFiles.toSet()), isEmpty);
  });

  test('every write to a fixture sits in an explicit record branch', () {
    final writer = RegExp(r'(file|File\(_fixture\))\.writeAs(String|Bytes)Sync');
    final record = RegExp(r"bool\.fromEnvironment\('(PH5A|PH6|PH7A|PH7B|PH8A|PH8B)_RECORD'\)|if \(_write\)");
    for (final f in Directory('test').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!writer.hasMatch(lines[i])) continue;
        final before = lines.sublist((i - 12).clamp(0, i), i).join('\n');
        expect(record.hasMatch(before), isTrue, reason: '${f.path}:${i + 1} writes a fixture outside a record branch');
      }
    }
  });
}
