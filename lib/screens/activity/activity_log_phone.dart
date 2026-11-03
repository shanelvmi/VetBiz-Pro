part of 'activity_log_screen.dart';

// PH8a: the Activity log on a phone, on the PH5a list pattern
// (docs/design/phone_list_pattern.md): the same two streams, the same type
// filter and search, the same retention setting as the wider log; only the
// layout differs.

extension _ActivityLogPhone on _ActivityLogScreenState {
  /// How many entries of each type the summary stream holds, most first; the
  /// chips and the Filter sheet offer exactly these (as the wide chip row).
  (int, List<String>, Map<String, int>) _typeCounts(List<LogDoc> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      // 'Unknown' is a grouping key the chip filters on (a stand-in for a
      // stored type), so it stays English, like any unlisted stored type.
      final type = ActivityType.canonicalKey((doc['actionType'] ?? 'Unknown').toString());
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final types = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return (docs.length, types, counts);
  }

  DateTime _when(LogDoc doc) {
    final t = doc.data()['timestamp'];
    return t is Timestamp ? t.toDate().toLocal() : DateTime(0);
  }

  Widget _buildPhone(String facilityId, {required bool isAdmin}) {
    final l = context.l10n;
    return StreamBuilder<List<LogDoc>>(
      stream: _actionSummaryStream,
      builder: (context, summary) => StreamBuilder<List<LogDoc>>(
        stream: _logStream,
        builder: (context, snapshot) {
          final (total, types, counts) = _typeCounts(summary.data ?? const []);
          String typeName(String v) => v == 'All' ? l.common_all : l.activityTypeLabel(v);
          final values = ['All', ...types];
          final logs = (snapshot.data ?? const <LogDoc>[]).where(_matchesFilters).toList();
          final days = _retentionDays ?? _ActivityLogScreenState._defaultRetentionDays;
          return PhoneListScaffold<LogDoc>(
            title: l.export_activityLog,
            asTab: false,
            menu: [
              if (isAdmin)
                PhoneListMenuItem(
                  label: l.activity_keepingLogsFor(days),
                  icon: Icons.schedule_outlined,
                  onSelected: () => _showRetentionDialog(facilityId),
                ),
            ],
            searchController: _searchController,
            searchHint: l.activity_searchHint,
            onSearchChanged: (v) => _setPhone(() => searchQuery = v.trim()),
            onSearchClosed: () => _setPhone(() {
              searchQuery = '';
              _searchController.clear();
            }),
            quickChips: PhoneQuickChips(
              values: values,
              selected: values.contains(selectedFilter) ? selectedFilter : 'All',
              label: (v) => l.activity_filterChip(typeName(v), v == 'All' ? total : counts[v]!),
              onSelected: (v) => _setPhone(() => selectedFilter = v),
            ),
            filtersActive: selectedFilter != 'All',
            onFilter: () async {
              final applied = await showPhoneFilterSheet(
                context,
                fields: {
                  'type': PhoneFilterField(title: l.common_type, options: values, label: typeName, defaultValue: 'All'),
                },
                values: {'type': values.contains(selectedFilter) ? selectedFilter : 'All'},
              );
              if (applied != null) _setPhone(() => selectedFilter = applied['type']!);
            },
            appliedFilters: const [],
            summaryLine: null,
            onSummary: () {},
            banner: isAdmin ? null : _buildScopeNote(),
            items: logs,
            idOf: (d) => d.id,
            dateOf: _when,
            amountOf: (_) => 0,
            grouped: true,
            dayTotals: false,
            tileBuilder: (context, doc, {required grouped}) => _phoneRow(context, doc),
            loading: snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none,
            error: snapshot.error,
            onRetry: () => _setPhone(() {
              _cleanupRanForFacilityId = null;
              _logStream = null;
              _actionSummaryStream = null;
            }),
            emptyIcon: Icons.history,
            emptyText: (snapshot.data ?? const []).isEmpty ? l.activity_empty : l.activity_noMatch,
            hasMore: false,
            loadingMore: false,
            onLoadMore: () {},
            // Live streams: a pull only waits a moment, as the wide log has no
            // refresh either.
            onRefresh: () async {},
          );
        },
      ),
    );
  }

  // ignore: invalid_use_of_protected_member
  void _setPhone(VoidCallback change) => setState(change);

  Widget _phoneRow(BuildContext context, LogDoc doc) {
    final l = context.l10n;
    final data = doc.data();
    final user = (data['userName'] ?? l.common_unknown).toString();
    final action = sanitizeForDisplay(data['description'] ?? '');
    final type = (data['actionType'] ?? '').toString();
    final time = AppDateFormat.time24.format(_when(doc));
    final typeLabel = l.activityTypeLabel(type);
    return RecordTile(
      title: user,
      amount: time,
      details: [action],
      status: RecordStatus(typeLabel, ActivityTypeStyle.color(type, context.colors)),
      icon: ActivityTypeStyle.icon(type),
      colorSeed: type,
      semanticsLabel: l.activity_rowSemantics(user, action, typeLabel, time),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ActivityDetailsPage(doc: doc))),
    );
  }
}

/// One entry in full, on a phone (R7): what was done, its type, who did it
/// and when (to the second, as the wide log).
class _ActivityDetailsPage extends StatelessWidget {
  final LogDoc doc;

  const _ActivityDetailsPage({required this.doc});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final data = doc.data();
    final type = (data['actionType'] ?? '').toString();
    final timestamp = data['timestamp'];
    final color = ActivityTypeStyle.color(type, colors);
    final secondary = TextStyle(fontSize: PhoneListMetrics.subtitle, color: colors.textSoft);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(l.common_details)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Row(
            children: [
              Icon(ActivityTypeStyle.icon(type), color: color),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text(l.activityTypeLabel(type), style: TextStyle(fontSize: PhoneListMetrics.subtitle, color: color))),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(sanitizeForDisplay(data['description'] ?? ''),
              style: const TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.medium)),
          const SizedBox(height: AppSpacing.s12),
          Row(children: [
            Icon(Icons.person, size: AppIconSize.i16, color: colors.textMuted),
            const SizedBox(width: AppSpacing.s6),
            Expanded(child: Text((data['userName'] ?? l.common_unknown).toString(), style: secondary)),
          ]),
          if (timestamp is Timestamp) ...[
            const SizedBox(height: AppSpacing.s6),
            Row(children: [
              Icon(Icons.access_time, size: AppIconSize.i16, color: colors.textMuted),
              const SizedBox(width: AppSpacing.s6),
              Expanded(child: Text(AppDateFormat.dateTime24Seconds.format(timestamp.toDate().toLocal()), style: secondary)),
            ]),
          ],
        ],
      ),
    );
  }
}
