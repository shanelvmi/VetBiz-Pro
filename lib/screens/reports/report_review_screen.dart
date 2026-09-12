import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_service.dart';
import '../../utils/thousands_input_formatter.dart';

class ReportReviewScreen extends StatefulWidget {
  final DailyReport report;
  final bool isModal;

  const ReportReviewScreen({super.key, required this.report, this.isModal = false});

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);
  static const Color offWhite = Color(0xFFFDFDF9);

  final DailyReportService _reportService = DailyReportService();
  final NumberFormat _moneyFormat = NumberFormat.decimalPattern();
  final _formatter = NumberFormat.decimalPattern();

  late List<ProductMovementEntry> _watchlisted;
  final Map<String, TextEditingController> _physicalCountControllers = {};
  final Map<String, TextEditingController> _varianceReasonControllers = {};

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _cashVarianceReasonController = TextEditingController();

  bool _declarationConfirmed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _watchlisted = widget.report.productMovement.where((p) => p.isWatchlisted).toList();
    for (final p in _watchlisted) {
      _physicalCountControllers[p.productId] =
          TextEditingController(text: p.physicalCount?.toString() ?? '');
      _varianceReasonControllers[p.productId] = TextEditingController(text: p.varianceReason ?? '');
    }
    if (widget.report.physicalCashCounted != null) {
      _cashController.text = _formatter.format(widget.report.physicalCashCounted!.round());
    }
    _cashVarianceReasonController.text = widget.report.cashVarianceReason ?? '';
  }

  @override
  void dispose() {
    for (final c in _physicalCountControllers.values) {
      c.dispose();
    }
    for (final c in _varianceReasonControllers.values) {
      c.dispose();
    }
    _cashController.dispose();
    _cashVarianceReasonController.dispose();
    super.dispose();
  }

  double? get _physicalCash {
    final raw = _cashController.text.replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double? get _cashVariance {
    final cash = _physicalCash;
    if (cash == null) return null;
    return cash - widget.report.expectedCashInDrawer;
  }

  bool get _missingCashReason {
    final variance = _cashVariance;
    return variance != null && variance != 0 && _cashVarianceReasonController.text.trim().isEmpty;
  }

  bool _isMissingStockReason(ProductMovementEntry p) {
    final count = _physicalCountFor(p.productId);
    if (count == null) return false;
    final variance = count - p.expectedClosing;
    final reason = _varianceReasonControllers[p.productId]?.text.trim() ?? '';
    return variance != 0 && reason.isEmpty;
  }

  bool get _anyMissingStockReasons => _watchlisted.any(_isMissingStockReason);

  int? _physicalCountFor(String productId) {
    final raw = _physicalCountControllers[productId]?.text ?? '';
    return int.tryParse(raw);
  }

  bool get _allWatchlistedCounted =>
      _watchlisted.every((p) => _physicalCountFor(p.productId) != null);

  bool get _canSubmit =>
      !_isSubmitting &&
      _allWatchlistedCounted &&
      _physicalCash != null &&
      _declarationConfirmed &&
      !_missingCashReason &&
      !_anyMissingStockReasons;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final updatedMovement = widget.report.productMovement.map((p) {
        if (!p.isWatchlisted) return p;
        final count = _physicalCountFor(p.productId);
        final reasonText = _varianceReasonControllers[p.productId]?.text.trim();
        return p.copyWith(
          physicalCount: count,
          varianceReason: (reasonText != null && reasonText.isNotEmpty) ? reasonText : null,
        );
      }).toList();

      final cashReason = _cashVarianceReasonController.text.trim();

      final submitted = await _reportService.submitReport(
        facilityId: facilityId,
        reportId: widget.report.id,
        productMovement: updatedMovement,
        physicalCashCounted: _physicalCash!,
        cashVarianceReason: cashReason.isEmpty ? null : cashReason,
        declarationConfirmed: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(submitted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Review & Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            Text(DateFormat('EEEE, d MMM yyyy').format(widget.report.reportDate),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildIntroCard(),
              const SizedBox(height: 16),
              if (_watchlisted.isNotEmpty) ...[
                _buildStockCountCard(),
                const SizedBox(height: 16),
              ],
              _buildCashCard(),
              const SizedBox(height: 16),
              _buildDeclarationCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _card(Widget child) {
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

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDeepGreen),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDeepGreen)),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryDeepGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryDeepGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: primaryDeepGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sales, services, transactions, and debt activity have already been calculated automatically. '
              'Count the items below and enter what you actually find before submitting.',
              style: TextStyle(fontSize: 12.5, color: primaryDeepGreen.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCountCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.inventory_2_outlined, 'Physical Stock Count'),
          const SizedBox(height: 4),
          Text('Watch-listed products only - count these before submitting.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          for (final p in _watchlisted) _buildProductCountRow(p),
        ],
      ),
    );
  }

  Widget _buildProductCountRow(ProductMovementEntry p) {
    final count = _physicalCountFor(p.productId);
    final variance = count == null ? null : count - p.expectedClosing;
    final hasVariance = variance != null && variance != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasVariance ? Colors.red.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasVariance ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              Text('Expected: ${p.expectedClosing}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _physicalCountControllers[p.productId],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Physical count',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (hasVariance) ...[
                const SizedBox(width: 12),
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[700]),
                const SizedBox(width: 4),
                Text('${variance > 0 ? '+' : ''}$variance variance',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[700])),
              ] else if (count != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text('Match', style: TextStyle(fontSize: 12, color: Colors.green[700])),
              ],
            ],
          ),
          if (hasVariance) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _varianceReasonControllers[p.productId],
              decoration: InputDecoration(
                hintText: 'Reason for variance (e.g. damaged, unable to locate)',
                errorText: _isMissingStockReason(p) ? 'Please provide a reason for the variance.' : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCashCard() {
    final variance = _cashVariance;
    final hasVariance = variance != null && variance != 0;

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.payments_outlined, 'Cash Reconciliation'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected cash in drawer', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text('Tsh ${_moneyFormat.format(widget.report.expectedCashInDrawer)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Physical cash counted *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(
              hintText: '0',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (hasVariance) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[700]),
                const SizedBox(width: 4),
                Text('Cash variance: ${variance > 0 ? '+' : ''}Tsh ${_moneyFormat.format(variance)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red[700])),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cashVarianceReasonController,
              decoration: InputDecoration(
                hintText: 'Reason for cash variance',
                errorText: _missingCashReason ? 'Please provide a reason for the variance.' : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else if (_physicalCash != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text('Cash matches', style: TextStyle(fontSize: 12.5, color: Colors.green[700])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeclarationCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.verified_outlined, 'Daily Closing Declaration'),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _declarationConfirmed = !_declarationConfirmed),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _declarationConfirmed,
                  activeColor: primaryDeepGreen,
                  onChanged: (v) => setState(() => _declarationConfirmed = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "I confirm that I have reviewed today's transactions and that the cash and stock figures "
                      'entered above represent the closing figures for my shift.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    String? blockedReason;
    if (!_allWatchlistedCounted) {
      blockedReason = 'Enter a physical count for every watch-listed product';
    } else if (_physicalCash == null) {
      blockedReason = 'Enter the physical cash counted';
    } else if (_anyMissingStockReasons || _missingCashReason) {
      blockedReason = 'Please provide a reason for the variance found';
    } else if (!_declarationConfirmed) {
      blockedReason = 'Confirm the closing declaration to submit';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          if (blockedReason != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Text(blockedReason,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
              ),
            ),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDeepGreen,
              foregroundColor: offWhite,
              disabledBackgroundColor: primaryDeepGreen.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 16),
                      SizedBox(width: 8),
                      Text('Submit Daily Closing'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Opens Review & Submit as a modal, matching the convention already
/// established by showAddSaleScreen/showReportFullViewScreen - a
/// centered dialog on wide screens, a full-screen push on narrow ones.
Future<DailyReport?> showReportReviewScreen(BuildContext context, DailyReport report) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    return Navigator.of(context).push<DailyReport>(
      MaterialPageRoute(builder: (_) => ReportReviewScreen(report: report, isModal: false)),
    );
  }

  return showGeneralDialog<DailyReport>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Review & Submit',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.72).clamp(0, 900).toDouble();
      final modalHeight = (screenSize.height * 0.9) < 480 ? 480.0 : screenSize.height * 0.9;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              child: ReportReviewScreen(report: report, isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
