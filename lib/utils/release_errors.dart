import 'package:flutter/widgets.dart';

import '../widgets/friendly_error_card.dart';

/// FX1: in a RELEASE build ([release] is kReleaseMode), a widget that fails
/// to build shows the FriendlyErrorCard instead of the grey box, and every
/// Flutter error prints ONE readable line to the console (releaseErrorLine)
/// for the owner to paste to the developer. Debug and profile builds keep
/// Flutter's own error screen and report.
void installReleaseErrorHandling({required bool release}) {
  if (!release) return;
  ErrorWidget.builder = (_) => const FriendlyErrorCard();
  FlutterError.onError = (details) => debugPrint(releaseErrorLine(details));
}

/// The error on one line: the exception, the library, what was being built
/// (details.context, which names the widget) and the first three stack
/// frames.
String releaseErrorLine(FlutterErrorDetails details) {
  String oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final frames = (details.stack?.toString() ?? '')
      .split('\n')
      .map(oneLine)
      .where((frame) => frame.isNotEmpty)
      .take(3)
      .join(' < ');
  return [
    '[VetBiz error] ${oneLine(details.exceptionAsString())}',
    if (details.library != null) 'library: ${details.library}',
    if (details.context != null) 'while: ${oneLine(details.context!.toDescription())}',
    if (frames.isNotEmpty) 'at: $frames',
  ].join(' | ');
}
