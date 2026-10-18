import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/hover_elevate_card.dart';
import '../../utils/presence_heartbeat.dart';
import 'user_detail_screen.dart';
import '../../services/role_change_service.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../data/user_status.dart';
import '../../config/app_limits.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/friendly_error.dart';

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
  static const int _pageSize = AppLimits.platformAdminPageSize;
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
  // Client-side only, unlike _roleFilter - avoids needing yet another
  // Firestore composite index for a role+status combination, and the
  // already-loaded page is a perfectly reasonable size to filter
  // locally against.
  String? _statusFilter;

  final ScrollController _scrollController = ScrollController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  // Corrects for _docs being a one-time-fetched, paginated snapshot
  // rather than a live stream - a card can show a status change made
  // on the detail screen (e.g. reactivated) the moment you return to
  // it, rather than only once this list happens to be re-fetched for
  // some unrelated reason (a filter change, a fresh page load).
  final Map<String, Map<String, dynamic>> _dataOverrides = {};

  // Falls back to the original cached snapshot when nothing has
  // changed since this list was first loaded.
  Map<String, dynamic> _effectiveData(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _dataOverrides[doc.id] ?? doc.data();
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  // The error itself, not its text: the view shows FriendlyError's message,
  // except for a missing-index error, whose link it keeps.
  Object? _loadError;

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
        FirebaseFirestore.instance.collection(Collections.users).orderBy('fullName');
    if (_roleFilter != null) {
      query = query.where(Fields.role, isEqualTo: _roleFilter);
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
      debugPrint('Users load failed: $e');
      if (mounted) setState(() => _loadError = e);
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
      debugPrint('Users load failed: $e');
      if (mounted) setState(() => _loadError = e);
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

  void _onStatusFilterChanged(String? status) {
    setState(() => _statusFilter = status);
  }

  // Compared to the keys rather than UserRole.fromKey, which would read an
  // unknown role as assistant: an unknown role stays grey.
  Color _roleColor(String role) {
    if (role == UserRole.admin.key) return context.colors.primary;
    if (role == UserRole.assistant.key) return context.colors.info;
    return context.colors.textHint;
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, 0),
          child: TextField(
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r10),
                borderSide: BorderSide(color: context.colors.primary, width: 2),
              ),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(Collections.users)
              .where(
                'lastActiveAt',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(DateTime.now().subtract(PresenceHeartbeat.onlineWindow)),
              )
              .snapshots(),
          builder: (context, onlineSnapshot) {
            final onlineCount = onlineSnapshot.data?.docs.length ?? 0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s12, 0),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.statusDot,
                    height: AppSizes.statusDot,
                    decoration: BoxDecoration(color: context.colors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    '$onlineCount online',
                    style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft, fontWeight: AppFontWeight.semibold),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          child: Row(
            children: [
              _RoleFilterChip(
                label: 'All',
                selected: _roleFilter == null,
                color: context.colors.primary,
                onTap: () => _onRoleFilterChanged(null),
              ),
              const SizedBox(width: AppSpacing.s8),
              _RoleFilterChip(
                label: 'Admins',
                selected: _roleFilter == UserRole.admin.key,
                color: context.colors.primary,
                onTap: () => _onRoleFilterChanged(UserRole.admin.key),
              ),
              const SizedBox(width: AppSpacing.s8),
              _RoleFilterChip(
                label: 'Assistants',
                selected: _roleFilter == UserRole.assistant.key,
                color: context.colors.info,
                onTap: () => _onRoleFilterChanged(UserRole.assistant.key),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 0, AppSpacing.s12, AppSpacing.s8),
          child: Row(
            children: [
              _RoleFilterChip(
                label: 'All',
                selected: _statusFilter == null,
                color: context.colors.primary,
                onTap: () => _onStatusFilterChanged(null),
              ),
              const SizedBox(width: AppSpacing.s8),
              _RoleFilterChip(
                label: 'Active',
                selected: _statusFilter == UserStatus.active.key,
                color: context.colors.success,
                onTap: () => _onStatusFilterChanged(UserStatus.active.key),
              ),
              const SizedBox(width: AppSpacing.s8),
              _RoleFilterChip(
                label: 'Awaiting Approval',
                selected: _statusFilter == UserStatus.pending.key,
                color: context.colors.info,
                onTap: () => _onStatusFilterChanged(UserStatus.pending.key),
              ),
              const SizedBox(width: AppSpacing.s8),
              _RoleFilterChip(
                label: 'Deactivated',
                selected: _statusFilter == UserStatus.deactivated.key,
                color: context.colors.warning,
                onTap: () => _onStatusFilterChanged(UserStatus.deactivated.key),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(Collections.platformAdmins).snapshots(),
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
                    .collection(Collections.users)
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

  Widget _buildErrorView(Object errorObject) {
    final error = '$errorObject';
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(error);
    var url = urlMatch?.group(0);
    // Trim trailing punctuation that might have been swept up if the
    // URL sits at the end of a sentence.
    if (url != null) {
      url = url.replaceAll(RegExp(r'[.,;:\)\]]+$'), '');
    }
    final message = url != null ? error.replaceFirst(url, '').trim() : FriendlyError.messageFor(errorObject);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load users: $message', textAlign: TextAlign.center),
            if (url != null) ...[
              const SizedBox(height: AppSpacing.s12),
              InkWell(
                onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
                child: Text(
                  url,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.info, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      ),
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
      return _buildErrorView(_loadError!);
    }

    var platformAdminDocs = platformAdminDocsRaw.where((doc) {
      final data = _effectiveData(doc);
      if (_roleFilter != null && data[Fields.role] != _roleFilter) return false;
      if (_statusFilter != null && (data[Fields.status] ?? UserStatus.active.key) != _statusFilter) {
        return false;
      }
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
    if (_statusFilter != null) {
      docs = docs.where((doc) {
        final data = _effectiveData(doc);
        return (data[Fields.status] ?? UserStatus.active.key) == _statusFilter;
      }).toList();
    }
    if (_search.isNotEmpty) {
      docs = docs.where((doc) => _matchesSearch(_effectiveData(doc))).toList();
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

        final Widget scrollable;
        if (crossAxisCount == 1) {
          scrollable = ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
            itemCount: items.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return items[index];
            },
          );
        } else {
          scrollable = GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 4.2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          );
        }

        if (platformAdminDocs.isEmpty) return scrollable;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s12, AppSpacing.s4),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, size: AppIconSize.i14, color: context.colors.rolePlatformAdmin),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    'Platform Admins (${platformAdminDocs.length})',
                    style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f12_5, color: context.colors.rolePlatformAdmin),
                  ),
                ],
              ),
            ),
            Expanded(child: scrollable),
          ],
        );
      },
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool isPlatformAdmin) {
    final data = _effectiveData(doc);
    final facilities = (data['facilities'] as List?)?.cast<dynamic>() ?? [];
    final status = (data[Fields.status] ?? UserStatus.active.key).toString();
    final role = (data[Fields.role] ?? 'unknown').toString();
    final name = (data['fullName'] ?? 'Unknown').toString();
    final roleColor = _roleColor(role);

    final lastActiveField = data['lastActiveAt'];
    final lastActiveAt = lastActiveField is Timestamp ? lastActiveField.toDate() : null;
    final isOnline =
        lastActiveAt != null && DateTime.now().difference(lastActiveAt) <= PresenceHeartbeat.onlineWindow;

    return HoverElevateCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
      child: Stack(
        children: [
          InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailScreen(userId: doc.id, userData: data),
            ),
          );
          if (!mounted) return;
          final freshDoc = await FirebaseFirestore.instance.collection(Collections.users).doc(doc.id).get();
          if (!mounted) return;
          final freshData = freshDoc.data();
          if (freshData != null) {
            setState(() => _dataOverrides[doc.id] = freshData);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isPlatformAdmin ? context.colors.rolePlatformAdmin : context.colors.primary,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: context.colors.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPlatformAdmin) ...[
                          const SizedBox(width: AppSpacing.s6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                            decoration: BoxDecoration(
                              color: context.colors.rolePlatformAdmin.withValues(alpha: AppAlpha.a10),
                              borderRadius: BorderRadius.circular(AppRadius.r8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium, size: AppIconSize.i12, color: context.colors.rolePlatformAdmin),
                                const SizedBox(width: AppSpacing.s3),
                                Text(
                                  'Platform Admin',
                                  style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.rolePlatformAdmin, fontWeight: AppFontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      data['email'] ?? '',
                      style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: AppAlpha.a10),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: Text(RoleChangeService.isCoAdmin(data) ? 'co-admin' : role,
                              style: TextStyle(color: roleColor, fontSize: AppFontSize.f10_5, fontWeight: AppFontWeight.semibold)),
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Text(
                          '${facilities.length} ${facilities.length == 1 ? 'facility' : 'facilities'}',
                          style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status != UserStatus.active.key)
                Chip(
                  label: Text(
                    status == UserStatus.pending.key ? 'Awaiting Approval' : status,
                    style: const TextStyle(fontSize: AppFontSize.f11),
                  ),
                  backgroundColor: status == UserStatus.pending.key ? context.colors.statusPendingFill : context.colors.statusOtherFill,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
          ),
          if (isOnline)
            Positioned(
              top: 6,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: context.colors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Text(
                    'Online',
                    style: TextStyle(fontSize: AppFontSize.f9, color: context.colors.successStrong, fontWeight: AppFontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
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
      borderRadius: BorderRadius.circular(AppRadius.r20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: AppAlpha.a10) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r20),
          border: Border.all(color: selected ? color : context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : context.colors.textSoft,
            fontSize: AppFontSize.f12_5,
            fontWeight: selected ? AppFontWeight.semibold : AppFontWeight.medium,
          ),
        ),
      ),
    );
  }
}
