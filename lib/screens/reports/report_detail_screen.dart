import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_pdf_service.dart';
import 'report_tabbed_content.dart';
import '../../config/app_date_format.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// Read-only view of a past, already-generated report - the AppBar
/// (date, submission status, PDF action) plus the shared tabbed
/// content widget. Used when opening a report from the Past Reports
/// list; today's own report is shown directly on the main View
/// Reports screen instead, using the same shared tab content.
class ReportDetailScreen extends StatelessWidget {
  final DailyReport report;

  const ReportDetailScreen({super.key, required this.report});


  Future<void> _printOrDownloadPdf(BuildContext context) async {
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final rawName = facilityProvider.selectedFacilityName ?? '${AppInfo.name} Facility';
    final facilityType = facilityProvider.selectedFacilityType;
    final facilityName = (facilityType != null && facilityType.isNotEmpty) ? '$rawName $facilityType' : rawName;
    await DailyReportPdfService.printOrDownload(report, facilityName: facilityName);
  }

  @override
  Widget build(BuildContext context) {
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
                  ? 'Submitted by ${report.generatedByName}'
                  : 'Draft - not yet submitted',
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
              label: const Text('PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primary,
                side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40)),
              ),
            ),
          ),
        ],
      ),
      body: ReportTabbedContent(report: report),
    );
  }
}
