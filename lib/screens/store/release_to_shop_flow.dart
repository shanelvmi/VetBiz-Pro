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

// The "release to shelf" flow, shared so it behaves identically wherever it's
// started from - the Stock Store's own Release button and the Product Alerts
// screen's "Move to shelf" button. Moved here unchanged from the Stock Store
// screen (only what it needed from its old State - the context and the
// colours - is now passed in / read from the theme).

// Mirrors moveToSellable's own batch-selection logic exactly (same
// soonest-expiry-first sort, same "take" math) but read-only - just
// to find out, before committing to anything, whether releasing this
// quantity would actually draw from an already-expired batch, and if
// so, precisely how many units from which one.
Future<List<(String, int)>> _simulateExpiredPortion(Product product, int qty) async {
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

  final expiredPortion = <(String, int)>[];
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
      final label = batchNo?.isNotEmpty == true ? 'Batch $batchNo' : 'an unlabeled batch';
      expiredPortion.add((label, take));
    }
    remaining -= take;
  }
  return expiredPortion;
}

Future<bool?> _showExpiredReleaseWarning(BuildContext context, Product product, List<(String, int)> expiredPortion) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ctx.colors.danger),
          const SizedBox(width: AppSpacing.s8),
          const Text('Expired Stock'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This product is expired. Do you still want to release it to the shop?',
                style: const TextStyle(fontSize: AppFontSize.f13_5)),
            const SizedBox(height: AppSpacing.s10),
            ...expiredPortion.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Text('• ${e.$2} ${product.unit} from ${e.$1}',
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: ctx.colors.dangerStrong)),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ctx.colors.danger, foregroundColor: ctx.colors.onPrimary),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Release Anyway'),
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
      title: Text('Release to Shop',
          style: TextStyle(color: context.colors.primary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Available stock: ${product.stockQty} ${product.unit}'),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              labelText: 'Quantity to release',
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
              labelText: 'Notes (optional)',
              hintText: 'e.g., Quality checked, ready for sale',
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
          child: const Text('Cancel'),
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
          child: const Text('Release'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final qty = int.tryParse(qtyController.text.trim()) ?? 0;
  if (qty <= 0 || qty > product.stockQty) {
    AppFeedback.warning('Enter a quantity from 1 to ${product.stockQty}');
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
      final unitsSummary = expiredPortion.map((e) => '${e.$2} from ${e.$1}').join(', ');
      await ActivityLogger.logActivity(
        facilityId: product.facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName']!,
        actionType: ActivityType.inventoryMove.key,
        description: "${product.name}: released $unitsSummary despite expired-stock warning",
      );
    }

    AppFeedback.success('Released $qty ${product.unit} of ${product.name} to the shelf');
  } catch (e, st) {
    AppFeedback.error("Couldn't release the product", error: e, stackTrace: st);
  }
}
