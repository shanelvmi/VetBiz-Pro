import 'package:flutter/material.dart';

import '../../utils/facility_activation.dart';

/// Only ever shown for an Admin managing more than one facility - the
/// single-facility case (every Assistant, and most Admins) never
/// reaches this at all, going straight to Dashboard instead. Deliberately
/// does no fetching of its own - it's handed the facility list directly
/// by whatever already has it (main.dart's login flow), since a second,
/// independent fetch of data the caller already has was exactly the
/// class of bug that made logging in unreliable.
class FacilityPickerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> facilities;
  final String? role;

  const FacilityPickerScreen({super.key, required this.facilities, this.role});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        title: const Text('Select Facility'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final facility = facilities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(Icons.storefront_outlined, color: primaryColor),
                  title: Text(facility['facilityName'] ?? 'Unnamed Facility', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(facility['facilityType'] ?? ''),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: warmAmber),
                  onTap: () {
                    activateFacilityAndGoToDashboard(context: context, facility: facility, role: role);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
