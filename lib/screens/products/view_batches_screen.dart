import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import 'add_edit_product_screen.dart';
import 'add_batch_screen.dart';
import 'move_expired_to_stock_dialog.dart';
import '../../config/money.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_breakpoints.dart';
import '../../l10n/l10n.dart';

/// Full management view for one product's stock - every batch on file,
/// with a way to correct or top up any of them directly, plus a clear
/// path to add a genuinely new batch or edit the product's own details.
/// This is where the duplicate-detection prompt in Add Product sends you
/// when you pick an existing product, so you have full context (and both
/// options) in one place instead of being dropped straight into a form.
class ViewBatchesScreen extends StatefulWidget {
  final Product product;
  final bool isModal;
  // Defaults to Products' original wording - Stock Store passes
  // MoveToStockAction.removeFromSellable explicitly, since the same action reads
  // oddly as "move to stock" while already standing in the Stock
  // screen.
  final MoveToStockAction moveToStockAction;
  const ViewBatchesScreen({
    super.key,
    required this.product,
    this.isModal = false,
    this.moveToStockAction = MoveToStockAction.moveToStock,
  });

  @override
  State<ViewBatchesScreen> createState() => _ViewBatchesScreenState();
}

class _ViewBatchesScreenState extends State<ViewBatchesScreen> {
  // Space under the batch list so the floating "Add Batch" button does not
  // cover the last card. A size (above the spacing ladder), kept exact.
  static const double _fabClearance = 80;

  // Created once here, not on every rebuild - a StreamBuilder given a
  // new stream instance each time resets to its loading state before
  // that new stream's first value arrives, which is what was causing
  // this screen's content to flicker (appear, disappear, reappear)
  // whenever anything caused a rebuild.
  late final Stream<List<ProductBatch>> _batchesStream;

  @override
  void initState() {
    super.initState();
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    _batchesStream = facilityId == null
        ? Stream.value(<ProductBatch>[])
        : Provider.of<ProductProvider>(context, listen: false).streamBatchesForProduct(facilityId, widget.product.id);
  }

