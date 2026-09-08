import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../providers/product_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../models/product.dart';
import '../../models/notification_model.dart';
import '../subscription/subscription_screen.dart';
import '../../widgets/announcement_message.dart';

/// Everything that needs your attention in one place - subscription
/// status, urgent announcements, and low-stock/expiry alerts, precise to
/// the individual batch. Products with no batch records yet (created
/// before batch tracking existed) fall back to a single whole-product
/// row using their own aggregate fields.
class StockAlertsScreen extends StatefulWidget {
  final bool isDropdown;
  // When set, the full screen is restricted to only this category -
  // both the visible tabs and the underlying data - rather than the
  // complete facility-wide feed. Used by screens like Products/Stock
  // Store, where the bell icon should only ever surface product-related
  // alerts, not payments/clients/debts/etc.
  final NotificationCategory? lockedCategory;
  const StockAlertsScreen({super.key, this.isDropdown = false, this.lockedCategory});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const int expiryWarningDays = 30;

  /// Cheap, aggregate-only check for the Dashboard bell's red dot - a
  /// quick yes/no signal doesn't need per-batch precision, just "is
  /// there anything to look at". The detail screen below is what shows
  /// the real per-batch breakdown.
  static bool hasAnyAlert(List<Product> products) {
    final now = DateTime.now();
    return products.any((p) =>
        p.isLowStock ||
        p.hasRestockShelfAlert ||
        (p.expiry != null && p.expiry!.difference(now).inDays <= expiryWarningDays));
  }

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  bool _isLoading = true;
  String? _error;

  List<FacilityNotification> _needsAttention = [];
  List<FacilityNotification> _earlier = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;

  // Full-screen only: the complete recent history (not filtered to only
  // currently-visible ones, since this screen is for browsing what's
  // happened, not just what's still new) plus the search/date/category
  // filters and pagination state that drive it.
  List<FacilityNotification> _fullHistory = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  NotificationCategory? _selectedCategory; // null = "All"
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.lockedCategory;
    _watchNotifications();
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
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
      final all = snapshot.docs.map(FacilityNotification.fromFirestore).toList();
      final visible = all.where((n) => n.isCurrentlyVisible).toList();

      // "Needs Attention" is everything with real, specific meaning -
      // stock/critical/payment/debt/system - while "Earlier" catches
      // the more routine, informational events (a service recorded, a
      // new client added) that don't need the same urgency, matching
      // NotificationType.category's "other" grouping.
      final needsAttention =
          visible.where((n) => n.category != NotificationCategory.other).toList();
      final earlier = visible.where((n) => n.category == NotificationCategory.other).toList();

      if (mounted) {
        setState(() {
          _needsAttention = needsAttention;
          _earlier = earlier;
          _fullHistory = all;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    });
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

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  // Search + date range + category tab, applied together - the flat,
  // filtered result pagination and day-grouping below both work from.
  List<FacilityNotification> get _filteredHistory {
    return _fullHistory.where((n) {
      if (_selectedCategory != null && n.category != _selectedCategory) return false;

      if (_dateRange != null && n.createdAt != null) {
        final day = DateTime(n.createdAt!.year, n.createdAt!.month, n.createdAt!.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!n.title.toLowerCase().contains(q) && !n.message.toLowerCase().contains(q)) return false;
      }

      return true;
    }).toList();
  }

  int get _totalPages => (_filteredHistory.length / _pageSize).ceil().clamp(1, 999999);

  List<FacilityNotification> get _currentPageItems {
    final filtered = _filteredHistory;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= filtered.length) return [];
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  // "Today", "Yesterday", or a plain date - the day-group headers shown
  // above each cluster of notifications from that day.
  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateText = DateFormat('d MMM y').format(dt);
    if (day == today) return 'Today · $dateText';
    if (day == yesterday) return 'Yesterday · $dateText';
    return dateText;
  }

