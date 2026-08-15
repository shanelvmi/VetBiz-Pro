import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/subscription_status_utils.dart';
import 'facility_detail_screen.dart';

class FacilitiesDirectoryTab extends StatefulWidget {
  const FacilitiesDirectoryTab({super.key});

  @override
  State<FacilitiesDirectoryTab> createState() => _FacilitiesDirectoryTabState();
}

class _FacilitiesDirectoryTabState extends State<FacilitiesDirectoryTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  String _searchQuery = '';

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

  @override
  Widget build(BuildContext context) {
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
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('facilities').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Could not load facilities: ${snapshot.error}'));
              }

              final docs = (snapshot.data?.docs ?? []).where((doc) {
                if (_searchQuery.isEmpty) return true;
                final name = ((doc.data() as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Text(_searchQuery.isEmpty ? 'No facilities yet.' : 'No facilities match your search.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final expiresAtField = data['subscriptionExpiresAt'];
                  final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
                  final status = computeSubscriptionStatus(expiresAt);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(data['name'] ?? 'Unnamed facility', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(data['type'] ?? ''),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _statusColor(status)),
                        ),
                        child: Text(
                          subscriptionStatusLabel(status),
                          style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FacilityDetailScreen(facilityId: doc.id)),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
