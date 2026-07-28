import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/facility_provider.dart';
import '../login_screen.dart';

const Color deepGreen = Color(0xFF2F5D62);
const Color warmAmber = Color(0xFFFFB200);
const Color offWhite = Color(0xFFFDFDF9);

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key});

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final User? currentUser;
  List<Map<String, dynamic>> facilities = [];
  String? activeFacilityId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    fetchFacilities();
  }

  Future<void> fetchFacilities() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final userData = userDoc.data();

      if (userData != null && userData['role'] == 'admin') {
        final facilityList = List<Map<String, dynamic>>.from(userData['facilities'] ?? []);
        final selectedFacilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

        setState(() {
          facilities = facilityList;
          activeFacilityId = selectedFacilityId;
        });
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load facilities: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchAssistantsForFacility(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'assistant')
        .where('facilityIds', arrayContains: facilityId)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  void handleSwitchFacility() {
    if (facilities.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Switch Facility"),
          content: const Text("You will be logged out to switch facility. Continue?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                await _auth.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text("Switch"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No other facility to switch to.")),
      );
    }
  }

  Widget buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'active':
        chipColor = Colors.green;
        break;
      case 'inactive':
        chipColor = Colors.red;
        break;
      case 'pending':
        chipColor = Colors.orange;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: chipColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget buildFacilityCard(Map<String, dynamic> facility) {
    final isActive = facility['facilityId'] == activeFacilityId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchAssistantsForFacility(facility['facilityId']),
      builder: (context, snapshot) {
        final assistants = snapshot.data ?? [];

        return Card(
          color: isActive ? deepGreen.withValues(alpha: 0.05) : Colors.white,
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business, color: deepGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        facility['name'] ?? 'Facility',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deepGreen),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: deepGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Opened',
                          style: TextStyle(color: deepGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text("Code: ${facility['code']}", style: const TextStyle(fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: facility['code'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Copied to clipboard!")),
                        );
                      },
                    ),
                  ],
                ),
                Text("Type: ${facility['type']}", style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 10),
                Text("Admin: ${currentUser?.displayName ?? 'You'}", style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 10),
                const Text("Assistants:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...assistants.map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(a['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 14))),
                          buildStatusChip(a['status'] ?? 'pending'),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: deepGreen,
      iconTheme: const IconThemeData(color: offWhite),
      title: const Text(
        'My Facilities',
        style: TextStyle(color: offWhite),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: offWhite),
          tooltip: 'Refresh Facilities',
          onPressed: fetchFacilities, // make sure this function refreshes the list
        ),
      ],
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : facilities.isEmpty
            ? const Center(child: Text("No facilities found."))
            : ListView.builder(
                itemCount: facilities.length,
                itemBuilder: (context, index) =>
                    buildFacilityCard(facilities[index]),
              ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: handleSwitchFacility,
        icon: const Icon(Icons.sync_alt),
        label: const Text('Switch Facility'),
        style: ElevatedButton.styleFrom(
          backgroundColor: deepGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );
}
}