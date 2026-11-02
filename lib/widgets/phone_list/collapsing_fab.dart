import 'package:flutter/material.dart';

import '../../theme/theme_context.dart';

// PH5a R2: a phone list's primary action, an extended floating button at the
// bottom right. PhoneListScaffold collapses it to its icon while the person
// scrolls down, extends it when they scroll up, and leaves it out while the
// keyboard is open.

class CollapsingFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool extended;
  final VoidCallback onPressed;

  const CollapsingFab({
    super.key,
    required this.label,
    required this.icon,
    required this.extended,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FloatingActionButton.extended(
      heroTag: null,
      tooltip: label,
      onPressed: onPressed,
      isExtended: extended,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
