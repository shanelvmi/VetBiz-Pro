import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'invite_assistant_dialog.dart';
import '../../widgets/hover_elevate_card.dart';

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
                ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: accentColor.withValues(alpha: 0.15),
                            child: Icon(Icons.person, color: accentColor),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: accentColor.withValues(alpha: 0.15),
                          child: Icon(Icons.person, color: accentColor),
                        ),
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
              children: [
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantsList(List<QueryDocumentSnapshot> assistants) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Smoothly scales to available width rather than one fixed
        // breakpoint - same reasoning as View Facilities' grid, just a
        // narrower ideal width since these cards carry less content.
        const idealCardWidth = 400.0;
        final crossAxisCount = (constraints.maxWidth / idealCardWidth).floor().clamp(1, 4);

        if (crossAxisCount > 1) {
          return MasonryGridView.count(
            padding: const EdgeInsets.symmetric(vertical: 8),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            itemCount: assistants.length,
            itemBuilder: (context, index) => _buildAssistantCard(assistants[index]),
          );
        }

        return ListView.builder(
          itemCount: assistants.length,
          itemBuilder: (context, index) => _buildAssistantCard(assistants[index]),
        );
      },
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
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: adminFacilityIds.isEmpty
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

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No assistants registered yet.'));
                  }

                  final allAssistants = snapshot.data!.docs;

                  final filtered = _searchQuery.isEmpty
                      ? allAssistants
                      : allAssistants.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['fullName'] ?? '').toString().toLowerCase();
                          final facilityId = (data['facilityIds'] as List?)?.first ?? '';
                          final facilityName = (facilityNames[facilityId] ?? '').toLowerCase();
                          return name.contains(_searchQuery) || facilityName.contains(_searchQuery);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Text('No assistants match "$_searchQuery".'));
                  }

                  return _buildAssistantsList(filtered);
                },
              ),
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
