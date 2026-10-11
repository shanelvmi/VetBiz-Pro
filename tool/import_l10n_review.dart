// Reads the owner's edited docs/kiswahili_review.csv back into
// lib/l10n/app_sw.arb (docs/PHASE2_LOCALISATION_SPEC.md section 8).
//
//   dart run tool/import_l10n_review.dart [path/to/edited.csv]
//
// A row whose status is "reviewed" (or ok / approved / done / sawa), or
// whose Kiswahili text was changed, is saved and marked reviewed. Then run
// flutter gen-l10n (or flutter run) to rebuild the generated code.
import 'dart:io';

import 'l10n_arb.dart';
import 'l10n_review.dart';

void main(List<String> args) {
  final root = Directory.current;
  final csvFile = File(args.isNotEmpty ? args.first : '${root.path}/$reviewCsvPath');
  if (!csvFile.existsSync()) {
    stderr.writeln('${csvFile.path} not found.');
    exit(1);
  }
  final en = Arb.read(Arb.fileFor(root, 'en'));
  final swFile = Arb.fileFor(root, 'sw');
  final sw = Arb.read(swFile);

  final result = applyReview(en, sw, parseCsv(csvFile.readAsStringSync()));
  for (final w in result.warnings) {
    stderr.writeln('  $w');
  }
  swFile.writeAsStringSync(sw.encode(order: en.values.keys));
  final drafts = en.values.keys.where((k) => sw.reviewOf(k) != 'reviewed').length;
  stdout.writeln('${result.reviewed.length} rows marked reviewed; '
      '${result.warnings.length} skipped; $drafts keys still draft.');
}
