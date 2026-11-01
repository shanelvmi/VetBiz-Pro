import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/client.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../services/debtor_clients_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../utils/subscription_guard.dart';
import '../../widgets/app_sheet.dart';
import '../clients/add_client_screen.dart';
import '../debtors/add_payment_screen.dart';
import '../sales/add_sale_screen.dart';
import '../services/add_edit_service_screen.dart';

/// The locked-facility guard's shape (navigateOrShowLockedDialog).
typedef RecordGuard = Future<void> Function(
  BuildContext context,
  Widget destination, {
  Future<void> Function()? onNavigate,
});

/// What each row of the "+" sheet does. [RecordSheetActions.real] opens the
/// app's existing forms; tests pass stand-ins.
class RecordSheetActions {
  final Future<void> Function(BuildContext context) recordSale;
  final Future<void> Function(BuildContext context) recordVisit;
  final Future<void> Function(BuildContext context, List<Client> debtors) recordPayment;
  final Future<void> Function(BuildContext context) addClient;

  /// Every client who owes money now (fetchAllDebtorClients).
  final Future<List<Client>> Function(BuildContext context) fetchDebtors;

  const RecordSheetActions({
    required this.recordSale,
    required this.recordVisit,
    required this.recordPayment,
    required this.addClient,
    required this.fetchDebtors,
  });

  /// The app's own forms, as the dashboard's quick actions and Debtors open
  /// them.
  static RecordSheetActions get real => RecordSheetActions(
        recordSale: (context) => showAddSaleScreen(context),
        recordVisit: (context) => showAddEditServiceScreen(context),
        recordPayment: (context, debtors) async {
          final recorded = await showAddPaymentScreen(
            context,
            facilityId: Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId,
            debtorClients: debtors,
            debtorBalances: {for (final c in debtors) c.id: c.balance},
          );
          // As Debtors does after a payment, so its list is right when opened.
          if (recorded == true && context.mounted) {
            Provider.of<ClientProvider>(context, listen: false).debtorsListController.refreshSession();
          }
        },
        addClient: (context) => showAddClientScreen(context),
        fetchDebtors: (context) => fetchAllDebtorClients(
          FirebaseFirestore.instance,
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId,
        ),
      );
}

/// PH3 (4): the "+" sheet (phone_shell.md D1 and section 3), opened from
/// every tab: Record Sale, Record Visit, Record Payment, Add Client, each
/// through the locked-facility guard so a locked facility stays read-only for
/// all four. [onDone] runs after a form closes.
Future<void> showRecordSheet(
  BuildContext context, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  VoidCallback? onDone,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.shell_recordSheetTitle,
    builder: (_) => _RecordRows(
      // The forms open from the shell's context: the sheet is closed by then.
      shellContext: context,
      actions: actions ?? RecordSheetActions.real,
      guard: guard,
      onDone: onDone,
    ),
  );
}

enum _PaymentState { idle, loading, nobody }

class _RecordRows extends StatefulWidget {
  final BuildContext shellContext;
  final RecordSheetActions actions;
  final RecordGuard guard;
  final VoidCallback? onDone;

  const _RecordRows({required this.shellContext, required this.actions, required this.guard, this.onDone});

  @override
  State<_RecordRows> createState() => _RecordRowsState();
}

class _RecordRowsState extends State<_RecordRows> {
  _PaymentState _payment = _PaymentState.idle;

  /// Through the guard: locked, it shows its dialog over the sheet and no
  /// form opens; otherwise the sheet closes and [open] runs.
  Future<void> _run(Widget destination, Future<void> Function() open) {
    return widget.guard(context, destination, onNavigate: () async {
      if (!mounted) return;
      Navigator.of(context).pop();
      await open();
      widget.onDone?.call();
    });
  }

  Future<void> _recordPayment() {
    return widget.guard(context, const AddPaymentScreen(), onNavigate: () async {
      if (!mounted || _payment == _PaymentState.loading) return;
      setState(() => _payment = _PaymentState.loading);
      final List<Client> debtors;
      try {
        debtors = await widget.actions.fetchDebtors(context);
      } catch (e, st) {
        if (mounted) setState(() => _payment = _PaymentState.idle);
        AppFeedback.error(L10n.current.error_couldNotLoad, error: e, stackTrace: st);
        return;
      }
      if (!mounted) return;
      if (debtors.isEmpty) {
        setState(() => _payment = _PaymentState.nobody);
        return;
      }
      Navigator.of(context).pop();
      if (!widget.shellContext.mounted) return;
      await widget.actions.recordPayment(widget.shellContext, debtors);
      widget.onDone?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = widget.shellContext;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordRow(
          icon: Icons.add_shopping_cart,
          label: l10n.sales_recordSale,
          hint: l10n.dashboard_createNewSale,
          onTap: () => _run(const AddSaleScreen(), () => widget.actions.recordSale(shell)),
        ),
        _RecordRow(
          icon: Icons.design_services,
          label: l10n.services_recordVisit,
          hint: l10n.dashboard_addServiceRecord,
          onTap: () => _run(const AddEditServiceScreen(), () => widget.actions.recordVisit(shell)),
        ),
        _RecordRow(
          icon: Icons.payments,
          label: l10n.debtors_recordPayment,
          hint: switch (_payment) {
            _PaymentState.idle => l10n.shell_recordPaymentHint,
            _PaymentState.loading => l10n.shell_findingDebtors,
            _PaymentState.nobody => l10n.shell_nobodyOwes,
          },
          loading: _payment == _PaymentState.loading,
          onTap: _recordPayment,
        ),
        _RecordRow(
          icon: Icons.person_add_alt_1,
          label: l10n.clients_add,
          hint: l10n.shell_addClientHint,
          onTap: () => _run(const AddClientScreen(), () => widget.actions.addClient(shell)),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool loading;
  final VoidCallback onTap;

  const _RecordRow({required this.icon, required this.label, required this.hint, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PhoneShellMetrics.sheetRowHeight),
        child: Row(
          children: [
            Container(
              width: PhoneShellMetrics.sheetIconCircle,
              height: PhoneShellMetrics.sheetIconCircle,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: PhoneShellMetrics.pillAlpha),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: PhoneShellMetrics.sheetIcon, color: colors.primary),
            ),
            const SizedBox(width: PhoneShellMetrics.sheetGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: PhoneShellMetrics.sheetLabel,
                      fontWeight: AppFontWeight.semibold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: PhoneShellMetrics.sheetHint, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(width: PhoneShellMetrics.sheetGap),
              SizedBox(
                width: PhoneShellMetrics.sheetSpinner,
                height: PhoneShellMetrics.sheetSpinner,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
