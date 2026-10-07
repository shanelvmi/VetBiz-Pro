import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every collection name in lib/data/collections.dart must be one the
/// backend knows: matched by a path in firestore.rules, or named by the
/// Cloud Functions. A name in neither is either a typo (the app would read or
/// write a collection the rules refuse) or a collection the rules don't
/// cover yet - both worth stopping for.
///
/// Read as text, like functions/test/endpoints.test.js reads the Dart source.
void main() {
  /// Collections the backend legitimately doesn't mention, each with why.
  /// Keep this short and explained; the test also fails if an entry here
  /// stops being needed, so the list can't go stale.
  const notInBackend = <String, String>{
    // (none at the moment)
  };

  final source = File('lib/data/collections.dart').readAsStringSync();
  final names = RegExp(r"static const String \w+ = '([^']+)';")
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toList();

  final rules = File('firestore.rules').readAsStringSync();
  // index.js and membership.js; not node_modules, not the tests.
  final functions = Directory('functions')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.js'))
      .map((f) => f.readAsStringSync())
      .join('\n');

  bool inRules(String name) => RegExp('/${RegExp.escape(name)}/').hasMatch(rules);
  bool inFunctions(String name) =>
      RegExp('["\'`/]${RegExp.escape(name)}["\'`/]').hasMatch(functions);

  test('Collections was read', () {
    expect(names.length, greaterThanOrEqualTo(35));
    expect(names.toSet().length, names.length, reason: 'a collection name is listed twice');
  });

  test('every Collections value is in firestore.rules or functions/', () {
    final missing = names
        .where((n) => !inRules(n) && !inFunctions(n) && !notInBackend.containsKey(n))
        .toList();
    expect(missing, isEmpty,
        reason: 'Not in firestore.rules or functions/: $missing. Fix the name, add the '
            'collection to the rules, or add it to notInBackend with a reason.');
  });

  test('notInBackend only lists names that need it', () {
    final stale = notInBackend.keys.where((n) => !names.contains(n) || inRules(n) || inFunctions(n)).toList();
    expect(stale, isEmpty, reason: 'Remove these from notInBackend: $stale');
  });
}
