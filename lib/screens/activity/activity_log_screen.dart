import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/activity_log_retention.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/merged_query_stream.dart';
import '../../utils/text_sanitizer.dart';
import '../../widgets/firestore_error_view.dart';
import '../../theme/activity_type_style.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/app_motion.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../data/activity_type.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../config/app_limits.dart';
import '../../config/app_rules.dart';
import '../../config/app_date_format.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_sheet.dart';

class ActivityLogScreen extends StatefulWidget {
  final bool isModal;
  const ActivityLogScreen({super.key, this.isModal = false});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String selectedFilter = 'All';
  String searchQuery = '';

  // Always-visible, same layout pattern as the Notifications screen's
  // search box - to the left of the days filter, not tucked behind an
  // expandable AppBar icon.
  final TextEditingController _searchController = TextEditingController();

  // Drives the action-chip row's horizontal scroll - a plain
  // SingleChildScrollView supports click-drag on desktop by default,
  // but nothing maps mouse-wheel/trackpad scrolling to it, and there's
  // no visible affordance telling anyone drag-to-scroll is even
  // possible. This controller lets both be added explicitly.
  final ScrollController _chipScrollController = ScrollController();

  // One key per chip (keyed by its filter value: 'All' or an action
  // type), so tapping a chip that's only partially visible near the
  // edge can be scrolled fully into view on its own - rather than
  // requiring the user to figure out how to scroll at all first.
  final Map<String, GlobalKey> _chipKeys = {};

  GlobalKey _keyFor(String filterValue) =>
      _chipKeys.putIfAbsent(filterValue, () => GlobalKey());

  FacilityProvider? _facilityProvider;

  // How long logs are kept before auto-delete - configurable per
  // facility (Admin only), one of 14/30/60/90 days. Cached here once
  // fetched, rather than re-reading the facility doc on every build.
  // Null only ever means "not loaded yet, for display purposes" - the
  // actual cleanup run (_ensureInitializedForFacility) always waits
  // for _fetchRetentionDays to resolve before calling it, rather than
  // reading this field directly, so cleanup itself never sees a null
  // or stale value. Any facility that never explicitly set this
  // defaults to 90, same as before this setting existed.
  int? _retentionDays;
  String? _retentionLoadedForFacilityId;

  static const List<int> _retentionOptions = AppRules.activityLogRetentionOptions;
  static const int _defaultRetentionDays = AppRules.activityLogRetentionDefaultDays;

  // The log query itself - was previously rebuilt fresh inside build()
  // on every rebuild, which handed StreamBuilder a brand-new Stream
  // instance each time. StreamBuilder has no way to know that's "the
  // same query, still loading" rather than a genuinely new one, so it
  // reset to ConnectionState.waiting and re-showed the loading state
  // on every rebuild - the reported flicker while scrolling. Cached
  // here instead, created once per facilityId.
  Stream<List<LogDoc>>? _logStream;

  // Same fix as _logStream above, for the second place this file had
  // the identical bug: _buildActionSummary built its own `.snapshots()`
  // call inline, on every build() - including rebuilds that have
  // nothing to do with the summary itself (typing in search, picking a
  // filter chip) - so its StreamBuilder flickered to its own loading
  // state (a blank SizedBox.shrink()) and back on each one. Cached here
  // instead, created once per facilityId, exactly like _logStream.
  Stream<List<LogDoc>>? _actionSummaryStream;

