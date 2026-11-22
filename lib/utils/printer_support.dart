import 'package:flutter/foundation.dart';

/// UX5 (Step 0c, owner 2026-11-22): where Bluetooth receipt printing can run.
/// print_bluetooth_thermal 1.2.2 registers Android, iOS, macOS and Windows;
/// its web and Linux entries are commented out, so there the plugin has no
/// implementation and the Printer settings could only fail. A PLATFORM
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
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }
}
