// PH6: tablets and computers keep today's money forms and stock dialogs
// exactly. At 768x1024 (a full page), 1024x768 and 1200x800 (the modal's
// content) the whole widget tree of each form is compared with the
// fingerprint recorded from the code before PH6
// (test/fixtures/ph5a_wide_fingerprints.json, the ph6- names).
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ph6_forms.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

void main() {
  for (final e in ph6Forms.entries) {
    final (_, type) = e.value;
    for (final size in ph5WideSizes) {
      final where = 'ph6-${e.key}-${size.width.toInt()}x${size.height.toInt()}';
      ph5TestWidgets('$where: the form as before PH6', (tester) async {
        await pumpPh6(tester, e.key, size: size);
        expectSameFingerprint(where, '${_errors(tester)}${treeFingerprint(tester, find.byType(type))}');
      }, skip: _skip);
    }
  }
}
