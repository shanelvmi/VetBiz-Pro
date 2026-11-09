import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_service.dart';
import 'report_detail_screen.dart';
import 'report_review_screen.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_layout.dart';
import '../../widgets/phone_list/phone_list_scaffold.dart';
import '../../widgets/phone_list/phone_quick_chips.dart';
import '../../widgets/phone_list/phone_summary_sheet.dart';
import '../../widgets/phone_list/record_tile.dart';

class PastReportsScreen extends StatefulWidget {
  /// Null: the app's own Firestore. Tests pass an in-memory one (PH2a).
  final FirebaseFirestore? firestore;

  const PastReportsScreen({super.key, this.firestore});

  @override
  State<PastReportsScreen> createState() => _PastReportsScreenState();
}

enum _TimeFilter { allTime, last7Days, thisMonth, thisYear }

extension on _TimeFilter {
  String label(AppLocalizations l10n) {
    switch (this) {
      case _TimeFilter.allTime:
        return l10n.clients_allTime;
      case _TimeFilter.last7Days:
        return l10n.services_last7;
      case _TimeFilter.thisMonth:
        return l10n.services_thisMonth;
      case _TimeFilter.thisYear:
        return l10n.reports_thisYear;
    }
  }

  DateTime? cutoff(DateTime now) {
    switch (this) {
      case _TimeFilter.allTime:
        return null;
      case _TimeFilter.last7Days:
        return now.subtract(AppRanges.week);
      case _TimeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _TimeFilter.thisYear:
        return DateTime(now.year, 1, 1);
    }
  }
}

class _PastReportsScreenState extends State<PastReportsScreen> {
  static const int _pageSize = AppLimits.pageSize;

  late final DailyReportService _reportService = DailyReportService(firestore: widget.firestore);
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<DailyReport> _reports = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  int _totalCount = 0;
  String _searchQuery = '';
  _TimeFilter _timeFilter = _TimeFilter.allTime;

