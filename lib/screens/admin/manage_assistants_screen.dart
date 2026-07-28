import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAssistantsScreen extends StatefulWidget {
  const ManageAssistantsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      adminUid = user.uid;
      _fetchAdminFacilities();
    } else {
      adminUid = '';
    }
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
      print('Error fetching admin facilities: $e');
    }
  }

  Future<void> updateAssistantStatus(String userId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assistant status updated to $newStatus')),
      );
    } catch (e) {
      print('Error updating assistant status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> reassignAssistant(String userId, String newFacilityId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'facilityIds': [newFacilityId],
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistant reassigned successfully')));
    } catch (e) {
      print('Error reassigning assistant: $e');
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
                      return MouseRegion(
                        onEnter: (_) => setHoverState(() => entry.value),
                        onExit: (_) => setHoverState(() {}),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            reassignAssistant(userId, entry.key);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
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
        title: const Text('My Assistants', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Assistants',
            onPressed: _fetchAdminFacilities,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            if (adminFacilityIds.isEmpty)
              const Expanded(child: Center(child: Text('No facilities found for your account.')))
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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

                    final assistants = snapshot.data!.docs;

                    return ListView.builder(
                      primary: true,
                      itemCount: assistants.length,
                      itemBuilder: (context, index) {
                        final doc = assistants[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status = (data['status'] ?? 'pending').toString();
                        final facilityId = (data['facilityIds'] as List?)?.first ?? '';
                        final facilityName = facilityNames[facilityId] ?? 'Unknown';
                        final statusColor = status == 'active'
                            ? Colors.green
                            : status == 'pending'
                                ? Colors.orange
                                : Colors.red;

                        return Card(
                          child: ListTile(
                            leading: data['avatarUrl'] != null && data['avatarUrl'].toString().isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(data['avatarUrl']),
                                  )
                                : Icon(Icons.person, color: accentColor),
                            title: Text(data['fullName'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Phone: ${data['phone'] ?? ''}'),
                                Row(
                                  children: [
                                    Text('Status: ', style: TextStyle(color: Colors.grey[700])),
                                    Text(status, style: TextStyle(color: statusColor)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text('Facility: $facilityName')),
                                    if (status == 'active')
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz, color: Colors.teal),
                                        tooltip: 'Reassign Facility',
                                        onPressed: () => _showFacilityPickerDialog(doc.id),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    tooltip: 'Approve',
                                    onPressed: () => updateAssistantStatus(doc.id, 'active'),
                                  ),
                                if (status == 'active')
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    tooltip: 'Deactivate',
                                    onPressed: () => updateAssistantStatus(doc.id, 'inactive'),
                                  ),
                                if (status == 'inactive')
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.orange),
                                    tooltip: 'Reactivate',
                                    onPressed: () => updateAssistantStatus(doc.id, 'active'),
                                  ),
                                if (status != 'active')
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.grey),
                                    tooltip: 'Remove Assistant',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Remove Assistant'),
                                          content: const Text('Are you sure you want to remove this assistant?',
                                              style: TextStyle(fontSize: 13, color: Colors.redAccent)),
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
                                        await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Assistant removed')),
                                        );
                                      }
                                    },
                                  ),
                              ],
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
    );
  }
}
