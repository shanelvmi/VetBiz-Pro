// The hardcoded-values guard (Phase 2 spec, section 9).
//
// Counts raw values (colours, font sizes, radii, spacing, durations, query
// limits, breakpoints, currency text, collection names) per rule per file in
// lib/, outside the folders that are meant to hold them. The counts in
// tool/hardcoded_baseline.json are a ratchet: they may go down, never up.
//
//   dart run tool/check_hardcoded.dart            report counts vs baseline
//   dart run tool/check_hardcoded.dart --update   lower the baseline to today's
//                                                 counts (refuses to raise any)
//
// test/hardcoded_values_test.dart runs the same check on every `flutter test`.
import 'dart:convert';
import 'dart:io';

class GuardRule {
  final String id;
  final String description;
  final List<RegExp> patterns;

  /// Optional second check on each match (for example "has a non-zero number").
  final bool Function(RegExpMatch match)? accept;

  /// Off until its step switches it on (R10 is switched on in step 2F).
  final bool enabled;

  /// Folders this rule alone doesn't look in (on top of the shared
  /// exclusions in [isExcluded]).
  final List<String> alsoExcludes;

  /// When not empty, the only folders this rule looks in.
  final List<String> onlyIn;

  /// For a value that can sit on the line after its opener: a line ending
  /// in [opensAtLineEnd] makes the next line be tested with [continues]
  /// (one count at most), as well as with [patterns].
  final RegExp? opensAtLineEnd;
  final RegExp? continues;

  const GuardRule(this.id, this.description, this.patterns,
      {this.accept,
      this.enabled = true,
      this.alsoExcludes = const [],
      this.onlyIn = const [],
      this.opensAtLineEnd,
      this.continues});

  bool _hits(RegExp p, String line) => p.allMatches(line).any((m) => accept == null || accept!(m));

  /// Matches on [line]; [afterOpener] says the previous line ended in an opener.
  int count(String line, {bool afterOpener = false}) {
    var n = 0;
    for (final p in patterns) {
      n += p.allMatches(line).where((m) => accept == null || accept!(m)).length;
    }
    if (afterOpener && continues != null && _hits(continues!, line)) n++;
    return n;
  }

  bool opens(String line) => opensAtLineEnd?.hasMatch(line) ?? false;
}

// R10: the parameters that carry text a person reads. A string literal
// follows (on the same line, or alone on the next one).
const _r10Openers = r'(?:\b(?:Selectable)?Text\(|\bTextSpan\(\s*text:|\bAppFeedback\.(?:success|info|warning|error|undo)\(|'
    r'\b(?:labelText|hintText|helperText|errorText|prefixText|suffixText|title|subtitle|tooltip|'
    r'semanticLabel|semanticsLabel|label|message|content|text|confirmText|cancelText):)';
const _r10Literal = r'''\s*(?:const\s+)?['"](?<s>(?:\\.|[^'"\\])*)''';

/// R10 counts a literal only if it has a letter outside interpolations:
/// '${a.name}' or ': $count' are not words to translate.
bool _hasWords(RegExpMatch m) {
  final s = m.namedGroup('s') ?? '';
  return RegExp('[A-Za-z]').hasMatch(s.replaceAll(RegExp(r'\$\{[^}]*\}?|\$\w+'), ''));
}

final _nonZeroNumber = RegExp(r'(?<![\w.])(0*[1-9]\d*(\.\d+)?|0?\.\d*[1-9]\d*)(?![\w.])');

