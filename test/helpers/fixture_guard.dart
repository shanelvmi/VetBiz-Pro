// STAB1: a normal test run never writes a fixture. flutter_test_config.dart
// notes every fixture's content when a test file starts and fails the file
// if any changed by its end, unless a record mode is on (an explicit
// --dart-define, see [recordingFixtures]).
import 'dart:io';

/// The files the recorders write (and every test reads).
const fixtureFiles = [
  'test/fixtures/ph5a_wide_fingerprints.json',
  'test/fixtures/ph6_saved_forms.json',
  'test/fixtures/ph7a_saved_forms.json',
  'test/fixtures/ph7b_submitted_report.json',
  'test/fixtures/ph8a_saved_forms.json',
  'test/fixtures/ph8b_saved_facility.json',
  'firestore_rules_tests/fixtures/app_write_shapes.json',
];

/// True when a record mode was asked for: only then may a fixture change.
const recordingFixtures = bool.fromEnvironment('PH5A_RECORD') ||
    bool.fromEnvironment('PH6_RECORD') ||
    bool.fromEnvironment('PH7A_RECORD') ||
    bool.fromEnvironment('PH7B_RECORD') ||
    bool.fromEnvironment('PH8A_RECORD') ||
    bool.fromEnvironment('PH8B_RECORD') ||
    bool.fromEnvironment('WRITE_SHAPES');

/// Each fixture's content now (null when the file is missing).
Map<String, String?> fixtureSnapshot() => {
      for (final path in fixtureFiles) path: File(path).existsSync() ? File(path).readAsStringSync() : null,
    };

/// The fixtures whose content differs between [before] and [after].
List<String> changedFixtures(Map<String, String?> before, Map<String, String?> after) => [
      for (final path in {...before.keys, ...after.keys})
        if (before[path] != after[path]) path,
    ];
