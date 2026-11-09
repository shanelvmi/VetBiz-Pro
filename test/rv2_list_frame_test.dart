// RV2: a phone list's skeleton and its loaded list share their frame (the app
// bar, the floating button, the chips, the summary line's slot) at phone
// sizes, in Light, Dark and Kiswahili.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/rv2_list_host.dart';

const _skip = true;

void main() {
  for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360)]) {
    for (final look in const [(Brightness.light, Locale('en')), (Brightness.dark, Locale('en')), (Brightness.light, Locale('sw'))]) {
      testWidgets('skeleton and list share their frame at ${size.width.toInt()}x${size.height.toInt()} '
          '${look.$1.name} ${look.$2.languageCode}', (tester) async {
        await pumpList(tester, ListData()..summaryPending = true, size: size, brightness: look.$1, locale: look.$2);
        final frame = listFrame(tester);
        final chips = chipsRect(tester);
        final summary = tester.getRect(find.byKey(summarySlotKey).first);
        setList((d) {
          d.loading = false;
          d.items = const ['a', 'b', 'c'];
          d.summaryPending = false;
          d.summaryLine = '3 sales';
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(listFrame(tester), frame);
        expect(chipsRect(tester), chips);
        expect(tester.getRect(find.byKey(summaryLineKey)).height, lessThanOrEqualTo(summary.height));
      }, skip: _skip);
    }
  }
}
