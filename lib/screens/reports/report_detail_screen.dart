import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_pdf_service.dart';
import 'report_tabbed_content.dart';
import '../../config/app_date_format.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
import '../../theme/theme_context.dart';

/// Read-only view of a past, already-generated report - the AppBar
/// (date, submission status, PDF action) plus the shared tabbed
/// content widget. Used when opening a report from the Past Reports
/// list; today's own report is shown directly on the main View
/// Reports screen instead, using the same shared tab content.
class ReportDetailScreen extends StatelessWidget {
  final DailyReport report;

  /// Null: the app's own Firestore. Tests pass an in-memory one (PH7b).
  final FirebaseFirestore? firestore;

  const ReportDetailScreen({super.key, required this.report, this.firestore});


  Future<void> _printOrDownloadPdf(BuildContext context) async {
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facilityName = DailyReportPdfService.facilityNameOf(facilityProvider.selectedFacility);
    await DailyReportPdfService.printOrDownload(report, facilityName: facilityName);
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isPhone(context)) return _buildPhone(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: AppElevation.e1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppDateFormat.dateLong.format(report.reportDate),
                style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18, color: context.colors.textPrimary)),
            Text(
              report.status == 'submitted'
                  ? context.l10n.reports_submittedBy(report.generatedByName)
                  : context.l10n.reports_draftNotSubmitted,
              style: TextStyle(fontSize: AppFontSize.f12, color: report.status == 'submitted' ? context.colors.textSecondary : context.colors.warningStrong),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s12),
            child: OutlinedButton.icon(
              onPressed: () => _printOrDownloadPdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: AppIconSize.i16),
              label: Text(context.l10n.reports_pdf),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primary,
                side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40)),
              ),
            ),
          ),
        ],
      ),
      body: ReportTabbedContent(report: report, firestore: firestore),
    );
  }

  // PH7b R10 (docs/design/phone_reports.md): on a phone the date is the
  // title (up to two lines, nothing cut), the status a line under the bar,
  // and the PDF an icon button: the same PDF. Wider windows keep the bar
  // above.
  Widget _buildPhone(BuildContext context) {
    final colors = context.colors;
    final submitted = report.status == 'submitted';
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: AppElevation.e1,
        title: Text(
          AppDateFormat.dateLong.format(report.reportDate),
          maxLines: 2,
          softWrap: true,
          style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: PhoneReportMetrics.sectionTitle),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.reports_pdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _printOrDownloadPdf(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(
                PhoneReportMetrics.pagePadding, PhoneReportMetrics.headerGap, PhoneReportMetrics.pagePadding, 0),
            child: Text(
              submitted ? context.l10n.reports_submittedBy(report.generatedByName) : context.l10n.reports_draftNotSubmitted,
              style: TextStyle(fontSize: PhoneReportMetrics.title, color: submitted ? colors.textSecondary : colors.warningStrong),
            ),
          ),
          Expanded(child: ReportTabbedContent(report: report, firestore: firestore)),
        ],
      ),
    );
  }
}