final List<GuardRule> guardRules = [
  // \b so that our own AppColors.* (the tokens) isn't mistaken for Flutter's Colors.*.
  GuardRule('R1', 'raw colour', [RegExp(r'Color\(0x'), RegExp(r'\bColors\.(?!transparent\b)')]),
  GuardRule('R2', 'raw font size', [RegExp(r'fontSize:\s*\d')]),
  GuardRule('R3', 'raw radius', [RegExp(r'Radius\.circular\(\s*\d')]),
  GuardRule(
    'R4',
    'raw spacing',
    [
      RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\(([^)]*)\)'),
      RegExp(r'SizedBox\((height|width):\s*\d'),
    ],
    // An EdgeInsets made only of zeros (or of named values) is not raw spacing.
    accept: (m) => !m.group(0)!.startsWith('EdgeInsets') || _nonZeroNumber.hasMatch(m.group(2) ?? ''),
  ),
  GuardRule('R5', 'raw duration', [RegExp(r'Duration\(')]),
  GuardRule('R6', 'raw query limit', [RegExp(r'\.limit\(\s*\d')]),
  GuardRule('R7', 'raw breakpoint', [RegExp(r'(width|maxWidth)\s*(>=|<=|>|<)\s*\d{3}')]),
  // Anywhere on the line, not only at the start of a string: most currency
  // text sits mid-string ('Total: Tsh ${...}'), including the saved activity
  // descriptions, and the spec's start-of-string sketch missed about 50 of them.
  GuardRule('R8', 'raw currency text', [RegExp(r'\bT(sh|Sh|ZS)\b')]),
  // Also counts, in scan(), a string literal equal to a Collections value on a
  // line that mentions "ollection" (collection:, trashCollection, ...): a name
  // passed through a variable to .collection(x) is just as raw.
  GuardRule('R9', 'raw collection name', [RegExp(r"\.collection(Group)?\('")]),
  // docs/PHASE2_LOCALISATION_SPEC.md section 7: texts come from the ARB
  // files (context.l10n / L10n.current). Out-of-scope files are allowlisted
  // with their reason in the baseline.
  GuardRule(
    'R10',
    'raw user-facing string',
    [RegExp(_r10Openers + _r10Literal)],
    accept: _hasWords,
    opensAtLineEnd: RegExp('$_r10Openers\\s*(?:const\\s*)?\$'),
    continues: RegExp('^$_r10Literal'),
  ),
  // docs/PHASE2_FEEDBACK_SPEC.md section 9: messages go through AppFeedback;
  // only lib/ui/feedback/ may talk to the SnackBar machinery. Falls to 0 by
  // the end of step 2D.
  GuardRule(
    'R11',
    'raw feedback call',
    [RegExp(r'\bshowSnackBar\('), RegExp(r'\bSnackBar\('), RegExp(r'ScaffoldMessenger\.of')],
    alsoExcludes: ['lib/ui/feedback/'],
  ),
];

/// Folders allowed to hold raw values, and generated files.
bool isExcluded(String path) {
  const allowedDirs = ['lib/theme/', 'lib/config/', 'lib/data/', 'lib/l10n/'];
  if (allowedDirs.any(path.startsWith)) return true;
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return true;
  if (path == 'lib/firebase_options.dart') return true; // generated by flutterfire
  return false;
}

/// One allowlisted false positive: a match on a line of [file] containing
/// [lineContains] is not counted for [rule].
class AllowEntry {
  final String rule;
  final String file;
  final String lineContains;
  final String reason;

  AllowEntry(this.rule, this.file, this.lineContains, this.reason);

  /// A [file] ending in '/' is a whole folder; with an empty [lineContains]
  /// every line of it is allowed (out-of-scope folders, with their reason).
  bool covers(String path) => file.endsWith('/') ? path.startsWith(file) : file == path;

  factory AllowEntry.fromJson(Map<String, dynamic> j) => AllowEntry(
      j['rule'] as String, j['file'] as String, j['lineContains'] as String, j['reason'] as String);
}

/// Counts per rule id, per file path (relative, forward slashes). Files with
/// no hits are left out.
Map<String, Map<String, int>> scan(Directory root, {List<AllowEntry> allowlist = const []}) {
  final counts = <String, Map<String, int>>{for (final r in guardRules) r.id: {}};
  final lib = Directory('${root.path}/lib');
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final namedCollection = collectionNameLiteral(root);

  for (final file in files) {
    final rel = file.path
        .substring(root.path.length)
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '');
    if (isExcluded(rel)) continue;

    // Rules whose opener ended the previous code line.
    var opened = <String>{};
    for (final line in file.readAsLinesSync()) {
      // Whole-line comments (including doc comments) are explanations, not code.
      if (line.trimLeft().startsWith('//')) continue;
      final openedBefore = opened;
      opened = {for (final r in guardRules) if (r.opens(line)) r.id};
      for (final rule in guardRules) {
        if (rule.alsoExcludes.any(rel.startsWith)) continue;
        final allowed = allowlist.any((a) => a.rule == rule.id && a.covers(rel) && line.contains(a.lineContains));
        if (allowed) continue;
        var n = rule.count(line, afterOpener: openedBefore.contains(rule.id));
        if (rule.id == 'R9' && namedCollection != null && line.contains('ollection')) {
          n += namedCollection.allMatches(line).length;
        }
        if (n > 0) counts[rule.id]![rel] = (counts[rule.id]![rel] ?? 0) + n;
      }
    }
  }
  return counts;
}

/// A quoted string equal to one of the Collections values (read from
/// lib/data/collections.dart), not counting one written straight inside
/// .collection(...) / .collectionGroup(...), which R9's pattern already counts.
RegExp? collectionNameLiteral(Directory root) {
  final file = File('${root.path}/lib/data/collections.dart');
  if (!file.existsSync()) return null;
  final names = RegExp(r"static const String \w+ = '([^']+)';")
      .allMatches(file.readAsStringSync())
      .map((m) => RegExp.escape(m.group(1)!))
      .toList();
  if (names.isEmpty) return null;
  return RegExp('(?<!collection\\()(?<!collectionGroup\\()[\'"](${names.join('|')})[\'"]');
}

