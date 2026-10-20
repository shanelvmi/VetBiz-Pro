import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../utils/activity_logger.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/activity_type.dart';
import '../../config/money.dart';
import '../../l10n/l10n.dart';
import '../../config/app_rules.dart';
import '../../config/app_date_format.dart';
import '../../services/trash_service.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../ui/feedback/restore_feedback.dart';

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
        title: Text(context.l10n.activityType_trash),
        centerTitle: true,
        backgroundColor: context.colors.brandSurface,
        foregroundColor: context.colors.onBrandSurface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.onBrandSurface,
          labelColor: context.colors.onBrandSurface,
          unselectedLabelColor: context.colors.onBrandSurfaceMuted,
          tabs: [
            Tab(text: context.l10n.activityType_products),
            Tab(text: context.l10n.clients_title),
            Tab(text: context.l10n.common_serviceRecords),
            Tab(text: context.l10n.payments_typeSales),
            Tab(text: context.l10n.transactions_title),
          ],
        ),
      ),
      body: facilityId == null
          ? Center(child: Text(context.l10n.common_noFacilityDot))
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
                      // The title also goes into the saved activity description ("Permanently

                      // deleted: ..."), so it stays English.

                      titleBuilder: (data) {
                        final client = (data['clientName'] as String?) ?? 'Walk-in';
                        final amount = (data['totalAmount'] as num?) ?? 0;
                        return 'Sale - $client - ${Money.format(amount)}';
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
                        return '$label - ${Money.format(amount)}';
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

  // Sales and services restore with their stock, debt and balance (E2,
  // delete_restore.md), so no warning first; a refusal says why.
  TrashedRecord? get _record => liveCollection == Collections.sales
      ? TrashedRecord.sale
      : liveCollection == Collections.services
          ? TrashedRecord.service
          : null;

  Future<void> _restore(BuildContext context, String id, Map<String, dynamic> data) async {
    final record = _record;
    // Read before the await: a restored client must show in the Clients
    // list again (its pages are fetched once, E3).
    final clientProvider =
        liveCollection == Collections.clients ? Provider.of<ClientProvider>(context, listen: false) : null;
    try {
      final result = await TrashService.restore(
        facilityId: facilityId,
        trashCollection: trashCollection,
        liveCollection: liveCollection,
        id: id,
        data: data,
      );
      clientProvider?.refreshClientsList();

      if (record != null) {
        RestoreFeedback.restored(record, result);
      } else {
        AppFeedback.success(L10n.current.trash_restored);
      }
    } catch (e, st) {
      if (record != null) {
        RestoreFeedback.failed(record, e, st);
      } else {
        AppFeedback.error(L10n.current.trash_restoreFailed, error: e, stackTrace: st);
      }
    }
  }

  Future<void> _deleteForever(BuildContext context, String id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.trash_deleteForeverTitle),
        content: Text(context.l10n.trash_deleteForeverBody(label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.common_cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.trash_deleteForever, style: TextStyle(color: context.colors.danger)),
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
      AppFeedback.success(L10n.current.trash_deleted);
    } catch (e, st) {
      AppFeedback.error(L10n.current.trash_deleteFailed, error: e, stackTrace: st);
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
                Text(context.l10n.trash_empty, style: TextStyle(color: context.colors.textMuted)),
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
                        context.l10n.trash_expiringBanner(soonToExpireCount, _warningThresholdDays),
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
                      : (data['name'] as String?) ?? 'Untitled'; // also in the saved activity description: English
                  final deletedAt = data['deletedAt'] is Timestamp
                      ? (data['deletedAt'] as Timestamp).toDate()
                      : null;
                  final deletedBy = (data['deletedBy'] as String?) ?? context.l10n.common_unknown;
                  final remaining = _daysRemaining(deletedAt);

                  String expiryText;
                  Color expiryColor = context.colors.textMuted;
                  if (remaining == null) {
                    expiryText = '';
                  } else if (remaining <= 0) {
                    expiryText = context.l10n.trash_deletingSoon;
                    expiryColor = context.colors.dangerAccent;
                  } else if (remaining == 1) {
                    expiryText = context.l10n.trash_expiresTomorrow;
                    expiryColor = context.colors.dangerAccent;
                  } else if (remaining <= _warningThresholdDays) {
                    expiryText = context.l10n.trash_expiresIn(remaining);
                    expiryColor = context.colors.warningStrong;
                  } else {
                    expiryText = context.l10n.trash_expiresIn(remaining);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deletedAt != null
                                ? context.l10n.trash_deletedByOn(deletedBy, AppDateFormat.dateTime24.format(deletedAt))
                                : context.l10n.trash_deletedBy(deletedBy),
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
                            tooltip: context.l10n.common_restore,
                            onPressed: () => _restore(context, doc.id, data),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_forever, color: context.colors.dangerAccent),
                            tooltip: context.l10n.trash_deleteForever,
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
