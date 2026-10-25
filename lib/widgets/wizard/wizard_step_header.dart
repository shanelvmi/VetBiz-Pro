import 'package:flutter/material.dart';

/// RW2a stub: replaced by the real header (register_wizard.md section 3).
class WizardStepHeader extends StatelessWidget {
  final int current;
  final int total;
  final String title;

  const WizardStepHeader({super.key, required this.current, required this.total, required this.title});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
