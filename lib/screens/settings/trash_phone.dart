import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_date_format.dart';
import '../../data/collections.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/phone_list/phone_list_scaffold.dart';
import '../../widgets/phone_list/phone_quick_chips.dart';
import '../../widgets/phone_list/record_tile.dart';
import 'trash_actions.dart';
import 'trash_details_page.dart';

/// The five Trash listeners (the same queries as the tabs), opened once and
/// kept until the page closes; [restart] opens them again (pull to refresh,
/// Retry).
class _TrashFeed extends ChangeNotifier {
  _TrashFeed(this.firestore, this.facilityId) {
    _listen();
  }

  final FirebaseFirestore firestore;
  final String facilityId;
  final _subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final _byKind = <String, List<TrashItem>>{};
  Object? error;

  bool get loading => error == null && _byKind.length < trashKinds.length;

  /// Every kind together, newest first.
  List<TrashItem> get items => [for (final list in _byKind.values) ...list]
    ..sort((a, b) => (b.deletedAt ?? DateTime(0)).compareTo(a.deletedAt ?? DateTime(0)));

  void _listen() {
    for (final kind in trashKinds) {
      _subscriptions.add(firestore
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(kind.trashCollection)
          .orderBy('deletedAt', descending: true)
          .snapshots()
          .listen((s) {
        _byKind[kind.trashCollection] = [for (final d in s.docs) TrashItem(kind, d.id, d.data())];
        notifyListeners();
      }, onError: (Object e) {
        error = e;
        notifyListeners();
      }));
    }
  }

  void _cancel() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> restart() async {
    _cancel();
    _byKind.clear();
    error = null;
    notifyListeners();
    _listen();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}

/// PH8a: Trash on a phone, on the PH5a list pattern: every deleted record in
/// one list, newest first, two-line rows with the record type chip, quick
/// chips by type, search by title, the details as a full page with Restore
/// and Delete forever for admins.
class TrashPhoneList extends StatefulWidget {
  final String facilityId;
  final FirebaseFirestore firestore;
  final Future<Map<String, String>> Function() currentUserInfo;

  const TrashPhoneList({super.key, required this.facilityId, required this.firestore, required this.currentUserInfo});

  @override
  State<TrashPhoneList> createState() => _TrashPhoneListState();
}

class _TrashPhoneListState extends State<TrashPhoneList> {
  static const _all = 'All';

  late final _TrashFeed _feed = _TrashFeed(widget.firestore, widget.facilityId)..addListener(_changed);
  final _search = TextEditingController();
  String _query = '';
  String _kind = _all;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _feed.dispose();
    _search.dispose();
    super.dispose();
  }

  String _deletedLine(BuildContext context, TrashItem item) {
    final by = (item.data['deletedBy'] as String?) ?? context.l10n.common_unknown;
    final at = item.deletedAt;
    return at != null ? context.l10n.trash_deletedByOn(by, AppDateFormat.dateTime24.format(at)) : context.l10n.trash_deletedBy(by);
  }

  Future<void> _open(TrashItem item) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TrashDetailsPage(
          item: item,
          deletedLine: _deletedLine(context, item),
          facilityId: widget.facilityId,
          firestore: widget.firestore,
          currentUserInfo: widget.currentUserInfo,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final all = _feed.items;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final i in all)
        if ((_kind == _all || i.kind.trashCollection == _kind) && (q.isEmpty || i.title.toLowerCase().contains(q))) i,
    ];
    final soon = all.where((i) {
      final remaining = trashDaysRemaining(i.deletedAt);
      return remaining != null && remaining <= trashWarningThresholdDays;
    }).length;

    return PhoneListScaffold<TrashItem>(
      title: l.activityType_trash,
      menu: const [],
      searchController: _search,
      searchHint: l.common_search,
      onSearchChanged: (v) => setState(() => _query = v),
      onSearchClosed: () => setState(() => _query = ''),
      quickChips: PhoneQuickChips(
        values: [_all, for (final k in trashKinds) k.trashCollection],
        selected: _kind,
        label: (v) => v == _all ? l.common_all : trashKinds.firstWhere((k) => k.trashCollection == v).label(l),
        onSelected: (v) => setState(() => _kind = v),
      ),
      filtersActive: false,
      onFilter: null,
      appliedFilters: const [],
      summaryLine: null,
      onSummary: () {},
      banner: soon == 0
          ? null
          : Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: AppAlpha.a10),
                border: Border.all(color: colors.warning),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.warning, size: AppIconSize.i20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(l.trash_expiringBanner(soon, trashWarningThresholdDays),
                        style: const TextStyle(fontSize: PhoneListMetrics.subtitle, fontWeight: AppFontWeight.medium)),
                  ),
                ],
              ),
            ),
      items: shown,
      idOf: (i) => '${i.kind.trashCollection}/${i.id}',
      dateOf: (i) => i.deletedAt ?? DateTime(0),
      amountOf: (_) => 0,
      grouped: false,
      tileBuilder: (context, item, {required grouped}) {
        final type = item.kind.label(l);
        final deleted = _deletedLine(context, item);
        final (expiry, _) = trashExpiry(context, item.deletedAt);
        final remaining = trashDaysRemaining(item.deletedAt);
        return RecordTile(
          title: item.title,
          amount: '',
          details: [deleted, if (remaining != null && remaining <= trashWarningThresholdDays) expiry],
          status: RecordStatus(type, colors.primary),
          icon: item.kind.icon,
          colorSeed: item.kind.trashCollection,
          semanticsLabel: l.trash_rowSemantics(item.title, type, deleted),
          onTap: () => _open(item),
        );
      },
      loading: _feed.loading,
      error: _feed.error,
      onRetry: _feed.restart,
      emptyIcon: Icons.delete_outline,
      emptyText: l.trash_empty,
      hasMore: false,
      loadingMore: false,
      onLoadMore: () {},
      onRefresh: _feed.restart,
    );
  }
}

