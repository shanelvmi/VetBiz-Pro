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
  // 'Remove from Sellable' explicitly, since the same action reads
  // oddly as "move to stock" while already standing in the Stock
  // screen.
  final String moveToStockLabel;
  const ViewBatchesScreen({
    super.key,
    required this.product,
    this.isModal = false,
    this.moveToStockLabel = 'Move to Stock',
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
          title: Text(batch.batchNo?.isNotEmpty == true ? 'Batch ${batch.batchNo}' : 'Unlabeled Batch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currently: ${batch.stockQty} store · ${batch.sellableQty} sellable',
                    style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                const SizedBox(height: AppSpacing.s14),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Add to it', style: TextStyle(fontSize: AppFontSize.f13)),
                        value: 'add',
                        groupValue: mode,
                        onChanged: (v) => setDialogState(() => mode = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Correct to', style: TextStyle(fontSize: AppFontSize.f13)),
                        value: 'set',
                        groupValue: mode,
                        onChanged: (v) => setDialogState(() => mode = v!),
                      ),
                    ),
                  ],
                ),
                Text(
                  mode == 'add'
                      ? 'Adds this amount on top of what\'s already there (a top-up delivery).'
                      : 'Sets the exact amount on file right now (fixing a miscount).',
                  style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: mode == 'add' ? 'Add to Store Qty' : 'Correct Store Qty to',
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
                    labelText: mode == 'add' ? 'Add to Sellable Qty' : 'Correct Sellable Qty to',
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
              child: const Text('Cancel'),
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
                          errorText = 'Could not save: $e';
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
                  : const Text('Save'),
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
          title: Text(isExpired ? 'Delete Expired Batch?' : 'Delete This Batch?'),
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
                          'This batch has not expired - it still has good, sellable stock.',
                          style: TextStyle(color: context.colors.warning, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                'This permanently removes ${batch.batchNo?.isNotEmpty == true ? 'Batch ${batch.batchNo}' : 'this unlabeled batch'} '
                'and subtracts its ${batch.stockQty} store and ${batch.sellableQty} sellable units from this product\'s '
                'totals. This cannot be undone.',
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
              child: const Text('Cancel'),
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
                          errorText = 'Could not delete: $e';
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
                  : const Text('Delete'),
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
                tooltip: 'Close',
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
        label: const Text('Add New Batch'),
      ),
      body: facilityId == null
          ? const Center(child: Text('No facility selected.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(widget.product.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                        subtitle: Text('${widget.product.category} · ${Money.symbolWhole(widget.product.sellPrice)}'),
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
                          child: const Text('Edit Details'),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    const Text('Batches', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
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
                            child: Text('Could not load batches: ${snapshot.error}'),
                          );
                        }

                        final batches = snapshot.data ?? [];
                        if (batches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: Text('No batches recorded yet.', style: TextStyle(color: context.colors.textMuted)),
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
                                            ? 'Batch ${batch.batchNo}'
                                            : 'Unlabeled batch',
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
                                              'Out of Stock - 0 available',
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
                                  'Store: ${batch.stockQty} · Shelf: ${batch.sellableQty} · ${Money.symbolWhole(batch.buyPrice)}'
                                  '${batch.expiry != null ? '\n${isExpired ? 'Expired' : 'Expires'} ${AppDateFormat.date.format(batch.expiry!)}' : ''}',
                                ),
                                isThreeLine: batch.expiry != null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (batch.sellableQty > 0)
                                      IconButton(
                                        icon: const Icon(Icons.move_up_outlined, size: AppIconSize.i20),
                                        tooltip: widget.moveToStockLabel,
                                        style: ButtonStyle(
                                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                            if (states.contains(WidgetState.hovered)) return context.colors.accent;
                                            return context.colors.primary;
                                          }),
                                        ),
                                        onPressed: () => promptQuantityAndMoveToStock(
                                            context, widget.product, batch, actionLabel: widget.moveToStockLabel),
                                      ),
                                    if (isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: AppIconSize.i20),
                                        tooltip: isExpired ? 'Delete expired batch' : 'Delete batch',
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
                                      tooltip: 'Adjust quantity',
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
  String moveToStockLabel = 'Move to Stock',
}) async {
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewBatchesScreen(product: product, moveToStockLabel: moveToStockLabel)),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'View Batches',
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
              child: ViewBatchesScreen(product: product, isModal: true, moveToStockLabel: moveToStockLabel),
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
