import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/notification_seen_tracker.dart';
import '../../models/notification_model.dart';
import '../../widgets/announcement_message.dart';
import '../../widgets/notification_row.dart';

/// Everything that needs your attention, facility-wide - subscription
/// status, urgent announcements, payments, debts, and system messages.
/// Stock/product alerts have their own dedicated screen now (see
/// StockAlertsScreen in screens/products/) - this one is deliberately
/// general-purpose, so it no longer needs to know about a "locked
/// category" at all.
class NotificationsScreen extends StatefulWidget {
  final bool isDropdown;
  const NotificationsScreen({super.key, this.isDropdown = false});

  static const Color primaryColor = Color(0xFF2F5D62);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;

  List<FacilityNotification> _needsAttention = [];
  List<FacilityNotification> _earlier = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;

  // Exactly what's stored in Firestore, before the subscription row is
  // reconciled against SubscriptionProvider - kept so the displayed
  // lists can be rebuilt when the subscription state changes, not just
  // when a new snapshot arrives.
  List<FacilityNotification> _rawAll = [];
  SubscriptionProvider? _subscriptionProvider;

  // Full-screen only: the complete recent history (not filtered to only
  // currently-visible ones, since this screen is for browsing what's
  // happened, not just what's still new) plus the search/date/category
  // filters and pagination state that drive it.
  List<FacilityNotification> _fullHistory = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  NotificationCategory? _selectedCategory; // null = "All"
  String _statusFilter = 'All'; // 'All' | 'Unread' | 'Read'

