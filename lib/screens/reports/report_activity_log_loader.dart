import 'package:flutter/material.dart';

import '../../models/daily_report.dart';
import '../../services/daily_report_service.dart';

/// Reads a report's activity log from its admin-only subdocument (E4c, a1)
/// and hands the result to [builder]. Only build this for an ADMIN, and only
/// when [DailyReport.activityLogIncluded]: the rules refuse an assistant.
///
/// The read starts once, in initState: a FutureBuilder given a new future on
/// every build starts over at "waiting".
class ReportActivityLogLoader extends StatefulWidget {
  final DailyReport report;

  /// The snapshot's data is null when no log was saved with the report (one
  /// made before the log moved to the subdocument).
  final Widget Function(BuildContext context, AsyncSnapshot<List<ActivityLogEntry>?> snapshot) builder;

  /// Tests pass their own read; the app reads through DailyReportService.
  final Future<List<ActivityLogEntry>?> Function(DailyReport report)? load;

  const ReportActivityLogLoader({super.key, required this.report, required this.builder, this.load});

  @override
  State<ReportActivityLogLoader> createState() => _ReportActivityLogLoaderState();
}

class _ReportActivityLogLoaderState extends State<ReportActivityLogLoader> {
  late final Future<List<ActivityLogEntry>?> _future;

  @override
  void initState() {
    super.initState();
    final load = widget.load ??
        (DailyReport r) => DailyReportService().getActivityLog(facilityId: r.facilityId, reportId: r.id);
    _future = load(widget.report);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActivityLogEntry>?>(future: _future, builder: widget.builder);
  }
}
