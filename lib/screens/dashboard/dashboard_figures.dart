import 'package:intl/intl.dart';

import '../../config/app_date_format.dart';
import '../../config/app_ranges.dart';
import '../../l10n/l10n.dart';
import '../../services/dashboard_summary_service.dart';

/// The dashboard's period choices. Stored and compared in English (the
/// dashboard's selectedFilter); only [dashboardPeriodLabel] is shown.
const dashboardPeriods = ['Today', 'This Week', 'This Month', 'This Year'];

String dashboardPeriodLabel(AppLocalizations l, String period) => switch (period) {
      'This Week' => l.payments_thisWeek,
      'This Month' => l.payments_thisMonth,
      'This Year' => l.export_thisYear,
      _ => l.common_today,
    };

/// UI5: the (start, end) the dashboard watches its period totals over, the
/// one place it is worked out: the Today card's label shows this same range.
/// Monday starts the week; an unknown period is Today.
(DateTime, DateTime) dashboardPeriodRange(String period, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  return switch (period) {
    'This Week' => (today.subtract(AppRanges.day * (at.weekday - 1)), at),
    'This Month' => (DateTime(at.year, at.month, 1), at),
    'This Year' => (DateTime(at.year, 1, 1), at),
    _ => (today, at),
  };
}

/// UI5: [range] as the Today card's short label in [locale]: Today the day
/// ("Mon 9 Nov"), This Week the days ("3–9 Nov", "30 Nov–2 Dec", "28 Dec
/// 2026–1 Jan 2027"; its Monday alone "9 Nov"), This Month the month ("Nov
/// 2026"), This Year the year ("2026").
String dashboardPeriodRangeLabel(AppLocalizations l, String period, (DateTime, DateTime) range,
    {required String locale}) {
  final (start, end) = range;
  String format(String pattern, DateTime d) => DateFormat(pattern, locale).format(d);
  switch (period) {
    case 'This Week':
      if (start.year != end.year) {
        return l.home_periodRange(
            format(AppDateFormat.dateNoPadYPattern, start), format(AppDateFormat.dateNoPadYPattern, end));
      }
      final last = format(AppDateFormat.dateShortPattern, end);
      if (start.month != end.month) return l.home_periodRange(format(AppDateFormat.dateShortPattern, start), last);
      if (start.day != end.day) return l.home_periodRange(format(AppDateFormat.dayPattern, start), last);
      return last;
    case 'This Month':
      return format(AppDateFormat.monthYearShortPattern, start);
    case 'This Year':
      return format(AppDateFormat.yearPattern, start);
    default:
      return format(AppDateFormat.weekdayDayMonthShortPattern, start);
  }
}

/// PH4: what the dashboard loads at each moment. Tablets and computers keep
/// today's loads; on a phone, Home shows only the live period totals and the
/// app-level providers, and the rest loads when All details opens
/// (phone_shell.md section 2).
enum DashboardLoad { periodTotals, previousPeriod, previousSnapshot, todayGlance, chart, recentActivity }

enum DashboardMoment { coldOpen, periodChanged, returnToHome, allDetailsOpened }

Set<DashboardLoad> dashboardLoadsFor(DashboardMoment moment, {required bool phone}) {
  const refresh = {
    DashboardLoad.periodTotals,
    DashboardLoad.previousPeriod,
    DashboardLoad.previousSnapshot,
    DashboardLoad.todayGlance,
    DashboardLoad.chart,
  };
  if (!phone) {
    return switch (moment) {
      // The Recent Activity feed's stream is cached: made once, on the first open.
      DashboardMoment.coldOpen => {...refresh, DashboardLoad.recentActivity},
      DashboardMoment.periodChanged || DashboardMoment.returnToHome => refresh,
      DashboardMoment.allDetailsOpened => const {},
    };
  }
  return switch (moment) {
    DashboardMoment.coldOpen || DashboardMoment.periodChanged => const {DashboardLoad.periodTotals},
    // The period totals are live: nothing to fetch again.
    DashboardMoment.returnToHome => const {},
    DashboardMoment.allDetailsOpened => const {DashboardLoad.chart, DashboardLoad.recentActivity},
  };
}

/// The Today card's figures, as the old cards show them: Sales, Collected
/// and Net profit from the period totals, Owed from DebtProvider's
/// totalOutstanding (everything owed now, the Outstanding Payment card).
/// HUB2: with Vet services chosen, the period's service revenue and visits
/// (totalServiceRevenue, completedServicesCount: the same totals, no read).
class PhoneHomeFigures {
  final double sales;
  final double collected;
  final double owed;
  final double netProfit;
  final double serviceRevenue;
  final int visits;
  final bool loading;

  const PhoneHomeFigures({
    required this.sales,
    required this.collected,
    required this.owed,
    required this.netProfit,
    this.serviceRevenue = 0,
    this.visits = 0,
    this.loading = false,
  });

  factory PhoneHomeFigures.from(DashboardPeriodTotals totals, {required double owed, bool loading = false}) =>
      PhoneHomeFigures(
        sales: totals.totalSales,
        collected: totals.totalCollected,
        owed: owed,
        netProfit: totals.netProfit,
        serviceRevenue: totals.totalServiceRevenue,
        visits: totals.completedServicesCount,
        loading: loading,
      );
}


/// The eight dashboard figures, in the grid's order (the tablet and computer
/// cards; on a phone, the rows of All details).
enum DashboardFigure { productValue, sales, collected, netProfit, expenses, outstanding, clients, services }

/// PH4b: the figures a role is shown, on the grid and in All details alike.
/// Total Expenses is for admins only: with Sales and Collected it would let
/// an assistant work out the Net Profit that is masked for them. A display
/// rule only: the summaries stay readable by members under firestore.rules.
List<DashboardFigure> dashboardFiguresFor({required bool isAdmin}) => [
      for (final f in DashboardFigure.values)
        if (isAdmin || f != DashboardFigure.expenses) f,
    ];

/// Whether [isAdmin]'s grid card or All details row for [figure] is drawn.
bool dashboardShowsFigure(DashboardFigure figure, {required bool isAdmin}) =>
    dashboardFiguresFor(isAdmin: isAdmin).contains(figure);