  Future<void> _showAdjustDialog(BuildContext context, String facilityId, ProductBatch batch) async {
    final stockController = TextEditingController();
    final sellableController = TextEditingController();
    String mode = 'add';
    bool isSaving = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(batch.batchNo?.isNotEmpty == true ? context.l10n.store_batchName(batch.batchNo!) : context.l10n.batch_unlabeledTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.batch_currently(batch.stockQty, batch.sellableQty),
                    style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                const SizedBox(height: AppSpacing.s14),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(context.l10n.batch_modeAdd, style: const TextStyle(fontSize: AppFontSize.f13)),
                        value: 'add',
                        groupValue: mode,
                        onChanged: (v) => setDialogState(() => mode = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(context.l10n.batch_modeSet, style: const TextStyle(fontSize: AppFontSize.f13)),
                        value: 'set',
                        groupValue: mode,
                        onChanged: (v) => setDialogState(() => mode = v!),
                      ),
                    ),
                  ],
                ),
                Text(
                  mode == 'add'
                      ? context.l10n.batch_modeAddHint
                      : context.l10n.batch_modeSetHint,
                  style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: mode == 'add' ? context.l10n.batch_addStoreQty : context.l10n.batch_setStoreQty,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s10),
                TextField(
                  controller: sellableController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: mode == 'add' ? context.l10n.batch_addSellableQty : context.l10n.batch_setSellableQty,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: AppSpacing.s10),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: context.colors.danger.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i16),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Text(errorText!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final stockVal = int.tryParse(stockController.text.trim());
                      final sellableVal = int.tryParse(sellableController.text.trim());
                      if (stockVal == null && sellableVal == null) {
                        Navigator.pop(context);
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorText = null;
                      });

                      try {
                        await Provider.of<ProductProvider>(context, listen: false).adjustExistingBatch(
                          facilityId: facilityId,
                          productId: widget.product.id,
                          batchId: batch.id,
                          mode: mode,
                          stockQty: stockVal,
                          sellableQty: sellableVal,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        // Previously uncaught entirely - any failure here
                        // (a permission error, a network issue) was
                        // silently swallowed by Flutter's own zone-level
                        // error handling, logged only to the debug
                        // console. The dialog just appeared to do
                        // nothing when Save was tapped, with no
                        // indication anything had gone wrong.
                        setDialogState(() {
                          isSaving = false;
                          errorText = context.l10n.batch_saveFailed('$e');
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                    )
                  : Text(context.l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBatch(BuildContext context, String facilityId, ProductBatch batch, bool isExpired) async {
    bool isDeleting = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isExpired ? context.l10n.batch_deleteExpiredTitle : context.l10n.batch_deleteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isExpired) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: AppIconSize.i16),
                      SizedBox(width: AppSpacing.s6),
                      Expanded(
                        child: Text(
                          context.l10n.batch_notExpiredWarning,
                          style: TextStyle(color: context.colors.warning, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                context.l10n.batch_deleteBody(
                  batch.batchNo?.isNotEmpty == true ? context.l10n.store_batchName(batch.batchNo!) : context.l10n.batch_thisUnlabeled,
                  batch.stockQty,
                  batch.sellableQty,
                ),
                style: const TextStyle(fontSize: AppFontSize.f13),
              ),
              if (errorText != null) ...[
                const SizedBox(height: AppSpacing.s10),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: context.colors.danger.withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i16),
                      const SizedBox(width: AppSpacing.s6),
                      Expanded(
                        child: Text(errorText!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() {
                        isDeleting = true;
                        errorText = null;
                      });
                      try {
                        await Provider.of<ProductProvider>(context, listen: false).deleteBatch(
                          facilityId: facilityId,
                          productId: widget.product.id,
                          batchId: batch.id,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() {
                          isDeleting = false;
                          errorText = context.l10n.batch_deleteFailed('$e');
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.dangerDeep;
                  return context.colors.dangerAccent;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: isDeleting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                    )
                  : Text(context.l10n.common_delete),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.common_close,
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showAddBatchScreen(context, product: widget.product);
        },
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        hoverColor: context.colors.accent,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.products_addNewBatch),
      ),
      body: facilityId == null
          ? Center(child: Text(context.l10n.common_noFacilityDot))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(widget.product.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                        subtitle: Text('${context.l10n.productCategoryLabel(widget.product.category)} · ${Money.symbolWhole(widget.product.sellPrice)}'),
                        trailing: TextButton(
                          onPressed: () {
                            showAddEditProductScreen(context, product: widget.product);
                          },
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                              if (states.contains(WidgetState.hovered)) return context.colors.accent;
                              return context.colors.primary;
                            }),
                          ),
                          child: Text(context.l10n.batch_editDetails),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(context.l10n.batch_batches, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                    const SizedBox(height: AppSpacing.s8),
                    StreamBuilder<List<ProductBatch>>(
                      stream: _batchesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.s24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: Text(context.l10n.batch_loadFailed('${snapshot.error}')),
                          );
                        }

                        final batches = snapshot.data ?? [];
                        if (batches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: Text(context.l10n.batch_noneYet, style: TextStyle(color: context.colors.textMuted)),
                          );
                        }

                        final now = DateTime.now();

                        return Column(
                          children: batches.map((batch) {
                            final isExpired = batch.expiry != null && batch.expiry!.isBefore(now);
                            final isDepleted = batch.stockQty <= 0 && batch.sellableQty <= 0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                              child: ListTile(
                                leading: Icon(
                                  Icons.inventory_2_outlined,
                                  color: isExpired
                                      ? context.colors.dangerAccent
                                      : (isDepleted ? context.colors.textHint : context.colors.primary),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        batch.batchNo?.isNotEmpty == true
                                            ? context.l10n.store_batchName(batch.batchNo!)
                                            : context.l10n.batch_unlabeled,
                                      ),
                                    ),
                                    if (isDepleted) ...[
                                      const SizedBox(width: AppSpacing.s8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                                        decoration: BoxDecoration(
                                          color: context.colors.danger.withValues(alpha: AppAlpha.a10),
                                          borderRadius: BorderRadius.circular(AppRadius.r20),
                                          border: Border.all(color: context.colors.danger.withValues(alpha: AppAlpha.a40)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle, size: AppSizes.statusDot, color: context.colors.danger),
                                            SizedBox(width: AppSpacing.s4),
                                            Text(
                                              context.l10n.batch_outOfStock,
                                              style: TextStyle(
                                                color: context.colors.danger,
                                                fontSize: AppFontSize.f11,
                                                fontWeight: AppFontWeight.semibold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${context.l10n.batch_rowQuantities(batch.stockQty, batch.sellableQty, Money.symbolWhole(batch.buyPrice))}'
                                  '${batch.expiry != null ? '\n${isExpired ? context.l10n.batch_expiredOn(AppDateFormat.date.format(batch.expiry!)) : context.l10n.batch_expiresOn(AppDateFormat.date.format(batch.expiry!))}' : ''}',
                                ),
                                isThreeLine: batch.expiry != null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (batch.sellableQty > 0)
                                      IconButton(
                                        icon: const Icon(Icons.move_up_outlined, size: AppIconSize.i20),
                                        tooltip: widget.moveToStockAction.label(context.l10n),
                                        style: ButtonStyle(
                                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                            if (states.contains(WidgetState.hovered)) return context.colors.accent;
                                            return context.colors.primary;
                                          }),
                                        ),
                                        onPressed: () => promptQuantityAndMoveToStock(
                                            context, widget.product, batch, action: widget.moveToStockAction),
                                      ),
                                    if (isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: AppIconSize.i20),
                                        tooltip: isExpired ? context.l10n.batch_deleteExpiredTooltip : context.l10n.batch_deleteTooltip,
                                        style: ButtonStyle(
                                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                            if (states.contains(WidgetState.hovered)) return context.colors.dangerDeep;
                                            return context.colors.dangerAccent;
                                          }),
                                        ),
                                        onPressed: () => _confirmDeleteBatch(context, facilityId, batch, isExpired),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: AppIconSize.i20),
                                      tooltip: context.l10n.batch_adjustQuantity,
                                      style: ButtonStyle(
                                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                          if (states.contains(WidgetState.hovered)) return context.colors.accent;
                                          return context.colors.primary;
                                        }),
                                      ),
                                      onPressed: () => _showAdjustDialog(context, facilityId, batch),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: _fabClearance),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The one entry point for opening View Batches - same reasoning and
/// threshold as showAddSaleScreen elsewhere in this app: a full-screen
/// push on mobile, a large, centered, dismissable modal on
/// desktop/tablet-width screens. This is a focused, per-product
/// drill-down reached from one specific row on the Products list, not
/// an independent destination you'd browse on its own - the same
/// category as Platform Admin's Activity Log or Promotions screens,
/// both already modal on desktop despite also being list views rather
/// than forms.
Future<void> showViewBatchesScreen(
  BuildContext context, {
  required Product product,
  MoveToStockAction moveToStockAction = MoveToStockAction.moveToStock,
}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewBatchesScreen(product: product, moveToStockAction: moveToStockAction)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.products_viewBatches,
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      // Never shorter than 480px, fixed - 88% of screen height
      // comfortably exceeds that on most windows, but this guarantees
      // it even on a smaller one.
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            child: Material(
              child: ViewBatchesScreen(product: product, isModal: true, moveToStockAction: moveToStockAction),
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
