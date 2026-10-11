import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_arb.dart';

/// The language files agree (docs/PHASE2_LOCALISATION_SPEC.md section 8).
/// The Kiswahili draft count is printed, not failed on, so progress shows.
void main() {
  final root = Directory.current;
  final en = Arb.read(Arb.fileFor(root, 'en'));
  final sw = Arb.read(Arb.fileFor(root, 'sw'));

  test('every key exists in both files', () {
    expect(sw.values.keys.toSet().difference(en.values.keys.toSet()), isEmpty, reason: 'only in app_sw.arb');
    expect(en.values.keys.toSet().difference(sw.values.keys.toSet()), isEmpty, reason: 'missing from app_sw.arb');
  });

  test('no empty texts', () {
    for (final arb in [en, sw]) {
      for (final e in arb.values.entries) {
        expect(e.value.trim(), isNotEmpty, reason: '${arb.locale}: ${e.key}');
      }
    }
  });

  test('every English key says where it appears, and declares its placeholders', () {
    for (final k in en.values.keys) {
      expect((en.meta[k]?['description'] as String?)?.trim(), isNotEmpty, reason: '@$k needs a description');
      final used = RegExp(r'\{\s*(\w+)\s*[,}]').allMatches(en.values[k]!).map((m) => m.group(1)!);
      final declared = declaredPlaceholders(en, k);
      // Only words that are not inside a plural branch: those are text.
      for (final name in used.where((n) => !RegExp(r'^[A-Z]').hasMatch(n) && !RegExp(r'^\d').hasMatch(n))) {
        expect(declared, contains(name), reason: '$k uses {$name}; declare it, with its type, in @$k');
      }
      for (final p in declared) {
        expect((en.meta[k]!['placeholders'] as Map)[p]?['type'], isNotNull, reason: '$k: {$p} needs a type');
      }
    }
  });

  test('placeholders and plural arguments match between English and Kiswahili', () {
    for (final k in en.values.keys.where(sw.values.containsKey)) {
      expect(argumentProblem(en, k, sw.values[k]!), isNull, reason: k);
    }
  });

  test('every Kiswahili entry is marked draft or reviewed; progress is printed', () {
    for (final k in sw.values.keys) {
      expect(sw.meta[k]?['x-review'], anyOf('draft', 'reviewed'), reason: '@$k needs "x-review"');
    }
    final drafts = sw.values.keys.where((k) => sw.reviewOf(k) == 'draft').length;
    // ignore: avoid_print
    print('Kiswahili: $drafts of ${sw.values.length} entries still draft.');
  });

  test('the files are in the tools\' format, so a tool rewrite shows only real changes', () {
    expect(en.encode(), Arb.fileFor(root, 'en').readAsStringSync().replaceAll('\r\n', '\n'));
    expect(sw.encode(order: en.values.keys), Arb.fileFor(root, 'sw').readAsStringSync().replaceAll('\r\n', '\n'));
  });
}
