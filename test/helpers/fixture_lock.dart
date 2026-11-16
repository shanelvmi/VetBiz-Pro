// STAB1: recording a fixture (test/fixtures/*.json, only with an explicit
// --dart-define=..._RECORD=true) reads the file, adds its entry and writes it
// back. Two test files recording in one `flutter test` run do that at the
// same time in two processes, and one entry was lost (d581b8b). Every
// recorder does its read-modify-write inside [withFixtureLock]: an exclusive
// lock on a file under build/, held for the read and the write. If another
// recorder holds it, a clear warning is printed and this one waits for it.
import 'dart:io';

/// The lock file for [fixture] (under build/, never committed).
File fixtureLockFile(String fixture) =>
    File('build/fixture_locks/${fixture.split(RegExp(r'[\\/]')).last}.lock');

/// Whether another open handle holds [fixture]'s lock now (a recorder in
/// another test file).
bool anotherRecorderHolds(String fixture) {
  final file = fixtureLockFile(fixture)..createSync(recursive: true);
  final probe = file.openSync(mode: FileMode.append);
  try {
    probe.lockSync(FileLock.exclusive);
    probe.unlockSync();
    return false;
  } on FileSystemException {
    return true;
  } finally {
    probe.closeSync();
  }
}

/// Runs [body] (the read, the change and the write of [fixture]) while
/// holding [fixture]'s lock.
T withFixtureLock<T>(String fixture, T Function() body) {
  final file = fixtureLockFile(fixture)..createSync(recursive: true);
  final lock = file.openSync(mode: FileMode.append);
  try {
    try {
      lock.lockSync(FileLock.exclusive);
    } on FileSystemException {
      stderr.writeln('WARNING: another test file is recording $fixture at the same time. '
          'Waiting for it; record one test file at a time (tool/run_tests.ps1 -Record <file>).');
      lock.lockSync(FileLock.blockingExclusive);
    }
    return body();
  } finally {
    try {
      lock.unlockSync();
    } on FileSystemException {
      // Never locked (the body threw before): nothing to release.
    }
    lock.closeSync();
  }
}
