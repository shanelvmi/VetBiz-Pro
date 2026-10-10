import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/hover_elevate_card.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../config/app_limits.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../ui/feedback/friendly_error.dart';

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
          .collection(Collections.users)
          .where('email', isEqualTo: email)
          .limit(AppLimits.single)
          .get();

      if (userQuery.docs.isEmpty) {
        AppFeedback.warning('No user found with email "$email"');
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();

      // Only an account whose current role is already admin can be
      // added as a Platform Admin - an Assistant must first be promoted
      // to Admin (Users > their profile > Change role), not silently
      // upgraded as a side effect of this action.
      if (userData[Fields.role] != UserRole.admin.key) {
        AppFeedback.warning(
          '"$email" is an Assistant and cannot be added as a Platform Admin',
          detail: 'Change their role to Admin first (Users > their profile > Change role)',
        );
        return;
      }

      await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(userDoc.id).set({
        'email': email,
        'fullName': userData['fullName'],
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      });

      _emailController.clear();

      AppFeedback.success('$email is now a platform admin');
    } catch (e, st) {
      AppFeedback.error("Couldn't add the platform admin", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _removeAdmin(String uid, String? email) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == currentUid) {
      AppFeedback.warning(
        "You can't remove your own admin access from here",
        detail: 'Ask another platform admin, or do it directly in Firebase Console',
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
            child: Text('Remove', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(uid).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Card(
            elevation: AppElevation.e1,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: context.colors.primary, size: AppIconSize.i22),
                  const SizedBox(width: AppSpacing.s10),
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
                  const SizedBox(width: AppSpacing.s8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _addAdminByEmail,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return context.colors.accent;
                        return context.colors.primary;
                      }),
                      foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                    ),
                    child: _isSearching
                        ? SizedBox(width: AppSpacing.s18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                        : const Text('Add'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(Collections.platformAdmins).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Could not load admins: ${FriendlyError.messageFor(snapshot.error!)}'));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No platform admins found.'));
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
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
                    future: FirebaseFirestore.instance.collection(Collections.users).doc(doc.id).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>?;
                      final fullName = userData?['fullName'] as String? ?? data['fullName'] as String?;
                      final email = userData?['email'] as String? ?? data['email'] as String?;
                      final title = fullName?.isNotEmpty == true
                          ? fullName!
                          : (email ?? doc.id);
                      final addedAtField = data['addedAt'];
                      final addedAt = addedAtField is Timestamp ? addedAtField.toDate() : null;
                      final addedBy = data['addedBy'] as String?;

                      return HoverElevateCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: context.colors.primary,
                                child: Text(
                                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                                  style: TextStyle(color: context.colors.onPrimary),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            title,
                                            style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isYou) ...[
                                          const SizedBox(width: AppSpacing.s6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                                            decoration: BoxDecoration(
                                              color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                              borderRadius: BorderRadius.circular(AppRadius.r8),
                                            ),
                                            child: Text('You', style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.s2),
                                    Text(
                                      email ?? 'No email on record',
                                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (addedAt != null) ...[
                                      const SizedBox(height: AppSpacing.s2),
                                      Text(
                                        'Added ${AppDateFormat.dateNoPad.format(addedAt)}${addedBy != null ? ' by $addedBy' : ''}',
                                        style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isYou)
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: context.colors.dangerAccent),
                                  tooltip: 'Remove admin access',
                                  onPressed: () => _removeAdmin(doc.id, email),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
