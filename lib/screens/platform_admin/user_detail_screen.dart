import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/role_change_service.dart';
import '../../theme/app_palette.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../data/user_status.dart';
import '../../config/app_date_format.dart';

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
  static const Color primaryColor = AppPalette.primary;
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
      final freshDoc = await FirebaseFirestore.instance.collection(Collections.users).doc(widget.userId).get();
      if (!mounted || !freshDoc.exists) return;
      setState(() => _userData = Map<String, dynamic>.from(freshDoc.data()!));
    } catch (_) {
      // The passed-in data (from the moment the card was tapped) stays
      // as a reasonable fallback if this fails - not worth blocking
      // the screen over.
    }
  }

  Future<void> _addToFacility() async {
    final facilitiesSnap = await FirebaseFirestore.instance.collection(Collections.facilities).get();
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
            title: Text((_userData[Fields.role] ?? '') == UserRole.assistant.key ? 'Move to Facility' : 'Add to Facility'),
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
                                  Fields.facilityId: doc.id,
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

    final isAssistant = (_userData[Fields.role] ?? '') == UserRole.assistant.key;
    final currentFacilities = (_userData['facilities'] as List?)?.cast<dynamic>() ?? [];
    final alreadyThere = currentFacilities.any((f) => f is Map && f[Fields.facilityId] == selected[Fields.facilityId]);
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
        (await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(widget.userId).get()).exists;

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
        await FirebaseFirestore.instance.collection(Collections.users).doc(widget.userId).update({
          'facilities': [selected],
          'facilityIds': [selected[Fields.facilityId]],
          if (isTargetPlatformAdmin) Fields.role: UserRole.admin.key,
        });
      } else {
        await FirebaseFirestore.instance.collection(Collections.users).doc(widget.userId).update({
          'facilities': FieldValue.arrayUnion([selected]),
          'facilityIds': FieldValue.arrayUnion([selected[Fields.facilityId]]),
          if (isTargetPlatformAdmin) Fields.role: UserRole.admin.key,
        });
      }

      if (!mounted) return;
      setState(() {
        _userData['facilities'] = isAssistant ? [selected] : [...currentFacilities, selected];
        if (isTargetPlatformAdmin) _userData[Fields.role] = UserRole.admin.key;
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
      await FirebaseFirestore.instance.collection(Collections.users).doc(widget.userId).update({
        'facilities': FieldValue.arrayRemove([facility]),
        'facilityIds': FieldValue.arrayRemove([facility[Fields.facilityId]]),
      });
      if (!mounted) return;
      setState(() {
        (_userData['facilities'] as List).removeWhere((f) => f is Map && f[Fields.facilityId] == facility[Fields.facilityId]);
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
    final currentStatus = (_userData[Fields.status] ?? UserStatus.active.key).toString();
    final newStatus = currentStatus == UserStatus.active.key ? UserStatus.deactivated.key : UserStatus.active.key;

    if (newStatus == UserStatus.deactivated.key) {
      final platformAdminDoc =
          await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(widget.userId).get();
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
        title: Text(newStatus == UserStatus.active.key ? 'Reactivate Account?' : 'Deactivate Account?'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: Text(newStatus == UserStatus.active.key
              ? 'This user will be able to log in again.'
              : 'This user will no longer be able to log in, at any facility.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == UserStatus.active.key ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == UserStatus.active.key ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final admin = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection(Collections.users).doc(widget.userId).update({
        Fields.status: newStatus,
        'statusChangedBy': admin?.email ?? admin?.uid ?? 'Unknown',
        'statusChangedByRole': 'Platform Admin',
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _userData[Fields.status] = newStatus;
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

  // ---------------- role ----------------

  // Takes the label itself ("Admin", "Co-admin", "Assistant") rather than
  // the stored role, so a promoted Assistant reads as Co-admin everywhere.
  Widget _roleChip(String label) {
    final color = label == 'Assistant' ? Colors.blueGrey : primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _roleDialogLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }

  // Checks the account first; null if it couldn't be checked (already told).
  Future<RoleChangePlan?> _planRoleChange(String name) async {
    setState(() => _isSaving = true);
    try {
      final facts = await RoleChangeService.gatherFacts(widget.userId, _userData);
      return RoleChangeService.evaluate(userName: name, facts: facts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check this account: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeRole() async {
    final name = (_userData['fullName'] ?? 'this user').toString();

    final plan = await _planRoleChange(name);
    if (plan == null || !mounted) return;

    final isPromotion = plan.newRole == UserRole.admin.key;
    // Not disposed: it lives exactly as long as the dialog, and disposing it
    // while the dialog is still animating closed can trip a "used after
    // dispose" error. It holds no resources, so letting it be collected is
    // harmless.
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.allowed ? 'Change role' : "Can't change role yet"),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleChip(plan.currentLabel),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                    ),
                    _roleChip(plan.newLabel),
                  ],
                ),
                const SizedBox(height: 16),
                if (!plan.allowed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final reason in plan.blockers) _roleDialogLine(Icons.block, Colors.red, reason),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('What will change', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  for (final effect in plan.effects) _roleDialogLine(Icons.check_circle_outline, Colors.green, effect),
                  for (final warning in plan.warnings)
                    _roleDialogLine(Icons.info_outline, Colors.orange.shade800, warning),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'Shown in the facility\'s Activity Log',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: plan.allowed
            ? [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPromotion ? primaryColor : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isPromotion ? 'Make Co-admin' : 'Make Assistant'),
                ),
              ]
            : [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK'))],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final outcome =
          await RoleChangeService.apply(userId: widget.userId, userData: _userData, reason: reasonController.text);
      await _refreshUserData();
      if (!mounted) return;
      // The role changed either way; only the notifications can have failed.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name is now ${isPromotion ? 'a Co-admin' : 'an Assistant'}'
              '${outcome.notificationsSent ? '' : ' - but some notifications could not be sent'}'),
          backgroundColor: outcome.notificationsSent ? Colors.green : Colors.orange.shade800,
        ),
      );
    } on RoleChangeBlockedException catch (e) {
      // Re-checked at the moment of change; something moved since the dialog opened.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't change the role: $e"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change role: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilities = (_userData['facilities'] as List?)?.cast<dynamic>() ?? [];
    final status = (_userData[Fields.status] ?? UserStatus.active.key).toString();
    final role = (_userData[Fields.role] ?? '').toString();

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
                      Row(
                        children: [
                          const Text('Role: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          _roleChip(RoleChangeService.displayRole(role,
                              previousRole: _userData['previousRole']?.toString())),
                          const Spacer(),
                          // Only a Platform Admin can change a role - this is
                          // the one place it's done.
                          if (role == UserRole.admin.key || role == UserRole.assistant.key)
                            TextButton.icon(
                              onPressed: _isSaving ? null : _changeRole,
                              icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                              label: const Text('Change role'),
                            ),
                        ],
                      ),
                      if (_userData['roleChangedBy'] != null) ...[
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final changedAtField = _userData['roleChangedAt'];
                          final changedAt = changedAtField is Timestamp ? changedAtField.toDate() : null;
                          final previous = (_userData['previousRoleLabel'] as String?) ??
                              RoleChangeService.roleLabel((_userData['previousRole'] ?? '').toString());
                          final by = (_userData['roleChangedBy'] as String?) ?? 'Unknown';
                          final why = (_userData['roleChangeReason'] as String?) ?? '';
                          return Text(
                            'Role changed from $previous by $by (Platform Admin)'
                            '${changedAt != null ? ' \u00b7 ${AppDateFormat.dateTime24.format(changedAt)}' : ''}'
                            '${why.isEmpty ? '' : ' - "$why"'}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          );
                        }),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Status: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: status == UserStatus.active.key ? Colors.green : Colors.orange,
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
                            '${changedAt != null ? ' · ${AppDateFormat.dateTime24.format(changedAt)}' : ''}',
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
                    icon: Icon((_userData[Fields.role] ?? '') == UserRole.assistant.key ? Icons.swap_horiz : Icons.add),
                    label: Text((_userData[Fields.role] ?? '') == UserRole.assistant.key ? 'Move to Facility' : 'Add to Facility'),
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
                icon: Icon(status == UserStatus.active.key ? Icons.block : Icons.check_circle_outline),
                label: Text(status == UserStatus.active.key ? 'Deactivate Account' : 'Reactivate Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: status == UserStatus.active.key ? Colors.red : Colors.green,
                ),
              ),
              if (status == UserStatus.deactivated.key) ...[
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
