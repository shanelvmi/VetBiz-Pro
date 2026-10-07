import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'subscription_screen.dart' show submissionStatusColor;
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/payment_submission_status.dart';
import '../../config/money.dart';

/// One payment submission, read from a payment_submissions document.
class _Submission {
  final String planLabel;
  final num amount;
  final String method;
  final String reference;
  final String status; // 'approved' | 'rejected' | 'pending'
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String reviewNote; // the rejection reason - empty if none was given
  final String? promotionLabel;

  const _Submission({
    required this.planLabel,
    required this.amount,
    required this.method,
    required this.reference,
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewNote,
    required this.promotionLabel,
  });

  factory _Submission.fromMap(Map<String, dynamic> d) {
    DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    final rawStatus = (d[Fields.status] as String?) ?? PaymentSubmissionStatus.pending.key;
    return _Submission(
      planLabel: (d['planLabel'] as String?) ?? '',
      amount: (d['amount'] as num?) ?? 0,
      method: (d['method'] as String?) ?? '',
      reference: ((d['reference'] as String?) ?? '').trim(),
      // Anything that isn't a final decision is still waiting on one.
      status: (rawStatus == PaymentSubmissionStatus.approved.key || rawStatus == PaymentSubmissionStatus.rejected.key) ? rawStatus : PaymentSubmissionStatus.pending.key,
      submittedAt: asDate(d['submittedAt']),
      reviewedAt: asDate(d['reviewedAt']),
      reviewNote: ((d['reviewNote'] as String?) ?? '').trim(),
      promotionLabel: d['promotionLabel'] as String?,
    );
  }

  bool get hasReason => reviewNote.isNotEmpty;
}

/// The full subscription/payment submission history for a facility -
/// reached via "View all" on the Subscription screen's own recent-list
/// section, which only ever shows a handful at a glance.
///
/// Laid out like the Sales and Product Alerts screens: small summary
/// cards (tap one to filter), one search/filter row, a full-width table,
/// and the same pagination bar. A rejected submission shows the reason
/// the platform admin gave, right in the row.
class SubscriptionHistoryScreen extends StatefulWidget {
  final String facilityId;
  final Color primaryColor;

  const SubscriptionHistoryScreen({super.key, required this.facilityId, required this.primaryColor});

  @override
  State<SubscriptionHistoryScreen> createState() => _SubscriptionHistoryScreenState();
}

class _SubscriptionHistoryScreenState extends State<SubscriptionHistoryScreen> {
  // A generous cap rather than a truly unlimited query - protects
  // against an unbounded read for a facility with an unusually long
  // history, while still comfortably covering years of normal use.
  static const int _historyLimit = 200;

  // Created once - building a new stream inside build() would restart
  // the StreamBuilder (back to "waiting") on every filter tap.
  late final Stream<QuerySnapshot> _stream;

  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  String _searchQuery = '';
  String? _statusFilter; // null = all
  String _planFilter = 'All';
  String _methodFilter = 'All';
  int _page = 1;
  int _pageSize = 10;

