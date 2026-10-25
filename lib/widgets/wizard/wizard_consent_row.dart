import 'package:flutter/material.dart';

/// A tappable name inside [WizardConsentRow]'s sentence.
class WizardLink {
  final String label;
  final VoidCallback onTap;

  const WizardLink({required this.label, required this.onTap});
}

/// RW2a stub: replaced by the real terms checkbox (RW1 answer 1).
class WizardConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final List<WizardLink> links;
  final String? errorText;

  const WizardConsentRow({
    super.key,
    this.value = false,
    required this.onChanged,
    required this.text,
    required this.links,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
