import 'package:flutter/material.dart';

import '../../config/app_limits.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../app_safe_area.dart';

// PH7b (docs/design/phone_reports.md): one block of a report tab on a phone:
// a heading, an optional note, then its rows. A long list shows its first
// rows and "See all (N)", which opens every row on a page of its own (R3).

class PhoneReportSection extends StatelessWidget {
  /// Names the section's keys (phoneReport-section-, -seeAll-).
  final String id;
  final IconData icon;
  final String title;
  final String? note;

  /// The rows a list may cut (the See all page shows them all).
  final List<Widget> rows;

  /// Shown when [rows] is empty (and [rows] is a list, not figures).
  final String? emptyText;

  /// Rows always shown under the list (a total).
  final List<Widget> footer;

  const PhoneReportSection({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.rows,
    this.note,
    this.emptyText,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cut = rows.length > AppLimits.reportPreviewRows;
    final shown = cut ? rows.take(AppLimits.reportPreviewRows).toList() : rows;
    return Container(
      key: ValueKey('phoneReport-section-$id'),
      margin: const EdgeInsets.only(bottom: PhoneReportMetrics.sectionGap),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(PhoneReportMetrics.sectionRadius),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PhoneReportMetrics.pagePadding,
              PhoneReportMetrics.pagePadding,
              PhoneReportMetrics.pagePadding,
              PhoneReportMetrics.headerGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Icon(icon, size: PhoneReportMetrics.icon, color: colors.primary),
                      const SizedBox(width: PhoneReportMetrics.partGap),
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: PhoneReportMetrics.sectionTitle, fontWeight: AppFontWeight.bold, color: colors.primary)),
                      ),
                    ],
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: PhoneReportMetrics.lineGap),
                  Text(note!, style: TextStyle(fontSize: PhoneReportMetrics.subtitle, color: colors.textMuted)),
                ],
              ],
            ),
          ),
          if (rows.isEmpty && footer.isEmpty && emptyText != null)
            Padding(
              padding: const EdgeInsets.all(PhoneReportMetrics.pagePadding),
              child: Text(emptyText!, style: TextStyle(fontSize: PhoneReportMetrics.title, color: colors.textMuted)),
            ),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: PhoneReportMetrics.pagePadding, color: colors.divider),
            shown[i],
          ],
          if (cut) ...[
            Divider(height: 1, color: colors.divider),
            InkWell(
              key: ValueKey('phoneReport-seeAll-$id'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PhoneReportSeeAllPage(id: id, title: title, rows: rows),
              )),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: PhoneReportMetrics.statMinHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PhoneReportMetrics.pagePadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.phoneReport_seeAll(rows.length),
                          style: TextStyle(
                              fontSize: PhoneReportMetrics.title, fontWeight: AppFontWeight.semibold, color: colors.primary),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (footer.isNotEmpty) ...[
            Divider(height: 1, color: colors.divider),
            ...footer,
          ],
          const SizedBox(height: PhoneReportMetrics.headerGap),
        ],
      ),
    );
  }
}

/// Every row of a section, in the same order, under its heading (R3).
class PhoneReportSeeAllPage extends StatelessWidget {
  final String id;
  final String title;
  final List<Widget> rows;

  const PhoneReportSeeAllPage({super.key, required this.id, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      key: ValueKey('phoneReport-seeAllPage-$id'),
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: AppElevation.e1,
        title: Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold)),
      ),
      body: ListView.separated(
        padding: EdgeInsets.only(bottom: PhoneReportMetrics.pagePadding + AppSafeArea.bottomOf(context)),
        itemCount: rows.length,
        separatorBuilder: (_, _) => Divider(height: 1, indent: PhoneReportMetrics.pagePadding, color: colors.divider),
        itemBuilder: (_, i) => ColoredBox(color: colors.surface, child: rows[i]),
      ),
    );
  }
}