  // PH7b: why the first page failed; a phone shows it with Retry (wider
  // windows keep showing the empty list, as before).
  Object? _loadError;

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialPage();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPage() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
      _reports = [];
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final cutoff = _timeFilter.cutoff(DateTime.now());
      final pageFuture = _reportService.getReportsPage(
        facilityId: facilityId,
        limit: _pageSize,
        dateCutoff: cutoff,
        excludeOnOrAfter: _todayStart,
      );
      final countFuture =
          _reportService.getReportsCount(facilityId: facilityId, dateCutoff: cutoff, excludeOnOrAfter: _todayStart);
      final page = await pageFuture;
      final count = await countFuture;
      if (!mounted) return;
      setState(() {
        _reports = page.reports;
        _lastDoc = page.lastDoc;
        _hasMore = page.reports.length == _pageSize;
        _totalCount = count;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final cutoff = _timeFilter.cutoff(DateTime.now());
      final page = await _reportService.getReportsPage(
        facilityId: facilityId,
        limit: _pageSize,
        startAfter: _lastDoc,
        dateCutoff: cutoff,
        excludeOnOrAfter: _todayStart,
      );
      if (!mounted) return;
      setState(() {
        _reports = [..._reports, ...page.reports];
        _lastDoc = page.lastDoc;
        _hasMore = page.reports.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more reports: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // Search only ever filters what's currently loaded, not the
  // facility's whole history - Firestore has no built-in free-text
  // search, so a search term that matches an older, not-yet-loaded
  // report won't surface until that page has been loaded (e.g. via
  // Load More, or a narrower time filter that brings it within reach).
  List<DailyReport> get _filteredReports {
    if (_searchQuery.isEmpty) return _reports;
    return _reports.where((r) {
      final dateText = AppDateFormat.dateLong.format(r.reportDate).toLowerCase();
      return dateText.contains(_searchQuery) || r.generatedByName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  /// A report opens Review while a draft, its detail once submitted; the
  /// list reloads after.
  Future<void> _openReport(DailyReport report) async {
    if (report.status == 'draft') {
      await showReportReviewScreen(context, report, firestore: widget.firestore);
    } else {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report, firestore: widget.firestore)));
    }
    _loadInitialPage();
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isPhone(context)) return _buildPhone();
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
            Text(context.l10n.reports_pastTitle, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
            Text(context.l10n.reports_pastSubtitle,
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
                  child: _searchAndFilterRow(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
                  child: _summaryRow(),
                ),
                Expanded(
                  child: _filteredReports.isEmpty
                      ? Center(
                          child: Text(
                            _reports.isEmpty ? context.l10n.reports_noneYet : context.l10n.reports_noMatch,
                            style: TextStyle(color: context.colors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          itemCount: _filteredReports.length + (_searchQuery.isEmpty && _hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _filteredReports.length) {
                              return _loadMoreButton();
                            }
                            return _buildReportRow(_filteredReports[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _loadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(width: AppSpacing.s22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
                child: Text(context.l10n.reports_loadMore),
              ),
      ),
    );
  }

  Widget _searchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.reports_searchHint,
              prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
              filled: true,
              fillColor: context.colors.surface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_TimeFilter>(
              value: _timeFilter,
              icon: const Padding(padding: EdgeInsets.only(right: AppSpacing.s8), child: Icon(Icons.expand_more, size: AppIconSize.i18)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              items: _TimeFilter.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: AppIconSize.i16, color: context.colors.primary),
                            const SizedBox(width: AppSpacing.s8),
                            Text(f.label(context.l10n), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (f) {
                if (f == null || f == _timeFilter) return;
                setState(() => _timeFilter = f);
                _loadInitialPage();
              },
            ),
          ),
        ),
      ],
    );
  }

  /// The loaded period and the latest report's date (the summary row, and
  /// on a phone the Summary sheet).
  ({String period, String latest}) _summaryFigures() {
    String periodLabel;
    if (_reports.isEmpty) {
      periodLabel = '-';
    } else {
      final dates = _reports.map((r) => r.reportDate).toList()..sort();
      final earliest = dates.first;
      final latest = dates.last;
      periodLabel = (earliest.year == latest.year && earliest.month == latest.month)
          ? AppDateFormat.monthYear.format(earliest)
          : '${AppDateFormat.monthYearShort.format(earliest)} - ${AppDateFormat.monthYearShort.format(latest)}';
    }
    final latestDate = _reports.isEmpty ? null : (_reports.map((r) => r.reportDate).toList()..sort()).last;
    return (period: periodLabel, latest: latestDate == null ? '-' : AppDateFormat.dateNoPad.format(latestDate));
  }

  Widget _summaryRow() {
    final figures = _summaryFigures();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryStat(Icons.assignment_outlined, '$_totalCount', context.l10n.reports_generatedCount)),
          _summaryDivider(),
          Expanded(child: _summaryStat(Icons.event_note_outlined, figures.period, context.l10n.reports_loadedPeriod)),
          _summaryDivider(),
          Expanded(
            child: _summaryStat(
              Icons.access_time,
              figures.latest,
              context.l10n.reports_latest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(width: 1, height: 34, color: context.colors.textHint.withValues(alpha: AppAlpha.a30));

  Widget _summaryStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
          child: Icon(icon, size: AppIconSize.i16, color: context.colors.primary),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14), overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportRow(DailyReport report) {
    final revenue = report.salesTotalValue + report.servicesTotalValue;
    final isDraft = report.status == 'draft';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        onTap: () => _openReport(report),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r12),
            border: Border.all(color: isDraft ? context.colors.warning.withValues(alpha: AppAlpha.a40) : context.colors.textHint.withValues(alpha: AppAlpha.a20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Icon(Icons.description_outlined, color: context.colors.primary, size: AppIconSize.i20),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppDateFormat.dateLong.format(report.reportDate),
                        style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13_5)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(context.l10n.reports_rowSummary(Money.format(revenue), report.generatedByName),
                        style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              if (isDraft)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r20),
                  ),
                  child: Text(context.l10n.reports_notSubmitted,
                      style: TextStyle(fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold, color: context.colors.warningStrong)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: AppIconSize.i14, color: context.colors.successStrong),
                      const SizedBox(width: AppSpacing.s4),
                      Text(context.l10n.reports_completed, style: TextStyle(fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold, color: context.colors.successStrong)),
                    ],
                  ),
                ),
              const SizedBox(width: AppSpacing.s8),
              Icon(Icons.chevron_right, color: context.colors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Phone (PH7b R9, docs/design/phone_reports.md) ----------

  // The PH5a list: search in the bar (the same filter of the loaded
  // reports), the four time filters as quick chips (the same reload), the
  // summary line with the three old cards in its sheet, the reports under
  // month headers, the same taps, the skeleton, empty and error states,
  // and Load more. The same two queries as the layout above.
  Widget _buildPhone() {
    final l10n = context.l10n;
    final colors = context.colors;
    final figures = _summaryFigures();
    return PhoneListScaffold<DailyReport>(
      title: l10n.reports_pastTitle,
      menu: const [],
      searchController: _searchController,
      searchHint: l10n.reports_searchHint,
      // The controller's listener already filters.
      onSearchChanged: (_) {},
      onSearchClosed: _searchController.clear,
      quickChips: PhoneQuickChips(
        values: [for (final f in _TimeFilter.values) f.name],
        selected: _timeFilter.name,
        label: (v) => _TimeFilter.values.byName(v).label(l10n),
        onSelected: (v) {
          final f = _TimeFilter.values.byName(v);
          if (f == _timeFilter) return;
          setState(() => _timeFilter = f);
          _loadInitialPage();
        },
      ),
      filtersActive: false,
      onFilter: null,
      appliedFilters: const [],
      summaryLine: _isLoading || _loadError != null ? null : l10n.phoneReport_pastSummaryLine(_totalCount),
      onSummary: () => showPhoneSummarySheet(context, rows: [
        (l10n.reports_generatedCount, '$_totalCount'),
        (l10n.reports_loadedPeriod, figures.period),
        (l10n.reports_latest, figures.latest),
      ]),
      items: _filteredReports,
      idOf: (r) => r.id,
      dateOf: (r) => r.reportDate,
      amountOf: (r) => r.salesTotalValue + r.servicesTotalValue,
      grouped: true,
      byMonth: true,
      tileBuilder: (context, r, {required grouped}) {
        final isDraft = r.status == 'draft';
        final date = AppDateFormat.dateLong.format(r.reportDate);
        final amount = Money.format(r.salesTotalValue + r.servicesTotalValue);
        final status = RecordStatus(isDraft ? l10n.reports_notSubmitted : l10n.reports_completed,
            isDraft ? colors.warningStrong : colors.successStrong);
        return RecordTile(
          title: date,
          amount: amount,
          details: [r.generatedByName],
          status: status,
          icon: Icons.description_outlined,
          colorSeed: 'report',
          semanticsLabel: l10n.phoneList_rowSemantics(date, amount, status.label, r.generatedByName),
          onTap: () => _openReport(r),
        );
      },
      loading: _isLoading,
      error: _loadError,
      onRetry: _loadInitialPage,
      emptyIcon: Icons.description_outlined,
      emptyText: _reports.isEmpty ? l10n.reports_noneYet : l10n.reports_noMatch,
      hasMore: _searchQuery.isEmpty && _hasMore,
      loadingMore: _isLoadingMore,
      onLoadMore: _loadMore,
      onRefresh: _loadInitialPage,
    );
  }
}
