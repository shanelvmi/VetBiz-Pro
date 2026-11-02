import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_sheet.dart';

// PH5a R4: a phone list's Summary sheet. Every figure the tablet's metric
// cards show, as label and value rows, for the cards' own period: nothing is
// lost when the cards make way for the one summary line.

Future<void> showPhoneSummarySheet(
  BuildContext context, {
  required String period,
  required List<(String label, String value)> rows,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.common_summary,
    builder: (context) {
      final colors = context.colors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(period, style: TextStyle(fontSize: PhoneListMetrics.subtitle, color: colors.textMuted)),
          const SizedBox(height: PhoneListMetrics.headerGap),
          for (final (label, value) in rows)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(fontSize: AppFontSize.f14, color: colors.textSecondary)),
                  ),
                  const SizedBox(width: PhoneListMetrics.partGap),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: PhoneListMetrics.title,
                      fontWeight: AppFontWeight.semibold,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
