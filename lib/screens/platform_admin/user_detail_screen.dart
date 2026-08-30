import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    try {
      final freshDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (!mounted || !freshDoc.exists) return;
      setState(() => _userData = Map<String, dynamic>.from(freshDoc.data()!));
    } catch (_) {
      // The passed-in data (from the moment the card was tapped) stays
      // as a reasonable fallback if this fails - not worth blocking
      // the screen over.
    }
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
            title: Text((_userData['role'] ?? '') == 'assistant' ? 'Move to Facility' : 'Add to Facility'),
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

    final isAssistant = (_userData['role'] ?? '') == 'assistant';
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

    // Platform Admin status and this facility-level role field are two
    // separate, independent things - nothing otherwise guarantees they
    // stay in sync. Without this, a Platform Admin whose role field
    // isn't exactly 'admin' would get treated as a lower-privilege
    // account the moment they have any facility at all.
    final isTargetPlatformAdmin =
        (await FirebaseFirestore.instance.collection('platform_admins').doc(widget.userId).get()).exists;

    setState(() => _isSaving = true);
    try {
      if (isAssistant) {
        // Replaces rather than appends - an Assistant only ever
        // belongs to one facility at a time everywhere else in the
        // app (see Manage Assistants' Reassign). Appending here
        // instead would leave them belonging to two facilities at
        // once, which the rest of the app isn't built to handle -
        // it would just silently use whichever one happens to be
        // first in the array.
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'facilities': [selected],
          'facilityIds': [selected['facilityId']],
          if (isTargetPlatformAdmin) 'role': 'admin',
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'facilities': FieldValue.arrayUnion([selected]),
          'facilityIds': FieldValue.arrayUnion([selected['facilityId']]),
          if (isTargetPlatformAdmin) 'role': 'admin',
        });
      }

      if (!mounted) return;
      setState(() {
        _userData['facilities'] = isAssistant ? [selected] : [...currentFacilities, selected];
        if (isTargetPlatformAdmin) _userData['role'] = 'admin';
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
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: Text('Remove this user from "${facility['name']}"? They\'ll no longer be able to access it.'),
        ),
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
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
              child: const Text(
                  'This account has Platform Admin access, so it can\'t be deactivated from '
                  'here or anywhere else. Remove their Platform Admin access first (from the '
                  'Admins tab) if you genuinely need to deactivate this account.'),
            ),
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
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: Text(newStatus == 'active'
              ? 'This user will be able to log in again.'
              : 'This user will no longer be able to log in, at any facility.'),
        ),
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
      final admin = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'status': newStatus,
        'statusChangedBy': admin?.email ?? admin?.uid ?? 'Unknown',
        'statusChangedByRole': 'Platform Admin',
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _userData['status'] = newStatus;
        _userData['statusChangedBy'] = admin?.email ?? admin?.uid ?? 'Unknown';
        _userData['statusChangedByRole'] = 'Platform Admin';
        _userData['statusChangedAt'] = Timestamp.now();
      });
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

  Future<void> _removeAccount() async {
    final name = (_userData['fullName'] ?? 'this user').toString();
    final confirmController = TextEditingController();
    bool canConfirm = false;
    bool isRemoving = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Remove Account'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This permanently deletes "$name"\'s account and login. This cannot be undone, and the email becomes free to register again.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text('Type DELETE to confirm:',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) => setDialogState(() => canConfirm = val.trim() == 'DELETE'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isRemoving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (!canConfirm || isRemoving)
                  ? null
                  : () async {
                      setDialogState(() {
                        isRemoving = true;
                        dialogError = null;
                      });
                      try {
                        final callable = FirebaseFunctions.instance.httpsCallable('platformRemoveUser');
                        await callable.call({'userId': widget.userId});
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (!mounted) return;
                        Navigator.pop(context); // back to Users list - this account no longer exists
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account removed'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isRemoving = false;
                          dialogError = 'Could not remove: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: isRemoving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilities = (_userData['facilities'] as List?)?.cast<dynamic>() ?? [];
    final status = (_userData['status'] ?? 'active').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(_userData['fullName'] ?? 'User'),
        centerTitle: true,
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
                      if (_userData['statusChangedBy'] != null) ...[
                        const SizedBox(height: 4),
                        Builder(builder: (context) {
                          final changedByField = _userData['statusChangedAt'];
                          final changedAt = changedByField is Timestamp ? changedByField.toDate() : null;
                          final role = (_userData['statusChangedByRole'] as String?) ?? 'Unknown';
                          final by = (_userData['statusChangedBy'] as String?) ?? 'Unknown';
                          return Text(
                            'Changed by $by ($role)'
                            '${changedAt != null ? ' · ${DateFormat('dd MMM yyyy, HH:mm').format(changedAt)}' : ''}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          );
                        }),
                      ],
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
                    icon: Icon((_userData['role'] ?? '') == 'assistant' ? Icons.swap_horiz : Icons.add),
                    label: Text((_userData['role'] ?? '') == 'assistant' ? 'Move to Facility' : 'Add to Facility'),
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
              if (status == 'deactivated') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _removeAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Remove Account Permanently'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade900,
                    side: BorderSide(color: Colors.red.shade900),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
