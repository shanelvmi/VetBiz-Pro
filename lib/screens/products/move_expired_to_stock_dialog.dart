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

const List<String> _moveReasons = ['Expired', 'Deteriorated', 'Other (specify)'];

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
  String actionLabel = 'Move to Stock',
}) async {
  final qtyController = TextEditingController(text: '${batch.sellableQty}');
  final notesController = TextEditingController();
  final isAlreadyExpired = batch.expiry != null && batch.expiry!.isBefore(DateTime.now());
  // A convenience, not a gate - pre-selects the common case (a batch
  // whose own date has already passed) but never stops someone from
  // picking Deteriorated or Other instead, or from moving a batch
  // that isn't expired at all.
  String? reason = isAlreadyExpired ? 'Expired' : null;
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
                '${product.name}${batch.batchNo?.isNotEmpty == true ? ' - Batch ${batch.batchNo}' : ''}'
                '${batch.expiry != null ? ' (${isAlreadyExpired ? 'expired' : 'expires'} ${AppDateFormat.date.format(batch.expiry!)})' : ''}. '
                'Up to ${batch.sellableQty} ${product.unit} can move back to Stock Store.',
                style: const TextStyle(fontSize: AppFontSize.f13),
              ),
              const SizedBox(height: AppSpacing.s14),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to move (${product.unit})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: qtyErrorText,
                ),
              ),
              const SizedBox(height: AppSpacing.s10),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: reasonErrorText,
                ),
                items: _moveReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: AppFontSize.f13))))
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
                  labelText: reason == 'Other (specify)' ? 'Note (required for Other)' : 'Note (optional)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              var hasError = false;
              if (qty <= 0 || qty > batch.sellableQty) {
                qtyErrorText = 'Enter a quantity up to ${batch.sellableQty}';
                hasError = true;
              }
              if (reason == null) {
                reasonErrorText = 'Select a reason';
                hasError = true;
              } else if (reason == 'Other (specify)' && notesController.text.trim().isEmpty) {
                reasonErrorText = 'Describe the reason in the note below';
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
    AppFeedback.success(actionLabel == 'Move to Stock'
        ? 'Moved $qty ${product.unit} back to Stock Store'
        : 'Removed $qty ${product.unit} from Sellable');
  } catch (e, st) {
    AppFeedback.error("Couldn't move the stock", error: e, stackTrace: st);
  }
}