  // Groups a page's items by day, preserving the newest-first order the
  // underlying query already provides - each group is a run of
  // consecutive same-day items, not a full re-sort.
  List<MapEntry<String, List<FacilityNotification>>> _groupByDay(List<FacilityNotification> items) {
    final groups = <String, List<FacilityNotification>>{};
    for (final n in items) {
      if (n.createdAt == null) continue;
      final label = _dayLabel(n.createdAt!);
      groups.putIfAbsent(label, () => []).add(n);
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final sub = Provider.of<SubscriptionProvider>(context);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    // Same thresholds as the Dashboard banner, so the two can never
    // disagree about whether the subscription needs attention.
    final subNeedsAttention = sub.status == SubscriptionStatus.grace ||
        sub.status == SubscriptionStatus.locked ||
        ((sub.status == SubscriptionStatus.trial || sub.status == SubscriptionStatus.active) &&
            sub.daysRemaining != null &&
            sub.daysRemaining! <= 7);

    // True for the entire trial, not just its last 7 days - a
    // deliberately calmer, informational notice (not urgent) shown
    // whenever someone's on a trial at all, separate from
    // subNeedsAttention above which only covers the "running out
    // soon" case.
    final isInTrial = sub.status == SubscriptionStatus.trial;

    final nothingToShow = !_isLoading &&
        _error == null &&
        (widget.lockedCategory != null || (!subNeedsAttention && !isInTrial)) &&
        _needsAttention.isEmpty &&
        _earlier.isEmpty;

    if (widget.isDropdown) {
      return _buildDropdownChrome(sub, isAdmin, nothingToShow, subNeedsAttention, isInTrial);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.lockedCategory == NotificationCategory.stock ? 'Product Alerts' : 'Notifications',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87),
            ),
            Text(
              widget.lockedCategory == NotificationCategory.stock
                  ? 'Stock and expiry alerts for your products'
                  : 'All updates and alerts from your facility',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load alerts: $_error')))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildFullScreenBody(),
                  ),
                ),
    );
  }

  Widget _buildFullScreenBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notifications...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _dateRange == null
                      ? 'Date range'
                      : '${DateFormat('d MMM').format(_dateRange!.start)} - ${DateFormat('d MMM y').format(_dateRange!.end)}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: StockAlertsScreen.primaryColor),
              ),
              if (_dateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear date range',
                  onPressed: () => setState(() {
                    _dateRange = null;
                    _currentPage = 1;
                  }),
                ),
            ],
          ),
        ),
        _buildCategoryTabs(),
        const Divider(height: 1),
        Expanded(child: _buildPaginatedList()),
        if (_filteredHistory.isNotEmpty) _buildPaginationControls(),
      ],
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

  Widget _buildCategoryTabs() {
    if (widget.lockedCategory != null) return const SizedBox.shrink();

    final tabs = <(String, NotificationCategory?)>[
      ('All', null),
      ('Critical', NotificationCategory.critical),
      ('Stock', NotificationCategory.stock),
      ('Debts', NotificationCategory.debt),
      ('Payments', NotificationCategory.payment),
      ('System', NotificationCategory.system),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final (label, category) = tab;
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 12.5)),
                selected: isSelected,
                selectedColor: StockAlertsScreen.primaryColor,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                onSelected: (_) => setState(() {
                  _selectedCategory = category;
                  _currentPage = 1;
                }),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaginatedList() {
    final pageItems = _currentPageItems;
    if (pageItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _filteredHistory.isEmpty
                ? 'No notifications match your filters.'
                : 'Nothing more to show.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final groups = _groupByDay(pageItems);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  group.key,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.grey[600]),
                ),
              ),
              ...group.value.map((n) => _NotificationRow(
                    notification: n,
                    relativeTime: _relativeTime(n.createdAt),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    final total = _filteredHistory.length;
    final start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final end = ((_currentPage - 1) * _pageSize + _pageSize).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing $start - $end of $total notifications',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              for (var page = 1; page <= _totalPages && page <= 5; page++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _currentPage = page),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: page == _currentPage ? StockAlertsScreen.primaryColor : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: page == _currentPage ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
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
  Widget _buildDropdownChrome(SubscriptionProvider sub, bool isAdmin, bool nothingToShow, bool subNeedsAttention, bool isInTrial) {
    final totalUnread = [..._needsAttention, ..._earlier].where((n) => !n.isRead).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: StockAlertsScreen.primaryColor,
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
                      child: _buildAlertsList(sub, isAdmin, nothingToShow, subNeedsAttention, isInTrial),
                    ),
        ),
      ],
    );
  }

  // Shared between the full-screen and dropdown chrome - same content
  // either way, only how much space it's given differs.
  Widget _buildAlertsList(SubscriptionProvider sub, bool isAdmin, bool nothingToShow, bool subNeedsAttention, bool isInTrial) {
    if (nothingToShow) return _buildAllCaughtUp();

    return ListView(
      shrinkWrap: true,
      physics: widget.isDropdown ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.lockedCategory == null) ...[
          if (subNeedsAttention) ...[
            _buildSubscriptionCard(context, sub, isAdmin),
            const SizedBox(height: 20),
          ] else if (isInTrial) ...[
            _buildTrialInfoCard(context, sub, isAdmin),
            const SizedBox(height: 20),
          ],
          _buildUrgentAnnouncements(),
        ],
        if (_needsAttention.isNotEmpty) ...[
          _sectionHeader(Icons.priority_high, 'Needs Attention', _needsAttention.length, Colors.orange),
          const SizedBox(height: 8),
          ..._needsAttention.map((n) => _NotificationRow(
                notification: n,
                relativeTime: _relativeTime(n.createdAt),
              )),
          const SizedBox(height: 20),
        ],
        if (_earlier.isNotEmpty) ...[
          _sectionHeader(Icons.history, 'Earlier', _earlier.length, Colors.grey),
          const SizedBox(height: 8),
          ..._earlier.map((n) => _NotificationRow(
                notification: n,
                relativeTime: _relativeTime(n.createdAt),
              )),
          const SizedBox(height: 12),
        ],
        if (widget.isDropdown)
          Center(
            child: TextButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                final lockedCategory = widget.lockedCategory;
                navigator.pop();
                navigator.push(MaterialPageRoute(
                    builder: (_) => StockAlertsScreen(lockedCategory: lockedCategory)));
              },
              style: TextButton.styleFrom(foregroundColor: StockAlertsScreen.primaryColor),
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
            widget.lockedCategory == NotificationCategory.stock
                ? 'No stock alerts right now.'
                : 'No urgent announcements, subscription issues, or stock alerts right now.',
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

  // Calm, informational - not urgent. Shown for the entire trial
  // (once subNeedsAttention's <=7-day threshold no longer applies,
  // this takes over instead of showing nothing at all), so someone's
  // aware they're on a trial well before it's actually running out.
  Widget _buildTrialInfoCard(BuildContext context, SubscriptionProvider sub, bool isAdmin) {
    const color = Colors.blue;
    final daysText = sub.daysRemaining != null
        ? '${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'} left'
        : null;

    return _AccentCard(
      color: color,
      icon: Icons.workspace_premium_outlined,
      title: 'Free Trial',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              daysText != null
                  ? "You're on a free trial - $daysText."
                  : "You're on a free trial.",
              style: const TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          if (isAdmin)
            TextButton(
              onPressed: () => showSubscriptionScreen(context),
              style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
              child: const Text('View Plans'),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionProvider sub, bool isAdmin) {
    final isLocked = sub.status == SubscriptionStatus.locked;
    final isGrace = sub.status == SubscriptionStatus.grace;
    final isTrial = sub.status == SubscriptionStatus.trial;
    final color = isLocked ? Colors.redAccent : Colors.orange;

    String message;
    if (isLocked) {
      message = isTrial
          ? 'Your trial has ended. The app is in read-only mode - subscribe to restore full access.'
          : 'Your subscription has expired. The app is in read-only mode - submit a payment to restore full access.';
    } else if (isGrace) {
      message = isTrial
          ? 'Your trial ended - you have a few days of grace before read-only mode begins.'
          : 'Your subscription expired - you have a few days of grace before read-only mode begins.';
    } else if (isTrial) {
      message = sub.daysRemaining != null
          ? 'Your trial expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.'
          : 'Your trial is active.';
    } else {
      message = sub.daysRemaining != null
          ? 'Your subscription expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.'
          : 'Your subscription is active.';
    }

    return _AccentCard(
      color: color,
      icon: isLocked ? Icons.lock_outline : Icons.workspace_premium_outlined,
      title: 'Subscription',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          if (isAdmin)
            TextButton(
              onPressed: () {
                showSubscriptionScreen(context);
              },
              style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
              child: const Text('Renew'),
            )
          else
            Text('Ask your admin', style: TextStyle(color: color, fontSize: 11.5, fontStyle: FontStyle.italic)),
        ],
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
        Icon(icon, size: 16, color: StockAlertsScreen.primaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StockAlertsScreen.primaryColor)),
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
/// leading icon, a title, and freeform content below. Used for every
/// kind of notification (subscription, urgent announcement, stock
/// alert) so the whole screen reads as one consistent system instead of
/// several different card styles bolted together.
/// A single notification row, matching the mockup's card style: a
/// circular, colored icon (from the notification's own centralized
/// type.color/type.icon, so every screen that shows notifications
/// stays visually consistent), title and message stacked, a relative
/// timestamp, and a trailing chevron only when there's somewhere
/// specific to navigate to.
class _NotificationRow extends StatelessWidget {
  final FacilityNotification notification;
  final String relativeTime;

  const _NotificationRow({required this.notification, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final color = notification.type.color;
    final hasTarget = notification.relatedEntityType != null && notification.relatedEntityId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(notification.type.icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(notification.message,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                if (hasTarget) ...[
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
