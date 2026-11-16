// STAB1: the fixture recorders' lock (test/helpers/fixture_lock.dart). A
// recorder's read-modify-write runs inside it; another handle holding it is
// seen (the recorder then warns and waits), and it is released afterwards.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixture_lock.dart';

const _fixture = 'test/fixtures/stab1_lock_probe.json';

void main() {
  test('the body runs under the lock, and the lock is released afterwards', () {
    var ran = false;
    final result = withFixtureLock(_fixture, () {
      ran = true;
      return 42;
    });
    expect(ran, isTrue);
    expect(result, 42);
    expect(anotherRecorderHolds(_fixture), isFalse);
  });

  test('a lock held by another handle (another recorder) is seen', () {
    final other = fixtureLockFile(_fixture).openSync(mode: FileMode.append);
    addTearDown(other.closeSync);
    other.lockSync(FileLock.exclusive);
    expect(anotherRecorderHolds(_fixture), isTrue);
    other.unlockSync();
    expect(anotherRecorderHolds(_fixture), isFalse);
  });

  test('the lock file lives under build/, never next to the fixtures', () {
    expect(fixtureLockFile(_fixture).path, startsWith('build/fixture_locks/'));
    expect(File(_fixture).existsSync(), isFalse, reason: 'the probe never writes a fixture');
  });
}
