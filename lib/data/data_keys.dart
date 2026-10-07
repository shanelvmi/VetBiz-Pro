/// Date patterns that produce DATA (document ids, query keys, file names),
/// not text for people. Never localised, never changed: existing ids and
/// file names were built with them.
class DataKeys {
  DataKeys._();

  /// Daily summary document ids and their queries: "2026-03-05".
  static const String isoDay = 'yyyy-MM-dd';

  /// Timestamp written into exports (export_data_screen.dart).
  static const String exportTimestamp = 'yyyy-MM-dd HH:mm';

  /// Export file names (export_data_screen.dart).
  static const String exportFileStamp = 'yyyyMMdd_HHmm';

  /// Statement file names (debtors_screen.dart).
  static const String fileDateStamp = 'yyyyMMdd';
}
