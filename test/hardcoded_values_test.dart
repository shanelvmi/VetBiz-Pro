import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_hardcoded.dart';

/// The ratchet: no file may gain a raw colour, size, duration, limit,
/// breakpoint, currency text or collection name. Use the tokens in
/// lib/theme, lib/config and lib/data instead. See tool/check_hardcoded.dart.
void main() {
  test('no raw value count rises above tool/hardcoded_baseline.json', () {
    final root = Directory.current;
    final baseline = Baseline.load(root);
    expect(baseline, isNotNull, reason: 'tool/hardcoded_baseline.json is missing');

    final current = scan(root, allowlist: baseline!.allowlist);
    final problems = violations(current, baseline.counts);
    expect(problems, isEmpty,
        reason: 'Raw values were added. Use the tokens instead:\n${problems.join('\n')}');
  });

  test('a rise, or hits in a file not in the baseline, is reported; a fall is not', () {
    final base = {'R1': {'lib/a.dart': 3}};
    expect(violations({'R1': {'lib/a.dart': 2}}, base), isEmpty);
    expect(violations({'R1': {'lib/a.dart': 4}}, base), hasLength(1));
    expect(violations({'R1': {'lib/new.dart': 1}}, base), hasLength(1));
    // R10 is off until step 2F.
    expect(violations({'R10': {'lib/a.dart': 9}}, base), isEmpty);
  });

  test('R9 also sees a collection name passed through a variable', () {
    final literal = collectionNameLiteral(Directory.current)!;
    expect(literal.hasMatch("trashCollection: 'trash_clients',"), isTrue);
    expect(literal.hasMatch("if (collection == 'sales') {"), isTrue);
    // Written straight inside .collection(...): R9's own pattern counts it,
    // so this must not count it a second time.
    expect(literal.hasMatch(".collection('sales')"), isFalse);
    expect(literal.hasMatch('collection: Collections.sales,'), isFalse);
    expect(literal.hasMatch("collection: 'not_a_collection',"), isFalse);
    final r9 = guardRules.firstWhere((r) => r.id == 'R9');
    expect(r9.patterns.any((p) => p.hasMatch(".collectionGroup('users')")), isTrue);
  });

  test('the scanner sees what it should', () {
    final r4 = guardRules.firstWhere((r) => r.id == 'R4');
    bool hits(GuardRule rule, String line) =>
        rule.patterns.any((p) => p.allMatches(line).any((m) => rule.accept == null || rule.accept!(m)));

    expect(hits(r4, 'padding: const EdgeInsets.all(16),'), isTrue);
    expect(hits(r4, 'padding: EdgeInsets.fromLTRB(0, 0, 0, 0),'), isFalse);
    expect(hits(r4, 'padding: EdgeInsets.all(AppSpacing.s16),'), isFalse);
    expect(hits(r4, 'EdgeInsets.symmetric(horizontal: 0.5)'), isTrue);

    final r1 = guardRules.firstWhere((r) => r.id == 'R1');
    expect(hits(r1, 'color: Colors.transparent,'), isFalse);
    expect(hits(r1, 'color: Colors.grey[600],'), isTrue);
    expect(hits(r1, 'final c = AppColors.fromTheme(theme);'), isFalse);
    expect(isExcluded('lib/theme/app_colors.dart'), isTrue);
    expect(isExcluded('lib/screens/sales/sales_screen.dart'), isFalse);
  });
}