  Color get _primary => widget.primaryColor;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection(Collections.facilities)
        .doc(widget.facilityId)
        .collection(Collections.paymentSubmissions)
        .orderBy('submittedAt', descending: true)
        .limit(_historyLimit)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusName(String status) => status[0].toUpperCase() + status.substring(1);

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
      _planFilter = 'All';
      _methodFilter = 'All';
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Subscription History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
            Text('Your payments and their review status', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load history: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = (snapshot.data?.docs ?? [])
              .map((d) => _Submission.fromMap(d.data() as Map<String, dynamic>))
              .toList();
          return _buildBody(all);
        },
      ),
    );
  }

  Widget _buildBody(List<_Submission> all) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No submissions yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Payments you submit will be listed here.', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    final counts = <String, int>{PaymentSubmissionStatus.approved.key: 0, PaymentSubmissionStatus.pending.key: 0, PaymentSubmissionStatus.rejected.key: 0};
    num approvedTotal = 0;
    for (final s in all) {
      counts[s.status] = (counts[s.status] ?? 0) + 1;
      if (s.status == PaymentSubmissionStatus.approved.key) approvedTotal += s.amount;
    }

    final plans = <String>{for (final s in all) if (s.planLabel.isNotEmpty) s.planLabel}.toList()..sort();
    final methods = <String>{for (final s in all) if (s.method.isNotEmpty) s.method}.toList()..sort();
    // A chosen plan/method can vanish if the data changes underneath it.
    final plan = (_planFilter == 'All' || plans.contains(_planFilter)) ? _planFilter : 'All';
    final method = (_methodFilter == 'All' || methods.contains(_methodFilter)) ? _methodFilter : 'All';

    final q = _searchQuery.trim().toLowerCase();
    final filtered = all.where((s) {
      if (_statusFilter != null && s.status != _statusFilter) return false;
      if (plan != 'All' && s.planLabel != plan) return false;
      if (method != 'All' && s.method != method) return false;
      if (q.isNotEmpty) {
        final hay = '${s.planLabel} ${s.method} ${s.reference} ${s.reviewNote} ${s.status} ${s.promotionLabel ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final hasActiveFilters = _searchQuery.trim().isNotEmpty || _statusFilter != null || plan != 'All' || method != 'All';

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    final page = _page > totalPages ? totalPages : _page;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildCards(all.length, counts, approvedTotal),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilters(plans, plan, methods, method, hasActiveFilters),
        ),
        Expanded(
          child: filtered.isEmpty ? _buildNoMatches() : _buildResults(pageItems),
        ),
        _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );
  }

  // ==================== CARDS ====================

  Widget _buildCards(int totalCount, Map<String, int> counts, num approvedTotal) {
    final cards = <Widget>[
      _card(
        label: 'Total Submissions',
        value: '$totalCount',
        hint: 'All payments',
        icon: Icons.receipt_long_outlined,
        color: _primary,
        filter: null,
      ),
      _card(
        label: 'Approved',
        value: '${counts[PaymentSubmissionStatus.approved.key] ?? 0}',
        hint: Money.format(approvedTotal),
        icon: Icons.check_circle_outline,
        color: submissionStatusColor(PaymentSubmissionStatus.approved.key),
        filter: PaymentSubmissionStatus.approved.key,
      ),
      _card(
        label: 'Pending',
        value: '${counts[PaymentSubmissionStatus.pending.key] ?? 0}',
        hint: 'Awaiting review',
        icon: Icons.hourglass_empty,
        color: submissionStatusColor(PaymentSubmissionStatus.pending.key),
        filter: PaymentSubmissionStatus.pending.key,
      ),
      _card(
        label: 'Rejected',
        value: '${counts[PaymentSubmissionStatus.rejected.key] ?? 0}',
        hint: 'Not accepted',
        icon: Icons.cancel_outlined,
        color: submissionStatusColor(PaymentSubmissionStatus.rejected.key),
        filter: PaymentSubmissionStatus.rejected.key,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 600 ? 4 : 2,
            mainAxisExtent: 90,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: cards,
        );
      },
    );
  }

  // Same small card as Sales / Product Alerts. Tapping a status card
  // filters the table to it (tap again to clear); the Total card clears
  // the status filter.
  Widget _card({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
    required String? filter,
  }) {
    final selected = filter != null && _statusFilter == filter;
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
          _statusFilter = (filter == null || selected) ? null : filter;
          _page = 1;
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
                      child: Icon(icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                Text(hint, style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters(List<String> plans, String plan, List<String> methods, String method, bool hasActiveFilters) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by plan, method, reference or reason...',
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
                    _page = 1;
                  });
                },
              ),
      ),
      onChanged: (v) => setState(() {
        _searchQuery = v;
        _page = 1;
      }),
    );

    final reset = hasActiveFilters ? TextButton(onPressed: _resetFilters, child: const Text('Reset')) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _dropdown('Plan', plan, plans, (v) => _planFilter = v, expand: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _dropdown('Method', method, methods, (v) => _methodFilter = v, expand: true)),
                  if (reset != null) ...[const SizedBox(width: 6), reset],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            _dropdown('Plan', plan, plans, (v) => _planFilter = v),
            const SizedBox(width: 10),
            _dropdown('Method', method, methods, (v) => _methodFilter = v),
            if (reset != null) ...[const SizedBox(width: 10), reset],
          ],
        );
      },
    );
  }

  Widget _dropdown(String label, String value, List<String> options, void Function(String) assign,
      {bool expand = false}) {
    final items = ['All', ...options];
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
          value: value,
          isExpanded: expand,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: _primary),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text('$label: $v', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                assign(v);
                _page = 1;
              });
            }
          },
        ),
      ),
    );
  }

  // ==================== TABLE ====================

  Widget _buildNoMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No submissions match your filters', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton(onPressed: _resetFilters, child: const Text('Reset filters')),
        ],
      ),
    );
  }

  Widget _buildResults(List<_Submission> items) {
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
                  _headerCell('Submitted', flex: 3),
                  _headerCell('Plan', flex: 3),
                  _headerCell('Amount', flex: 2),
                  _headerCell('Method', flex: 3),
                  _headerCell('Status', flex: 2),
                  _headerCell('Details', flex: 5),
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

  Widget _statusChip(String status) {
    final color = submissionStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(_statusName(status), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  // What this row says about the review: for a rejection, the reason
  // (or an honest "none given"), for an approval when, for a pending
  // one that it's still waiting.
  Widget _detailsFor(_Submission s) {
    switch (PaymentSubmissionStatus.fromKey(s.status)) {
      case PaymentSubmissionStatus.rejected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.hasReason ? 'Reason: ${s.reviewNote}' : 'No reason was given',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: s.hasReason ? Colors.red[700] : Colors.grey[600],
                fontStyle: s.hasReason ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            if (s.reviewedAt != null) ...[
              const SizedBox(height: 2),
              Text('Rejected ${_dateTimeFormat.format(s.reviewedAt!)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            ],
          ],
        );
      case PaymentSubmissionStatus.approved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approved', style: TextStyle(fontSize: 12.5, color: Colors.green[700], fontWeight: FontWeight.w500)),
            if (s.reviewedAt != null) ...[
              const SizedBox(height: 2),
              Text(_dateTimeFormat.format(s.reviewedAt!), style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            ],
          ],
        );
      default:
        return Text('Awaiting review', style: TextStyle(fontSize: 12.5, color: Colors.grey[600]));
    }
  }

  // Wide layout: one table row.
  Widget _buildRow(_Submission s) {
    final submitted = s.submittedAt;
    return Container(
      // Coloured bar down the left edge - the outcome at a glance.
      decoration: BoxDecoration(border: Border(left: BorderSide(color: submissionStatusColor(s.status), width: 4))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: submitted == null
                ? const Text('-', style: TextStyle(fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_dateFormat.format(submitted), style: const TextStyle(fontSize: 13)),
                      Text(DateFormat('HH:mm').format(submitted),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    ],
                  ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.planLabel.isEmpty ? '-' : s.planLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                if (s.promotionLabel != null && s.promotionLabel!.isNotEmpty)
                  Text(s.promotionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(Money.format(s.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.method.isEmpty ? '-' : s.method,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                if (s.reference.isNotEmpty)
                  Text(s.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(s.status))),
          Expanded(flex: 5, child: _detailsFor(s)),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per submission.
  Widget _buildNarrowCard(_Submission s) {
    final submitted = s.submittedAt;
    final color = submissionStatusColor(s.status);
    final methodLine = [if (s.method.isNotEmpty) s.method, if (s.reference.isNotEmpty) s.reference].join(' · ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      // Clipped so the bar down the left follows the card's rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(s.planLabel.isEmpty ? '-' : s.planLabel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(Money.format(s.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              if (s.promotionLabel != null && s.promotionLabel!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(s.promotionLabel!, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  _statusChip(s.status),
                  const SizedBox(width: 8),
                  if (submitted != null)
                    Expanded(
                      child: Text(_dateTimeFormat.format(submitted),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    ),
                ],
              ),
              if (methodLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(methodLine, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
              if (s.status != PaymentSubmissionStatus.pending.key) ...[
                const SizedBox(height: 8),
                _detailsFor(s),
              ],
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
            total == 0 ? 'No submissions' : 'Showing $start to $end of $total submission${total == 1 ? '' : 's'}',
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
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _pageSize = v;
                        _page = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => setState(() => _page = page - 1) : null,
              ),
              Text('Page $page', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => setState(() => _page = page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
