import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../providers/facility_provider.dart';
import '../../utils/activity_logger.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Trash'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Clients'),
            Tab(text: 'Service Records'),
            Tab(text: 'Sales'),
          ],
        ),
      ),
      body: facilityId == null
          ? const Center(child: Text('No facility selected.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: 'trash_products',
                      liveCollection: 'products',
                      primaryColor: primaryColor,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: 'trash_clients',
                      liveCollection: 'clients',
                      primaryColor: primaryColor,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: 'trash_services',
                      liveCollection: 'services',
                      primaryColor: primaryColor,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: 'trash_sales',
                      liveCollection: 'sales',
                      primaryColor: primaryColor,
                      titleBuilder: (data) {
                        final client = (data['clientName'] as String?) ?? 'Walk-in';
                        final amount = (data['totalAmount'] as num?) ?? 0;
                        return 'Sale - $client - Tsh ${amount.toStringAsFixed(0)}';
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TrashList extends StatelessWidget {
  final String facilityId;
  final String trashCollection;
  final String liveCollection;
  final Color primaryColor;
  final String Function(Map<String, dynamic> data)? titleBuilder;

  const _TrashList({
    required this.facilityId,
    required this.trashCollection,
    required this.liveCollection,
    required this.primaryColor,
    this.titleBuilder,
  });

  Future<void> _restore(BuildContext context, String id, Map<String, dynamic> data) async {
    final restoredData = Map<String, dynamic>.from(data)
      ..remove('deletedAt')
      ..remove('deletedBy');

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    batch.set(
      firestore
          .collection('facilities')
          .doc(facilityId)
          .collection(liveCollection)
          .doc(id),
      restoredData,
    );
    batch.delete(
      firestore
          .collection('facilities')
          .doc(facilityId)
          .collection(trashCollection)
          .doc(id),
    );

    try {
      await batch.commit();

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Trash',
        description: 'Restored ${data['name'] ?? data['clientName'] ?? liveCollection}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteForever(BuildContext context, String id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text('"$label" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // A trashed product's batches subcollection is never touched when
      // it was trashed (Firestore doesn't cascade-delete subcollections)
      // - it just sits there, dangling, at the same path. Restoring the
      // product later reconnects to it automatically, which is fine -
      // but permanently deleting it needs to clean this up explicitly,
      // or it's orphaned in Firestore forever with nothing left pointing
      // to it.
      if (trashCollection == 'trash_products') {
        final batchesSnap = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('products')
            .doc(id)
            .collection('batches')
            .get();
        for (final batchDoc in batchesSnap.docs) {
          await batchDoc.reference.delete();
        }
      }

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection(trashCollection)
          .doc(id)
          .delete();

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Trash',
        description: 'Permanently deleted: $label',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permanently deleted'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete permanently: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Must match TRASH_RETENTION_DAYS in functions/index.js.
  static const int _retentionDays = 30;
  // Items within this many days of auto-purge trigger the warning banner.
  static const int _warningThresholdDays = 7;

  int? _daysRemaining(DateTime? deletedAt) {
    if (deletedAt == null) return null;
    final purgeDate = deletedAt.add(const Duration(days: _retentionDays));
    return purgeDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection(trashCollection)
          .orderBy('deletedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Trash is empty', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final soonToExpireCount = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final deletedAt = data['deletedAt'] is Timestamp
              ? (data['deletedAt'] as Timestamp).toDate()
              : null;
          final remaining = _daysRemaining(deletedAt);
          return remaining != null && remaining <= _warningThresholdDays;
        }).length;

        return Column(
          children: [
            if (soonToExpireCount > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$soonToExpireCount item${soonToExpireCount == 1 ? '' : 's'} will be '
                        'permanently deleted within $_warningThresholdDays days. '
                        'Restore now if you still need ${soonToExpireCount == 1 ? 'it' : 'them'}.',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = titleBuilder != null
                      ? titleBuilder!(data)
                      : (data['name'] as String?) ?? 'Untitled';
                  final deletedAt = data['deletedAt'] is Timestamp
                      ? (data['deletedAt'] as Timestamp).toDate()
                      : null;
                  final deletedBy = (data['deletedBy'] as String?) ?? 'Unknown';
                  final remaining = _daysRemaining(deletedAt);

                  String expiryText;
                  Color expiryColor = Colors.grey[600]!;
                  if (remaining == null) {
                    expiryText = '';
                  } else if (remaining <= 0) {
                    expiryText = 'Deleting soon';
                    expiryColor = Colors.redAccent;
                  } else if (remaining == 1) {
                    expiryText = 'Expires tomorrow';
                    expiryColor = Colors.redAccent;
                  } else if (remaining <= _warningThresholdDays) {
                    expiryText = 'Expires in $remaining days';
                    expiryColor = Colors.orange[800]!;
                  } else {
                    expiryText = 'Expires in $remaining days';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deleted by $deletedBy'
                            '${deletedAt != null ? ' on ${DateFormat('dd MMM yyyy, HH:mm').format(deletedAt)}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (expiryText.isNotEmpty)
                            Text(
                              expiryText,
                              style: TextStyle(fontSize: 11.5, color: expiryColor, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.restore, color: primaryColor),
                            tooltip: 'Restore',
                            onPressed: () => _restore(context, doc.id, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            tooltip: 'Delete Forever',
                            onPressed: () => _deleteForever(context, doc.id, name),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
