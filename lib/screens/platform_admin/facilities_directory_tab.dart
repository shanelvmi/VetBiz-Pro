import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/subscription_status_utils.dart';
import '../../widgets/hover_elevate_card.dart';
import 'facility_detail_screen.dart';

/// Every facility across the whole platform, real pagination rather
/// than one open-ended listener over the entire collection - same
/// reasoning as the Users tab, and built ahead of actually reaching a
/// large facility count rather than waiting until it becomes a
/// visible problem.
class FacilitiesDirectoryTab extends StatefulWidget {
  const FacilitiesDirectoryTab({super.key});

  @override
  State<FacilitiesDirectoryTab> createState() => _FacilitiesDirectoryTabState();
}

class _FacilitiesDirectoryTabState extends State<FacilitiesDirectoryTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const int _pageSize = 50;
  // Search can't be paginated the same way as plain browsing -
  // Firestore has no native "contains" match on a name field, so this
  // fetches a bounded scan (ordered by name) and filters client-side
  // within that set, rather than pretending to search literally every
  // facility ever created. Large enough to comfortably cover a real
  // platform's near-term size. A genuinely huge platform beyond this
  // wouldn't find one past this scan - a real, named tradeoff, not a
  // silent one.
  static const int _searchScanLimit = 500;

  final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  String? _loadError;

  // Deliberately a one-time fetch, not a live listener - this needs
  // the FULL platform picture to mean what it claims ("how's the
  // whole business doing"), and status isn't a field Firestore can
  // cheaply aggregate by (it's computed client-side from two
  // different date fields plus a grace-period rule). A live listener
  // here would re-download and re-compute every facility's status on
  // every single change to any facility anywhere on the platform,
  // just to keep a summary stat current to the second - not worth
  // that cost for a number that's still accurate as of "when this
  // screen was last opened or refreshed".
  Map<SubscriptionStatusKind, int> _summaryCounts = {};
  int _summaryTotal = 0;
  bool _isSummaryLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialPage();
    _loadSummary();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  SubscriptionStatusKind _statusOf(Map<String, dynamic> data) {
    final expiresAtField = data['subscriptionExpiresAt'];
    final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
    final trialExpiresAtField = data['trialExpiresAt'];
    final trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;
    return computeSubscriptionStatus(expiresAt, trialExpiresAt);
  }

  Color _statusColor(SubscriptionStatusKind status) {
    switch (status) {
      case SubscriptionStatusKind.active:
        return Colors.green;
      case SubscriptionStatusKind.trial:
        return primaryColor;
      case SubscriptionStatusKind.grace:
        return Colors.orange;
      case SubscriptionStatusKind.locked:
        return Colors.redAccent;
    }
  }

  Future<void> _loadInitialPage() async {
    setState(() {
      _docs = [];
      _lastDoc = null;
      _hasMore = true;
      _isInitialLoading = true;
      _loadError = null;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore || _searchQuery.isNotEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      var query = FirebaseFirestore.instance.collection('facilities').orderBy('name').limit(_pageSize);
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);
      final snap = await query.get();
      if (!mounted) return;
      setState(() {
        _docs.addAll(snap.docs);
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _loadForSearch() async {
    setState(() {
      _isInitialLoading = true;
      _loadError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('facilities')
          .orderBy('name')
          .limit(_searchScanLimit)
          .get();
      if (!mounted) return;
      setState(() {
        _docs = snap.docs;
        _hasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isSummaryLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('facilities').get();
      if (!mounted) return;
      final counts = <SubscriptionStatusKind, int>{};
      for (final doc in snap.docs) {
        final status = _statusOf(doc.data());
        counts[status] = (counts[status] ?? 0) + 1;
      }
      setState(() {
        _summaryCounts = counts;
        _summaryTotal = snap.docs.length;
        _isSummaryLoading = false;
      });
    } catch (_) {
      // A failed summary refresh isn't worth surfacing as an error
      // state over the actual facility list below - it just keeps
      // showing whatever it last successfully loaded.
      if (mounted) setState(() => _isSummaryLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim().toLowerCase();
    setState(() => _searchQuery = trimmed);
    if (trimmed.isEmpty) {
      _loadInitialPage();
    } else {
      _loadForSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    var docs = _docs;
    if (_searchQuery.isNotEmpty) {
      docs = docs.where((doc) {
        final name = ((doc.data())['name'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            cursorColor: primaryColor,
            decoration: InputDecoration(
              hintText: 'Search facilities by name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _isSummaryLoading && _summaryTotal == 0
                    ? const LinearProgressIndicator(minHeight: 2)
                    : _SummaryRow(
                        total: _summaryTotal,
                        counts: _summaryCounts,
                        statusColor: _statusColor,
                      ),
              ),
              IconButton(
                icon: _isSummaryLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh totals',
                onPressed: _isSummaryLoading ? null : _loadSummary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _isInitialLoading && _docs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : (_loadError != null && _docs.isEmpty)
                  ? Center(child: Text('Could not load facilities: $_loadError'))
                  : docs.isEmpty
                      ? Center(
                          child: Text(_searchQuery.isEmpty
                              ? 'No facilities yet.'
                              : 'No facilities match your search.'),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // Same formula-based column scaling used
                            // elsewhere in this app (View Facilities,
                            // Manage Assistants) - adds columns
                            // smoothly on wider screens instead of
                            // stretching a fixed count further.
                            const idealCardWidth = 380.0;
                            final crossAxisCount =
                                (constraints.maxWidth / idealCardWidth).floor().clamp(1, 4);

                            if (crossAxisCount == 1) {
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: docs.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= docs.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  return _buildFacilityCard(docs[index]);
                                },
                              );
                            }

                            return GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 3.4,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) => _buildFacilityCard(docs[index]),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildFacilityCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final expiresAtField = data['subscriptionExpiresAt'];
    final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
    final trialExpiresAtField = data['trialExpiresAt'];
    final trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;
    final status = computeSubscriptionStatus(expiresAt, trialExpiresAt);
    final color = _statusColor(status);
    // Whichever date actually governs the status shown - a trial
    // facility's meaningful date is when its trial ends, not a
    // subscriptionExpiresAt it may not even have yet.
    final relevantDate = status == SubscriptionStatusKind.trial ? trialExpiresAt : expiresAt;

    return HoverElevateCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FacilityDetailScreen(facilityId: doc.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.storefront_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Unnamed facility',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((data['type'] as String?)?.isNotEmpty == true) data['type'],
                        if ((data['code'] as String?)?.isNotEmpty == true) data['code'],
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (relevantDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${status == SubscriptionStatusKind.trial ? 'Trial ends' : 'Expires'} ${_dateFormat.format(relevantDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Text(
                  subscriptionStatusLabel(status),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line breakdown of the whole facility base by status - lets a
/// Platform Admin see "how's the business doing" without counting
/// colored chips down a long list themselves.
class _SummaryRow extends StatelessWidget {
  final int total;
  final Map<SubscriptionStatusKind, int> counts;
  final Color Function(SubscriptionStatusKind) statusColor;

  const _SummaryRow({required this.total, required this.counts, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('$total total', const Color(0xFF2F5D62)),
          for (final status in SubscriptionStatusKind.values)
            if ((counts[status] ?? 0) > 0)
              _chip('${counts[status]} ${subscriptionStatusLabel(status)}', statusColor(status)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
