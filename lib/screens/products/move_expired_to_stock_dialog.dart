import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../constants/batch_move_reasons.dart';
import '../../l10n/l10n.dart';

/// The one action, worded two ways: Products says "Move to Stock", while
/// the Stock Store and Product Alerts say "Remove from Sellable" (moving
/// stock back to the store reads oddly while standing in the store). The
/// success message is chosen by this value, never by comparing the label,
/// which is translated.
enum MoveToStockAction {
  moveToStock,
  removeFromSellable;

  String label(AppLocalizations l) => switch (this) {
        MoveToStockAction.moveToStock => l.batch_moveToStock,
        MoveToStockAction.removeFromSellable => l.batch_removeFromSellable,
      };
}

/// Prompts for a quantity and a reason, then moves a sellable batch
/// back to Stock Store - called from View Batches' per-batch action,
/// where the batch is already known. The reason comes from whoever is
/// standing at the shelf, not a system guess - they already know why a
/// batch needs to come off it, and "Other (specify)" covers any reason
/// neither Expired nor Deteriorated fits.
Future<void> promptQuantityAndMoveToStock(
  BuildContext context,
  Product product,
  ProductBatch batch, {
  MoveToStockAction action = MoveToStockAction.moveToStock,
}) async {
  final actionLabel = action.label(context.l10n);
  final qtyController = TextEditingController(text: '${batch.sellableQty}');
  final notesController = TextEditingController();
  final isAlreadyExpired = batch.expiry != null && batch.expiry!.isBefore(DateTime.now());
  // A convenience, not a gate - pre-selects the common case (a batch
  // whose own date has already passed) but never stops someone from
  // picking Deteriorated or Other instead, or from moving a batch
  // that isn't expired at all.
  String? reason = isAlreadyExpired ? kBatchMoveReasonExpired : null;
  String? qtyErrorText;
  String? reasonErrorText;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(actionLabel),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.batch_moveIntro(
                  product.name,
                  batch.batchNo?.isNotEmpty == true ? context.l10n.batch_moveBatchPart(batch.batchNo!) : '',
                  batch.expiry == null
                      ? ''
                      : isAlreadyExpired
                          ? context.l10n.batch_moveExpiredPart(AppDateFormat.date.format(batch.expiry!))
                          : context.l10n.batch_moveExpiresPart(AppDateFormat.date.format(batch.expiry!)),
                  batch.sellableQty,
                  context.l10n.productUnitLabel(product.unit),
                ),
                style: const TextStyle(fontSize: AppFontSize.f13),
              ),
              const SizedBox(height: AppSpacing.s14),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.batch_quantityToMove(context.l10n.productUnitLabel(product.unit)),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: qtyErrorText,
                ),
              ),
              const SizedBox(height: AppSpacing.s10),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(
                  labelText: context.l10n.reports_reason,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: reasonErrorText,
                ),
                items: kBatchMoveReasons
                    // Shows the label; saves the stored reason (English, also in the activity entry).
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(context.l10n.batchMoveReasonLabel(r), style: const TextStyle(fontSize: AppFontSize.f13))))
                    .toList(),
                onChanged: (v) => setDialogState(() {
                  reason = v;
                  reasonErrorText = null;
                }),
              ),
              const SizedBox(height: AppSpacing.s10),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: reason == kBatchMoveReasonOther ? context.l10n.batch_noteRequiredOther : context.l10n.batch_noteOptional,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              var hasError = false;
              if (qty <= 0 || qty > batch.sellableQty) {
                qtyErrorText = context.l10n.batch_quantityUpTo(batch.sellableQty);
                hasError = true;
              }
              if (reason == null) {
                reasonErrorText = context.l10n.batch_selectReason;
                hasError = true;
              } else if (reason == kBatchMoveReasonOther && notesController.text.trim().isEmpty) {
                reasonErrorText = context.l10n.batch_describeReason;
                hasError = true;
              }
              if (hasError) {
                setDialogState(() {});
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final qty = int.tryParse(qtyController.text.trim()) ?? 0;
  if (qty <= 0 || reason == null) return;

  try {
    await Provider.of<ProductProvider>(context, listen: false).moveBatchToStock(
      product,
      batch,
      qty,
      reason!,
      context,
      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
    );
    AppFeedback.success(action == MoveToStockAction.moveToStock
        ? L10n.current.batch_movedBack(qty, L10n.current.productUnitLabel(product.unit))
        : L10n.current.batch_removedFromSellable(qty, L10n.current.productUnitLabel(product.unit)));
  } catch (e, st) {
    AppFeedback.error(L10n.current.batch_moveFailed, error: e, stackTrace: st);
  }
}
