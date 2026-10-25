import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Builds a [HoverLink.icon]'s icon in the colour of its state.
typedef HoverLinkIconBuilder = Widget Function(Color color);

/// Stub (G4 tests first): the API only.
class HoverLink extends StatelessWidget {
  const HoverLink({
    super.key,
    required String this.label,
    required this.onTap,
    this.color,
    this.style,
    this.underlineAtRest = false,
    this.button = false,
  })  : icon = null,
        tooltip = null;

  const HoverLink.icon({
    super.key,
    required HoverLinkIconBuilder this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.button = false,
  })  : label = null,
        style = null,
        underlineAtRest = false;

  static const focusRingKey = ValueKey<String>('hover-link-focus-ring');
  static const iconUnderlineKey = ValueKey<String>('hover-link-icon-underline');

  final String? label;
  final HoverLinkIconBuilder? icon;
  final VoidCallback onTap;
  final Color? color;
  final TextStyle? style;
  final bool underlineAtRest;
  final bool button;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.colors.primary;
    return GestureDetector(
      onTap: onTap,
      child: label != null ? Text(label!, style: (style ?? const TextStyle()).copyWith(color: ink)) : icon!(ink),
    );
  }
}
