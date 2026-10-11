import 'package:flutter/material.dart';
import '../config/app_date_format.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// Shared date-range picker dialog, used anywhere a screen needs "pick a
/// custom period" (Payments, Transactions, and anywhere else this comes
/// up later) - built once here so every screen gets the identical
/// experience instead of a slightly different one-off each time.
///
/// Returns a `{'start': DateTime, 'end': DateTime}` map via
/// `Navigator.pop`, or null if cancelled. The returned `end` is set to
/// 23:59:59 on the chosen day, so range queries using it as an inclusive
/// upper bound capture the whole final day.
class DateRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final Color primaryDeepGreen;
  final Color warmAmber;
  final Color offWhite;

  const DateRangeDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.primaryDeepGreen,
    required this.warmAmber,
    required this.offWhite,
  });

  @override
  State<DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<DateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.dateRange_title, style: TextStyle(color: widget.primaryDeepGreen)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.dateRange_start, style: const TextStyle(fontWeight: AppFontWeight.bold)),
          const SizedBox(height: AppSpacing.s8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime(2020),
                lastDate: _end,
              );
              if (picked != null) setState(() => _start = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.borderStrong),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                  const SizedBox(width: AppSpacing.s12),
                  Text(AppDateFormat.date.format(_start)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(context.l10n.dateRange_end, style: const TextStyle(fontWeight: AppFontWeight.bold)),
          const SizedBox(height: AppSpacing.s8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _end,
                firstDate: _start,
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _end = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.borderStrong),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: widget.primaryDeepGreen),
                  const SizedBox(width: AppSpacing.s12),
                  Text(AppDateFormat.date.format(_end)),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(foregroundColor: widget.primaryDeepGreen),
          child: Text(context.l10n.common_cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final endOfDay = DateTime(_end.year, _end.month, _end.day, 23, 59, 59);
            Navigator.pop(context, {'start': _start, 'end': endOfDay});
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(widget.primaryDeepGreen),
            foregroundColor: WidgetStateProperty.all(widget.offWhite),
          ),
          child: Text(context.l10n.common_apply),
        ),
      ],
    );
  }
}
