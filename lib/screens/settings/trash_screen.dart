import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../utils/activity_logger.dart';
import '../../data/collections.dart';
import '../../l10n/l10n.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import 'trash_actions.dart';

class TrashScreen extends StatefulWidget {
  // Null: the app's own Firestore and signed-in person. Tests pass fakes
  // (PH8a seams; no behaviour change).
  final FirebaseFirestore? firestore;
  final Future<Map<String, String>> Function()? currentUserInfo;

  const TrashScreen({super.key, this.firestore, this.currentUserInfo});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: trashKinds.length, vsync: this);
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
    final firestore = widget.firestore ?? FirebaseFirestore.instance;
    final currentUserInfo = widget.currentUserInfo ?? ActivityLogger.getCurrentUserInfo;

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
          tabs: [for (final kind in trashKinds) Tab(text: kind.label(context.l10n))],
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
                    for (final kind in trashKinds)
                      _TrashList(
                        facilityId: facilityId,
                        firestore: firestore,
                        currentUserInfo: currentUserInfo,
                        kind: kind,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TrashList extends StatefulWidget {
  final String facilityId;
  final FirebaseFirestore firestore;
  final Future<Map<String, String>> Function() currentUserInfo;
  final TrashKind kind;

  const _TrashList({
    required this.facilityId,
    required this.firestore,
    required this.currentUserInfo,
    required this.kind,
  });

  @override
  State<_TrashList> createState() => _TrashListState();
}

class _TrashListState extends State<_TrashList> {
  // PH8a (S9, the DASH-1 lesson): made once. A stream made in build() was a
  // new listener on every rebuild of the tab.
  late final Stream<QuerySnapshot> _stream = widget.firestore
      .collection(Collections.facilities)
      .doc(widget.facilityId)
      .collection(widget.kind.trashCollection)
      .orderBy('deletedAt', descending: true)
      .snapshots();

  Future<void> _restore(String id, Map<String, dynamic> data) => restoreTrashed(
        firestore: widget.firestore,
        currentUserInfo: widget.currentUserInfo,
        facilityId: widget.facilityId,
        kind: widget.kind,
        id: id,
        data: data,
      );

  Future<void> _deleteForever(BuildContext context, String id, String label) => deleteTrashedForever(
        context,
        firestore: widget.firestore,
        currentUserInfo: widget.currentUserInfo,
        facilityId: widget.facilityId,
        trashCollection: widget.kind.trashCollection,
        id: id,
        label: label,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
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
          final remaining = trashDaysRemaining(deletedAt);
          return remaining != null && remaining <= trashWarningThresholdDays;
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
                        context.l10n.trash_expiringBanner(soonToExpireCount, trashWarningThresholdDays),
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
                  final name = widget.kind.titleOf(data);
                  final deletedAt = data['deletedAt'] is Timestamp
                      ? (data['deletedAt'] as Timestamp).toDate()
                      : null;
                  final deletedBy = (data['deletedBy'] as String?) ?? context.l10n.common_unknown;
                  final (expiryText, expiryColor) = trashExpiry(context, deletedAt);

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
                            onPressed: () => _restore(doc.id, data),
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
