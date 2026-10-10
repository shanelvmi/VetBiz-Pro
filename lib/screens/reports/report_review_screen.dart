import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:provider/provider.dart';

import '../../models/daily_report.dart';
import '../../providers/facility_provider.dart';
import '../../services/daily_report_service.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/app_feedback.dart';

class ReportReviewScreen extends StatefulWidget {
  final DailyReport report;
  final bool isModal;

  const ReportReviewScreen({super.key, required this.report, this.isModal = false});

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {

  final DailyReportService _reportService = DailyReportService();

  late List<ProductMovementEntry> _watchlisted;
  final Map<String, TextEditingController> _physicalCountControllers = {};
  final Map<String, TextEditingController> _varianceReasonControllers = {};

  final Map<String, TextEditingController> _paymentCountControllers = {};
  final Map<String, TextEditingController> _paymentVarianceReasonControllers = {};

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
    for (final p in widget.report.paymentReconciliation) {
      _paymentCountControllers[p.method] =
          TextEditingController(text: p.physicalCount != null ? Money.decimal(p.physicalCount!.round()) : '');
      _paymentVarianceReasonControllers[p.method] = TextEditingController(text: p.varianceReason ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _physicalCountControllers.values) {
      c.dispose();
    }
    for (final c in _varianceReasonControllers.values) {
      c.dispose();
    }
    for (final c in _paymentCountControllers.values) {
      c.dispose();
    }
    for (final c in _paymentVarianceReasonControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _physicalCountForMethod(String method) {
    final raw = _paymentCountControllers[method]?.text.replaceAll(',', '') ?? '';
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double? _varianceForMethod(String method) {
    final count = _physicalCountForMethod(method);
    if (count == null) return null;
    final expected = widget.report.paymentReconciliation.firstWhere((p) => p.method == method).expected;
    return count - expected;
  }

  bool _isMissingPaymentReason(String method) {
    final variance = _varianceForMethod(method);
    if (variance == null) return false;
    final reason = _paymentVarianceReasonControllers[method]?.text.trim() ?? '';
    return variance != 0 && reason.isEmpty;
  }

  bool get _anyMissingPaymentReasons =>
      widget.report.paymentReconciliation.where((p) => p.requiresCount).any((p) => _isMissingPaymentReason(p.method));

  bool get _allPaymentMethodsCounted => widget.report.paymentReconciliation
      .where((p) => p.requiresCount)
      .every((p) => _physicalCountForMethod(p.method) != null);

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
      _allPaymentMethodsCounted &&
      _declarationConfirmed &&
      !_anyMissingPaymentReasons &&
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

      final updatedReconciliation = widget.report.paymentReconciliation.map((p) {
        final count = _physicalCountForMethod(p.method);
        final reasonText = _paymentVarianceReasonControllers[p.method]?.text.trim();
        return p.copyWith(
          physicalCount: count,
          varianceReason: (reasonText != null && reasonText.isNotEmpty) ? reasonText : null,
        );
      }).toList();

      final submitted = await _reportService.submitReport(
        facilityId: facilityId,
        reportId: widget.report.id,
        productMovement: updatedMovement,
        paymentReconciliation: updatedReconciliation,
        declarationConfirmed: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(submitted);
    } catch (e, st) {
      AppFeedback.error("Couldn't submit the report", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
            Text('Review & Submit', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18, color: context.colors.textPrimary)),
            Text(AppDateFormat.dateLong.format(widget.report.reportDate),
                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              _buildIntroCard(),
              const SizedBox(height: AppSpacing.s16),
              if (_watchlisted.isNotEmpty) ...[
                _buildStockCountCard(),
                const SizedBox(height: AppSpacing.s16),
              ],
              _buildPaymentReconciliationCard(),
              const SizedBox(height: AppSpacing.s16),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: context.colors.primary)),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: AppIconSize.i18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              'Sales, services, transactions, and debt activity have already been calculated automatically. '
              'Count the items below and enter what you actually find before submitting.',
              style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.primary.withValues(alpha: AppAlpha.a85)),
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
          const SizedBox(height: AppSpacing.s4),
          Text('Watch-listed products only - count these before submitting.',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.s12),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: hasVariance ? context.colors.danger.withValues(alpha: AppAlpha.a05) : context.colors.textHint.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: hasVariance ? context.colors.danger.withValues(alpha: AppAlpha.a30) : context.colors.textHint.withValues(alpha: AppAlpha.a20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13_5)),
              ),
              Text('Expected: ${p.expectedClosing}', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
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
                    fillColor: context.colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (hasVariance) ...[
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.warning_amber_rounded, size: AppIconSize.i16, color: context.colors.dangerStrong),
                const SizedBox(width: AppSpacing.s4),
                Text('${variance > 0 ? '+' : ''}$variance variance',
                    style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.dangerStrong)),
              ] else if (count != null) ...[
                const SizedBox(width: AppSpacing.s12),
                Icon(Icons.check_circle_outline, size: AppIconSize.i16, color: context.colors.success),
                const SizedBox(width: AppSpacing.s4),
                Text('Match', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.successStrong)),
              ],
            ],
          ),
          if (hasVariance) ...[
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _varianceReasonControllers[p.productId],
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [SentenceCapitalizationFormatter()],
              decoration: InputDecoration(
                hintText: 'Reason for variance (e.g. damaged, unable to locate)',
                errorText: _isMissingStockReason(p) ? 'Please provide a reason for the variance.' : null,
                isDense: true,
                filled: true,
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentReconciliationCard() {
    if (widget.report.paymentReconciliation.isEmpty) {
      return _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.payments_outlined, 'Payment Reconciliation'),
            const SizedBox(height: AppSpacing.s10),
            Text('No payments recorded today.', style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
          ],
        ),
      );
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.payments_outlined, 'Payment Reconciliation'),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Count what you actually have for each method used today - mobile money balance, bank balance, and cash in the drawer.',
            style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
          ),
          for (final p in widget.report.paymentReconciliation) ...[
            const SizedBox(height: AppSpacing.s16),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),
            _buildPaymentMethodBlock(p),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodBlock(PaymentMethodReconciliation p) {
    if (!p.requiresCount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.method, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
          const SizedBox(height: AppSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount paid out', style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
              Text(Money.symbolDecimal(p.expected.abs()),
                  style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Icon(Icons.info_outline, size: AppIconSize.i16, color: Colors.blueGrey[400]),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  'No income came in via ${p.method} today - just an outflow. No physical count needed here.',
                  style: TextStyle(fontSize: AppFontSize.f12, color: Colors.blueGrey[500]),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final variance = _varianceForMethod(p.method);
    final hasVariance = variance != null && variance != 0;
    final count = _physicalCountForMethod(p.method);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.method, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Expected balance', style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSoft)),
            Text(Money.symbolDecimal(p.expected),
                style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        const Text('Physical balance counted *', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
        const SizedBox(height: AppSpacing.s6),
        TextField(
          controller: _paymentCountControllers[p.method],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            hintText: '0',
            isDense: true,
            filled: true,
            fillColor: context.colors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r10),
              borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (hasVariance) ...[
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: AppIconSize.i16, color: context.colors.dangerStrong),
              const SizedBox(width: AppSpacing.s4),
              Text('${p.method} variance: ${variance > 0 ? '+' : ''}${Money.symbolDecimal(variance)}',
                  style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.dangerStrong)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _paymentVarianceReasonControllers[p.method],
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: InputDecoration(
              hintText: 'Reason for ${p.method} variance',
              errorText: _isMissingPaymentReason(p.method) ? 'Please provide a reason for the variance.' : null,
              isDense: true,
              filled: true,
              fillColor: context.colors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ] else if (count != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s10),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: AppIconSize.i16, color: context.colors.success),
                const SizedBox(width: AppSpacing.s4),
                Text('${p.method} matches', style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.successStrong)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeclarationCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.verified_outlined, 'Daily Closing Declaration'),
          const SizedBox(height: AppSpacing.s10),
          InkWell(
            onTap: () => setState(() => _declarationConfirmed = !_declarationConfirmed),
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _declarationConfirmed,
                  activeColor: context.colors.primary,
                  onChanged: (v) => setState(() => _declarationConfirmed = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s12),
                    child: Text(
                      "I confirm that I have reviewed today's transactions and that the cash and stock figures "
                      'entered above represent the closing figures for my shift.',
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textPrimary),
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
    } else if (!_allPaymentMethodsCounted) {
      blockedReason = 'Enter the physical balance for every payment method';
    } else if (_anyMissingStockReasons || _anyMissingPaymentReasons) {
      blockedReason = 'Please provide a reason for the variance found';
    } else if (!_declarationConfirmed) {
      blockedReason = 'Confirm the closing declaration to submit';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.s20, AppSpacing.s14, AppSpacing.s20, AppSpacing.s14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppIconSize.i16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a40)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          if (blockedReason != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s12, right: AppSpacing.s12),
                child: Text(blockedReason,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted)),
              ),
            ),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              disabledBackgroundColor: context.colors.primary.withValues(alpha: AppAlpha.a40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s22, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: AppIconSize.i16),
                      SizedBox(width: AppSpacing.s8),
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
  final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

  if (!isWideScreen) {
    return Navigator.of(context).push<DailyReport>(
      MaterialPageRoute(builder: (_) => ReportReviewScreen(report: report, isModal: false)),
    );
  }

  return showGeneralDialog<DailyReport>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Review & Submit',
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.72).clamp(0, 900).toDouble();
      final modalHeight = (screenSize.height * 0.9) < 480 ? 480.0 : screenSize.height * 0.9;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
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
