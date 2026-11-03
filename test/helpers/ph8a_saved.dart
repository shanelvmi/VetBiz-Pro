// PH8a: what a form saved, compared with what the same form saved before
// PH8a (test/fixtures/ph8a_saved_forms.json, recorded once from the code
// before PH8a with --dart-define=PH8A_RECORD=true). Times become <time>.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = 'test/fixtures/ph8a_saved_forms.json';

Object? _normalize(Object? node) {
  if (node is Map) {
    return Map.fromEntries([for (final e in node.entries) MapEntry('${e.key}', _normalize(e.value))]
      ..sort((a, b) => a.key.compareTo(b.key)));
  }
  if (node is List) return [for (final v in node) _normalize(v)];
  if (node is Timestamp || node is DateTime || node is FieldValue) return '<time>';
  return node;
}

/// Compares [saved] (the documents a form wrote, in a stable order) with the
/// fixture's [name].
void expectSameSaved(String name, List<Map<String, dynamic>> saved) {
  final now = jsonDecode(jsonEncode(_normalize(saved)));
  final file = File(_fixture);
  final recorded = file.existsSync() ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>) : <String, dynamic>{};
  if (const bool.fromEnvironment('PH8A_RECORD')) {
    recorded[name] = now;
    final sorted = Map.fromEntries(recorded.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    return;
  }
  expect(now, recorded[name], reason: '$name: what the form saves changed');
}
