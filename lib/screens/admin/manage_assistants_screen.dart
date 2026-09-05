import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invite_assistant_dialog.dart';
import '../../widgets/hover_elevate_card.dart';
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

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
      _searchController.text = widget.initialSearchQuery!.trim();
      _isSearchExpanded = true;
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

  Future<void> _fetchAdminFacilities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .where('createdBy', isEqualTo: adminUid)
          .get();

      setState(() {
        adminFacilityIds = snapshot.docs.map((doc) => doc.id).toList();
        facilityNames = {
          for (var doc in snapshot.docs) doc.id: doc['name'] ?? 'Unknown'
        };
      });
    } catch (e) {
      debugPrint('Error fetching admin facilities: $e');
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
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) return Colors.white;
          return color;
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) return color;
          return null;
        }),
        side: WidgetStateProperty.all(BorderSide(color: color)),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
    );
  }

  Map<String, int> _statusCounts(List<QueryDocumentSnapshot> assistants) {
    int active = 0, deactivated = 0, pending = 0;
    for (final doc in assistants) {
      final status = ((doc.data() as Map<String, dynamic>)['status'] ?? 'pending').toString();
      if (status == 'active') {
        active++;
      } else if (status == 'deactivated') {
        deactivated++;
      } else {
        pending++;
      }
    }
    return {'total': assistants.length, 'active': active, 'deactivated': deactivated, 'pending': pending};
  }

  Widget _buildSummaryMetrics(List<QueryDocumentSnapshot> assistants) {
    final counts = _statusCounts(assistants);
    final metrics = [
      ('Total', counts['total']!, Icons.groups_outlined, primaryColor),
      ('Active', counts['active']!, Icons.check_circle_outline, Colors.green),
      ('Deactivated', counts['deactivated']!, Icons.pause_circle_outline, Colors.grey[600]!),
      ('Waiting Approval', counts['pending']!, Icons.hourglass_empty, Colors.orange),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isNarrow ? 2 : 4,
          childAspectRatio: isNarrow ? 2.2 : 2.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: metrics.map((m) => _metricCard(m.$1, m.$2, m.$3, m.$4)).toList(),
        );
      },
    );
  }

  Widget _metricCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? 'pending').toString();
    final facilityId = (data['facilityIds'] as List?)?.first ?? '';
    final facilityName = facilityNames[facilityId] ?? 'Unknown';
    final avatarUrl = data['avatarUrl'] as String?;
    final statusColor = status == 'active'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.red;

    return HoverElevateCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(
                  avatarUrl: avatarUrl,
                  name: data['fullName'] ?? '',
                  size: 48,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  foregroundColor: accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text('Phone: ${data['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Status: ', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                          Text(status, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Facility: $facilityName', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildActionButtons(doc, status, facilityId),
            ),
          ],
        ),
      ),
    );
  }

  // Shared between the card layout (narrow screens) and the table row
  // layout (wide screens) below - the status-driven action logic is
  // identical either way, only the surrounding container differs.
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

  Widget _buildAssistantsTable(List<QueryDocumentSnapshot> assistants) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildTableHeaderRow(),
          for (int i = 0; i < assistants.length; i++)
            _buildTableRow(assistants[i], isLast: i == assistants.length - 1),
        ],
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Assistant', style: headerStyle)),
          Expanded(flex: 2, child: Text('Phone', style: headerStyle)),
          Expanded(flex: 2, child: Text('Facility', style: headerStyle)),
          Expanded(flex: 1, child: Text('Status', style: headerStyle)),
          Expanded(flex: 3, child: Text('Actions', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(QueryDocumentSnapshot doc, {required bool isLast}) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? 'pending').toString();
    final facilityId = (data['facilityIds'] as List?)?.first ?? '';
    final facilityName = facilityNames[facilityId] ?? 'Unknown';
    final avatarUrl = data['avatarUrl'] as String?;
    final statusColor = status == 'active'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InitialsAvatar(
                  avatarUrl: avatarUrl,
                  name: data['fullName'] ?? '',
                  size: 36,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  foregroundColor: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['fullName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${data['phone'] ?? ''}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(facilityName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _buildActionButtons(doc, status, facilityId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantsList(List<QueryDocumentSnapshot> assistants) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A full-width table reads naturally on desktop, where there's
        // room for every column at once - cards take over below that,
        // since the same columns would otherwise get cramped or need
        // to wrap awkwardly.
        const tableBreakpoint = 800.0;

        if (constraints.maxWidth >= tableBreakpoint) {
          return _buildAssistantsTable(assistants);
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assistants.length,
          separatorBuilder: (context, index) => const SizedBox(height: 4),
          itemBuilder: (context, index) => _buildAssistantCard(assistants[index]),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Text(
      "Manage your team's access and status across your facilities.",
      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (adminUid.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: backgroundColor),
          title: const Center(child: Text('My Assistants', style: TextStyle(color: Colors.white))),
        ),
        body: const Center(child: Text('No logged in admin user found')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: backgroundColor),
        centerTitle: true,
        title: _isSearchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: backgroundColor,
                style: TextStyle(color: backgroundColor),
                decoration: InputDecoration(
                  hintText: 'Search by name or facility...',
                  hintStyle: TextStyle(color: backgroundColor.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: backgroundColor),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _isSearchExpanded = false;
                      });
                    },
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              )
            : const Text('My Assistants', style: TextStyle(color: Colors.white)),
        actions: [
          if (!_isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => setState(() => _isSearchExpanded = true),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Assistants',
            onPressed: _fetchAdminFacilities,
          ),
        ],
      ),
      body: adminFacilityIds.isEmpty
          ? const Center(child: Text('No facilities found for your account.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'assistant')
                  .where('facilityIds', arrayContainsAny: adminFacilityIds)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allAssistants = snapshot.data?.docs ?? [];

                final filtered = _searchQuery.isEmpty
                    ? allAssistants
                    : allAssistants.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['fullName'] ?? '').toString().toLowerCase();
                        final facilityId = (data['facilityIds'] as List?)?.first ?? '';
                        final facilityName = (facilityNames[facilityId] ?? '').toLowerCase();
                        return name.contains(_searchQuery) || facilityName.contains(_searchQuery);
                      }).toList();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildSummaryMetrics(allAssistants),
                        const SizedBox(height: 24),
                        if (allAssistants.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text('No assistants registered yet.', style: TextStyle(color: Colors.grey[600])),
                            ),
                          )
                        else if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text('No assistants match "$_searchQuery".',
                                  style: TextStyle(color: Colors.grey[600])),
                            ),
                          )
                        else
                          _buildAssistantsList(filtered),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        hoverColor: accentColor,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Invite Assistant'),
        onPressed: _startInviteFlow,
      ),
    );
  }
}
