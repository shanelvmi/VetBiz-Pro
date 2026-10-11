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
    // R10 is on since step 2F-1.
    expect(violations({'R10': {'lib/a.dart': 9}}, base), hasLength(1));
  });

  test('R10 counts texts a person reads, and only those', () {
    final r10 = guardRules.firstWhere((r) => r.id == 'R10');
    expect(r10.count("const Text('Save'),"), 1);
    expect(r10.count('SelectableText("Don\'t worry"),'), 1);
    expect(r10.count("AppFeedback.success('Product saved');"), 1);
    expect(r10.count("decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Juma'),"), 2);
    expect(r10.count("IconButton(tooltip: 'Close', onPressed: close),"), 1);
    expect(r10.count("title: const Text('Sold \$n items'),"), 1, reason: 'not counted twice');
    expect(r10.count("Text('Sold \${sale.count}'),"), 1);
    // Interpolation and punctuation alone are not words.
    expect(r10.count("Text('\${client.name}'),"), 0);
    expect(r10.count("Text(': \$count'),"), 0);
    expect(r10.count('Text(context.l10n.common_save),'), 0);
    expect(r10.count("debugPrint('[UI] saved');"), 0);
    // The literal alone on the line after its opener.
    expect(r10.opens('child: Text('), isTrue);
    expect(r10.opens('message:'), isTrue);
    expect(r10.count("  'Business hours saved',", afterOpener: true), 1);
    expect(r10.count("  'Business hours saved',"), 0);
  });

  test('a folder allowlist entry covers every file in it', () {
    final folder = AllowEntry('R10', 'lib/screens/legal/', '', 'reason');
    expect(folder.covers('lib/screens/legal/terms_screen.dart'), isTrue);
    expect(folder.covers('lib/screens/legally.dart'), isFalse);
    expect(AllowEntry('R5', 'lib/a.dart', 'x', 'r').covers('lib/a.dart.bak'), isFalse);
  });

  test('every R10 allowlist entry is a whole folder or file, with a reason', () {
    final r10 = Baseline.load(Directory.current)!.allowlist.where((a) => a.rule == 'R10').toList();
    expect(r10.map((a) => a.file), containsAll(['lib/screens/platform_admin/', 'lib/screens/legal/']));
    for (final a in r10) {
      expect(a.lineContains, isEmpty, reason: a.file);
      expect(a.reason, contains('2.8'), reason: a.file);
    }
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

  test('every switched-on rule has a baseline', () {
    final baseline = Baseline.load(Directory.current)!;
    for (final r in guardRules.where((r) => r.enabled)) {
      expect(baseline.counts.containsKey(r.id), isTrue,
          reason: '${r.id} has no baseline: run dart run tool/check_hardcoded.dart --update');
    }
  });

  test('R11 sees raw feedback calls, but not inside lib/ui/feedback', () {
    final r11 = guardRules.firstWhere((r) => r.id == 'R11');
    bool hits(String line) => r11.patterns.any((p) => p.hasMatch(line));
    expect(hits('ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x)));'), isTrue);
    expect(hits('messenger.showSnackBar(bar);'), isTrue);
    expect(hits("AppFeedback.success('Product saved');"), isFalse);
    expect(r11.alsoExcludes, contains('lib/ui/feedback/'));
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
    // The language files and the code generated from them hold the texts.
    expect(isExcluded('lib/l10n/app_localizations_sw.dart'), isTrue);
    expect(isExcluded('lib/screens/sales/sales_screen.dart'), isFalse);
  });
}
