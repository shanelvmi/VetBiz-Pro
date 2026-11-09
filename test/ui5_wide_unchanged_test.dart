// UI5: tablets and computers keep today's dashboard exactly. The loaded wide
// group (the card grid and the lower panels, wide_dashboard_group.dart) at
// 768x1024, 1024x768 and 1200x800 in Light and Dark: its layout fingerprint
// and every colour it paints were recorded before UI5 changed anything
// (PH5A_RECORD=true on 3126284) and must still match.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';
import 'helpers/wide_dashboard_group.dart';

const _sizes = [
  MatrixSize('768x1024', Size(768, 1024)),
  MatrixSize('1024x768', Size(1024, 768)),
  MatrixSize('1200x800', Size(1200, 800)),
];

String _hex(Color? c) => c == null ? '-' : c.toARGB32().toRadixString(16).padLeft(8, '0');

/// Every colour the group paints, in tree order: text, Material fills,
/// decorations (fill, border, gradient) and icons.
String _colours(WidgetTester tester, Finder root) {
  final out = StringBuffer();
  void visit(Element e) {
    final w = e.widget;
    if (w is RichText) out.writeln('T ${_hex(w.text.style?.color)}');
    if (w is Material) out.writeln('M ${_hex(w.color)}');
    if (w is Icon) out.writeln('I ${_hex(w.color)}');
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      final border = d.border is Border ? (d.border! as Border).top.color : null;
      out.writeln('D ${_hex(d.color)} ${_hex(border)} ${d.gradient?.colors.map(_hex).join(',') ?? '-'}');
    }
    e.visitChildren(visit);
  }

  visit(root.evaluate().single);
  return out.toString();
}

void main() {
  setUpAll(loadRealFont);

  for (final s in _sizes) {
    for (final look in [MatrixLook.light, MatrixLook.dark]) {
      testWidgets('${matrixCase(s, look)}: the loaded wide dashboard is unchanged', (tester) async {
        final gate = RevealGate(primary: const []);
        addTearDown(gate.dispose);
        await pumpAtSize(
          tester,
          screen: wideDashboardGroup(gate, wide: s.size.width >= AppBreakpoints.expanded),
          size: s.size,
          look: look,
        );
        final root = find.byType(SingleChildScrollView);
        final name = 'ui5-wide-dashboard-${s.label}-${look.name}';
        expectSameFingerprint(name, treeFingerprint(tester, root, stripReveal: true));
        expectSameFingerprint('$name-colours', _colours(tester, root));
      });
    }
  }
}
