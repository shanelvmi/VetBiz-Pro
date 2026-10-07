import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_pdf_service.dart';
import 'report_tabbed_content.dart';
import '../../theme/app_palette.dart';
import '../../config/app_date_format.dart';

/// Read-only view of a past, already-generated report - the AppBar
/// (date, submission status, PDF action) plus the shared tabbed
/// content widget. Used when opening a report from the Past Reports
/// list; today's own report is shown directly on the main View
/// Reports screen instead, using the same shared tab content.
class ReportDetailScreen extends StatelessWidget {
  final DailyReport report;

  const ReportDetailScreen({super.key, required this.report});

  static const Color primaryDeepGreen = AppPalette.primary;
  static const Color offWhite = AppPalette.background;

  Future<void> _printOrDownloadPdf(BuildContext context) async {
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final rawName = facilityProvider.selectedFacilityName ?? 'VetBiz Pro Facility';
    final facilityType = facilityProvider.selectedFacilityType;
    final facilityName = (facilityType != null && facilityType.isNotEmpty) ? '$rawName $facilityType' : rawName;
    await DailyReportPdfService.printOrDownload(report, facilityName: facilityName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppDateFormat.dateLong.format(report.reportDate),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            Text(
              report.status == 'submitted'
                  ? 'Submitted by ${report.generatedByName}'
                  : 'Draft - not yet submitted',
              style: TextStyle(fontSize: 12, color: report.status == 'submitted' ? Colors.black54 : Colors.orange[800]),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => _printOrDownloadPdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryDeepGreen,
                side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ),
      body: ReportTabbedContent(report: report),
    );
  }
}
