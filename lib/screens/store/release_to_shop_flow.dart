import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import '../../utils/activity_logger.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/activity_type.dart';
import '../../l10n/l10n.dart';

// The "release to shelf" flow, shared so it behaves identically wherever it's
// started from - the Stock Store's own Release button and the Product Alerts
// screen's "Move to shelf" button. Moved here unchanged from the Stock Store
// screen (only what it needed from its old State - the context and the
// colours - is now passed in / read from the theme).

// Mirrors moveToSellable's own batch-selection logic exactly (same
// soonest-expiry-first sort, same "take" math) but read-only - just
// to find out, before committing to anything, whether releasing this
// quantity would actually draw from an already-expired batch, and if
// so, precisely how many units from which one. Each entry is the batch's
// number (null when it has none) and the units it would give.
Future<List<(String?, int)>> _simulateExpiredPortion(Product product, int qty) async {
  final batchesRef = FirebaseFirestore.instance
      .collection(Collections.facilities)
      .doc(product.facilityId)
      .collection(Collections.products)
      .doc(product.id)
      .collection(Collections.batches);

  final snap = await batchesRef.where('stockQty', isGreaterThan: 0).get();
  if (snap.docs.isEmpty) return [];

  final now = DateTime.now();
  final candidates = snap.docs.toList()
    ..sort((a, b) {
      final aExp = a.data()['expiry'] as Timestamp?;
      final bExp = b.data()['expiry'] as Timestamp?;
      if (aExp == null && bExp == null) return 0;
      if (aExp == null) return 1;
      if (bExp == null) return -1;
      return aExp.compareTo(bExp);
    });

  final expiredPortion = <(String?, int)>[];
  int remaining = qty;
  for (final doc in candidates) {
    if (remaining <= 0) break;
    final data = doc.data();
    final availableStock = (data['stockQty'] ?? 0) as int;
    if (availableStock <= 0) continue;

    final take = remaining < availableStock ? remaining : availableStock;
    final expiry = data['expiry'] as Timestamp?;
    if (expiry != null && expiry.toDate().isBefore(now)) {
      final batchNo = data['batchNo'] as String?;
      expiredPortion.add((batchNo?.isNotEmpty == true ? batchNo : null, take));
    }
    remaining -= take;
  }
  return expiredPortion;
}

// How a batch is named in the activity entry: in English, exactly as it has
// always been saved. The warning dialog shows it in the current language.
String _batchNameForLog(String? batchNo) => batchNo != null ? 'Batch $batchNo' : 'an unlabeled batch';

Future<bool?> _showExpiredReleaseWarning(BuildContext context, Product product, List<(String?, int)> expiredPortion) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ctx.colors.danger),
          const SizedBox(width: AppSpacing.s8),
          Text(ctx.l10n.store_expiredStockTitle),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.store_expiredStockBody,
                style: const TextStyle(fontSize: AppFontSize.f13_5)),
            const SizedBox(height: AppSpacing.s10),
            ...expiredPortion.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Text(
                      ctx.l10n.store_expiredPortionLine('${e.$2}', ctx.l10n.productUnitLabel(product.unit),
                          e.$1 != null ? ctx.l10n.store_batchName(e.$1!) : ctx.l10n.store_unlabeledBatch),
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: ctx.colors.dangerStrong)),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.common_cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ctx.colors.danger, foregroundColor: ctx.colors.onPrimary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.store_releaseAnyway),
        ),
      ],
    ),
  );
}

/// Releases stock from the Stock Store to the shelf: asks how many, warns if
/// that would draw on expired stock, then does the move and logs it.
///
/// [initialQuantity] pre-fills the quantity box (Product Alerts passes how
/// many the shelf is short by); the Stock Store's own button leaves it at 1.
Future<void> releaseProductToShop(BuildContext context, Product product, {int initialQuantity = 1}) async {
  final qtyController = TextEditingController(text: '$initialQuantity');
  final notesController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(context.l10n.store_releaseTitle,
          style: TextStyle(color: context.colors.primary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.store_availableStock('${product.stockQty}', context.l10n.productUnitLabel(product.unit))),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              labelText: context.l10n.store_quantityToRelease,
              labelStyle: TextStyle(color: context.colors.textSoft),
              floatingLabelStyle: TextStyle(color: context.colors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                borderSide: BorderSide(color: context.colors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                borderSide: BorderSide(color: context.colors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: notesController,
            cursorColor: context.colors.primary,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: InputDecoration(
              labelText: context.l10n.common_notesOptional,
              hintText: context.l10n.store_notesHint,
              labelStyle: TextStyle(color: context.colors.textSoft),
              floatingLabelStyle: TextStyle(color: context.colors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                borderSide: BorderSide(color: context.colors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                borderSide: BorderSide(color: context.colors.primary, width: 2),
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
          ),
          child: Text(context.l10n.common_cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (states) {
                if (states.contains(WidgetState.hovered)) {
                  return context.colors.accent;
                }
                return context.colors.primary;
              },
            ),
            foregroundColor: WidgetStateProperty.all(context.colors.background),
          ),
          child: Text(context.l10n.products_release),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final qty = int.tryParse(qtyController.text.trim()) ?? 0;
  if (qty <= 0 || qty > product.stockQty) {
    AppFeedback.warning(L10n.current.store_quantityRange('${product.stockQty}'));
    return;
  }

  final expiredPortion = await _simulateExpiredPortion(product, qty);
  if (expiredPortion.isNotEmpty) {
    if (!context.mounted) return;
    final proceedAnyway = await _showExpiredReleaseWarning(context, product, expiredPortion);
    if (proceedAnyway != true) return;
  }

  // The simulation above awaited a Firestore read - make sure the screen is still there.
  if (!context.mounted) return;

  try {
    await Provider.of<ProductProvider>(context, listen: false)
        .moveToSellable(
          product,
          qty,
          context,
          notes: notesController.text.trim().isNotEmpty
              ? notesController.text.trim()
              : null,
        );

    if (expiredPortion.isNotEmpty) {
      final userInfo = await ActivityLogger.getCurrentUserInfo();
      final unitsSummary = expiredPortion.map((e) => '${e.$2} from ${_batchNameForLog(e.$1)}').join(', ');
      await ActivityLogger.logActivity(
        facilityId: product.facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName']!,
        actionType: ActivityType.inventoryMove.key,
        description: "${product.name}: released $unitsSummary despite expired-stock warning",
      );
    }

    AppFeedback.success(
        L10n.current.store_released('$qty', L10n.current.productUnitLabel(product.unit), product.name));
  } catch (e, st) {
    AppFeedback.error(L10n.current.store_releaseFailed, error: e, stackTrace: st);
  }
}
