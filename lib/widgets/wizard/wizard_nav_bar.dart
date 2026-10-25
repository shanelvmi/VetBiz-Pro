import 'package:flutter/material.dart';

/// RW2a stub: replaced by the real Back/Continue bar (register_wizard.md
/// section 3).
class WizardNavBar extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool submitting;
  final bool pinned;
  final String finishLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const WizardNavBar({
    super.key,
    required this.isFirst,
    required this.isLast,
    this.submitting = false,
    this.pinned = false,
    required this.finishLabel,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
