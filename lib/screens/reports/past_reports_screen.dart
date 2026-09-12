import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_service.dart';
import 'report_detail_screen.dart';
import 'report_review_screen.dart';

class PastReportsScreen extends StatefulWidget {
  const PastReportsScreen({super.key});

  @override
  State<PastReportsScreen> createState() => _PastReportsScreenState();
}

enum _TimeFilter { allTime, last7Days, thisMonth, thisYear }

extension on _TimeFilter {
  String get label {
    switch (this) {
      case _TimeFilter.allTime:
        return 'All time';
      case _TimeFilter.last7Days:
        return 'Last 7 days';
      case _TimeFilter.thisMonth:
        return 'This month';
      case _TimeFilter.thisYear:
        return 'This year';
    }
  }

  DateTime? cutoff(DateTime now) {
    switch (this) {
      case _TimeFilter.allTime:
        return null;
      case _TimeFilter.last7Days:
        return now.subtract(const Duration(days: 7));
      case _TimeFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _TimeFilter.thisYear:
        return DateTime(now.year, 1, 1);
    }
  }
}

class _PastReportsScreenState extends State<PastReportsScreen> {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color offWhite = Color(0xFFFDFDF9);
  static const int _pageSize = 25;

  final DailyReportService _reportService = DailyReportService();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<DailyReport> _reports = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  int _totalCount = 0;
  String _searchQuery = '';
  _TimeFilter _timeFilter = _TimeFilter.allTime;

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
      if (mounted) setState(() => _isLoading = false);
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
      final dateText = DateFormat('EEEE, d MMM yyyy').format(r.reportDate).toLowerCase();
      return dateText.contains(_searchQuery) || r.generatedByName.toLowerCase().contains(_searchQuery);
    }).toList();
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
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Past Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text('Every daily closing report for this facility',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _searchAndFilterRow(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _summaryRow(),
                ),
                Expanded(
                  child: _filteredReports.isEmpty
                      ? Center(
                          child: Text(
                            _reports.isEmpty ? 'No reports generated yet.' : 'No reports match your search.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(foregroundColor: primaryDeepGreen),
                child: const Text('Load more'),
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
              hintText: 'Search reports...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_TimeFilter>(
              value: _timeFilter,
              icon: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.expand_more, size: 18)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              items: _TimeFilter.values
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 15, color: primaryDeepGreen),
                            const SizedBox(width: 8),
                            Text(f.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _summaryRow() {
    String periodLabel;
    if (_reports.isEmpty) {
      periodLabel = '-';
    } else {
      final dates = _reports.map((r) => r.reportDate).toList()..sort();
      final earliest = dates.first;
      final latest = dates.last;
      periodLabel = (earliest.year == latest.year && earliest.month == latest.month)
          ? DateFormat('MMMM yyyy').format(earliest)
          : '${DateFormat('MMM yyyy').format(earliest)} - ${DateFormat('MMM yyyy').format(latest)}';
    }
    final latestDate = _reports.isEmpty ? null : (_reports.map((r) => r.reportDate).toList()..sort()).last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primaryDeepGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryStat(Icons.assignment_outlined, '$_totalCount', 'Reports generated')),
          _summaryDivider(),
          Expanded(child: _summaryStat(Icons.event_note_outlined, periodLabel, 'Loaded period')),
          _summaryDivider(),
          Expanded(
            child: _summaryStat(
              Icons.access_time,
              latestDate == null ? '-' : DateFormat('d MMM yyyy').format(latestDate),
              'Latest',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(width: 1, height: 34, color: Colors.grey.withValues(alpha: 0.25));

  Widget _summaryStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primaryDeepGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: primaryDeepGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (isDraft) {
            await showReportReviewScreen(context, report);
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)));
          }
          _loadInitialPage();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDraft ? Colors.orange.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryDeepGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined, color: primaryDeepGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMM yyyy').format(report.reportDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('Tsh ${_moneyFormat.format(revenue)} total revenue - generated by ${report.generatedByName}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDraft)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Not submitted',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 13, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text('Completed', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.green[700])),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
