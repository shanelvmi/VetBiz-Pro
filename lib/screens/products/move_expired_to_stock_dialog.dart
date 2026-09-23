import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';

const Color _primaryDeepGreen = Color(0xFF2F5D62);

/// Entry point from Products' "More actions" menu - finds this
/// product's expired batches that still hold sellable quantity, and
/// walks the admin through picking one and a quantity to pull back
/// into Stock Store. Only ever touches sellableQty on an already-
/// expired batch - never a fresh one, and never a whole product.
Future<void> showMoveExpiredToStockDialog(BuildContext context, {required Product product}) async {
  final batchesRef = FirebaseFirestore.instance
      .collection('facilities')
      .doc(product.facilityId)
      .collection('products')
      .doc(product.id)
      .collection('batches');

  final snap = await batchesRef.get();
  if (!context.mounted) return;

  final now = DateTime.now();
  final expiredBatches = snap.docs
      .map((doc) => ProductBatch.fromFirestore(doc.data(), doc.id, product.id))
      .where((b) => b.expiry != null && b.expiry!.isBefore(now) && b.sellableQty > 0)
      .toList()
    ..sort((a, b) => a.expiry!.compareTo(b.expiry!));

  if (expiredBatches.isEmpty) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Expired Stock on Shelf'),
        content: SizedBox(
          width: 320,
          child: Text(
            '${product.name} has no expired batches currently holding sellable stock - '
            'nothing here needs to move back to Stock Store.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final chosen = await _pickBatch(context, product, expiredBatches);
  if (chosen == null || !context.mounted) return;

  await _promptQuantityAndMove(context, product, chosen);
}

Future<ProductBatch?> _pickBatch(BuildContext context, Product product, List<ProductBatch> batches) async {
  // Skip straight to the quantity step when there's only one candidate -
  // no need to make someone pick from a list of one.
  if (batches.length == 1) return batches.first;

  return showDialog<ProductBatch>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Which Expired Batch?'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: batches.map((batch) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: Text(batch.batchNo?.isNotEmpty == true ? 'Batch ${batch.batchNo}' : 'Unlabeled batch'),
              subtitle: Text(
                'Expired ${DateFormat('dd MMM yyyy').format(batch.expiry!)} - '
                '${batch.sellableQty} ${product.unit} on shelf',
              ),
              onTap: () => Navigator.pop(ctx, batch),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  );
}

Future<void> _promptQuantityAndMove(BuildContext context, Product product, ProductBatch batch) async {
  final qtyController = TextEditingController(text: '${batch.sellableQty}');
  final notesController = TextEditingController();
  String? errorText;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Move to Stock'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product.name}${batch.batchNo?.isNotEmpty == true ? ' - Batch ${batch.batchNo}' : ''} '
                'expired ${DateFormat('dd MMM yyyy').format(batch.expiry!)}. '
                'Up to ${batch.sellableQty} ${product.unit} can move back to Stock Store.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to move (${product.unit})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: _primaryDeepGreen, foregroundColor: Colors.white),
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0 || qty > batch.sellableQty) {
                setDialogState(() => errorText = 'Enter a quantity up to ${batch.sellableQty}');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Move to Stock'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final qty = int.tryParse(qtyController.text.trim()) ?? 0;
  if (qty <= 0) return;

  try {
    await Provider.of<ProductProvider>(context, listen: false).moveExpiredBatchToStock(
      product,
      batch,
      qty,
      context,
      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $qty ${product.unit} back to Stock Store'), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move stock: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
