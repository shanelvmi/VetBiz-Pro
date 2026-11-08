import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/client.dart';
import '../../models/product.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/debtor_clients_service.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../utils/subscription_guard.dart';
import '../../widgets/app_sheet.dart';
import '../clients/add_client_screen.dart';
import '../debtors/add_payment_screen.dart';
import '../products/add_batch_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../sales/add_sale_screen.dart';
import '../services/add_edit_service_screen.dart';
import '../transactions/add_transaction_screen.dart';

/// The locked-facility guard's shape (navigateOrShowLockedDialog).
typedef RecordGuard = Future<void> Function(
  BuildContext context,
  Widget destination, {
  Future<void> Function()? onNavigate,
});

/// Everything the "+" sheet, the phone home's Quick access tiles and its
/// "View all" sheet can start (phone_shell.md D1, D2 and section 4).
enum RecordAction { recordSale, recordVisit, recordPayment, addClient, addProduct, addBatch, recordTransaction }

/// The "+" sheet's four, which are also the four Quick access tiles.
const quickAccessActions = [
  RecordAction.recordSale,
  RecordAction.recordVisit,
  RecordAction.recordPayment,
  RecordAction.addClient,
];

/// The rows a sheet shows. [all] is Quick access "View all": the four, then
/// Add Product (admins only, owner decision E4d-2, as the Products screen),
/// Add New Batch and Record Transaction (both open to assistants today).
List<RecordAction> recordActionsFor({required bool isAdmin, bool all = false}) => [
      ...quickAccessActions,
      if (all) ...[
        if (isAdmin) RecordAction.addProduct,
        RecordAction.addBatch,
        RecordAction.recordTransaction,
      ],
    ];

/// The app's existing labels for each action.
String recordActionLabel(BuildContext context, RecordAction action) {
  final l10n = context.l10n;
  return switch (action) {
    RecordAction.recordSale => l10n.sales_recordSale,
    RecordAction.recordVisit => l10n.services_recordVisit,
    RecordAction.recordPayment => l10n.debtors_recordPayment,
    RecordAction.addClient => l10n.clients_add,
    RecordAction.addProduct => l10n.products_addProduct,
    RecordAction.addBatch => l10n.products_addNewBatch,
    RecordAction.recordTransaction => l10n.transactions_record,
  };
}

String _hint(BuildContext context, RecordAction action) {
  final l10n = context.l10n;
  return switch (action) {
    RecordAction.recordSale => l10n.dashboard_createNewSale,
    RecordAction.recordVisit => l10n.dashboard_addServiceRecord,
    RecordAction.recordPayment => l10n.shell_recordPaymentHint,
    RecordAction.addClient => l10n.shell_addClientHint,
    RecordAction.addProduct => l10n.dashboard_addProductToStore,
    RecordAction.addBatch => l10n.home_addBatchHint,
    RecordAction.recordTransaction => l10n.home_recordTransactionHint,
  };
}

IconData recordActionIcon(RecordAction action) => switch (action) {
      RecordAction.recordSale => AppIcons.sales.filled,
      RecordAction.recordVisit => AppIcons.services.filled,
      RecordAction.recordPayment => AppIcons.payments.filled,
      RecordAction.addClient => Icons.person_add_alt_1,
      RecordAction.addProduct => Icons.add_box,
      RecordAction.addBatch => Icons.playlist_add,
      RecordAction.recordTransaction => AppIcons.expenses.filled,
    };

/// What the guard is shown (it only pushes it when no onNavigate is given,
/// which never happens here).
Widget _destination(RecordAction action) => switch (action) {
      RecordAction.recordSale => const AddSaleScreen(),
      RecordAction.recordVisit => const AddEditServiceScreen(),
      RecordAction.recordPayment => const AddPaymentScreen(),
      RecordAction.addClient => const AddClientScreen(),
      RecordAction.addProduct => const AddEditProductScreen(),
      RecordAction.addBatch => const SizedBox.shrink(),
      RecordAction.recordTransaction => const AddTransactionScreen(),
    };

Future<void> _realAddProduct(BuildContext context) => showAddEditProductScreen(context);
Future<void> _realAddBatch(BuildContext context) => pickProductAndAddBatch(context);
Future<void> _realRecordTransaction(BuildContext context) => showAddTransactionScreen(context);

/// What each row does. [RecordSheetActions.real] opens the app's existing
/// forms; tests pass stand-ins.
class RecordSheetActions {
  final Future<void> Function(BuildContext context) recordSale;
  final Future<void> Function(BuildContext context) recordVisit;
  final Future<void> Function(BuildContext context, List<Client> debtors) recordPayment;
  final Future<void> Function(BuildContext context) addClient;
  final Future<void> Function(BuildContext context) addProduct;
  final Future<void> Function(BuildContext context) addBatch;
  final Future<void> Function(BuildContext context) recordTransaction;

  /// Every client who owes money now (fetchAllDebtorClients).
  final Future<List<Client>> Function(BuildContext context) fetchDebtors;

