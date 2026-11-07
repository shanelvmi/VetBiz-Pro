// PH5a: a fingerprint of a screen's whole widget tree (types, masked texts,
// box sizes and positions), recorded before a change and compared after, to
// prove a layout did not change.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _months = RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b');

/// Dates and times move with the clock; their shape does not (the test font
/// draws every character the same width).
String _mask(String s) => s.replaceAll(RegExp(r'\d'), '#').replaceAll(_months, 'Mon').replaceAll(RegExp(r'\b[AP]M\b'), 'XM');

/// Every element under [root]: its depth, widget type, text (masked), and
/// for a box its size and position relative to [root].
String treeFingerprint(WidgetTester tester, Finder root) {
  final rootElement = root.evaluate().single;
  final origin = (rootElement.renderObject! as RenderBox).localToGlobal(Offset.zero);
  final out = StringBuffer();
  void visit(Element e, int depth, Offset origin) {
    final w = e.widget;
    // RV1: a route's page transition counts as its page (the wrappers the
    // platform's builder adds, Zoom before RV1 or AppPageSlide after, are
    // left out), so a screen under a Navigator compares across the change;
    // the page is measured from its own top left, as a covered page is moved
    // aside by the transition (Zoom and the slide move it differently).
    if (w.runtimeType.toString().startsWith('_PageTransitionsThemeTransitions')) {
      final Widget page = (w as dynamic).child as Widget;
      Element? content;
      void find(Element c) {
        if (content != null) return;
        if (identical(c.widget, page)) {
          content = c;
        } else {
          c.visitChildren(find);
        }
      }

      e.visitChildren(find);
      if (content != null) {
        RenderBox? box;
        void firstBox(Element c) {
          if (box != null) return;
          final r = c.renderObject;
          if (r is RenderBox && r.hasSize && r.attached) {
            box = r;
          } else {
            c.visitChildren(firstBox);
          }
        }

        firstBox(content!);
        return visit(content!, depth, box?.localToGlobal(Offset.zero) ?? origin);
      }
    }
    out.write('$depth ${w.runtimeType}');
    if (w is Text) out.write(' "${_mask(w.data ?? w.textSpan?.toPlainText() ?? '')}"');
    if (w is RichText) out.write(' "${_mask(w.text.toPlainText())}"');
    final r = e.renderObject;
    if (w is RenderObjectWidget && r is RenderBox && r.hasSize && r.attached) {
      final o = r.localToGlobal(Offset.zero) - origin;
      out.write(' ${r.size.width.toStringAsFixed(1)}x${r.size.height.toStringAsFixed(1)}'
          '@${o.dx.toStringAsFixed(1)},${o.dy.toStringAsFixed(1)}');
    }
    out.writeln();
    e.visitChildren((c) => visit(c, depth + 1, origin));
  }

  visit(rootElement, 0, origin);
  return out.toString();
}

/// FNV-1a over the fingerprint's UTF-8 bytes, as 16 hex digits.
String fingerprintHash(String fingerprint) {
  var hash = 0xcbf29ce484222325;
  for (final b in utf8.encode(fingerprint)) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

const _fixture = 'test/fixtures/ph5a_wide_fingerprints.json';

/// Compares [fingerprint] with the one recorded under [name] before PH5a.
/// --dart-define=PH5A_RECORD=true records it instead (done once, on the code
/// before PH5a). On a mismatch the new tree is written beside the fixture
/// for a diff.
void expectSameFingerprint(String name, String fingerprint) {
  final file = File(_fixture);
  final recorded = file.existsSync() ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>) : <String, dynamic>{};
  final hash = '${fingerprintHash(fingerprint)} ${'\n'.allMatches(fingerprint).length}';
  if (const bool.fromEnvironment('PH5A_RECORD')) {
    recorded[name] = hash;
    final sorted = Map.fromEntries(recorded.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    File('build/ph5a_fingerprints/$name.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(fingerprint);
    return;
  }
  if (recorded[name] != hash) {
    File('build/ph5a_fingerprints/$name.now.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(fingerprint);
  }
  expect(hash, recorded[name], reason: '$name: the layout changed (see build/ph5a_fingerprints/$name.now.txt)');
}
