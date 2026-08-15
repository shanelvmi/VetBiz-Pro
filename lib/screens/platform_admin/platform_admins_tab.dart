import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manage who else has platform admin access - previously the only way
/// to grant this was manually creating a document in Firebase Console.
/// Searches by email (using the `email` field already stored on every
/// user document) rather than needing a UID directly, since nobody
/// reasonably has that memorized.
class PlatformAdminsTab extends StatefulWidget {
  const PlatformAdminsTab({super.key});

  @override
  State<PlatformAdminsTab> createState() => _PlatformAdminsTabState();
}

class _PlatformAdminsTabState extends State<PlatformAdminsTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  final TextEditingController _emailController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addAdminByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No user found with email "$email"'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();

      await FirebaseFirestore.instance.collection('platform_admins').doc(userDoc.id).set({
        'email': email,
        'fullName': userData['fullName'],
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      });

      _emailController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$email is now a platform admin'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _removeAdmin(String uid, String? email) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can't remove your own admin access from here - ask another platform admin, or do it directly in Firebase Console."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Platform Admin?'),
        content: Text('${email ?? uid} will lose access to this panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('platform_admins').doc(uid).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Add admin by email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _addAdminByEmail,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return const Color(0xFFFFB200);
                    return primaryColor;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                child: _isSearching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('platform_admins').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Could not load admins: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No platform admins found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isYou = doc.id == FirebaseAuth.instance.currentUser?.uid;

                  return FutureBuilder<DocumentSnapshot>(
                    // The authoritative source for who this actually is -
                    // every user document reliably has this, unlike the
                    // platform_admins document itself, which may have
                    // been created with no fields at all (the manual,
                    // one-time bootstrap step for the very first admin
                    // doesn't require any).
                    future: FirebaseFirestore.instance.collection('users').doc(doc.id).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>?;
                      final fullName = userData?['fullName'] as String? ?? data['fullName'] as String?;
                      final email = userData?['email'] as String? ?? data['email'] as String?;
                      final title = fullName?.isNotEmpty == true
                          ? fullName!
                          : (email ?? doc.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings, color: primaryColor),
                          title: Text(isYou ? '$title (You)' : title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(email ?? 'No email on record'),
                          trailing: isYou
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removeAdmin(doc.id, email),
                                ),
                        ),
                      );
                    },
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
