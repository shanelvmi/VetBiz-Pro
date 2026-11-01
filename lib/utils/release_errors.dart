import 'package:flutter/foundation.dart';

/// FX1: in a RELEASE build ([release] is kReleaseMode), a widget that fails
/// to build shows the FriendlyErrorCard instead of the grey box, and every
/// Flutter error prints ONE readable line to the console (releaseErrorLine)
/// for the owner to paste to the developer. Debug and profile builds keep
/// Flutter's own error screen and report.
void installReleaseErrorHandling({required bool release}) => throw UnimplementedError();

/// The error on one line: the exception, the library, what was being built
/// (details.context, which names the widget) and the first three stack
/// frames.
String releaseErrorLine(FlutterErrorDetails details) => throw UnimplementedError();
