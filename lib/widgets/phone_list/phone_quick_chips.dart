import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

// PH5a R3: the quick status chips under a phone list's bar, in a row that
// scrolls sideways. Each chip holds a stored value and shows its label; the
// chosen one is the list's filter.

class PhoneQuickChips extends StatelessWidget {
  /// Stored values, in order (the first is usually 'All').
  final List<String> values;
  final String selected;
  final String Function(String value) label;
  final ValueChanged<String> onSelected;

  /// PH8a-fix: when set, each chip is keyed '[keyPrefix][value]' (tests).
  final String? keyPrefix;

  const PhoneQuickChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PhoneListMetrics.chipRowHeight,
      // A handful of chips: all built (not lazily), so each is reachable.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PhoneListMetrics.pagePadding),
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: PhoneListMetrics.chipGap),
              ChoiceChip(
                key: keyPrefix == null ? null : ValueKey('$keyPrefix${values[i]}'),
                label: Text(label(values[i])),
                selected: values[i] == selected,
                onSelected: (_) => onSelected(values[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
