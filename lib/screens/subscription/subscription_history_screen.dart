import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_screen.dart' show buildSubmissionCard;

/// The full subscription/payment submission history for a facility -
/// reached via "View all" on the Subscription screen's own recent-list
/// section, which only ever shows a handful at a glance. Reuses the
/// same card rendering as that section (buildSubmissionCard,
/// subscription_screen.dart) rather than duplicating it, so the two
/// always look identical.
class SubscriptionHistoryScreen extends StatelessWidget {
  final String facilityId;
  final Color primaryColor;

  const SubscriptionHistoryScreen({super.key, required this.facilityId, required this.primaryColor});

  // A generous cap rather than a truly unlimited query - protects
  // against an unbounded read for a facility with an unusually long
  // history, while still comfortably covering years of normal use.
  static const int _historyLimit = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription History'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('payment_submissions')
            .orderBy('submittedAt', descending: true)
            .limit(_historyLimit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('No submissions yet.', style: TextStyle(color: Colors.grey[600])),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) =>
                buildSubmissionCard(docs[index].data() as Map<String, dynamic>),
          );
        },
      ),
    );
  }
}
