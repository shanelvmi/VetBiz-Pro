import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/text_sanitizer.dart';

class ActivityLogScreen extends StatefulWidget {
  final bool isModal;
  const ActivityLogScreen({super.key, this.isModal = false});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  String selectedFilter = 'All';
  String searchQuery = '';

  // Search now lives in the AppBar (expandable icon), same pattern as
  // Sales/Products/Services - not a permanent field taking up body
  // space when nobody's actually searching.
  bool _isSearchExpanded = false;
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
  // Null means "not loaded yet" - _cleanupOldLogs falls back to 90
  // until it resolves, and any facility that never explicitly set
  // this also defaults to 90, same as before this setting existed.
  int? _retentionDays;
  String? _retentionLoadedForFacilityId;

  static const List<int> _retentionOptions = [14, 30, 60, 90];
  static const int _defaultRetentionDays = 90;

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
      _isSearchExpanded = false;
      _retentionDays = null;
      _retentionLoadedForFacilityId = null;
    });
  }

  Future<void> _fetchRetentionDays(String facilityId) async {
    if (_retentionLoadedForFacilityId == facilityId) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('facilities').doc(facilityId).get();
      final configured = (doc.data()?['activityLogRetentionDays'] as num?)?.toInt();
      if (!mounted) return;
      setState(() {
        _retentionDays = (configured != null && _retentionOptions.contains(configured))
            ? configured
            : _defaultRetentionDays;
        _retentionLoadedForFacilityId = facilityId;
      });
    } catch (e) {
      debugPrint('Could not load retention setting: $e');
      if (mounted) {
        setState(() {
          _retentionDays = _defaultRetentionDays;
          _retentionLoadedForFacilityId = facilityId;
        });
      }
    }
  }

  Future<void> _showRetentionDialog(String facilityId) async {
    final current = _retentionDays ?? _defaultRetentionDays;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep Logs For'),
        content: Column(
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
          content: Text(
            'Logs are currently kept for $current days. Switching to $selected days '
            'will permanently delete every log older than $selected days right now - '
            'not just going forward. This cannot be undone.',
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
      await FirebaseFirestore.instance.collection('facilities').doc(facilityId).set(
        {'activityLogRetentionDays': selected},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() => _retentionDays = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logs will now be kept for $selected days'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Auto-delete logs older than the configured retention window
  Future<void> _cleanupOldLogs(String facilityId) async {
    try {
      final retentionDays = _retentionDays ?? _defaultRetentionDays;
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      final oldLogs = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (oldLogs.docs.isEmpty) {
        debugPrint('No old logs to delete');
        return;
      }

      // Delete in batches (Firestore limit: 500 operations per batch)
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
        count++;

        if (count >= 500) break; // Safety limit
      }

      await batch.commit();
      debugPrint('Deleted $count old activity logs (>$retentionDays days)');
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

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
          title: const Text(
            'Activity Log',
            style: TextStyle(color: Color(0xFFFDFDF9)),
          ),
          backgroundColor: primaryDeepGreen,
          centerTitle: true,
          automaticallyImplyLeading: !widget.isModal,
          leading: widget.isModal
              ? IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFFDFDF9)),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: const Center(child: Text('No facility selected.')),
      );
    }

    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Load the configured retention window for this facility (once
    // per facility, not on every rebuild - _fetchRetentionDays itself
    // guards against redundant fetches).
    _fetchRetentionDays(facilityId);

    // Run cleanup on screen load (runs once per session)
    Future.delayed(Duration.zero, () => _cleanupOldLogs(facilityId));

    // No date-range filter here - retention (14/30/60/90 days,
    // configurable above) already naturally bounds how much data
    // exists at all. The limit below remains as a hard safety cap.
    final logStream = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(500) // Performance limit
        .snapshots();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(facilityId, isAdmin),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
        children: [
          // One unified summary that's also the filter - see
          // _buildActionSummary for the full reasoning.
          _buildActionSummary(facilityId),

          const Divider(height: 1),

          // Activity Log List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: logStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryDeepGreen,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                final logs = snapshot.data!.docs.where((doc) {
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
                          dateStr = DateFormat('dd MMM yyyy - HH:mm:ss')
                              .format(timestamp.toDate().toLocal());
                        }

                        final actionColor = _getActionColor(type);
                        final actionIcon = _getActionIcon(type);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: actionColor.withValues(alpha: 0.2),
                              child: Icon(
                                actionIcon,
                                color: actionColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              action,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: 2),
                                Row(
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
                              ],
                            ),
                            trailing: Container(
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
                          ),
                        );
                      },
                    );
              },
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String facilityId, bool isAdmin) {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      iconTheme: const IconThemeData(color: Color(0xFFFDFDF9)),
      centerTitle: true,
      automaticallyImplyLeading: !widget.isModal,
      leading: widget.isModal
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(color: offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: offWhite),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              onChanged: (val) => setState(() => searchQuery = val.trim()),
            )
          : const Text(
              'Activity Log',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: Color(0xFFFDFDF9),
              ),
            ),
      actions: [
        if (!_isSearchExpanded) ...[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Log retention setting',
              onPressed: () => _showRetentionDialog(facilityId),
            ),
        ],
      ],
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

  Widget _buildActionSummary(String facilityId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
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