class Baseline {
  final Map<String, Map<String, int>> counts;
  final List<AllowEntry> allowlist;
  final Map<String, dynamic> raw;

  Baseline(this.counts, this.allowlist, this.raw);

  static File fileIn(Directory root) => File('${root.path}/tool/hardcoded_baseline.json');

  static Baseline? load(Directory root) {
    final f = fileIn(root);
    if (!f.existsSync()) return null;
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final counts = <String, Map<String, int>>{};
    (raw['counts'] as Map<String, dynamic>? ?? {}).forEach((rule, files) {
      counts[rule] = (files as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    });
    final allow = (raw['allowlist'] as List<dynamic>? ?? [])
        .map((e) => AllowEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return Baseline(counts, allow, raw);
  }
}

/// Every place a count is above its baseline, as "R1 lib/x.dart: 5 > 3".
/// A file missing from the baseline has a baseline of 0.
List<String> violations(Map<String, Map<String, int>> current, Map<String, Map<String, int>> baseline) {
  final out = <String>[];
  for (final rule in guardRules.where((r) => r.enabled)) {
    final cur = current[rule.id] ?? {};
    final base = baseline[rule.id] ?? {};
    for (final e in cur.entries) {
      final allowed = base[e.key] ?? 0;
      if (e.value > allowed) {
        out.add('${rule.id} (${rule.description}) ${e.key}: ${e.value} > baseline $allowed');
      }
    }
  }
  out.sort();
  return out;
}

Map<String, int> totals(Map<String, Map<String, int>> counts) =>
    {for (final e in counts.entries) e.key: e.value.values.fold(0, (a, b) => a + b)};

String _encode(Map<String, Map<String, int>> counts, List<dynamic> allowlistRaw) {
  final sorted = <String, dynamic>{
    '_comment': 'Allowed raw-value counts per rule per file (Phase 2 spec, section 9). '
        'Counts may only go down: regenerate with `dart run tool/check_hardcoded.dart --update`. '
        'allowlist entries skip a known false positive: {rule, file, lineContains, reason}; '
        'a file ending in / is a folder, and an empty lineContains allows every line.',
    'allowlist': allowlistRaw,
    'counts': {
      for (final rule in guardRules)
        rule.id: {
          for (final f in (counts[rule.id]?.keys.toList() ?? <String>[])..sort()) f: counts[rule.id]![f],
        },
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
}

void main(List<String> args) {
  final root = Directory.current;
  final update = args.contains('--update');
  final baseline = Baseline.load(root);
  final current = scan(root, allowlist: baseline?.allowlist ?? const []);

  if (baseline == null) {
    if (!update) {
      stderr.writeln('No baseline yet. Run with --update to create it from today\'s counts.');
      exit(1);
    }
    Baseline.fileIn(root).writeAsStringSync(_encode(current, []));
    stdout.writeln('Baseline created: ${totals(current)}');
    return;
  }

  // A rule that has no baseline yet (just added) is seeded from today's
  // counts by --update. Every other rule can only go down. Without --update
  // an unseeded rule fails like any other rise, so it can't be forgotten.
  final unseeded = {
    for (final r in guardRules)
      if (r.enabled && !baseline.counts.containsKey(r.id)) r.id,
  };
  final problems = violations(current, baseline.counts)
      .where((p) => !(update && unseeded.any((id) => p.startsWith('$id '))))
      .toList();
  final before = totals(baseline.counts);
  final now = totals(current);
  for (final rule in guardRules) {
    final state = rule.enabled ? '' : ' (off)';
    stdout.writeln('${rule.id}$state ${rule.description}: ${before[rule.id] ?? 0} -> ${now[rule.id] ?? 0}');
  }

  if (problems.isNotEmpty) {
    stderr.writeln('\nAbove baseline (the baseline is never raised; use the tokens instead):');
    for (final p in problems) {
      stderr.writeln('  $p');
    }
    exit(1);
  }

  if (update) {
    // Only ever lowers: every current count is <= its baseline here. Rules
    // that are off keep their old numbers until they are switched on.
    final next = <String, Map<String, int>>{};
    for (final rule in guardRules) {
      next[rule.id] = rule.enabled ? current[rule.id]! : (baseline.counts[rule.id] ?? current[rule.id]!);
    }
    Baseline.fileIn(root).writeAsStringSync(_encode(next, baseline.raw['allowlist'] as List<dynamic>? ?? []));
    for (final id in unseeded) {
      stdout.writeln('\n$id had no baseline: seeded with today\'s counts (${totals(current)[id]}).');
    }
    stdout.writeln('\nBaseline lowered to today\'s counts.');
  }
}
