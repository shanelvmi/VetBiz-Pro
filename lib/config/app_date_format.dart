import 'package:intl/intl.dart';

/// Named date and time formats. The patterns are exactly the ones in use, so
/// moving a screen onto these changes nothing it shows.
///
/// `yyyy-MM-dd` and the file-name stamps are DATA, not display: they live in
/// DataKeys (lib/data/data_keys.dart) and are never localised.
class AppDateFormat {
  AppDateFormat._();

  // Patterns from the Phase 2 spec.
  static const String datePattern = 'dd MMM yyyy';
  static const String dateNoPadPattern = 'd MMM yyyy';
  static const String dateShortPattern = 'd MMM';
  static const String dateDayPattern = 'dd MMM';
  static const String dateLongPattern = 'EEEE, d MMM yyyy';
  static const String dateLongFullPattern = 'EEEE, d MMMM yyyy';
  static const String monthYearPattern = 'MMMM yyyy';
  static const String monthYearShortPattern = 'MMM yyyy';
  static const String time24Pattern = 'HH:mm';
  static const String time12Pattern = 'hh:mm a';
  static const String time12ShortPattern = 'h:mm a';
  static const String dateTime24SecondsPattern = 'dd MMM yyyy - HH:mm:ss';

  // Also in use, not listed in the spec; kept exact.
  static const String dateTime24Pattern = 'dd MMM yyyy, HH:mm';
  static const String dateTime12Pattern = 'dd MMM yyyy, hh:mm a';
  static const String dateNoPadTime12ShortPattern = 'd MMM yyyy, h:mm a';
  static const String dateLongPaddedPattern = 'EEEE, dd MMM yyyy';
  static const String dateWeekdayShortPattern = 'EEE, dd MMM yyyy';
  static const String dateDayTime24Pattern = 'dd MMM, HH:mm';

  /// `y` and `yyyy` print the same four-digit year.
  static const String dateNoPadYPattern = 'd MMM y';
  static const String dayMonthNumericPattern = 'd/M';

  static DateFormat get date => DateFormat(datePattern);
  static DateFormat get dateNoPad => DateFormat(dateNoPadPattern);
  static DateFormat get dateShort => DateFormat(dateShortPattern);
  static DateFormat get dateDay => DateFormat(dateDayPattern);
  static DateFormat get dateLong => DateFormat(dateLongPattern);
  static DateFormat get dateLongFull => DateFormat(dateLongFullPattern);
  static DateFormat get monthYear => DateFormat(monthYearPattern);
  static DateFormat get monthYearShort => DateFormat(monthYearShortPattern);
  static DateFormat get time24 => DateFormat(time24Pattern);
  static DateFormat get time12 => DateFormat(time12Pattern);
  static DateFormat get time12Short => DateFormat(time12ShortPattern);
  static DateFormat get dateTime24Seconds => DateFormat(dateTime24SecondsPattern);
  static DateFormat get dateTime24 => DateFormat(dateTime24Pattern);
  static DateFormat get dateTime12 => DateFormat(dateTime12Pattern);
  static DateFormat get dateNoPadTime12Short => DateFormat(dateNoPadTime12ShortPattern);
  static DateFormat get dateLongPadded => DateFormat(dateLongPaddedPattern);
  static DateFormat get dateWeekdayShort => DateFormat(dateWeekdayShortPattern);
  static DateFormat get dateDayTime24 => DateFormat(dateDayTime24Pattern);
  static DateFormat get dateNoPadY => DateFormat(dateNoPadYPattern);
  static DateFormat get dayMonthNumeric => DateFormat(dayMonthNumericPattern);

}