  // Guards _cleanupOldLogs so it actually runs once per facility per
  // session, as its own comment already claimed - previously had no
  // guard at all, so it re-ran its Firestore query (and potential
  // batch delete) on every rebuild, each one racing _fetchRetentionDays
  // independently.
  String? _cleanupRanForFacilityId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    _facilityProvider!.addListener(_onFacilityChange);
  }

  @override
  void dispose() {
    _facilityProvider?.removeListener(_onFacilityChange);
    _searchController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _onFacilityChange() {
    if (!mounted) return;
    setState(() {
      selectedFilter = 'All';
      searchQuery = '';
      _searchController.clear();
      _retentionDays = null;
      _retentionLoadedForFacilityId = null;
      _logStream = null;
      _actionSummaryStream = null;
      _cleanupRanForFacilityId = null;
    });
  }

  /// Returns the resolved value so callers that need it immediately
  /// (cleanup, below) don't have to re-read _retentionDays afterward -
  /// previously, cleanup read that field straight away without waiting
  /// for this fetch to actually finish, so on a facility's first load
  /// each session it silently used the 90-day default instead of
  /// whatever was really configured, deleting nothing between the
  /// real cutoff and 90 days even when a shorter window was set.
  Future<int> _fetchRetentionDays(String facilityId) async {
    if (_retentionLoadedForFacilityId == facilityId) return _retentionDays ?? _defaultRetentionDays;
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).get();
      final configured = (doc.data()?['activityLogRetentionDays'] as num?)?.toInt();
      final resolved = (configured != null && _retentionOptions.contains(configured))
          ? configured
          : _defaultRetentionDays;
      if (mounted) {
        setState(() {
          _retentionDays = resolved;
          _retentionLoadedForFacilityId = facilityId;
        });
      }
      return resolved;
    } catch (e) {
      debugPrint('Could not load retention setting: $e');
      if (mounted) {
        setState(() {
          _retentionDays = _defaultRetentionDays;
          _retentionLoadedForFacilityId = facilityId;
        });
      }
      return _defaultRetentionDays;
    }
  }

  /// Everything that only needs to happen once per facility, not on
  /// every rebuild: loading the configured retention window, then (and
  /// only then) creating the log streams and running cleanup against it.
  ///
  /// The streams wait for the retention window because they are bounded by
  /// it - see [_buildStreams]. Creating them first and correcting them
  /// afterwards would flash logs from outside the window (everything up to
  /// the 90-day default) before settling.
  void _ensureInitializedForFacility(String facilityId, {required bool isAdmin}) {
    if (_cleanupRanForFacilityId == facilityId) return;
    _cleanupRanForFacilityId = facilityId;

    _fetchRetentionDays(facilityId).then((retentionDays) async {
      if (!mounted || _cleanupRanForFacilityId != facilityId) return;
      setState(() => _buildStreams(facilityId, retentionDays, isAdmin: isAdmin));
      // Tidying up old entries is the admin's job (it deletes, which only an
      // admin may do) - and it reads the WHOLE log to find them, which an
      // assistant can't.
      if (!isAdmin) return;
      try {
        await _cleanupOldLogs(facilityId, retentionDays);
      } catch (e) {
        // Background tidy-up: nothing to tell the user here, and the screen
        // is already correct without it because the streams hide anything
        // outside the window. (Deleting is what frees the storage.)
        debugPrint('Could not delete expired activity logs: $e');
      }
    });
  }

  /// Creates the two log streams, both limited to the retention window.
  ///
  /// Deleting expired logs is a separate, best-effort step (see
  /// [_cleanupOldLogs]) that depends on security rules, batch sizes and the
  /// network. Previously the screen showed whatever happened to still be in
  /// the database, so if that cleanup lagged or failed, logs from outside
  /// the "keep for N days" window stayed visible - the reported "set to 30
  /// days but still seeing 31 August". Bounding the query itself means the
  /// screen is always right, whether or not anything has been deleted yet.
  void _buildStreams(String facilityId, int retentionDays, {required bool isAdmin}) {
    final cutoff = Timestamp.fromDate(ActivityLogRetention.cutoffFor(retentionDays));
    final logs = FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).collection(Collections.activityLogs);

    // Newest first, inside the retention window.
    Query<Map<String, dynamic>> windowed(Query<Map<String, dynamic>> q) =>
        q.where('timestamp', isGreaterThanOrEqualTo: cutoff).orderBy('timestamp', descending: true);

    if (isAdmin) {
      _logStream = windowed(logs).limit(AppLimits.ledgerQueryCap).snapshots().map((s) => s.docs); // performance limit
      // The type counts in the summary row cover only what's visible, and no
      // longer read every log ever stored.
      _actionSummaryStream =
          logs.where('timestamp', isGreaterThanOrEqualTo: cutoff).snapshots().map((s) => s.docs);
      return;
    }

    // An ASSISTANT sees only what is theirs: what they did (userId) and what is
    // about them (targetUserId - "approved", "promoted"...). Not the admin
    // matters of the facility. Two questions, joined into one list - the
    // security rule only vouches for a query that pins one of these down, and
    // would refuse anything wider outright (see firestore.rules).
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final mine = [
      windowed(logs.where(Fields.userId, isEqualTo: uid)),
      windowed(logs.where('targetUserId', isEqualTo: uid)),
    ];
    _logStream = mergedLogStream(mine.map((q) => q.limit(AppLimits.ledgerQueryCap)).toList(), limit: AppLimits.ledgerQueryCap);
    _actionSummaryStream = mergedLogStream(mine);
  }

  Future<void> _showRetentionDialog(String facilityId) async {
    final current = _retentionDays ?? _defaultRetentionDays;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.facilities_keepLogsFor),
        content: SizedBox(
          width: 320,
          child: RadioGroup<int>(
            groupValue: current,
            onChanged: (val) => Navigator.pop(ctx, val),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _retentionOptions.map((days) {
                return RadioListTile<int>(
                  value: days,
                  activeColor: context.colors.primary,
                  title: Text(context.l10n.debtors_daysCount(days)),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_cancel)),
        ],
      ),
    );

    if (selected == null || selected == current) return;

    // Shrinking the window is the one direction that's actually
    // destructive - cleanup runs on this screen's next load using
    // whatever's now configured, so picking a shorter window deletes
    // everything outside it immediately, not just going forward.
    // Growing the window (e.g. 14 to 60) deletes nothing and doesn't
    // need this extra step.
    if (selected < current) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.facilities_deleteOlderLogsTitle),
          content: SizedBox(
            width: 360,
            child: Text(context.l10n.facilities_deleteOlderLogsMessage(current, selected)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.facilities_deleteAndSwitch(selected), style: TextStyle(color: context.colors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).set(
        {'activityLogRetentionDays': selected},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      // The screen follows the new window immediately - hiding what's now
      // outside it - whether or not the delete below succeeds.
      setState(() {
        _retentionDays = selected;
        // Only an admin can reach this dialog (it changes the facility's setting).
        _buildStreams(facilityId, selected, isAdmin: true);
      });
      // Explicit, rather than relying on the once-per-session cleanup in
      // _ensureInitializedForFacility, so shrinking the window deletes
      // right now, as promised in the confirmation above.
      var deleted = 0;
      String? problem;
      try {
        deleted = await _cleanupOldLogs(facilityId, selected);
      } catch (e) {
        problem = ActivityLogRetention.explainFailure(e);
      }
      if (!mounted) return;
      if (problem != null) {
        AppFeedback.warning(
          L10n.current.activity_retentionSavedHidden(selected),
          detail: L10n.current.activity_retentionNotDeletedDetail(problem),
        );
      } else if (deleted > 0) {
        AppFeedback.success(L10n.current.facilities_retentionSaved(selected),
            detail: L10n.current.activity_olderLogsDeleted(deleted));
      } else {
        AppFeedback.success(L10n.current.facilities_retentionSaved(selected));
      }
    } catch (e, st) {
      if (!mounted) return;
      AppFeedback.error(L10n.current.activity_saveRetentionFailed, error: e, stackTrace: st);
    }
  }

  // Deletes logs older than the retention window, returning how many were
  // removed. Throws if the delete fails (see ActivityLogRetention) - callers
  // decide what to tell the user. Takes the resolved retention value from
  // the caller rather than reading _retentionDays, so it can never see an
  // unset or stale one.
  Future<int> _cleanupOldLogs(String facilityId, int retentionDays) =>
      ActivityLogRetention.deleteExpired(facilityId, retentionDays);

  @override
  Widget build(BuildContext context) {
    final facilityProvider =
        Provider.of<FacilityProvider>(context, listen: false);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityId = selectedFacility?['id'];

    if (facilityId == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Text(context.l10n.export_activityLog, style: TextStyle(color: context.colors.textPrimary)),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          elevation: AppElevation.e1,
          centerTitle: true,
          automaticallyImplyLeading: !widget.isModal,
          leading: widget.isModal
              ? IconButton(
                  icon: Icon(Icons.close, color: context.colors.textPrimary),
                  tooltip: context.l10n.common_close,
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: Center(child: Text(context.l10n.common_noFacilityDot)),
      );
    }

    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Creates the stream and kicks off retention-loading/cleanup the
    // first time this facility is seen; a no-op on every rebuild after
    // that. Previously ran unconditionally on every single build() -
    // both recreating the stream (the reported flicker - a fresh
    // Stream instance resets StreamBuilder to "waiting" even though
    // it's the same query) and re-running cleanup redundantly, each
    // time racing the retention fetch independently.
    _ensureInitializedForFacility(facilityId, isAdmin: isAdmin);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // One unified summary that's also the filter - see
          // _buildActionSummary for the full reasoning.
          if (!isAdmin) _buildScopeNote(),
          _buildActionSummary(facilityId),

          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.activity_searchHint,
                      prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: AppSpacing.s12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val.trim()),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: AppSpacing.s8),
                  TextButton.icon(
                    onPressed: () => _showRetentionDialog(facilityId),
                    icon: const Icon(Icons.schedule_outlined, size: AppIconSize.i16),
                    label: Text(context.l10n.activity_keepingLogsFor(_retentionDays ?? _defaultRetentionDays)),
                    style: TextButton.styleFrom(foregroundColor: context.colors.primary, textStyle: const TextStyle(fontSize: AppFontSize.f12_5)),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Activity Log List
          Expanded(
            child: StreamBuilder<List<LogDoc>>(
              stream: _logStream,
              builder: (context, snapshot) {
                // Said out loud: a refused or not-yet-ready query used to fall
                // through to "No activity logs found", which looks like an
                // empty log rather than a problem.
                if (snapshot.hasError) {
                  return Center(child: FirestoreErrorView(error: snapshot.error));
                }
                // 'none' = the stream doesn't exist yet (still loading the
                // retention window) - show loading, not an empty list.
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                          size: AppIconSize.i64,
                          color: context.colors.textDisabled),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          context.l10n.activity_empty,
                          style: TextStyle(
                            fontSize: AppFontSize.f18,
                            color: context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          context.l10n.activity_autoDeleteAfter(_retentionDays ?? _defaultRetentionDays),
                          style: TextStyle(
                            fontSize: AppFontSize.f14,
                            color: context.colors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter logs
                final logs = snapshot.data!.where((doc) {
                  final data = doc.data();
                  final actionType = ActivityType.canonicalKey((data['actionType'] ?? '').toString());
                  final description = data['description'] ?? '';

                  final matchesType = selectedFilter == 'All' ||
                      actionType.toLowerCase() ==
                          selectedFilter.toLowerCase();
                  final matchesSearch =
                      description.toLowerCase().contains(searchQuery.toLowerCase());

                  return matchesType && matchesSearch;
                }).toList();

                if (logs.isEmpty) {
                  return Center(
                    child: Text(context.l10n.activity_noMatch),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                        final data = logs[index].data();
                        final user = data['userName'] ?? context.l10n.common_unknown;
                        final action = sanitizeForDisplay(data['description'] ?? '');
                        final type = data['actionType'] ?? '';
                        final timestamp = data['timestamp'];
                        String dateStr = '';
                        if (timestamp != null && timestamp is Timestamp) {
                          dateStr = AppDateFormat.dateTime24Seconds
                              .format(timestamp.toDate().toLocal());
                        }

                        final actionColor = ActivityTypeStyle.color(type, context.colors);
                        final actionIcon = ActivityTypeStyle.icon(type);

                        return Card(
                          elevation: AppElevation.e2,
                          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.r8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: actionColor.withValues(alpha: AppAlpha.a20),
                                  child: Icon(
                                    actionIcon,
                                    color: actionColor,
                                    size: AppIconSize.i20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action,
                                        style: const TextStyle(
                                          fontSize: AppFontSize.f14,
                                          fontWeight: AppFontWeight.medium,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.s4),
                                      Row(
                                        children: [
                                          Icon(Icons.person,
                                            size: AppIconSize.i14,
                                            color: context.colors.textMuted),
                                          const SizedBox(width: AppSpacing.s4),
                                          Text(
                                            user,
                                            style: TextStyle(
                                              fontSize: AppFontSize.f12,
                                              color: context.colors.textSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s16),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time,
                                        size: AppIconSize.i14,
                                        color: context.colors.textMuted),
                                      const SizedBox(width: AppSpacing.s4),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: AppFontSize.f11,
                                          color: context.colors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s8,
                                    vertical: AppSpacing.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: actionColor.withValues(alpha: AppAlpha.a10),
                                    borderRadius: BorderRadius.circular(AppRadius.r12),
                                    border: Border.all(
                                      color: actionColor.withValues(alpha: AppAlpha.a30),
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.activityTypeLabel(type),
                                    style: TextStyle(
                                      fontSize: AppFontSize.f11,
                                      fontWeight: AppFontWeight.semibold,
                                      color: actionColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
              },
            ),
          ),
        ],
          ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      automaticallyImplyLeading: !widget.isModal,
      leading: widget.isModal
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.common_close,
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.l10n.export_activityLog, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text(context.l10n.activity_subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
    );
  }

  // A single thin line - just the numbers, no card, no gradient, no
  // padding-heavy container. Previously this was a large gradient
  // card sitting above the filters, above the list - between it and
  // two dropdowns and a search field, real data didn't start until
  // well down the screen. This is meant to read as a subtitle to the
  // list, not compete with it.
  // Merges what were two separate rows (a stats line, then a chip
  // row) into one - each chip is both a count and a filter, so
  // tapping "Products · 8" both shows you the number and narrows the
  // list to it. Wrapped in a light tint to still read as "the
  // summary," not just a generic filter row. Only ever shows action
  // types that actually have at least one log - a facility that's
  // never had, say, Debtors activity doesn't get a useless "Debtors ·
  // 0" chip cluttering the row.
  void _selectFilterAndScrollIntoView(String filterValue) {
    setState(() => selectedFilter = filterValue);
    final key = _chipKeys[filterValue];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: AppMotion.normal,
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    }
  }

  // Said plainly, so a short log isn't mistaken for a broken one.
  Widget _buildScopeNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s10, AppSpacing.s12, 0),
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: context.colors.info.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: context.colors.info.withValues(alpha: AppAlpha.a20)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: AppIconSize.i16, color: context.colors.infoStrong),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              context.l10n.activity_scopeNote,
              style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.infoDeep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSummary(String facilityId) {
    return StreamBuilder<List<LogDoc>>(
      stream: _actionSummaryStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!;
        final totalLogs = docs.length;

        final typeCounts = <String, int>{};
        for (final doc in docs) {
          // 'Unknown' is a grouping key the chip filters on (a stand-in for a
          // stored type), so it stays English, like any unlisted stored type.
          final type =ActivityType.canonicalKey((doc['actionType'] ?? 'Unknown').toString());
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        // Most-active types first - the most useful ordering for an
        // at-a-glance summary that's also a filter.
        final sortedTypes = typeCounts.keys.toList()
          ..sort((a, b) => typeCounts[b]!.compareTo(typeCounts[a]!));

        return Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s10, AppSpacing.s12, AppSpacing.s6),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: AppAlpha.a05),
            borderRadius: BorderRadius.circular(AppRadius.r10),
          ),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Listener(
                // Maps mouse-wheel/trackpad scrolling (which arrives
                // as a vertical delta) onto this row's horizontal
                // scroll - without this, scrolling over the chips with
                // a wheel or trackpad does nothing at all, since this
                // view only scrolls horizontally by default.
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && _chipScrollController.hasClients) {
                    final target = _chipScrollController.offset + event.scrollDelta.dy;
                    _chipScrollController.jumpTo(
                      target.clamp(0.0, _chipScrollController.position.maxScrollExtent),
                    );
                  }
                },
                child: Scrollbar(
                  controller: _chipScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                controller: _chipScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: ChoiceChip(
                        key: _keyFor('All'),
                        label: Text(context.l10n.activity_filterChip(context.l10n.common_all, totalLogs)),
                        selected: selectedFilter == 'All',
                        onSelected: (_) => _selectFilterAndScrollIntoView('All'),
                        selectedColor: context.colors.accent,
                        labelStyle: selectedFilter == 'All' ? TextStyle(color: context.colors.onAccentChip) : null,
                        checkmarkColor: context.colors.onAccentChip,
                      ),
                    ),
                    ...sortedTypes.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.s8),
                        child: ChoiceChip(
                          key: _keyFor(type),
                          // Shows the label; the chip filters on the stored type.
                          label: Text(context.l10n.activity_filterChip(context.l10n.activityTypeLabel(type), typeCounts[type]!)),
                          selected: selectedFilter == type,
                          onSelected: (_) => _selectFilterAndScrollIntoView(type),
                          selectedColor: context.colors.accent,
                          labelStyle: selectedFilter == type ? TextStyle(color: context.colors.onAccentChip) : null,
                          checkmarkColor: context.colors.onAccentChip,
                        ),
                      );
                    }),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The one entry point for opening Activity Log - decides between a
/// full-screen push (mobile, where there's no spare room for an
/// overlay to breathe) and a large, centered, dismissable modal
/// (desktop/tablet-width screens, where staying visually anchored to
/// the Dashboard underneath reads as "secondary and dismissable"
/// rather than "navigated away from"). Same threshold already used
/// elsewhere in this app for "is this desktop-width".
Future<void> showActivityLog(BuildContext context) async {
  await showAdaptiveForm(
    context,
    barrierLabel: context.l10n.export_activityLog,
    size: AdaptiveFormSize.activityLog,
    builder: (isModal) => ActivityLogScreen(isModal: isModal),
  );
}
