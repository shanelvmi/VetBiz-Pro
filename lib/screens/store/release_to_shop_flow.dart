import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import '../../utils/activity_logger.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_palette.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';

// The "release to shelf" flow, shared so it behaves identically wherever it's
// started from - the Stock Store's own Release button and the Product Alerts
// screen's "Move to shelf" button. Moved here unchanged from the Stock Store
// screen (only what it needed from its old State - the context and the
// colours - is now passed in / defined here).

const Color _deepTeal = AppPalette.primary;
const Color _amber = AppPalette.accent;
const Color _offWhite = AppPalette.background;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Expired Stock'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This product is expired. Do you still want to release it to the shop?',
                style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 10),
            ...expiredPortion.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.$2} ${product.unit} from ${e.$1}',
                      style: TextStyle(fontSize: 12.5, color: Colors.red[700])),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
          style: TextStyle(color: _deepTeal)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Available stock: ${product.stockQty} ${product.unit}'),
          const SizedBox(height: 12),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            cursorColor: _deepTeal,
            decoration: InputDecoration(
              labelText: 'Quantity to release',
              labelStyle: TextStyle(color: Colors.grey[700]),
              floatingLabelStyle: TextStyle(color: _deepTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _deepTeal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            cursorColor: _deepTeal,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [SentenceCapitalizationFormatter()],
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g., Quality checked, ready for sale',
              labelStyle: TextStyle(color: Colors.grey[700]),
              floatingLabelStyle: TextStyle(color: _deepTeal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _deepTeal, width: 2),
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
            foregroundColor: _deepTeal,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (states) {
                if (states.contains(WidgetState.hovered)) {
                  return _amber;
                }
                return _deepTeal;
              },
            ),
            foregroundColor: WidgetStateProperty.all(_offWhite),
          ),
          child: const Text('Release'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final qty = int.tryParse(qtyController.text.trim()) ?? 0;
  if (qty <= 0 || qty > product.stockQty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid quantity')),
    );
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
        actionType: "Inventory Move",
        description: "${product.name}: released $unitsSummary despite expired-stock warning",
      );
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Released $qty ${product.unit} of ${product.name} to shop',
        ),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to release product: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
