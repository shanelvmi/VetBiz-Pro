// Shared by the Kiswahili review tools (export_l10n_review.dart,
// import_l10n_review.dart) and test/l10n_test.dart.
// docs/PHASE2_LOCALISATION_SPEC.md section 8.
import 'dart:convert';
import 'dart:io';

/// One ARB file: its texts and their "@key" entries, in file order.
class Arb {
  final String locale;
  final Map<String, String> values;
  final Map<String, Map<String, dynamic>> meta;

  Arb(this.locale, this.values, this.meta);

  static File fileFor(Directory root, String locale) => File('${root.path}/lib/l10n/app_$locale.arb');

  static Arb read(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final values = <String, String>{};
    final meta = <String, Map<String, dynamic>>{};
    json.forEach((k, v) {
      if (k.startsWith('@@')) return;
      if (k.startsWith('@')) {
        meta[k.substring(1)] = Map<String, dynamic>.from(v as Map);
      } else {
        values[k] = v as String;
      }
    });
    return Arb(json['@@locale'] as String, values, meta);
  }

  /// Two lines per key ("key", then a one-line "@key"), in [order]. Kept
  /// identical to the files on disk, so a tool rewrite shows only real changes.
  String encode({Iterable<String>? order}) {
    final lines = ['  "@@locale": ${jsonEncode(locale)}'];
    for (final k in order ?? values.keys) {
      if (!values.containsKey(k)) continue;
      lines.add('  ${jsonEncode(k)}: ${jsonEncode(values[k])}');
      final m = meta[k];
      if (m != null && m.isNotEmpty) lines.add('  ${jsonEncode('@$k')}: ${jsonEncode(m)}');
    }
    return '{\n${lines.join(',\n')}\n}\n';
  }

  /// "draft" until the owner has approved it.
  String reviewOf(String key) => (meta[key]?['x-review'] as String?) ?? 'draft';
}

/// The placeholders [declared] in English that [text] uses, and the plural
/// or select arguments it has. Two translations of one key must agree.
({Set<String> placeholders, Set<String> choices}) argumentsOf(String text, Set<String> declared) {
  final used = RegExp(r'\{\s*(\w+)\s*[,}]').allMatches(text).map((m) => m.group(1)!);
  final choices = RegExp(r'\{\s*(\w+)\s*,\s*(plural|select)\s*,').allMatches(text).map((m) => '${m.group(1)}:${m.group(2)}');
  return (placeholders: used.where(declared.contains).toSet(), choices: choices.toSet());
}

Set<String> declaredPlaceholders(Arb en, String key) =>
    ((en.meta[key]?['placeholders'] as Map?)?.keys ?? const []).cast<String>().toSet();

/// Why [sw] can't stand for [english] of [key], or null if it can.
String? argumentProblem(Arb en, String key, String sw) {
  final declared = declaredPlaceholders(en, key);
  final a = argumentsOf(en.values[key]!, declared);
  final b = argumentsOf(sw, declared);
  if (a.placeholders.length != b.placeholders.length || !a.placeholders.containsAll(b.placeholders)) {
    return 'placeholders differ: English ${a.placeholders}, Kiswahili ${b.placeholders}';
  }
  if (a.choices.length != b.choices.length || !a.choices.containsAll(b.choices)) {
    return 'plural/select arguments differ: English ${a.choices}, Kiswahili ${b.choices}';
  }
  return null;
}

// --- CSV (RFC 4180), for the owner's review in Excel ---

const reviewColumns = ['key', 'english', 'kiswahili', 'notes', 'status'];

String toCsv(List<List<String>> rows) {
  String cell(String s) =>
      RegExp(r'[",;\r\n]|^\s|\s$').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  // A BOM, so Excel opens it as UTF-8 (Kiswahili and "…" intact). LF line
  // ends: git stores the CSV with LF (.gitattributes), and a CRLF file showed
  // as modified after every export. Excel reads LF; parseCsv reads both.
  return '﻿${rows.map((r) => r.map(cell).join(',')).join('\n')}\n';
}

/// Reads what Excel saves: with or without a BOM, comma or semicolon
/// separated (Excel uses ';' in some regional settings).
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final sep = !firstLine.contains(',') && firstLine.contains(';') ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else if (c == '\r') {
        // A line break inside a cell, as Excel saves it (CRLF): the ARB has
        // LF, so an untouched cell must read back the same.
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        cell.write('\n');
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((s) => s.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  row.add(cell.toString());
  if (row.any((s) => s.isNotEmpty)) rows.add(row);
  return rows;
}