  // Re-checks every minute which notifications have expired, so an offer
  // that ends while this screen is open disappears by itself instead of
  // waiting for the next data change.
  Timer? _expiryTicker;
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    _subscriptionProvider!.addListener(_onSubscriptionChanged);
    _watchNotifications();
    _expiryTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(_rebuildLists);
    });
    // NotificationSeenTracker had no callers anywhere in the app - the
    // "last viewed" record it's meant to persist was never actually
    // written, so Dashboard's bell-blink state (_hasNewUrgentSinceViewed
    // etc.) only ever cleared in-memory for the rest of the current
    // session (via _refreshNotificationsViewedState on return to
    // Dashboard), not durably: a fresh app restart would reload the
    // same old value - or none at all - and could show the same
    // already-seen items as new again.
    NotificationSeenTracker.markViewedNow();
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    _expiryTicker?.cancel();
    _subscriptionProvider?.removeListener(_onSubscriptionChanged);
    _searchController.dispose();
    super.dispose();
  }

  // A simple, single-field ordering with no where() clause at all -
  // never needs a composite index, unlike a filtered query would.
  // Ephemeral-vs-persistent visibility is decided client-side instead,
  // against a bounded recent window. Deliberately does NOT auto-mark
  // anything as read just by loading it - the mockup's explicit "Mark
  // all as read" action is the only thing that changes readAt, so it
  // actually has something to do rather than acting on notifications
  // already silently marked read the instant the panel opened.
  void _watchNotifications() {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _notificationsSub = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(widget.isDropdown ? 50 : 200)
        .snapshots()
        .listen((snapshot) {
      _rawAll = snapshot.docs.map(FacilityNotification.fromFirestore).toList();
      if (mounted) {
        setState(() {
          _rebuildLists();
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    });
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(_rebuildLists);
  }

  /// Splits the stored notifications into the screen's lists, after
  /// swapping the subscription row for what SubscriptionProvider says
  /// right now. Call inside setState.
  void _rebuildLists() {
    final all = _reconcileSubscription(_rawAll);
    final visible = all.where((n) => n.isCurrentlyVisible).toList();

    // "Needs Attention" is everything with real, specific meaning -
    // stock/critical/payment/debt/system - while "Earlier" catches
    // the more routine, informational events (a service recorded, a
    // new client added) that don't need the same urgency, matching
    // NotificationType.category's "other" grouping.
    _needsAttention = visible.where((n) => n.category != NotificationCategory.other).toList();
    _earlier = visible.where((n) => n.category == NotificationCategory.other).toList();
    // The full screen is for browsing what's happened, so it keeps read
    // items - but anything that has EXPIRED (an offer whose end date has
    // passed, say) is no longer true and is dropped, same as the dropdown
    // and the Dashboard bell already do.
    _fullHistory = all.where((n) => !n.isExpired).toList();
  }

  /// The stored subscription notice is a once-a-day snapshot written by
  /// the checkSubscriptionExpiry Cloud Function (00:30), so on its own
  /// it lags the Dashboard banner and Subscription screen by up to a
  /// day - it kept saying "1 day left" after the banner had already
  /// moved to the grace period - and lingers after a renewal until the
  /// next run. The live provider is the source of truth instead:
  ///   - nothing needs attention now -> any stored notice is dropped
  ///   - something does -> the stored one keeps its id, showing the
  ///     live wording; its read state carries over too, UNLESS the
  ///     live wording has moved past what's actually stored (severity
  ///     escalated since this was last written or read), in which case
  ///     it's shown as fresh and unread again instead; if none is
  ///     stored yet (a threshold crossed since 00:30) one is shown in
  ///     its place.
  List<FacilityNotification> _reconcileSubscription(List<FacilityNotification> stored) {
    final notice = _subscriptionProvider?.attentionNotice;
    final result = <FacilityNotification>[];
    var placed = false;

    for (final n in stored) {
      if (n.type != NotificationType.subscriptionExpiring) {
        result.add(n);
        continue;
      }
      if (notice == null || placed) continue;
      placed = true;
      // The stored document's own title/message - set once by the
      // Cloud Function and otherwise only refreshed on its next daily
      // run - is what readAt and createdAt actually correspond to.
      // When the live wording has moved past that (the severity
      // escalated - e.g. grace to locked - since the function or
      // another device last touched this document), this occurrence
      // hasn't actually been seen under its current wording yet, even
      // if readAt is set: shown as fresh and unread again, rather than
      // staying silently read forever once dismissed at an earlier,
      // milder stage. This is what was reported as "still showing
      // updated on 20 Sept" while already locked - a much more urgent
      // state than whatever was last read.
      final hasEscalated = n.message != notice.message;
      result.add(FacilityNotification(
        id: n.id,
        type: n.type,
        title: notice.title,
        message: notice.message,
        createdAt: hasEscalated ? DateTime.now() : n.createdAt,
        readAt: hasEscalated ? null : n.readAt,
        // Lifetime now follows the live state rather than the stored
        // document's 2-day safety-net expiry; rebuilt on every change,
        // so it can't go stale.
        expiresAt: DateTime.now().add(const Duration(days: 2)),
        relatedEntityType: n.relatedEntityType,
        relatedEntityId: n.relatedEntityId,
      ));
    }

    if (notice != null && !placed) {
      final now = DateTime.now();
      result.insert(
        0,
        FacilityNotification(
          id: 'subscription_expiring',
          type: NotificationType.subscriptionExpiring,
          title: notice.title,
          message: notice.message,
          createdAt: now,
          // No document behind this row yet, so it can't be marked read
          // (_markAllAsRead updates documents by id, and updating one
          // that doesn't exist fails the whole batch). It's a standing
          // condition the bell already shows live, not a fresh arrival,
          // so it appears as already seen until the daily run stores it.
          readAt: now,
          expiresAt: now.add(const Duration(days: 2)),
        ),
      );
    }
    return result;
  }

  Future<void> _markAllAsRead() async {
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    final unread = [..._needsAttention, ..._earlier].where((n) => !n.isRead);
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final notificationsRef =
        FirebaseFirestore.instance.collection('facilities').doc(facilityId).collection('notifications');
    for (final n in unread) {
      batch.update(notificationsRef.doc(n.id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // Search + date range + status + category card, applied together - the
  // flat, filtered result the table and its pagination both work from.
  List<FacilityNotification> get _filteredHistory {
    return _fullHistory.where((n) {
      if (_selectedCategory != null && n.category != _selectedCategory) return false;
      if (_statusFilter == 'Unread' && n.isRead) return false;
      if (_statusFilter == 'Read' && !n.isRead) return false;

      if (_dateRange != null && n.createdAt != null) {
        final day = DateTime(n.createdAt!.year, n.createdAt!.month, n.createdAt!.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!n.title.toLowerCase().contains(q) &&
            !n.message.toLowerCase().contains(q) &&
            !n.type.categoryLabel.toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _dateRange != null || _selectedCategory != null || _statusFilter != 'All';

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _dateRange = null;
      _selectedCategory = null;
      _statusFilter = 'All';
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nothingToShow = !_isLoading &&
        _error == null &&
        _needsAttention.isEmpty &&
        _earlier.isEmpty;

    if (widget.isDropdown) {
      return _buildDropdownChrome(nothingToShow);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 72,
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text('All updates and alerts from your facility', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load alerts: $_error')))
              : _buildFullScreenBody(),
    );
  }

  // ======================================================================
  // FULL SCREEN - summary cards, one filter row, and a full-width table,
  // laid out like the Sales and Product Alerts screens.
  // ======================================================================

  static const Color _primary = NotificationsScreen.primaryColor;

  // The filter cards, in display order - the same categories the old tab
  // strip offered; "All" is simply no card selected.
  static const List<NotificationCategory> _cardCategories = [
    NotificationCategory.critical,
    NotificationCategory.stock,
    NotificationCategory.payment,
    NotificationCategory.debt,
    NotificationCategory.system,
  ];

  String _categoryName(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.critical:
        return 'Critical';
      case NotificationCategory.stock:
        return 'Stock';
      case NotificationCategory.payment:
        return 'Payments';
      case NotificationCategory.debt:
        return 'Debts';
      case NotificationCategory.system:
        return 'System';
      case NotificationCategory.other:
        return 'Updates';
    }
  }

  IconData _categoryIcon(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.critical:
        return Icons.error_outline;
      case NotificationCategory.stock:
        return Icons.inventory_2_outlined;
      case NotificationCategory.payment:
        return Icons.payments_outlined;
      case NotificationCategory.debt:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.system:
        return Icons.campaign_outlined;
      case NotificationCategory.other:
        return Icons.notifications_none;
    }
  }

  Color _categoryColor(NotificationCategory c) {
    switch (c) {
      case NotificationCategory.critical:
        return Colors.red;
      case NotificationCategory.stock:
        return Colors.orange;
      case NotificationCategory.payment:
        return Colors.green;
      case NotificationCategory.debt:
        return const Color(0xFFE59A00);
      case NotificationCategory.system:
        return Colors.blue;
      case NotificationCategory.other:
        return Colors.grey;
    }
  }

  Widget _buildFullScreenBody() {
    final all = _fullHistory;

    final counts = <NotificationCategory, int>{for (final c in NotificationCategory.values) c: 0};
    final unreadCounts = <NotificationCategory, int>{for (final c in NotificationCategory.values) c: 0};
    for (final n in all) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
      if (!n.isRead) unreadCounts[n.category] = (unreadCounts[n.category] ?? 0) + 1;
    }

    final filtered = _filteredHistory;
    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    // Notifications expiring can shrink the list under the page being viewed.
    final page = _currentPage > totalPages ? totalPages : _currentPage;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildCategoryCards(counts, unreadCounts),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilters(),
        ),
        Expanded(
          child: all.isEmpty
              ? _buildEmptyState()
              : filtered.isEmpty
                  ? _buildNoMatches()
                  : _buildResults(pageItems),
        ),
        if (all.isNotEmpty) _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildCategoryCards(Map<NotificationCategory, int> counts, Map<NotificationCategory, int> unread) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 5 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 90,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _cardCategories.length,
          itemBuilder: (context, index) {
            final c = _cardCategories[index];
            return _categoryCard(c, counts[c] ?? 0, unread[c] ?? 0);
          },
        );
      },
    );
  }

  // Same small card as Sales / Product Alerts: tapping filters the table
  // to that category, tapping again clears it.
  Widget _categoryCard(NotificationCategory category, int count, int unread) {
    final color = _categoryColor(category);
    final selected = _selectedCategory == category;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.7) : Colors.grey.withValues(alpha: 0.15),
        width: selected ? 1.5 : 1,
      ),
    );
    return Material(
      color: selected ? color.withValues(alpha: 0.06) : Colors.white,
      shape: shape,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        customBorder: shape,
        onTap: () => setState(() {
          _selectedCategory = selected ? null : category;
          _currentPage = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration:
                          BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                      child: Icon(_categoryIcon(category), color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_categoryName(category), style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                Text(
                  unread > 0 ? '$unread unread' : 'All read',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: unread > 0 ? color : Colors.grey[400],
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search notifications...',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: border,
        enabledBorder: border,
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _currentPage = 1;
                  });
                },
              ),
      ),
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _currentPage = 1;
      }),
    );

    final hasUnread = [..._needsAttention, ..._earlier].any((n) => !n.isRead);
    final markAll = OutlinedButton.icon(
      onPressed: hasUnread ? _markAllAsRead : null,
      icon: const Icon(Icons.done_all, size: 16),
      label: const Text('Mark all read'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
    );
    final reset = _hasActiveFilters ? TextButton(onPressed: _resetFilters, child: const Text('Reset')) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _dateRangeButton(expand: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _statusDropdown(expand: true)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (reset != null) reset,
                  const Spacer(),
                  markAll,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            _dateRangeButton(),
            const SizedBox(width: 10),
            _statusDropdown(),
            if (reset != null) ...[const SizedBox(width: 10), reset],
            const SizedBox(width: 10),
            markAll,
          ],
        );
      },
    );
  }

  Widget _statusDropdown({bool expand = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: expand,
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: _primary),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          items: const ['All', 'Unread', 'Read']
              .map((v) => DropdownMenuItem(value: v, child: Text('Status: $v')))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _statusFilter = val;
                _currentPage = 1;
              });
            }
          },
        ),
      ),
    );
  }

  // [expand] is for the narrow layout, where this sits in a half-width slot
  // and its label must be able to shorten rather than overflow. In the wide
  // row it has no width limit, so it just sizes to its label.
  Widget _dateRangeButton({bool expand = false}) {
    final label = _dateRange == null
        ? 'Date: All'
        : '${DateFormat('d MMM').format(_dateRange!.start)} - ${DateFormat('d MMM y').format(_dateRange!.end)}';
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
    );
    final tappable = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _pickDateRange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: _primary),
            const SizedBox(width: 8),
            if (expand) Flexible(child: labelText) else labelText,
          ],
        ),
      ),
    );
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expand) Expanded(child: tappable) else tappable,
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Clear date range',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _dateRange = null;
                _currentPage = 1;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentPage = 1;
      });
    }
  }

  // ==================== TABLE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No notifications', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('New updates from your facility will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildNoMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No notifications match your filters', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton(onPressed: _resetFilters, child: const Text('Reset filters')),
        ],
      ),
    );
  }

  Widget _buildResults(List<FacilityNotification> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildNarrowCard(items[index]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
              child: Row(
                children: [
                  _headerCell('Notification', flex: 6),
                  _headerCell('Category', flex: 2),
                  _headerCell('Date', flex: 2),
                  _headerCell('Status', flex: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
                itemBuilder: (context, index) => _buildRow(items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _typeIcon(FacilityNotification n, double size) {
    final color = n.type.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(n.type.icon, color: color, size: size * 0.5),
    );
  }

  Widget _categoryChip(FacilityNotification n) {
    final color = _categoryColor(n.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        n.type.categoryLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statusChip(FacilityNotification n) {
    final color = n.isRead ? Colors.grey : _primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        n.isRead ? 'Read' : 'New',
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Wide layout: one table row.
  Widget _buildRow(FacilityNotification n) {
    final unread = !n.isRead;
    final created = n.createdAt;

    return Container(
      key: ValueKey(n.id),
      // Coloured bar down the left edge, tinted while unread.
      decoration: BoxDecoration(
        color: unread ? _primary.withValues(alpha: 0.04) : null,
        border: Border(left: BorderSide(color: _categoryColor(n.category), width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                _typeIcon(n, 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: unread ? FontWeight.bold : FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _categoryChip(n))),
          Expanded(
            flex: 2,
            child: created == null
                ? const Text('-', style: TextStyle(fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(created), style: const TextStyle(fontSize: 13)),
                      Text(DateFormat('hh:mm a').format(created),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    ],
                  ),
          ),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: _statusChip(n))),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per notification.
  Widget _buildNarrowCard(FacilityNotification n) {
    final unread = !n.isRead;
    final created = n.createdAt;

    return Container(
      key: ValueKey(n.id),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      // Clipped so the bar down the left follows the card's rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Container(
          decoration: BoxDecoration(
            color: unread ? Color.alphaBlend(_primary.withValues(alpha: 0.04), Colors.white) : Colors.white,
            border: Border(left: BorderSide(color: _categoryColor(n.category), width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typeIcon(n, 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.bold : FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(n.message, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _categoryChip(n),
                  const SizedBox(width: 6),
                  _statusChip(n),
                  const Spacer(),
                  if (created != null)
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(created),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PAGINATION ====================

  Widget _buildPaginationBar({required int total, required int page, required int totalPages}) {
    final start = total == 0 ? 0 : (page - 1) * _pageSize + 1;
    final end = (page * _pageSize) > total ? total : page * _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            total == 0
                ? 'No notifications'
                : 'Showing $start to $end of $total notification${total == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => setState(() => _currentPage = page - 1) : null,
              ),
              Text('Page $page', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => setState(() => _currentPage = page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Compact desktop dropdown, anchored near the bell rather than a
  // full screen - no Scaffold/AppBar of its own (the dropdown
  // container the caller wraps this in provides the surface and
  // shadow), just a small header row and the same content beneath it.
  Widget _buildDropdownChrome(bool nothingToShow) {
    final totalUnread = [..._needsAttention, ..._earlier].where((n) => !n.isRead).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: NotificationsScreen.primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Text(
                'Notifications',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (totalUnread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                  child: Text('$totalUnread',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: totalUnread > 0 ? _markAllAsRead : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                ),
                child: const Text('Mark all as read', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load alerts: $_error'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: _buildAlertsList(nothingToShow),
                    ),
        ),
      ],
    );
  }

  // Shared between the full-screen and dropdown chrome - same content
  // either way, only how much space it's given differs.
  Widget _buildAlertsList(bool nothingToShow) {
    if (nothingToShow) return _buildAllCaughtUp();

    return ListView(
      shrinkWrap: true,
      physics: widget.isDropdown ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildUrgentAnnouncements(),
        if (_needsAttention.isNotEmpty) ...[
          _sectionHeader(Icons.priority_high, 'Needs Attention', _needsAttention.length, Colors.orange),
          const SizedBox(height: 8),
          ..._needsAttention.map((n) => NotificationRow(notification: n)),
          const SizedBox(height: 20),
        ],
        if (_earlier.isNotEmpty) ...[
          _sectionHeader(Icons.history, 'Earlier', _earlier.length, Colors.grey),
          const SizedBox(height: 8),
          ..._earlier.map((n) => NotificationRow(notification: n)),
          const SizedBox(height: 12),
        ],
        if (widget.isDropdown)
          Center(
            child: TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              style: TextButton.styleFrom(foregroundColor: NotificationsScreen.primaryColor),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 15),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllCaughtUp() {
    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          ),
          const SizedBox(height: 16),
          const Text("You're all caught up!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            'No urgent announcements, subscription issues, or stock alerts right now.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );

    // The dropdown already sits inside its own SingleChildScrollView
    // (see _buildDropdownChrome), which offers unbounded height to its
    // child - the LayoutBuilder/minHeight-centering trick below needs
    // a *bounded* parent to make sense, so nesting it inside that
    // unbounded scroll view turned constraints.maxHeight into
    // infinity, and minHeight: infinity into a genuine layout error.
    // In dropdown mode this just needs to size itself naturally, no
    // viewport-filling/centering required.
    if (widget.isDropdown) return Center(child: content);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }

  Widget _buildUrgentAnnouncements() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_announcements')
          .where('urgent', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final urgentDocs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['hidden'] != true;
        }).toList();

        if (urgentDocs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.campaign_outlined, 'Urgent Announcements', urgentDocs.length, Colors.red),
              const SizedBox(height: 8),
              ...urgentDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _AccentCard(
                  color: Colors.red,
                  icon: Icons.priority_high,
                  title: data['title'] ?? '',
                  margin: const EdgeInsets.only(bottom: 8),
                  child: AnnouncementMessage(data: data, fontSize: 13),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: NotificationsScreen.primaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: NotificationsScreen.primaryColor)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Shared "notification card" look - a colored left accent bar, a
/// leading icon, a title, and freeform content below. Used for urgent
/// announcements so they read as part of the same notification system
/// as everything else on this screen, not a visually separate bolt-on.
class _AccentCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final Widget child;
  final EdgeInsets margin;

  const _AccentCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
