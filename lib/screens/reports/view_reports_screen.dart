import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../services/auth_service.dart';
import '../../services/daily_report_pdf_service.dart';
import '../../services/daily_report_service.dart';
import '../../utils/activity_logger.dart';
import '../../utils/web_download.dart';
import 'past_reports_screen.dart';
import 'report_full_view_screen.dart';
import 'report_review_screen.dart';
import 'report_tabbed_content.dart';

/// The main View Reports screen - shows today's own report directly,
/// matching the Daily Closing Report mockup, rather than a separate
/// list-and-generate screen. Generating and viewing history both move
/// out to their own places: Generate lives in the AppBar, and past
/// reports get their own screen reached via the "Past Reports" button.
class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({super.key});

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color offWhite = Color(0xFFFDFDF9);

  final DailyReportService _reportService = DailyReportService();
  final AuthService _authService = AuthService();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();

  bool _isLoading = true;
  bool _isGenerating = false;
  DailyReport? _todaysReport;

  Timer? _closingTimer;
  DateTime? _scheduledClosingTime;

  @override
  void initState() {
    super.initState();
    _loadTodaysReport();
  }

  @override
  void dispose() {
    _closingTimer?.cancel();
    super.dispose();
  }

  // Schedules a single timer to fire at the exact moment business
  // hours' configured closing time arrives, so the button flips from
  // disabled to enabled on its own without needing the person to
  // leave and reopen the screen. Not a ticking countdown - just one
  // precise wake-up call. Guarded against re-scheduling on every
  // rebuild by only acting when the actual closing time value changes.
  void _scheduleClosingTimerIfNeeded(DateTime? closingTime) {
    if (closingTime == _scheduledClosingTime) return;
    _closingTimer?.cancel();
    _scheduledClosingTime = closingTime;
    if (closingTime == null) return;
    final duration = closingTime.difference(DateTime.now());
    if (duration.isNegative) return;
    _closingTimer = Timer(duration, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadTodaysReport() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final todaysReport = await _reportService.getTodaysReport(facilityId);
      if (!mounted) return;
      setState(() {
        _todaysReport = todaysReport;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _fetchCurrentUserFullName() async {
    final user = _authService.getCurrentUser();
    if (user == null) return 'Unknown User';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    return (data?['fullName'] as String?) ?? 'Unknown User';
  }

  Future<void> _generateReport() async {
    if (_isGenerating) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isGenerating = true);
    try {
      final userName = await _fetchCurrentUserFullName();
      await _reportService.generateDraftReport(facilityId: facilityId, generatedByName: userName);
      if (!mounted) return;
      // Stays on this same screen, now showing the fresh draft's
      // figures directly - Review & Submit is a separate step,
      // reached from the "Continue Closing" action once ready.
      await _loadTodaysReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _continueClosing() async {
    if (_todaysReport == null) return;
    await showReportReviewScreen(context, _todaysReport!);
    _loadTodaysReport();
  }

  Future<void> _deleteDraft() async {
    if (_todaysReport == null) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: const SizedBox(
          width: 340,
          child: Text(
            "This clears today's draft report so it can be regenerated from scratch. "
            "It doesn't affect any of the underlying sales, services, or transactions - "
            'only this working snapshot.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Draft', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _reportService.deleteDraftReport(facilityId: facilityId, reportId: _todaysReport!.id);
      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Report Draft Deleted',
        description: 'Draft report for ${DateFormat('d MMM yyyy').format(_todaysReport!.reportDate)} deleted',
      );
      if (!mounted) return;
      _loadTodaysReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete draft: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printOrDownloadPdf() async {
    if (_todaysReport == null) return;
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final rawName = facilityProvider.selectedFacilityName ?? 'VetBiz Pro Facility';
    final facilityType = facilityProvider.selectedFacilityType;
    final facilityName = (facilityType != null && facilityType.isNotEmpty) ? '$rawName $facilityType' : rawName;
    await DailyReportPdfService.printOrDownload(_todaysReport!, facilityName: facilityName);
  }

  Future<void> _shareWithAdmin() async {
    if (_todaysReport == null) return;
    Uint8List? bytes;
    try {
      final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
      final rawName = facilityProvider.selectedFacilityName ?? 'VetBiz Pro Facility';
      final facilityType = facilityProvider.selectedFacilityType;
      final facilityName = (facilityType != null && facilityType.isNotEmpty) ? '$rawName $facilityType' : rawName;

      final doc = await DailyReportPdfService.build(_todaysReport!, facilityName: facilityName);
      bytes = await doc.save();

      final xfile = XFile.fromData(
        bytes,
        name: 'daily-closing-report-${_todaysReport!.id}.pdf',
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles([xfile], text: 'Daily Closing Report');
    } catch (e) {
      if (!mounted) return;
      // Same known limitation as elsewhere in this app: desktop
      // browsers' Web Share API is unreliable specifically for files,
      // even though the API itself exists - fall back to a direct
      // download there rather than showing a scary error.
      if (kIsWeb && bytes != null) {
        downloadFileWeb(bytes, 'daily-closing-report-${_todaysReport!.id}.pdf', mimeType: 'application/pdf');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share report: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final isAllowedNow = facilityProvider.isReportGenerationAllowedNow();
    final closingTime = facilityProvider.todaysClosingTime();
    _scheduleClosingTimerIfNeeded(closingTime);

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
            Text('View Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text('Daily closing report for this facility',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildAppBarAction(isAllowedNow, closingTime, facilityProvider.isClosedAllDayToday),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _todaysReport == null
              ? _buildEmptyState(isAllowedNow, closingTime, facilityProvider.isClosedAllDayToday)
              : _buildReportBody(),
    );
  }

  Widget _buildAppBarAction(bool isAllowedNow, DateTime? closingTime, bool isClosedAllDayToday) {
    final status = _todaysReport?.status;

    if (status == 'submitted') {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text("Today's Report - Submitted"),
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: primaryDeepGreen,
          side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4)),
        ),
      );
    }
    if (status == 'draft') {
      return ElevatedButton.icon(
        onPressed: _continueClosing,
        icon: const Icon(Icons.edit_note_outlined, size: 16),
        label: const Text('Continue Closing'),
        style: ElevatedButton.styleFrom(backgroundColor: primaryDeepGreen, foregroundColor: Colors.white),
      );
    }
    return ElevatedButton.icon(
      onPressed: _isGenerating || !isAllowedNow ? null : _generateReport,
      icon: _isGenerating
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.summarize_outlined, size: 16),
      label: Text(isAllowedNow
          ? "Generate Today's Report"
          : isClosedAllDayToday
              ? "Generate Today's Report (closed today)"
              : closingTime != null
                  ? "Generate Today's Report (at ${DateFormat('h:mm a').format(closingTime).toLowerCase().replaceAll(' ', '')})"
                  : "Generate Today's Report (after closing time)"),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDeepGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildEmptyState(bool isAllowedNow, DateTime? closingTime, bool isClosedAllDayToday) {
    String message;
    if (isAllowedNow) {
      message = "Tap \"Generate Today's Report\" above to get started.";
    } else if (isClosedAllDayToday) {
      message = 'This facility is marked closed today.';
    } else if (closingTime != null) {
      final formatted = DateFormat('h:mm a').format(closingTime).toLowerCase().replaceAll(' ', '');
      message = 'Available at $formatted.';
    } else {
      message = "Available once today's closing time is reached.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.summarize_outlined, size: 48, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text('No report generated yet today',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PastReportsScreen())),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Past Reports'),
              style: OutlinedButton.styleFrom(foregroundColor: primaryDeepGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBody() {
    final report = _todaysReport!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: primaryDeepGreen),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Daily Closing Report - Today's Report",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen)),
                          Text(DateFormat('EEEE, d MMM yyyy').format(report.reportDate),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PastReportsScreen())),
                    icon: const Icon(Icons.history, size: 15),
                    label: const Text('Past Reports'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryDeepGreen,
                      side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.35)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: ReportTabbedContent(report: report)),
          ],
        );

        final rightColumnScrollable = SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActionsCard(),
              const SizedBox(height: 16),
              _buildAccountabilityCard(report),
              const SizedBox(height: 16),
              _buildDeclarationCard(report),
            ],
          ),
        );

        final rightColumnFilled = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActionsCard(),
              const SizedBox(height: 16),
              _buildAccountabilityCard(report),
              const SizedBox(height: 16),
              Expanded(child: _buildDeclarationCard(report)),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: leftColumn),
              SizedBox(width: 320, child: rightColumnFilled),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 500, child: leftColumn),
              rightColumnScrollable,
            ],
          ),
        );
      },
    );
  }

  Widget _panelCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _panelHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 17, color: primaryDeepGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryDeepGreen)),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    final isDraft = _todaysReport?.status == 'draft';

    return _panelCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(Icons.flash_on_outlined, 'Quick Actions'),
          const SizedBox(height: 10),
          _quickActionTile(
            icon: Icons.visibility_outlined,
            title: 'View Full Report',
            subtitle: 'See all sections in detail',
            onTap: () => showReportFullViewScreen(context, _todaysReport!),
          ),
          const Divider(height: 18),
          _quickActionTile(
            icon: Icons.download_outlined,
            title: 'Download PDF',
            subtitle: 'Get a printable report',
            onTap: _printOrDownloadPdf,
          ),
          if (isAdmin && isDraft) ...[
            const Divider(height: 18),
            _quickActionTile(
              icon: Icons.delete_outline,
              title: 'Delete Draft',
              subtitle: 'Clear today\'s draft to restart',
              iconColor: Colors.red,
              onTap: _deleteDraft,
            ),
          ] else if (!isAdmin) ...[
            const Divider(height: 18),
            _quickActionTile(
              icon: Icons.send_outlined,
              title: 'Share with Admin',
              subtitle: 'Send report to your admin',
              onTap: _shareWithAdmin,
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickActionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? iconColor}) {
    final color = iconColor ?? primaryDeepGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountabilityCard(DailyReport report) {
    final isSubmitted = report.status == 'submitted';
    return _panelCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(Icons.verified_user_outlined, 'Accountability'),
          const SizedBox(height: 10),
          _accountabilityRow(Icons.person_outline, 'Submitted by', report.generatedByName),
          const SizedBox(height: 10),
          _accountabilityRow(
            Icons.calendar_today_outlined,
            'Date & Time',
            DateFormat('d MMM yyyy, h:mm a').format(report.submittedAt ?? report.generatedAt),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.circle, size: 8, color: isSubmitted ? Colors.green : Colors.orange),
              const SizedBox(width: 10),
              Text(isSubmitted ? 'Submitted' : 'Draft - not yet submitted',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSubmitted ? Colors.green[700] : Colors.orange[800])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountabilityRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeclarationCard(DailyReport report) {
    final isSubmitted = report.status == 'submitted';
    return _panelCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(Icons.fact_check_outlined, 'Daily Closing Declaration'),
          const SizedBox(height: 10),
          if (isSubmitted)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Confirmed - I have reviewed today's transactions and that the cash and stock figures "
                    'entered represent the closing figures for my shift.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                ),
              ],
            )
          else
            Text(
              'This declaration is confirmed as part of Submit Daily Closing, once physical stock and cash counts have been entered.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The report will be saved in the system and available for you and the admin '
                    'to view or download at any time.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
