import 'package:flutter/foundation.dart';

/// Where the Printer & Receipt Settings row is offered.
///
/// UX6 (owner decision): Android and iOS only. print_bluetooth_thermal 1.2.2
/// also registers macOS and Windows, but Bluetooth thermal printing has never
/// been tried on a real desktop, so every desktop (Windows, macOS, Linux) and
/// the web are hidden; desktop can be enabled here later, after a real test.
/// (UX5 had kept Windows and macOS, following the plugin's list.) A PLATFORM
/// check, never the screen width: a wide Android tablet still prints.
class PrinterSupport {
  PrinterSupport._();

  /// Tests set this to stand for a platform (web cannot be simulated);
  /// null uses the real one.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isSupported => debugOverride ?? supportedOn(isWeb: kIsWeb, platform: defaultTargetPlatform);

  static bool supportedOn({required bool isWeb, required TargetPlatform platform}) {
    if (isWeb) return false;
    return switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }
}
