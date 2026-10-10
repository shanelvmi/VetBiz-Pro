import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../utils/activity_logger.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/activity_type.dart';
import '../../config/money.dart';
import '../../config/app_rules.dart';
import '../../config/app_date_format.dart';
import '../../services/trash_service.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Trash'),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.onPrimary,
          labelColor: context.colors.onPrimary,
          unselectedLabelColor: context.colors.onPrimaryMuted,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Clients'),
            Tab(text: 'Service Records'),
            Tab(text: 'Sales'),
            Tab(text: 'Transactions'),
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
                      trashCollection: Collections.trashProducts,
                      liveCollection: Collections.products,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: Collections.trashClients,
                      liveCollection: Collections.clients,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: Collections.trashServices,
                      liveCollection: Collections.services,
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: Collections.trashSales,
                      liveCollection: Collections.sales,
                      titleBuilder: (data) {
                        final client = (data['clientName'] as String?) ?? 'Walk-in';
                        final amount = (data['totalAmount'] as num?) ?? 0;
                        return 'Sale - $client - ${Money.symbolWhole(amount)}';
                      },
                    ),
                    _TrashList(
                      facilityId: facilityId,
                      trashCollection: Collections.trashTransactions,
                      liveCollection: Collections.transactions,
                      titleBuilder: (data) {
                        final description = (data['description'] as String?) ?? '';
                        final type = (data['type'] as String?) ?? '';
                        final amount = (data['amount'] as num?) ?? 0;
                        final label = description.isNotEmpty ? description : (type.isNotEmpty ? type : 'Transaction');
                        return '$label - ${Money.symbolWhole(amount)}';
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
  final String Function(Map<String, dynamic> data)? titleBuilder;

  const _TrashList({
    required this.facilityId,
    required this.trashCollection,
    required this.liveCollection,
    this.titleBuilder,
  });

  /// What Restore will NOT put back, for the types whose delete changed
  /// more than the document itself (design-open-questions.md, "Trash and
  /// restore: books consistency"). Null where Restore is complete.
  /// Restore only moves the document back; these lines just say so before
  /// the user commits to it.
  ({String title, String body})? get _restoreWarning {
    if (liveCollection == Collections.sales) {
      return (
        title: 'Restore this sale?',
        body: 'The sale will be back in your sales list, but restoring will NOT change:\n'
            '• stock: the items stay back on the shelf, as they were put back when the sale was deleted\n'
            "• debt: the client's debt for this sale is not re-created\n"
            "• client balance: it stays as it is now\n\n"
            'Adjust these by hand if the sale really happened.',
      );
    }
    if (liveCollection == Collections.services) {
      return (
        title: 'Restore this service?',
        body: 'The service will be back in your services list, but restoring will NOT change:\n'
            '• stock: the items it used stay back in stock\n'
            "• debt: the client's debt for this service is not re-created\n"
            "• client balance: it stays as it is now\n"
            '• expenses: its expense transaction was deleted for good and does not come back\n\n'
            'Adjust these by hand if the service really happened.',
      );
    }
    return null;
  }

  Future<void> _restore(BuildContext context, String id, Map<String, dynamic> data) async {
    final warning = _restoreWarning;
    if (warning != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(warning.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.dialogSm),
            child: Text(warning.body),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await TrashService.restore(
        facilityId: facilityId,
        trashCollection: trashCollection,
        liveCollection: liveCollection,
        id: id,
        data: data,
      );

      AppFeedback.success('Item restored');
    } catch (e, st) {
      AppFeedback.error("Couldn't restore the item", error: e, stackTrace: st);
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
            child: Text('Delete Forever', style: TextStyle(color: context.colors.danger)),
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
      if (trashCollection == Collections.trashProducts) {
        final batchesSnap = await FirebaseFirestore.instance
            .collection(Collections.facilities)
            .doc(facilityId)
            .collection(Collections.products)
            .doc(id)
            .collection(Collections.batches)
            .get();
        for (final batchDoc in batchesSnap.docs) {
          await batchDoc.reference.delete();
        }
      }

      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(trashCollection)
          .doc(id)
          .delete();

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.trash.key,
        description: 'Permanently deleted: $label',
      );

      // A hard delete: plain success, no Undo (PHASE2_FEEDBACK_SPEC section 8).
      AppFeedback.success('Permanently deleted');
    } catch (e, st) {
      AppFeedback.error("Couldn't delete the item permanently", error: e, stackTrace: st);
    }
  }

  // Items within this many days of auto-purge trigger the warning banner.
  static const int _warningThresholdDays = 7;

  int? _daysRemaining(DateTime? deletedAt) {
    if (deletedAt == null) return null;
    final purgeDate = deletedAt.add(AppRules.trashRetention);
    return purgeDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(trashCollection)
          .orderBy('deletedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: context.colors.primary));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: AppIconSize.i56, color: context.colors.textDisabled),
                const SizedBox(height: AppSpacing.s12),
                Text('Trash is empty', style: TextStyle(color: context.colors.textMuted)),
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
                margin: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 0),
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: AppAlpha.a10),
                  border: Border.all(color: context.colors.warning),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: AppIconSize.i20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        '$soonToExpireCount item${soonToExpireCount == 1 ? '' : 's'} will be '
                        'permanently deleted within $_warningThresholdDays days. '
                        'Restore now if you still need ${soonToExpireCount == 1 ? 'it' : 'them'}.',
                        style: const TextStyle(fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.medium),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s12),
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
                  Color expiryColor = context.colors.textMuted;
                  if (remaining == null) {
                    expiryText = '';
                  } else if (remaining <= 0) {
                    expiryText = 'Deleting soon';
                    expiryColor = context.colors.dangerAccent;
                  } else if (remaining == 1) {
                    expiryText = 'Expires tomorrow';
                    expiryColor = context.colors.dangerAccent;
                  } else if (remaining <= _warningThresholdDays) {
                    expiryText = 'Expires in $remaining days';
                    expiryColor = context.colors.warningStrong;
                  } else {
                    expiryText = 'Expires in $remaining days';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deleted by $deletedBy'
                            '${deletedAt != null ? ' on ${AppDateFormat.dateTime24.format(deletedAt)}' : ''}',
                            style: const TextStyle(fontSize: AppFontSize.f12),
                          ),
                          if (expiryText.isNotEmpty)
                            Text(
                              expiryText,
                              style: TextStyle(fontSize: AppFontSize.f11_5, color: expiryColor, fontWeight: AppFontWeight.semibold),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.restore, color: context.colors.primary),
                            tooltip: 'Restore',
                            onPressed: () => _restore(context, doc.id, data),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_forever, color: context.colors.dangerAccent),
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
