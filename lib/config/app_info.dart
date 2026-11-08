import 'package:flutter/foundation.dart';

/// The app's own name, typed once.
class AppInfo {
  AppInfo._();

  static const String name = 'VetBiz Pro';
  static const String shortName = 'VetBiz';

  /// The round logo's letters (login and register top bars): a mark, not a word to translate.
  static const String logoMark = 'VB.';

  /// The same letters without the dot, in the facility picker's top bar.
  static const String logoInitials = 'VB';

  /// The app's version, typed in one place (R3, D6): Settings shows it in its
  /// version line, the login footer as [versionLabel].
  static const String version = '1.0.0';

  /// The version shown in the login footer.
  static const String versionLabel = 'v$version';

  /// FIN1: when this build was made, so the owner can tell on a phone which
  /// build is open. tool/serve_web.ps1 passes the local date and time
  /// (--dart-define=BUILD_STAMP=yyyy-MM-dd HH:mm); any other build says dev.
  static const String definedBuildStamp = String.fromEnvironment('BUILD_STAMP', defaultValue: 'dev');

  /// Tests only: a stamp to show instead of [definedBuildStamp].
  @visibleForTesting
  static String? buildStampOverride;

  /// The stamp the footer and Settings show after the version.
  static String get buildStamp => buildStampOverride ?? definedBuildStamp;
}
