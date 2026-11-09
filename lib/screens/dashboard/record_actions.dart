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

/// Everything the action panel can record (HUB1; the old "+" sheet's rows and
/// its More group, phone_shell.md D1 SUPERSEDED).
enum RecordAction { recordSale, recordVisit, recordPayment, addClient, addProduct, addBatch, recordTransaction }

/// The app's existing labels for each action (HUB1: by AppLocalizations, as
/// Find a feature searches every language).
String recordActionLabelOf(AppLocalizations l10n, RecordAction action) {
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

/// The action's one-line hint (HUB1: also Find a feature's search words).
String recordActionHintOf(AppLocalizations l10n, RecordAction action) {
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

/// What each record action does. [RecordSheetActions.real] opens the app's existing
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

/// PH4: one action started from the phone (HUB1: an action panel tile),
/// through the locked-facility guard and the app's forms, as the old "+"
/// sheet ran it. Record Payment first finds who
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
