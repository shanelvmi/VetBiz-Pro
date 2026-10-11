import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';

/// The check every stored-value list's display lookup must pass (spec
/// section 6), shared by the stored-label tests:
/// - the table holds exactly the list's values, in the list's order;
/// - each value has a non-empty label in English and in Kiswahili, and the
///   English label is [english]'s (the stored text itself when not given);
/// - an unknown or custom value comes back unchanged in both languages.
///
/// [extra]: values the screens show that are not in the list (for example
/// "Uncategorized"), with their English labels.
void checkStoredList(
  StoredLabelTable table,
  List<String> known,
  String Function(AppLocalizations l, String stored) label, {
  Map<String, String> english = const {},
  Map<String, String> extra = const {},
}) {
  final en = lookupAppLocalizations(const Locale('en'));
  final sw = lookupAppLocalizations(const Locale('sw'));

  expect(table.labels.keys.toList(), [...known, ...extra.keys], reason: 'the table must match the stored list, in order');
  for (final v in [...known, ...extra.keys]) {
    expect(label(en, v), extra[v] ?? english[v] ?? v, reason: 'English label of "$v"');
    expect(label(sw, v).trim(), isNotEmpty, reason: 'Kiswahili label of "$v"');
  }
  const unknown = 'A custom value nobody listed';
  expect(label(en, unknown), unknown);
  expect(label(sw, unknown), unknown);
  expect(label(sw, ''), '', reason: 'an empty value stays empty');
}
