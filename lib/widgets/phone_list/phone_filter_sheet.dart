import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_sheet.dart';

// PH5a R3: every filter of a list's tablet toolbar, in one bottom sheet
// (showAppSheet), with Apply and Reset. The options are the toolbar's stored
// values; only their labels are shown.

/// One toolbar filter: its title, its stored values in the toolbar's order,
/// their labels, and the value it starts at.
class PhoneFilterField {
  final String title;
  final List<String> options;
  final String Function(String value) label;
  final String defaultValue;

  const PhoneFilterField({
    required this.title,
    required this.options,
    required this.label,
    required this.defaultValue,
  });
}

/// The current [values] (field id to stored value) for [fields]; returns the
/// applied values, or null when the sheet was closed without Apply. Reset puts
/// every field back to its default in the sheet; Apply applies.
Future<Map<String, String>?> showPhoneFilterSheet(
  BuildContext context, {
  required Map<String, PhoneFilterField> fields,
  required Map<String, String> values,
}) {
  return showAppSheet<Map<String, String>>(
    context,
    title: context.l10n.facilityPicker_filter,
    builder: (context) => _FilterSheetBody(fields: fields, initial: values),
  );
}

class _FilterSheetBody extends StatefulWidget {
  final Map<String, PhoneFilterField> fields;
  final Map<String, String> initial;

  const _FilterSheetBody({required this.fields, required this.initial});

  @override
  State<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends State<_FilterSheetBody> {
  late final Map<String, String> _draft = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in widget.fields.entries) ...[
          Text(
            entry.value.title,
            style: TextStyle(
              fontSize: AppFontSize.f14,
              fontWeight: AppFontWeight.semibold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: PhoneListMetrics.headerGap),
          Wrap(
            spacing: PhoneListMetrics.chipGap,
            children: [
              for (final option in entry.value.options)
                ChoiceChip(
                  label: Text(entry.value.label(option)),
                  selected: _draft[entry.key] == option,
                  onSelected: (_) => setState(() => _draft[entry.key] = option),
                ),
            ],
          ),
          const SizedBox(height: PhoneListMetrics.pagePadding),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.minTapTarget)),
                onPressed: () => setState(() {
                  for (final entry in widget.fields.entries) {
                    _draft[entry.key] = entry.value.defaultValue;
                  }
                }),
                child: Text(l10n.common_reset),
              ),
            ),
            const SizedBox(width: PhoneListMetrics.chipGap),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.minTapTarget)),
                onPressed: () => Navigator.of(context).pop(Map<String, String>.of(_draft)),
                child: Text(l10n.common_apply),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
