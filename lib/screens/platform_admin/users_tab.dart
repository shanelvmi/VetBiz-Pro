import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_detail_screen.dart';

/// Every registered user across the whole platform, not scoped to one
/// facility - the missing piece that made "an assistant switching
/// facilities" a dead end before: their email already exists, so they
/// can't register again, and there was no way for anyone to see that
/// existing account and just add the new facility to it.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  static const Color primaryColor = Color(0xFF2F5D62);
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Could not load users: ${snapshot.error}'));
              }

              var docs = snapshot.data?.docs ?? [];
              if (_search.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || email.contains(_search);
                }).toList();
              }

              // Sort client-side so this works regardless of whether
              // every user doc happens to have fullName set.
              docs.sort((a, b) {
                final an = ((a.data() as Map)['fullName'] ?? '').toString();
                final bn = ((b.data() as Map)['fullName'] ?? '').toString();
                return an.toLowerCase().compareTo(bn.toLowerCase());
              });

              if (docs.isEmpty) {
                return Center(
                  child: Text(_search.isEmpty ? 'No users found.' : 'No users match "$_search".'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final facilities = (data['facilities'] as List?)?.cast<dynamic>() ?? [];
                  final status = (data['status'] ?? 'active').toString();
                  final role = (data['role'] ?? 'unknown').toString();
                  final name = (data['fullName'] ?? 'Unknown').toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        '${data['email'] ?? ''} · $role · ${facilities.length} '
                        '${facilities.length == 1 ? 'facility' : 'facilities'}',
                      ),
                      trailing: status != 'active'
                          ? Chip(
                              label: Text(status, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.orange.shade100,
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(userId: doc.id, userData: data),
                          ),
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
