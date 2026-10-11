// Writes docs/kiswahili_review.csv for the owner to review in Excel
// (docs/PHASE2_LOCALISATION_SPEC.md section 8), and the snapshot of what
// it wrote (docs/.kiswahili_snapshot.json).
//
//   dart run tool/export_l10n_review.dart           refuses if the CSV has
//                                                   edits not imported yet
//   dart run tool/export_l10n_review.dart --force   overwrites it anyway
import 'dart:io';

import 'l10n_arb.dart';
import 'l10n_review.dart';

void main(List<String> args) {
  final root = Directory.current;
  final en = Arb.read(Arb.fileFor(root, 'en'));
  final sw = Arb.read(Arb.fileFor(root, 'sw'));
  final out = File('${root.path}/$reviewCsvPath');
  final snapshot = File('${root.path}/$reviewSnapshotPath');

  // Never overwrite the owner's work: edits still in the CSV must be
  // imported first. The CSV is compared with what was last written, not
  // with app_sw.arb, so a draft changed in the ARB since is not an "edit".
  if (out.existsSync() && !args.contains('--force')) {
    final pending = exportBlockers(
        en, sw, out.readAsStringSync(), snapshot.existsSync() ? snapshot.readAsStringSync() : null);
    if (pending.isNotEmpty) {
      stderr.writeln('$reviewCsvPath has ${pending.length} edits not imported yet '
          '(${pending.take(5).join(', ')}${pending.length > 5 ? ', ...' : ''}).\n'
          'Run dart run tool/import_l10n_review.dart first, or pass --force to discard them.');
      exit(1);
    }
  }

  final rows = reviewRows(en, sw);
  out.writeAsStringSync(toCsv(rows));
  snapshot.writeAsStringSync(encodeSnapshot(snapshotOf(rows)));
  final drafts = rows.skip(1).where((r) => r[4] == 'draft').length;
  stdout.writeln('Wrote $reviewCsvPath: ${rows.length - 1} keys, $drafts still draft.');
}
