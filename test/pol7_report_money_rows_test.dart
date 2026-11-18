// POL7: in a report's Transactions tab (computer and phone), income or
// expense is told by the sign and the word, in plain text: the word in
// textSecondary, the amount in the default text colour; never red or
// green per kind. The words and amounts are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

void main() {
  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    ph5TestWidgets('${size.width.toInt()} wide: Expense -10,000 and Other Income +50,000, no state colour', (tester) async {
      await ph7bPumpTabs(tester, ph7bReport(), size: size);
      await ph7bOpenTab(tester, 'Transactions');
      ph7bDropWideFontErrors(tester);
      final ctx = tester.element(find.byType(Scaffold).first);
      final c = ctx.colors;
      final red = {c.danger, c.dangerStrong, c.success, c.successStrong};
      for (final word in ['+50,000', '-10,000']) {
        final t = find.textContaining(word);
        expect(t, findsWidgets, reason: word);
      }
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        final text = rt.text.toPlainText();
        if (text.startsWith('+') || text.startsWith('-') || text == 'Expense' || text == 'Other Income') {
          expect(red.contains(rt.text.style?.color), isFalse, reason: text);
        }
      }
    });
  }
}
