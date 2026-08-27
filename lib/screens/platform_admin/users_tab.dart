import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/hover_elevate_card.dart';
import 'user_detail_screen.dart';

/// Every registered user across the whole platform, not scoped to one
/// facility - the missing piece that made "an assistant switching
/// facilities" a dead end before: their email already exists, so they
/// can't register again, and there was no way for anyone to see that
/// existing account and just add the new facility to it.
///
/// Real pagination, not one open-ended listener over the entire
/// collection - at genuine scale (hundreds to thousands of users),
/// downloading everyone every time this screen opens, and re-syncing
/// the whole list on any change to any user anywhere, was a real cost
/// worth avoiding.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const int _pageSize = 50;
  // Search can't be paginated the same way as plain browsing -
  // Firestore has no native "contains" match across two fields, so
  // this fetches a bounded scan (ordered by name, respecting the role
  // filter if one's set) and filters name/email client-side within
  // that set, rather than pretending to search literally every user
  // ever created. Large enough to comfortably cover most real
  // facilities' total user counts. A genuinely huge platform (beyond
  // this) wouldn't find someone past this scan - a real, named
  // tradeoff, not a silent one.
  static const int _searchScanLimit = 500;

  String _search = '';
  String? _roleFilter;

  final ScrollController _scrollController = ScrollController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Search mode already fetched everything it's going to show (up
    // to _searchScanLimit) in one go - nothing further to page in.
    if (_search.isNotEmpty) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('users').orderBy('fullName');
    if (_roleFilter != null) {
      query = query.where('role', isEqualTo: _roleFilter);
    }
    return query;
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
    if (!_hasMore || _isLoadingMore || _search.isNotEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      var query = _baseQuery().limit(_pageSize);
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
      final snap = await _baseQuery().limit(_searchScanLimit).get();
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

  void _onSearchChanged(String value) {
    final trimmed = value.trim().toLowerCase();
    setState(() => _search = trimmed);
    if (trimmed.isEmpty) {
      _loadInitialPage();
    } else {
      _loadForSearch();
    }
  }

  void _onRoleFilterChanged(String? role) {
    setState(() => _roleFilter = role);
    if (_search.isNotEmpty) {
      _loadForSearch();
    } else {
      _loadInitialPage();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return primaryColor;
      case 'assistant':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;
    final name = (data['fullName'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    return name.contains(_search) || email.contains(_search);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            cursorColor: primaryColor,
            decoration: InputDecoration(
              hintText: 'Search by name or email',
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _RoleFilterChip(
                label: 'All',
                selected: _roleFilter == null,
                color: primaryColor,
                onTap: () => _onRoleFilterChanged(null),
              ),
              const SizedBox(width: 8),
              _RoleFilterChip(
                label: 'Admins',
                selected: _roleFilter == 'admin',
                color: primaryColor,
                onTap: () => _onRoleFilterChanged('admin'),
              ),
              const SizedBox(width: 8),
              _RoleFilterChip(
                label: 'Assistants',
                selected: _roleFilter == 'assistant',
                color: Colors.blue,
                onTap: () => _onRoleFilterChanged('assistant'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('platform_admins').snapshots(),
            builder: (context, platformAdminsSnapshot) {
              final platformAdminIds =
                  (platformAdminsSnapshot.data?.docs ?? []).map((doc) => doc.id).toSet();

              // A Platform Admin's own user doc, fetched live and
              // always shown in its own section above the paginated
              // list - a small, bounded group regardless of total
              // platform size, so this stays a single, simple query
              // rather than needing pagination of its own. Excluded
              // from the paginated results below (client-side) so
              // nobody ever appears twice.
              if (platformAdminIds.isEmpty) {
                return _buildBody(const [], platformAdminIds);
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: platformAdminIds.take(30).toList())
                    .snapshots(),
                builder: (context, platformAdminDocsSnapshot) {
                  final platformAdminDocs = platformAdminDocsSnapshot.data?.docs ?? [];
                  return _buildBody(platformAdminDocs, platformAdminIds);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> platformAdminDocsRaw,
    Set<String> platformAdminIds,
  ) {
    if (_isInitialLoading && _docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _docs.isEmpty) {
      return Center(child: Text('Could not load users: $_loadError'));
    }

    var platformAdminDocs = platformAdminDocsRaw.where((doc) {
      final data = doc.data();
      if (_roleFilter != null && data['role'] != _roleFilter) return false;
      return _matchesSearch(data);
    }).toList();
    platformAdminDocs.sort((a, b) {
      final an = (a.data()['fullName'] ?? '').toString();
      final bn = (b.data()['fullName'] ?? '').toString();
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    // Platform Admins are always shown in their own section above,
    // never duplicated here too.
    var docs = _docs.where((doc) => !platformAdminIds.contains(doc.id)).toList();
    if (_search.isNotEmpty) {
      docs = docs.where((doc) => _matchesSearch(doc.data())).toList();
    }

    if (docs.isEmpty && platformAdminDocs.isEmpty) {
      return Center(
        child: Text(_search.isEmpty ? 'No users found.' : 'No users match "$_search".'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same formula-based column scaling as Facilities Directory -
        // adds columns smoothly on wider screens instead of
        // stretching a fixed count.
        const idealCardWidth = 380.0;
        final crossAxisCount = (constraints.maxWidth / idealCardWidth).floor().clamp(1, 4);

        final items = <Widget>[
          ...platformAdminDocs.map((doc) => _buildUserCard(doc, true)),
          ...docs.map((doc) => _buildUserCard(doc, false)),
        ];

        if (crossAxisCount == 1) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: items.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return items[index];
            },
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 4.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool isPlatformAdmin) {
    final data = doc.data();
    final facilities = (data['facilities'] as List?)?.cast<dynamic>() ?? [];
    final status = (data['status'] ?? 'active').toString();
    final role = (data['role'] ?? 'unknown').toString();
    final name = (data['fullName'] ?? 'Unknown').toString();
    final roleColor = _roleColor(role);

    return HoverElevateCard(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailScreen(userId: doc.id, userData: data),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isPlatformAdmin ? Colors.deepPurple : primaryColor,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPlatformAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium, size: 11, color: Colors.deepPurple),
                                SizedBox(width: 3),
                                Text(
                                  'Platform Admin',
                                  style: TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['email'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(role, style: TextStyle(color: roleColor, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${facilities.length} ${facilities.length == 1 ? 'facility' : 'facilities'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status != 'active')
                Chip(
                  label: Text(status, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.orange.shade100,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey[700],
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
