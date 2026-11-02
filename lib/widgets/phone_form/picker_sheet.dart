import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_sheet.dart';

/// One choice of a [showPickerSheet]: the stored value, its label, an
/// optional icon, and the group it sits under (null: none).
class PickerOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? group;

  const PickerOption(this.value, this.label, {this.icon, this.group});
}

/// PH6: a form's picker on a phone (type, category, method, debtor), as a
/// bottom sheet (showAppSheet): one option a row, 56 high, a visible check
/// on the chosen one; with [searchHint], a search field at the top that
/// filters by label (and by [matches], when given, the stored value too);
/// options with a group sit under its header. Returns the chosen value, or
/// null when the sheet is closed. The caller opens it on phones only and
/// keeps its own dialog or menu elsewhere.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  String? searchHint,
  bool Function(PickerOption<T> option, String query)? matches,
  String? emptyText,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (context) => _PickerBody<T>(
      options: options,
      selected: selected,
      searchHint: searchHint,
      matches: matches,
      emptyText: emptyText,
    ),
  );
}

class _PickerBody<T> extends StatefulWidget {
  final List<PickerOption<T>> options;
  final T? selected;
  final String? searchHint;
  final bool Function(PickerOption<T> option, String query)? matches;
  final String? emptyText;

  const _PickerBody({
    required this.options,
    required this.selected,
    required this.searchHint,
    required this.matches,
    required this.emptyText,
  });

  @override
  State<_PickerBody<T>> createState() => _PickerBodyState<T>();
}

class _PickerBodyState<T> extends State<_PickerBody<T>> {
  String _query = '';

  bool _shown(PickerOption<T> o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.label.toLowerCase().contains(q) || (widget.matches?.call(o, q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = widget.options.where(_shown).toList();
    final rows = <Widget>[];
    String? group;
    for (final o in shown) {
      if (o.group != null && o.group != group) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: PhoneFormMetrics.groupHeaderPaddingTop, bottom: AppSpacing.s4),
          child: Text(
            o.group!,
            style: TextStyle(fontSize: PhoneFormMetrics.label, fontWeight: AppFontWeight.bold, color: colors.primary),
          ),
        ));
      }
      group = o.group;
      final chosen = o.value == widget.selected;
      rows.add(Semantics(
        selected: chosen,
        button: true,
        child: InkWell(
          key: ValueKey('pickerSheet-option-${o.value}'),
          onTap: () => Navigator.of(context).pop(o.value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PhoneFormMetrics.optionRow),
            child: Row(
              children: [
                if (o.icon != null) ...[
                  Icon(o.icon, size: PhoneFormMetrics.optionIcon, color: colors.primary),
                  const SizedBox(width: PhoneFormMetrics.optionGap),
                ],
                Expanded(
                  child: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: PhoneFormMetrics.body,
                      fontWeight: chosen ? AppFontWeight.semibold : AppFontWeight.regular,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (chosen)
                  Icon(Icons.check, key: const ValueKey('pickerSheet-check'), size: PhoneFormMetrics.optionCheck, color: colors.primary),
              ],
            ),
          ),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.searchHint != null)
          TextField(
            key: const ValueKey('pickerSheet-search'),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              constraints: const BoxConstraints(minHeight: PhoneFormMetrics.fieldMinHeight),
            ),
            style: const TextStyle(fontSize: PhoneFormMetrics.body),
            onChanged: (v) => setState(() => _query = v),
          ),
        if (shown.isEmpty && widget.emptyText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            child: Text(widget.emptyText!, textAlign: TextAlign.center, style: TextStyle(fontSize: PhoneFormMetrics.body, color: colors.textMuted)),
          ),
        ...rows,
      ],
    );
  }
}
