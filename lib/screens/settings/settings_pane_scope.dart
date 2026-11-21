import 'package:flutter/widgets.dart';

/// LAY7 (#23): marks a screen shown as a pane inside Settings (PC and tablet,
/// content 900 or wider). The pane is not a page of its own: its AppBar must
/// not imply a back arrow, which would close Settings. Screens opened
/// anywhere else, or pushed from a pane, are not inside the marker and keep
/// their arrow as before.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({super.key, required super.child});

  /// True for a screen embedded as a Settings pane.
  static bool isPane(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SettingsPaneScope>() != null;

  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) => false;
}
