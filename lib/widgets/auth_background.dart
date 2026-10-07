import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The full-bleed background for the signed-out screens (Register today;
/// Login has its own copy of the same logic).
///
/// An admin-uploaded poster (Platform Admin > Announcements) takes over
/// entirely when set - the same upload the login page uses - and the bundled
/// default shows otherwise. A subtle dark scrim sits on top so a floating
/// card and its shadow stay readable however bright or busy the photo is.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('app_config').doc('login_poster').snapshots(),
          builder: (context, snapshot) {
            final posterUrl = snapshot.data?.data() != null
                ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
                : null;

            if (posterUrl != null) {
              return Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset('assets/background.jpeg', fit: BoxFit.cover),
              );
            }
            return Image.asset('assets/background.jpeg', fit: BoxFit.cover);
          },
        ),
        Container(color: Colors.black.withValues(alpha: 0.18)),
      ],
    );
  }
}
