import '../../l10n/l10n.dart';
import '../../services/dashboard_summary_service.dart';

// PH4 stub: the API the tests are written against; implemented next.

const dashboardPeriods = ['Today', 'This Week', 'This Month', 'This Year'];

String dashboardPeriodLabel(AppLocalizations l, String period) => throw UnimplementedError();

enum DashboardLoad { periodTotals, previousPeriod, previousSnapshot, todayGlance, chart, recentActivity }

enum DashboardMoment { coldOpen, periodChanged, returnToHome, allDetailsOpened }

Set<DashboardLoad> dashboardLoadsFor(DashboardMoment moment, {required bool phone}) => throw UnimplementedError();

class PhoneHomeFigures {
  final double sales;
  final double collected;
  final double owed;
  final double netProfit;
  final bool loading;

  const PhoneHomeFigures(
      {required this.sales, required this.collected, required this.owed, required this.netProfit, this.loading = false});

  factory PhoneHomeFigures.from(DashboardPeriodTotals totals, {required double owed, bool loading = false}) =>
      throw UnimplementedError();
}
