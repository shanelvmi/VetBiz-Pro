import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invite_assistant_dialog.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/initials_avatar.dart';

class ManageAssistantsScreen extends StatefulWidget {
  // Set when opened as a deep link from a specific facility's card in
  // View Facilities - pre-fills and expands the search so it's
  // immediately filtered to that facility's team, rather than the
  // full, unfiltered list of every assistant across every facility.
  final String? initialSearchQuery;
  const ManageAssistantsScreen({super.key, this.initialSearchQuery});

  @override
  State<ManageAssistantsScreen> createState() => _ManageAssistantsScreenState();
}

class _ManageAssistantsScreenState extends State<ManageAssistantsScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color backgroundColor = const Color(0xFFFDFDF9);
  final Color accentColor = const Color(0xFFFFB200);

  late final String adminUid;
  List<String> adminFacilityIds = [];
  Map<String, String> facilityNames = {};
  // Created once, only when adminFacilityIds actually changes (initial
  // load, or an explicit Refresh) - not on every rebuild. A
  // StreamBuilder given a brand-new stream instance on every build
  // resets to its loading state before that new stream's first value
  // arrives, which was causing this screen to load slowly and its
  // assistants to appear staggered rather than all at once.
  Stream<QuerySnapshot>? _assistantsStream;

  // False until the first facility lookup finishes - without it the
  // "No facilities found" message flashed up while that lookup was still
  // running.
  bool _facilitiesLoaded = false;

  String _searchQuery = ''; // trimmed + lowercased
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter; // 'active' | 'deactivated' | 'pending', null = all
  String _facilityFilter = 'All'; // a facility id, or 'All'
  int _page = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
      _searchController.text = widget.initialSearchQuery!.trim();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      adminUid = user.uid;
      _fetchAdminFacilities();
    } else {
      adminUid = '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // "Ukuli Agrovet" rather than just "Ukuli": the facility's type follows
  // its name - unless the name already says it, so a facility saved as
  // "Ukuli Agrovet" doesn't turn into "Ukuli Agrovet Agrovet". Everything
  // on this screen that shows a facility reads from facilityNames, so this
  // one place covers the table, cards, filter, search, and the reassign and
  // invite pickers.
  String _nameWithType(Map<String, dynamic> facility) {
    final name = ((facility['name'] as String?) ?? '').trim();
    final type = ((facility['type'] as String?) ?? '').trim();
    if (name.isEmpty) return 'Unknown';
    if (type.isEmpty || name.toLowerCase().contains(type.toLowerCase())) return name;
    return '$name $type';
  }

  Future<void> _fetchAdminFacilities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .where('createdBy', isEqualTo: adminUid)
          .get();

      if (!mounted) return;
      setState(() {
        adminFacilityIds = snapshot.docs.map((doc) => doc.id).toList();
        facilityNames = {
          for (var doc in snapshot.docs) doc.id: _nameWithType(doc.data())
        };
        _assistantsStream = adminFacilityIds.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'assistant')
                .where('facilityIds', arrayContainsAny: adminFacilityIds)
                .snapshots();
        _facilitiesLoaded = true;
      });
    } catch (e) {
      debugPrint('Error fetching admin facilities: $e');
      if (mounted) setState(() => _facilitiesLoaded = true);
    }
  }

  Future<void> updateAssistantStatus(String userId, String newStatus) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': newStatus,
        'statusChangedBy': currentUser?.email ?? currentUser?.uid ?? 'Unknown',
        'statusChangedByRole': 'Facility Admin',
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assistant status updated to $newStatus')),
      );
    } catch (e) {
      debugPrint('Error updating assistant status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  // Unlinks just this one facility, never touches status/role or the
  // account itself - deactivating or permanently removing an account
  // is Platform-Admin-only. A boss can still "fire" an assistant from
  // their own team without needing to contact a Platform Admin for
  // something this routine; the assistant's login stays fully active
  // and they could be invited to a facility again later.
  Future<void> removeFromFacility(String userId, String facilityId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = userDoc.data();
      if (data == null) return;

      final currentFacilityIds = (data['facilityIds'] as List?)?.cast<dynamic>() ?? [];
      final currentFacilities = (data['facilities'] as List?)?.cast<dynamic>() ?? [];

      final newFacilityIds = currentFacilityIds.where((id) => id != facilityId).toList();
      final newFacilities = currentFacilities
          .where((f) => (f as Map)['facilityId'] != facilityId)
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'facilityIds': newFacilityIds,
        'facilities': newFacilities,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant removed from this facility')),
      );
    } catch (e) {
      debugPrint('Error removing assistant from facility: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

  Future<void> reassignAssistant(String userId, String newFacilityId) async {
    try {
      // facilityIds is what every Firestore rule's isInFacility() check
      // relies on, but facilities is the separate, denormalized array
      // this app's UI actually reads for display (this screen, the
      // Dashboard drawer, the facility picker). Updating only
      // facilityIds left facilities still pointing at the old
      // facility - the assistant would keep seeing the old facility's
      // name/details everywhere, even though access to its actual data
      // was already revoked.
      final newFacilityDoc =
          await FirebaseFirestore.instance.collection('facilities').doc(newFacilityId).get();
      final newFacilityData = newFacilityDoc.data();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'facilityIds': [newFacilityId],
        'facilities': [
          {
            'facilityId': newFacilityId,
            'name': newFacilityData?['name'] ?? '',
            'type': newFacilityData?['type'] ?? '',
            'code': newFacilityData?['code'] ?? '',
          },
        ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistant reassigned successfully')));
    } catch (e) {
      debugPrint('Error reassigning assistant: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reassign: $e')),
      );
    }
  }

  void _showFacilityPickerDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Reassign Assistant', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 16),
                ...facilityNames.entries.map((entry) {
                  return StatefulBuilder(
                    builder: (context, setHoverState) {
                      bool hovered = false;
                      return MouseRegion(
                        onEnter: (_) => setHoverState(() => hovered = true),
                        onExit: (_) => setHoverState(() => hovered = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            reassignAssistant(userId, entry.key);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hovered ? Colors.grey[800] : Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(entry.value, style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startInviteFlow() async {
    if (adminFacilityIds.isEmpty) return;

    if (adminFacilityIds.length == 1) {
      await showInviteAssistantDialog(context, adminFacilityIds.first);
      return;
    }

    // More than one facility - ask which one this invite is for, since
    // there's no way to infer that otherwise.
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Invite Assistant To...'),
        children: adminFacilityIds.map((id) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, id),
            child: Text(facilityNames[id] ?? 'Unknown facility'),
          );
        }).toList(),
      ),
    );

    if (chosen != null && mounted) {
      await showInviteAssistantDialog(context, chosen);
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) return Colors.white;
          return color;
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) return color;
          return null;
        }),
        side: WidgetStateProperty.all(BorderSide(color: color.withValues(alpha: 0.6))),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        minimumSize: WidgetStateProperty.all(const Size(0, 34)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }

  // Anything that isn't active or deactivated is waiting on a decision -
  // same as before, just named once.
  String _bucket(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString();
    if (status == 'active') return 'active';
    if (status == 'deactivated') return 'deactivated';
    return 'pending';
  }

  Color _statusColor(String bucket) {
    switch (bucket) {
      case 'active':
        return Colors.green;
      case 'deactivated':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String bucket) {
    switch (bucket) {
      case 'active':
        return 'Active';
      case 'deactivated':
        return 'Deactivated';
      default:
        return 'Pending';
    }
  }

  // First facility id on the record, or '' - an empty list used to throw.
  String _facilityIdOf(Map<String, dynamic> data) {
    final ids = data['facilityIds'] as List?;
    return (ids != null && ids.isNotEmpty) ? ids.first.toString() : '';
  }

  // Shared between the card layout (narrow screens) and the table row
  // layout (wide screens) - the status-driven action logic is identical
  // either way, only the surrounding container differs.
  List<Widget> _buildActionButtons(QueryDocumentSnapshot doc, String status, String facilityId) {
    return [
      if (status == 'pending')
        _actionButton(
          label: 'Approve',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          onPressed: () => updateAssistantStatus(doc.id, 'active'),
        ),
      if (status == 'active')
        _actionButton(
          label: 'Deactivate',
          icon: Icons.pause_circle_outline,
          color: Colors.orange,
          onPressed: () => updateAssistantStatus(doc.id, 'deactivated'),
        ),
      if (status == 'deactivated')
        _actionButton(
          label: 'Reactivate',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          onPressed: () => updateAssistantStatus(doc.id, 'active'),
        ),
      if (status == 'active')
        _actionButton(
          label: 'Reassign',
          icon: Icons.swap_horiz,
          color: Colors.teal,
          onPressed: () => _showFacilityPickerDialog(doc.id),
        ),
      if (status == 'deactivated')
        _actionButton(
          label: 'Remove from Facility',
          icon: Icons.person_remove_outlined,
          color: Colors.grey[700]!,
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Remove from Facility'),
                content: const Text(
                    'This removes the assistant from your facility only - their login stays '
                    'active and they can be invited to a facility again later. Only a Platform '
                    'Admin can permanently delete an account.',
                    style: TextStyle(fontSize: 13)),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Remove'),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await removeFromFacility(doc.id, facilityId);
            }
          },
        ),
    ];
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
      _facilityFilter = 'All';
      _page = 1;
    });
  }

  PreferredSizeWidget _buildAppBar() {
    final narrow = MediaQuery.of(context).size.width < 600;
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('My Assistants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text("Manage your team's access and status", style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Assistants',
          onPressed: _fetchAdminFacilities,
        ),
        // Same place Sales puts "Record Sale" - the primary action lives
        // in the app bar, not a floating button.
        if (narrow)
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Invite Assistant',
            onPressed: _startInviteFlow,
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _startInviteFlow,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invite Assistant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (adminUid.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(),
        body: const Center(child: Text('No logged in admin user found')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: !_facilitiesLoaded
          ? const Center(child: CircularProgressIndicator())
          : adminFacilityIds.isEmpty
              ? const Center(child: Text('No facilities found for your account.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _assistantsStream!,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: FirestoreErrorView(error: snapshot.error));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildBody(snapshot.data?.docs ?? []);
                  },
                ),
    );
  }

  Widget _buildBody(List<QueryDocumentSnapshot> all) {
    final counts = <String, int>{'active': 0, 'deactivated': 0, 'pending': 0};
    for (final doc in all) {
      final b = _bucket(doc.data() as Map<String, dynamic>);
      counts[b] = (counts[b] ?? 0) + 1;
    }

    // A chosen facility can disappear if the list changes underneath it.
    final facility = (_facilityFilter == 'All' || facilityNames.containsKey(_facilityFilter)) ? _facilityFilter : 'All';

    final q = _searchQuery;
    final filtered = all.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_statusFilter != null && _bucket(data) != _statusFilter) return false;
      final fid = _facilityIdOf(data);
      if (facility != 'All' && fid != facility) return false;
      if (q.isNotEmpty) {
        final name = (data['fullName'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        final facilityName = (facilityNames[fid] ?? '').toLowerCase();
        if (!name.contains(q) && !phone.contains(q) && !facilityName.contains(q)) return false;
      }
      return true;
    }).toList();

    // Anyone waiting on a decision comes first, then active, then
    // deactivated - the people who need something from you are at the top.
    int rank(String b) => b == 'pending' ? 0 : (b == 'active' ? 1 : 2);
    filtered.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      final byStatus = rank(_bucket(da)).compareTo(rank(_bucket(db)));
      if (byStatus != 0) return byStatus;
      return (da['fullName'] ?? '').toString().toLowerCase().compareTo((db['fullName'] ?? '').toString().toLowerCase());
    });

    final hasActiveFilters = q.isNotEmpty || _statusFilter != null || facility != 'All';

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    final page = _page > totalPages ? totalPages : _page;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildCards(all.length, counts),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilters(facility, hasActiveFilters),
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

  Widget _buildCards(int totalCount, Map<String, int> counts) {
    final cards = <Widget>[
      _card(
        label: 'Total',
        value: '$totalCount',
        hint: 'Across your facilities',
        icon: Icons.groups_outlined,
        color: primaryColor,
        filter: null,
      ),
      _card(
        label: 'Active',
        value: '${counts['active'] ?? 0}',
        hint: 'Have access',
        icon: Icons.check_circle_outline,
        color: _statusColor('active'),
        filter: 'active',
      ),
      _card(
        label: 'Deactivated',
        value: '${counts['deactivated'] ?? 0}',
        hint: 'Access paused',
        icon: Icons.pause_circle_outline,
        color: _statusColor('deactivated'),
        filter: 'deactivated',
      ),
      _card(
        label: 'Waiting Approval',
        value: '${counts['pending'] ?? 0}',
        hint: 'Need your decision',
        icon: Icons.hourglass_empty,
        color: _statusColor('pending'),
        filter: 'pending',
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
  // filters the table to it (tap again to clear); Total clears the filter.
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

  Widget _buildFilters(String facility, bool hasActiveFilters) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name, phone or facility...',
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
      onChanged: (val) => setState(() {
        _searchQuery = val.trim().toLowerCase();
        _page = 1;
      }),
    );

    // Only worth showing when there's more than one facility to choose from.
    final showFacility = facilityNames.length > 1;
    final reset = hasActiveFilters ? TextButton(onPressed: _resetFilters, child: const Text('Reset')) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              if (showFacility || reset != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (showFacility) Expanded(child: _facilityDropdown(facility, expand: true)) else const Spacer(),
                    if (reset != null) ...[const SizedBox(width: 6), reset],
                  ],
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            if (showFacility) ...[const SizedBox(width: 10), _facilityDropdown(facility)],
            if (reset != null) ...[const SizedBox(width: 10), reset],
          ],
        );
      },
    );
  }

  Widget _facilityDropdown(String value, {bool expand = false}) {
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
          icon: Icon(Icons.arrow_drop_down, size: 18, color: primaryColor),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('Facility: All')),
            ...facilityNames.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text('Facility: ${e.value}', overflow: TextOverflow.ellipsis)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _facilityFilter = val;
                _page = 1;
              });
            }
          },
        ),
      ),
    );
  }

  // ==================== TABLE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No assistants registered yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Use Invite Assistant to add your first team member.',
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
          Text('No assistants match your filters', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton(onPressed: _resetFilters, child: const Text('Reset filters')),
        ],
      ),
    );
  }

  Widget _buildResults(List<QueryDocumentSnapshot> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
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
                  _headerCell('Assistant', flex: 4),
                  _headerCell('Phone', flex: 2),
                  _headerCell('Facility', flex: 3),
                  _headerCell('Status', flex: 2),
                  _headerCell('Actions', flex: 5),
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

  Widget _statusChip(String bucket) {
    final color = _statusColor(bucket);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(_statusLabel(bucket), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  // Wide layout: one table row.
  Widget _buildRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStatus = (data['status'] ?? 'pending').toString();
    final bucket = _bucket(data);
    final facilityId = _facilityIdOf(data);
    final facilityName = facilityNames[facilityId] ?? 'Unknown';

    return Container(
      key: ValueKey(doc.id),
      // Coloured bar down the left edge - the account's state at a glance.
      decoration: BoxDecoration(border: Border(left: BorderSide(color: _statusColor(bucket), width: 4))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                InitialsAvatar(
                  avatarUrl: data['avatarUrl'] as String?,
                  name: data['fullName'] ?? '',
                  size: 36,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  foregroundColor: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['fullName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${data['phone'] ?? ''}',
                style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(facilityName,
                style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(bucket))),
          Expanded(
            flex: 5,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _buildActionButtons(doc, rawStatus, facilityId),
            ),
          ),
        ],
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per assistant.
  Widget _buildNarrowCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStatus = (data['status'] ?? 'pending').toString();
    final bucket = _bucket(data);
    final facilityId = _facilityIdOf(data);
    final facilityName = facilityNames[facilityId] ?? 'Unknown';

    return Container(
      key: ValueKey(doc.id),
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
            border: Border(left: BorderSide(color: _statusColor(bucket), width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsAvatar(
                    avatarUrl: data['avatarUrl'] as String?,
                    name: data['fullName'] ?? '',
                    size: 44,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    foregroundColor: accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['fullName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text('${data['phone'] ?? ''}', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                        const SizedBox(height: 2),
                        Text(facilityName, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(bucket),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildActionButtons(doc, rawStatus, facilityId),
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
            total == 0 ? 'No assistants' : 'Showing $start to $end of $total assistant${total == 1 ? '' : 's'}',
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
