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
import '../../theme/app_palette.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../config/app_limits.dart';
import '../../config/app_rules.dart';
import '../../config/app_date_format.dart';

class ActivityLogScreen extends StatefulWidget {
  final bool isModal;
  const ActivityLogScreen({super.key, this.isModal = false});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final Color primaryDeepGreen = AppPalette.primary;
  final Color warmAmber = AppPalette.accent;
  final Color offWhite = AppPalette.background;

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
  String? _logStreamFacilityId;

  // Same fix as _logStream above, for the second place this file had
  // the identical bug: _buildActionSummary built its own `.snapshots()`
  // call inline, on every build() - including rebuilds that have
  // nothing to do with the summary itself (typing in search, picking a
  // filter chip) - so its StreamBuilder flickered to its own loading
  // state (a blank SizedBox.shrink()) and back on each one. Cached here
  // instead, created once per facilityId, exactly like _logStream.
  Stream<List<LogDoc>>? _actionSummaryStream;
  String? _actionSummaryStreamFacilityId;

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
      _logStreamFacilityId = null;
      _actionSummaryStream = null;
      _actionSummaryStreamFacilityId = null;
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

    _logStreamFacilityId = facilityId;
    _actionSummaryStreamFacilityId = facilityId;

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
        title: const Text('Keep Logs For'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _retentionOptions.map((days) {
              return RadioListTile<int>(
                value: days,
                groupValue: current,
                activeColor: primaryDeepGreen,
                title: Text('$days days'),
                onChanged: (val) => Navigator.pop(ctx, val),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Older Logs Now?'),
          content: SizedBox(
            width: 360,
            child: Text(
              'Logs are currently kept for $current days. Switching to $selected days '
              'will permanently delete every log older than $selected days right now - '
              'not just going forward. This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete and switch to $selected days', style: const TextStyle(color: Colors.red)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(problem != null
              ? 'Saved - logs older than $selected days are now hidden, but could not be deleted yet: $problem'
              : deleted > 0
                  ? 'Logs will now be kept for $selected days - $deleted older log${deleted == 1 ? '' : 's'} deleted'
                  : 'Logs will now be kept for $selected days'),
          backgroundColor: problem != null ? Colors.orange.shade800 : Colors.green,
          duration: Duration(seconds: problem != null ? 7 : 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Deletes logs older than the retention window, returning how many were
  // removed. Throws if the delete fails (see ActivityLogRetention) - callers
  // decide what to tell the user. Takes the resolved retention value from
  // the caller rather than reading _retentionDays, so it can never see an
  // unset or stale one.
  Future<int> _cleanupOldLogs(String facilityId, int retentionDays) =>
      ActivityLogRetention.deleteExpired(facilityId, retentionDays);

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'transactions':
        return Icons.receipt_long;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'inventory move':
        return Colors.blue;
      case 'products':
        return Colors.green;
      case 'sales':
        return warmAmber;
      case 'services':
        return Colors.purple;
      case 'transactions':
        return Colors.indigo;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      case 'admin':
        return Colors.red;
      default:
        return primaryDeepGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider =
        Provider.of<FacilityProvider>(context, listen: false);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityId = selectedFacility?['id'];

    if (facilityId == null) {
      return Scaffold(
        backgroundColor: offWhite,
        appBar: AppBar(
          title: const Text('Activity Log', style: TextStyle(color: Colors.black87)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          centerTitle: true,
          automaticallyImplyLeading: !widget.isModal,
          leading: widget.isModal
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: const Center(child: Text('No facility selected.')),
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
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // One unified summary that's also the filter - see
          // _buildActionSummary for the full reasoning.
          if (!isAdmin) _buildScopeNote(),
          _buildActionSummary(facilityId),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val.trim()),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showRetentionDialog(facilityId),
                    icon: const Icon(Icons.schedule_outlined, size: 16),
                    label: Text('Keeping logs for ${_retentionDays ?? _defaultRetentionDays} days'),
                    style: TextButton.styleFrom(foregroundColor: primaryDeepGreen, textStyle: const TextStyle(fontSize: 12.5)),
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
                      color: primaryDeepGreen,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                          size: 64,
                          color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No activity logs found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Logs auto-delete after ${_retentionDays ?? _defaultRetentionDays} days',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter logs
                final logs = snapshot.data!.where((doc) {
                  final data = doc.data();
                  final actionType = data['actionType'] ?? '';
                  final description = data['description'] ?? '';

                  final matchesType = selectedFilter == 'All' ||
                      actionType.toString().toLowerCase() ==
                          selectedFilter.toLowerCase();
                  final matchesSearch =
                      description.toLowerCase().contains(searchQuery.toLowerCase());

                  return matchesType && matchesSearch;
                }).toList();

                if (logs.isEmpty) {
                  return const Center(
                    child: Text('No logs match the selected filters.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                        final data = logs[index].data();
                        final user = data['userName'] ?? 'Unknown';
                        final action = sanitizeForDisplay(data['description'] ?? '');
                        final type = data['actionType'] ?? '';
                        final timestamp = data['timestamp'];
                        String dateStr = '';
                        if (timestamp != null && timestamp is Timestamp) {
                          dateStr = AppDateFormat.dateTime24Seconds
                              .format(timestamp.toDate().toLocal());
                        }

                        final actionColor = _getActionColor(type);
                        final actionIcon = _getActionIcon(type);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: actionColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    actionIcon,
                                    color: actionColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person,
                                            size: 14,
                                            color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            user,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: actionColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: actionColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      automaticallyImplyLeading: !widget.isModal,
      leading: widget.isModal
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Activity Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Every recorded action for this facility', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    }
  }

  // Said plainly, so a short log isn't mistaken for a broken one.
  Widget _buildScopeNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You see your own activity, and anything about you. Other team matters are only visible to admins.',
              style: TextStyle(fontSize: 12.5, color: Colors.blue.shade900),
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
          final type = (doc['actionType'] ?? 'Unknown').toString();
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        // Most-active types first - the most useful ordering for an
        // at-a-glance summary that's also a filter.
        final sortedTypes = typeCounts.keys.toList()
          ..sort((a, b) => typeCounts[b]!.compareTo(typeCounts[a]!));

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: primaryDeepGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: _keyFor('All'),
                        label: Text('All · $totalLogs'),
                        selected: selectedFilter == 'All',
                        onSelected: (_) => _selectFilterAndScrollIntoView('All'),
                        selectedColor: warmAmber,
                      ),
                    ),
                    ...sortedTypes.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: _keyFor(type),
                          label: Text('$type · ${typeCounts[type]}'),
                          selected: selectedFilter == type,
                          onSelected: (_) => _selectFilterAndScrollIntoView(type),
                          selectedColor: warmAmber,
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
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Activity Log',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1000,
            maxHeight: screenSize.height * 0.85,
          ),
          child: SizedBox(
            width: screenSize.width * 0.85,
            height: screenSize.height * 0.85,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const Material(
                child: ActivityLogScreen(isModal: true),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
