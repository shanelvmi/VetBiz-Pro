import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../utils/activity_logger.dart';
import '../../data/collections.dart';
import '../../l10n/l10n.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_layout.dart';
import '../../widgets/shell/page_header.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import 'trash_actions.dart';
import 'trash_phone.dart';
import '../../theme/polish_metrics.dart';
import '../../ui/polish/page_card.dart';
import '../../ui/polish/page_layout.dart';
import '../../ui/polish/filter_row.dart';
import '../../services/cursor_paginated_list_controller.dart';
import '../../widgets/paged_list_body.dart';
import '../../utils/app_clock.dart';
import '../../config/app_rules.dart';
import '../../config/app_ranges.dart';

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

  // UX7: the kind chosen in the wide FilterRow, and the ones built so far.
  int _kind = 0;
  final Set<int> _built = {0};

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
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final firestore = widget.firestore ?? FirebaseFirestore.instance;
    final currentUserInfo = widget.currentUserInfo ?? ActivityLogger.getCurrentUserInfo;

    // PH8a: a phone gets one list of every deleted record (the PH5a list
    // pattern); tablets and computers keep the five tabs.
    if (AppLayout.isPhone(context) && facilityId != null) {
      return TrashPhoneList(facilityId: facilityId, firestore: firestore, currentUserInfo: currentUserInfo);
    }

    // UX7 (owner, 2026-11-22): PC and tablet: the page header, then the five
    // kinds as the left-aligned FilterRow in the body (they were a TabBar
    // spread across the header), then the kind's table. Each list is built
    // the first time its kind is chosen, then kept (IndexedStack), as the
    // tabs kept theirs. (UX3 had the TabBar under the header.)
    if (!AppLayout.isPhone(context) && facilityId != null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: PageHeader(title: context.l10n.activityType_trash),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilterRow(
              values: [for (final k in trashKinds) k.trashCollection],
              selected: trashKinds[_kind].trashCollection,
              label: (c) => trashKinds.firstWhere((k) => k.trashCollection == c).label(context.l10n),
              keyPrefix: 'trashTab-',
              onSelected:
                  (c) => setState(() {
                    _kind = trashKinds.indexWhere((k) => k.trashCollection == c);
                    _built.add(_kind);
                  }),
            ),
            Expanded(
              child: IndexedStack(
                index: _kind,
                children: [
                  for (final (i, kind) in trashKinds.indexed)
                    _built.contains(i)
                        ? _TrashList(facilityId: facilityId, firestore: firestore, currentUserInfo: currentUserInfo, kind: kind)
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      // No facility selected: the bar and the tabs, as before.
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
      body:
          facilityId == null
              ? Center(child: Text(context.l10n.common_noFacilityDot))
              // UX6: the full content width (it was a 700 px centred column).
              : TabBarView(
                controller: _tabController,
                children: [
                  for (final kind in trashKinds)
                    _TrashList(facilityId: facilityId, firestore: firestore, currentUserInfo: currentUserInfo, kind: kind),
                ],
              ),
    );
  }
}

class _TrashList extends StatefulWidget {
  final String facilityId;
  final FirebaseFirestore firestore;
  final Future<Map<String, String>> Function() currentUserInfo;
  final TrashKind kind;

  const _TrashList({required this.facilityId, required this.firestore, required this.currentUserInfo, required this.kind});

  @override
  State<_TrashList> createState() => _TrashListState();
}

class _TrashListState extends State<_TrashList> {
  // PH8a (S9, the DASH-1 lesson): made once. A stream made in build() was a
  // new listener on every rebuild of the tab.
  // PAGE1: no stream of the whole trash any more: one cursor page at a time
  // (pageSize + 1), newest deleted first, and the soon-to-expire count is
  // one count() aggregate over the whole kind.
  CollectionReference<Map<String, dynamic>> get _collection => widget.firestore
      .collection(Collections.facilities)
      .doc(widget.facilityId)
      .collection(widget.kind.trashCollection);

  late final CursorPaginatedListController<QueryDocumentSnapshot<Map<String, dynamic>>> _pager =
      CursorPaginatedListController(
    fetchPage: ({required snapshotAt, required pageSize, startAfterDocument}) async {
      Query<Map<String, dynamic>> q = _collection.orderBy('deletedAt', descending: true);
      if (startAfterDocument != null) q = q.startAfterDocument(startAfterDocument);
      final snap = await q.limit(pageSize + 1).get();
      return CursorPage.fromDocs(snap.docs, pageSize, (d) => d);
    },
  );

  int _soonToExpireCount = 0;

  @override
  void initState() {
    super.initState();
    _pager.openSession(widget.kind.trashCollection);
    _loadSoonToExpire();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // trashDaysRemaining(deletedAt) <= trashWarningThresholdDays holds exactly
  // for the records deleted before this moment (whole days, as inDays).
  Future<void> _loadSoonToExpire() async {
    final cutoff = AppClock.now().subtract(AppRules.trashRetention).add(AppRanges.day * (trashWarningThresholdDays + 1));
    try {
      final agg = await _collection.where('deletedAt', isLessThan: Timestamp.fromDate(cutoff)).count().get();
      if (mounted) setState(() => _soonToExpireCount = agg.count ?? 0);
    } catch (e) {
      debugPrint('Could not count the trash expiring soon: $e');
    }
  }

  // The page and the count again after a restore or a delete (the stream
  // used to drop the row by itself).
  void _refresh() {
    _pager.refreshSession();
    _loadSoonToExpire();
  }

  Future<void> _restore(String id, Map<String, dynamic> data) async {
    final done = await restoreTrashed(
      firestore: widget.firestore,
      currentUserInfo: widget.currentUserInfo,
      facilityId: widget.facilityId,
      kind: widget.kind,
      id: id,
      data: data,
    );
    if (done && mounted) _refresh();
  }

  Future<void> _deleteForever(BuildContext context, String id, String label) async {
    final done = await deleteTrashedForever(
      context,
      firestore: widget.firestore,
      currentUserInfo: widget.currentUserInfo,
      facilityId: widget.facilityId,
      trashCollection: widget.kind.trashCollection,
      id: id,
      label: label,
    );
    if (done && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // PAGE1: the page, its bar, the skeleton, the error with Retry and the
    // empty state from PagedListBody; the banner counts the whole kind.
    return PagedListBody<QueryDocumentSnapshot<Map<String, dynamic>>>(
      controller: _pager,
      barEmptyText: context.l10n.trash_empty,
      empty: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: AppIconSize.i56, color: context.colors.textDisabled),
                const SizedBox(height: AppSpacing.s12),
                Text(context.l10n.trash_empty, style: TextStyle(color: context.colors.textMuted)),
              ],
            ),
          ),
      list: (docs) {
        final soonToExpireCount = _soonToExpireCount;

        // UX6: the PC/tablet card template: the full width, one flat card
        // holding a table (Name, Date, actions at the right), as the other
        // tables. Restore and Delete Forever are the same calls as before.
        return PageCardList(
          children: [
            if (soonToExpireCount > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: PolishMetrics.gapBetweenGroups),
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
            const SizedBox(height: PolishMetrics.gapBetweenGroups),
            PageCard(
              padding: null,
              child: Column(
                children: [
                  _headerRow(context),
                  for (final doc in docs) ...[
                    Divider(height: PolishMetrics.hairline, thickness: PolishMetrics.hairline, color: context.colors.divider),
                    _row(context, doc),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // UX7: the template table: Date and the actions are fixed columns, so
  // the date sits at one x on every row.
  Widget _headerRow(BuildContext context) =>
      PageTableRow.header(context, main: context.l10n.common_name, date: context.l10n.common_date, actions: context.l10n.common_actions);

  Widget _row(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = widget.kind.titleOf(data);
    final deletedAt = data['deletedAt'] is Timestamp ? (data['deletedAt'] as Timestamp).toDate() : null;
    final deletedBy = (data['deletedBy'] as String?) ?? context.l10n.common_unknown;
    final (expiryText, expiryColor) = trashExpiry(context, deletedAt);
    return PageTableRow(
      key: ValueKey('trash-row-${doc.id}'),
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: AppFontWeight.semibold)),
          Text(context.l10n.trash_deletedBy(deletedBy), style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      date: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deletedAt != null ? AppDateFormat.dateTime24.format(deletedAt) : '-', style: const TextStyle(fontSize: AppFontSize.f13)),
          if (expiryText.isNotEmpty)
            Text(expiryText, style: TextStyle(fontSize: AppFontSize.f12, color: expiryColor, fontWeight: AppFontWeight.semibold)),
        ],
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: TextButton.icon(
              key: ValueKey('trash-restore-${doc.id}'),
              onPressed: () => _restore(doc.id, data),
              icon: const Icon(Icons.restore, size: AppIconSize.i18),
              label: Text(context.l10n.common_restore),
              style: TextButton.styleFrom(minimumSize: const Size(0, AppSizes.minTapTarget)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_forever, color: context.colors.dangerAccent),
            tooltip: context.l10n.trash_deleteForever,
            onPressed: () => _deleteForever(context, doc.id, name),
          ),
        ],
      ),
    );
  }
}
