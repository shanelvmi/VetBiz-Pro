import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single user's account, editable by the Platform Admin - the direct
/// answer to "an assistant migrated to a new facility, and their old
/// email is stuck": find them here, add the new facility, done. No new
/// account, no workaround needed.
class UserDetailScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  const UserDetailScreen({super.key, required this.userId, required this.userData});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  bool _isSaving = false;
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
  }

  Future<void> _addToFacility() async {
    final facilitiesSnap = await FirebaseFirestore.instance.collection('facilities').get();
    if (!mounted) return;

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String query = '';
        return StatefulBuilder(builder: (context, setDialogState) {
          final filtered = facilitiesSnap.docs.where((doc) {
            if (query.isEmpty) return true;
            final name = (doc.data()['name'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text('Add to Facility'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search facility name',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching facility.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final doc = filtered[i];
                              final data = doc.data();
                              return ListTile(
                                title: Text(data['name'] ?? ''),
                                subtitle: Text(data['type'] ?? ''),
                                onTap: () => Navigator.pop(context, {
                                  'facilityId': doc.id,
                                  'name': data['name'],
                                  'type': data['type'],
                                  'code': data['code'],
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          );
        });
      },
    );

    if (selected == null) return;

    final currentFacilities = (_userData['facilities'] as List?)?.cast<dynamic>() ?? [];
    final alreadyThere = currentFacilities.any((f) => f is Map && f['facilityId'] == selected['facilityId']);
    if (alreadyThere) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already a member of that facility')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'facilities': FieldValue.arrayUnion([selected]),
        'facilityIds': FieldValue.arrayUnion([selected['facilityId']]),
      });

      if (!mounted) return;
      setState(() {
        _userData['facilities'] = [...currentFacilities, selected];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to ${selected['name']}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeFromFacility(Map<String, dynamic> facility) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Facility?'),
        content: Text('Remove this user from "${facility['name']}"? They\'ll no longer be able to access it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'facilities': FieldValue.arrayRemove([facility]),
        'facilityIds': FieldValue.arrayRemove([facility['facilityId']]),
      });
      if (!mounted) return;
      setState(() {
        (_userData['facilities'] as List).removeWhere((f) => f is Map && f['facilityId'] == facility['facilityId']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleStatus() async {
    final currentStatus = (_userData['status'] ?? 'active').toString();
    final newStatus = currentStatus == 'active' ? 'deactivated' : 'active';

    if (newStatus == 'deactivated') {
      final platformAdminDoc =
          await FirebaseFirestore.instance.collection('platform_admins').doc(widget.userId).get();
      if (platformAdminDoc.exists) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Deactivate'),
            content: const Text(
                'This account has Platform Admin access, so it can\'t be deactivated from '
                'here or anywhere else. Remove their Platform Admin access first (from the '
                'Admins tab) if you genuinely need to deactivate this account.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus == 'active' ? 'Reactivate Account?' : 'Deactivate Account?'),
        content: Text(newStatus == 'active'
            ? 'This user will be able to log in again.'
            : 'This user will no longer be able to log in, at any facility.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == 'active' ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'status': newStatus});
      if (!mounted) return;
      setState(() => _userData['status'] = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilities = (_userData['facilities'] as List?)?.cast<dynamic>() ?? [];
    final status = (_userData['status'] ?? 'active').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(_userData['fullName'] ?? 'User'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userData['email'] ?? '', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Role: ${_userData['role'] ?? 'unknown'}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Status: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: status == 'active' ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Facilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _addToFacility,
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Facility'),
                  ),
                ],
              ),
              if (facilities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Not a member of any facility.'),
                )
              else
                ...facilities.map((f) {
                  final facility = f as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(facility['name'] ?? 'Unknown'),
                      subtitle: Text(facility['type'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        tooltip: 'Remove from this facility',
                        onPressed: () => _removeFromFacility(facility),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _toggleStatus,
                icon: Icon(status == 'active' ? Icons.block : Icons.check_circle_outline),
                label: Text(status == 'active' ? 'Deactivate Account' : 'Reactivate Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: status == 'active' ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