  const RecordSheetActions({
    required this.recordSale,
    required this.recordVisit,
    required this.recordPayment,
    required this.addClient,
    required this.fetchDebtors,
    this.addProduct = _realAddProduct,
    this.addBatch = _realAddBatch,
    this.recordTransaction = _realRecordTransaction,
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

  /// Opens [action]'s form ([debtors] for Record Payment).
  Future<void> open(BuildContext context, RecordAction action, {List<Client> debtors = const []}) {
    return switch (action) {
      RecordAction.recordSale => recordSale(context),
      RecordAction.recordVisit => recordVisit(context),
      RecordAction.recordPayment => recordPayment(context, debtors),
      RecordAction.addClient => addClient(context),
      RecordAction.addProduct => addProduct(context),
      RecordAction.addBatch => addBatch(context),
      RecordAction.recordTransaction => recordTransaction(context),
    };
  }
}

/// PH4: one action started from the phone home (a Quick access tile), through
/// the same guard and forms as the "+" sheet. Record Payment first finds who
/// owes; with nobody, it says so and opens nothing.
Future<void> runRecordAction(
  BuildContext context,
  RecordAction action, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  VoidCallback? onDone,
}) {
  final run = actions ?? RecordSheetActions.real;
  return guard(context, _destination(action), onNavigate: () async {
    var debtors = const <Client>[];
    if (action == RecordAction.recordPayment) {
      try {
        debtors = await run.fetchDebtors(context);
      } catch (e, st) {
        AppFeedback.error(L10n.current.error_couldNotLoad, error: e, stackTrace: st);
        return;
      }
      if (debtors.isEmpty) {
        AppFeedback.info(L10n.current.shell_nobodyOwes);
        return;
      }
    }
    if (!context.mounted) return;
    await run.open(context, action, debtors: debtors);
    onDone?.call();
  });
}

/// PH3 (4): the "+" sheet (phone_shell.md D1 and section 3), opened from
/// every tab: Record Sale, Record Visit, Record Payment, Add Client, each
/// through the locked-facility guard so a locked facility stays read-only for
/// all of them. With [all] (PH4, Quick access "View all") it also has the
/// actions [recordActionsFor] gives the role. [onDone] runs after a form
/// closes.
Future<void> showRecordSheet(
  BuildContext context, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  VoidCallback? onDone,
  bool all = false,
  bool isAdmin = false,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.shell_recordSheetTitle,
    builder: (_) => _RecordRows(
      // The forms open from the shell's context: the sheet is closed by then.
      shellContext: context,
      rows: recordActionsFor(isAdmin: isAdmin, all: all),
      actions: actions ?? RecordSheetActions.real,
      guard: guard,
      onDone: onDone,
    ),
  );
}

enum _PaymentState { idle, loading, nobody }

class _RecordRows extends StatefulWidget {
  final BuildContext shellContext;
  final List<RecordAction> rows;
  final RecordSheetActions actions;
  final RecordGuard guard;
  final VoidCallback? onDone;

  const _RecordRows(
      {required this.shellContext, required this.rows, required this.actions, required this.guard, this.onDone});

  @override
  State<_RecordRows> createState() => _RecordRowsState();
}

class _RecordRowsState extends State<_RecordRows> {
  _PaymentState _payment = _PaymentState.idle;

  /// Through the guard: locked, it shows its dialog over the sheet and no
  /// form opens; otherwise the sheet closes and the form opens.
  Future<void> _run(RecordAction action) {
    return widget.guard(context, _destination(action), onNavigate: () async {
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.actions.open(widget.shellContext, action);
      widget.onDone?.call();
    });
  }

  Future<void> _recordPayment() {
    return widget.guard(context, _destination(RecordAction.recordPayment), onNavigate: () async {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in widget.rows)
          if (action == RecordAction.recordPayment)
            _RecordRow(
              icon: recordActionIcon(action),
              label: recordActionLabel(context, action),
              hint: switch (_payment) {
                _PaymentState.idle => _hint(context, action),
                _PaymentState.loading => l10n.shell_findingDebtors,
                _PaymentState.nobody => l10n.shell_nobodyOwes,
              },
              loading: _payment == _PaymentState.loading,
              onTap: _recordPayment,
            )
          else
            _RecordRow(
              icon: recordActionIcon(action),
              label: recordActionLabel(context, action),
              hint: _hint(context, action),
              onTap: () => _run(action),
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

/// PH4 (View all, Add New Batch): a batch belongs to a product, so the person
/// first picks one from the products the app already holds (no new read),
/// then the existing Add Batch form opens for it.
Future<void> pickProductAndAddBatch(BuildContext context) async {
  final products = Provider.of<ProductProvider>(context, listen: false).products;
  final product = await showAppSheet<Product>(
    context,
    title: context.l10n.home_chooseProduct,
    fullPage: true,
    builder: (_) => ProductPickerList(products: products),
  );
  if (product == null || !context.mounted) return;
  await showAddBatchScreen(context, product: product);
}

/// The products by name, with a search field; a tap returns the product.
class ProductPickerList extends StatefulWidget {
  final List<Product> products;

  const ProductPickerList({super.key, required this.products});

  @override
  State<ProductPickerList> createState() => _ProductPickerListState();
}

class _ProductPickerListState extends State<ProductPickerList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = widget.products.where((p) => p.name.toLowerCase().contains(_query)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PhoneHomeMetrics.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.l10n.common_searchEllipsis,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(PhoneHomeMetrics.pagePadding),
              child: Text(context.l10n.sales_noProductsFound, style: TextStyle(color: colors.textMuted)),
            ),
          for (final p in shown)
            InkWell(
              onTap: () => Navigator.of(context).pop(p),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: PhoneHomeMetrics.rowHeight),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: PhoneHomeMetrics.rowLabel, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
