import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'invite_assistant_dialog.dart';
import '../../widgets/firestore_error_view.dart';
import '../../widgets/initials_avatar.dart';
import '../../services/role_change_service.dart';
import '../../services/membership_service.dart';
import '../../utils/activity_logger.dart';
import '../../theme/app_palette.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../data/user_status.dart';
import '../../data/activity_type.dart';

/// Who someone is on a facility's team, as this screen shows them. Worked out
/// from the user record (role, previousRole, who created the facility); not
/// stored anywhere.
enum TeamMemberKind {
  /// The facility's Admin, its owner.
  owner,

  /// `role: admin` with `previousRole: assistant`.
  coAdmin,
  assistant,
}

class ManageAssistantsScreen extends StatefulWidget {
  // Set when opened as a deep link from a specific facility's card in
  // View Facilities - pre-fills and expands the search so it's
  // immediately filtered to that facility's team, rather than the
  // full, unfiltered list of every assistant across every facility.
  final String? initialSearchQuery;
  const ManageAssistantsScreen({super.key, this.initialSearchQuery});

  @override
  State<ManageAssistantsScreen> createState() => _ManageAssistantsScreenState();
}

class _ManageAssistantsScreenState extends State<ManageAssistantsScreen> {
  final Color primaryColor = AppPalette.primary;
  final Color backgroundColor = AppPalette.background;
  final Color accentColor = AppPalette.accent;

  late final String adminUid;
  List<String> adminFacilityIds = [];
  Map<String, String> facilityNames = {};
  // facility id -> uid of its creator (its OWNER). Decides who is "Admin"
  // rather than "Co-admin" in the list, and who may deactivate a Co-admin.
  Map<String, String> facilityOwners = {};
  // Created once, only when adminFacilityIds actually changes (initial
  // load, or an explicit Refresh) - not on every rebuild. A
  // StreamBuilder given a brand-new stream instance on every build
  // resets to its loading state before that new stream's first value
  // arrives, which was causing this screen to load slowly and its
  // assistants to appear staggered rather than all at once.
  Stream<QuerySnapshot>? _assistantsStream;

  // False until the first facility lookup finishes - without it the
  // "No facilities found" message flashed up while that lookup was still
  // running.
  bool _facilitiesLoaded = false;
  // Why the facility lookup failed, if it did. Previously a failure (for
  // example the security rules refusing the query) left the list empty and
  // the screen said "No facilities found for your account" - which is
  // untrue, and hid the real reason.
  Object? _facilitiesError;

  String _searchQuery = ''; // trimmed + lowercased
  final TextEditingController _searchController = TextEditingController();
  String? _statusFilter; // 'active' | 'deactivated' | 'pending', null = all
  String _facilityFilter = 'All'; // a facility id, or 'All'
  int _page = 1;
  int _pageSize = 10;

  // Whose details are open - in the panel beside the list, or a sheet on a phone.
  String? _selectedUserId;

  // The team must not be DRAWN until the server has answered. The first event
  // from the database can be a partial one, built from what this device
  // already remembers - often just YOUR OWN row - and drawing it showed you
  // alone with a "no assistants yet" banner until the real team arrived.
  // So: a placeholder until a snapshot that did NOT come from the local cache
  // arrives. After that a cache-only event (the connection dropping) is not
  // "loading" and is ignored. If the server never answers (offline), what
  // there is gets shown after a few seconds, rather than a placeholder forever.
  bool _teamServerLoaded = false;
  bool _teamLoadGaveUp = false;
  Timer? _teamLoadTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
      _searchController.text = widget.initialSearchQuery!.trim();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      adminUid = user.uid;
      _fetchAdminFacilities();
    } else {
      adminUid = '';
    }
  }

  @override
  void dispose() {
    _teamLoadTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // "Ukuli Agrovet" rather than just "Ukuli": the facility's type follows
  // its name - unless the name already says it, so a facility saved as
  // "Ukuli Agrovet" doesn't turn into "Ukuli Agrovet Agrovet". Everything
  // on this screen that shows a facility reads from facilityNames, so this
  // one place covers the table, cards, filter, search, and the reassign and
  // invite pickers.
  String _nameWithType(Map<String, dynamic> facility) {
    final name = ((facility['name'] as String?) ?? '').trim();
    final type = ((facility['type'] as String?) ?? '').trim();
    if (name.isEmpty) return 'Unknown';
    if (type.isEmpty || name.toLowerCase().contains(type.toLowerCase())) return name;
    return '$name $type';
  }

  Future<void> _fetchAdminFacilities() async {
    try {
      final facilitiesCollection = FirebaseFirestore.instance.collection(Collections.facilities);
      // Started together: they don't depend on each other, and they used to run
      // one after the other - each a full round trip before the team could
      // even begin to load.
      final createdFuture = facilitiesCollection.where('createdBy', isEqualTo: adminUid).get();
      final userDocFuture = FirebaseFirestore.instance.collection(Collections.users).doc(adminUid).get();
      final created = await createdFuture;

      // Also the facilities this Admin was ADDED to rather than created. A
      // co-admin (an Assistant a Platform Admin promoted) owns none, yet
      // manages the assistants of the one they belong to - looking only at
      // "created by me" left them with "No facilities found".
      final userDoc = await userDocFuture;
      final createdIds = created.docs.map((d) => d.id).toSet();
      final memberIds = <String>{
        for (final id in (userDoc.data()?['facilityIds'] as List? ?? const [])) id.toString(),
      }..removeWhere((id) => id.isEmpty || createdIds.contains(id));
      final added = await Future.wait(memberIds.map((id) => facilitiesCollection.doc(id).get()));
      final docs = <DocumentSnapshot<Map<String, dynamic>>>[
        ...created.docs,
        ...added.where((d) => d.exists),
      ];

      if (!mounted) return;
      setState(() {
        adminFacilityIds = docs.map((doc) => doc.id).toList();
        facilityNames = {
          for (final doc in docs) doc.id: _nameWithType(doc.data() ?? <String, dynamic>{})
        };
        facilityOwners = {
          for (final doc in docs) doc.id: (doc.data()?['createdBy'] ?? '').toString()
        };
        _teamServerLoaded = false;
        _teamLoadGaveUp = false;
        _teamLoadTimer?.cancel();
        _teamLoadTimer = Timer(const Duration(seconds: 8), () {
          if (mounted && !_teamServerLoaded) setState(() => _teamLoadGaveUp = true);
        });
        _assistantsStream = adminFacilityIds.isEmpty
            ? null
            // Everyone in these facilities, not just role == 'assistant': a
            // promoted Assistant (a Co-admin) is an Admin by role, yet must
            // stay in this list. Who actually belongs in it is decided by
            // _isListed - the query can't express "assistant OR co-admin".
            : FirebaseFirestore.instance
                .collection(Collections.users)
                .where('facilityIds', arrayContainsAny: adminFacilityIds)
                // includeMetadataChanges: so the move from "remembered" to "from the
                // server" arrives as an event, and the screen can wait for it.
                .snapshots(includeMetadataChanges: true);
        _facilitiesError = null;
        _facilitiesLoaded = true;
      });
    } catch (e) {
      debugPrint('Error fetching admin facilities: $e');
      if (mounted) {
        setState(() {
          _facilitiesError = e;
          _facilitiesLoaded = true;
        });
      }
    }
  }

  // Who has a change in flight. The server calls behind reassign / remove take
  // a few seconds from here, and with nothing on screen to say so people
  // tapped again - and every tap went through, so one removal produced several
  // "success" messages. While someone is in this set their buttons are
  // replaced by a "Working..." note and every handler refuses a second request.
  final Set<String> _busyUserIds = {};

  Future<void> _runBusy(String userId, Future<void> Function() action) async {
    if (_busyUserIds.contains(userId)) return;
    setState(() => _busyUserIds.add(userId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Widget _workingNote() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Working...', style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
      ],
    );
  }

  // The public names are the guarded versions; the work itself is below.
  Future<void> removeFromFacility(String userId, String facilityId) =>
      _runBusy(userId, () => _removeFromFacility(userId, facilityId));

  Future<void> reassignAssistant(String userId, String newFacilityId) =>
      _runBusy(userId, () => _reassignAssistant(userId, newFacilityId));

  // Approve, reject, deactivate, reactivate. These go through the server, which
  // stamps each change with its own clock and keeps a history (that's where
  // "approved on ..." in the details panel comes from), and refuses one that
  // no longer makes sense - say a second tap on Approve from a stale screen.
  Future<void> _assistantAction(String userId, Map<String, dynamic> data, String action) =>
      _runBusy(userId, () => _doAssistantAction(userId, data, action));

  Future<void> _doAssistantAction(String userId, Map<String, dynamic> data, String action) async {
    final name = (data['fullName'] ?? 'The assistant').toString();
    final facilityId = _facilityIdOf(data);
    const past = {'approve': 'approved', 'reject': 'rejected', 'deactivate': 'deactivated', 'reactivate': 'reactivated'};
    try {
      await MembershipService().setAssistantStatus(assistantUid: userId, action: action);

      // Worth a line in the Activity Log - and a rejection especially, since
      // the person disappears from this list.
      if (facilityId.isNotEmpty) {
        final info = await ActivityLogger.getCurrentUserInfo();
        final verb = past[action] ?? action;
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: info[Fields.userId] ?? '',
          userName: info['userName'],
          actionType: ActivityType.account.key,
          targetUserId: userId,
          description: '${verb[0].toUpperCase()}${verb.substring(1)} assistant $name',
        );
      }
      if (!mounted) return;
      if (action == 'reject' && _selectedUserId == userId) setState(() => _selectedUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name ${past[action]}')));
    } catch (e) {
      debugPrint('Error ($action) for assistant: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MembershipService.errorMessage(e))));
    }
  }

  // Unlinks just this one facility, never touches status/role or the
  // account itself - deactivating or permanently removing an account
  // is Platform-Admin-only. A boss can still "fire" an assistant from
  // their own team without needing to contact a Platform Admin for
  // something this routine; the assistant's login stays fully active
  // and they could be invited to a facility again later.
  // Moving or removing an assistant changes WHO BELONGS to a facility, which is
  // decided by the server, not written from here: it checks you administer the
  // facility, and keeps the two lists on their profile (the one the screens
  // show and the one every access rule checks) in step.
  Future<void> _removeFromFacility(String userId, String facilityId) async {
    try {
      await MembershipService().removeAssistantFromFacility(assistantUid: userId, facilityId: facilityId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant removed from this facility')),
      );
    } catch (e) {
      debugPrint('Error removing assistant from facility: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: ${MembershipService.errorMessage(e)}')),
      );
    }
  }

  Future<void> _reassignAssistant(String userId, String newFacilityId) async {
    try {
      await MembershipService().reassignAssistant(assistantUid: userId, newFacilityId: newFacilityId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistant reassigned successfully')));
    } catch (e) {
      debugPrint('Error reassigning assistant: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reassign: ${MembershipService.errorMessage(e)}')),
      );
    }
  }

  // Same look as the rest of the app - this used to be a dark grey dialog that
  // matched nothing else.
  void _showFacilityPickerDialog(String userId, {String name = 'this assistant', String currentFacilityId = ''}) {
    final options = facilityNames.entries.where((e) => e.key != currentFacilityId).toList();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move $name', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Choose the facility they should work in. They keep their account and their approval.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
                ),
                const SizedBox(height: 16),
                if (options.isEmpty)
                  Text("You don't run any other facility to move them to.",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]))
                else
                  ...options.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            reassignAssistant(userId, e.key);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.storefront_outlined, size: 20, color: primaryColor),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600))),
                                Icon(Icons.chevron_right, color: Colors.grey[500]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Opening the invite dialog takes a moment, and tapping Invite Assistant
  // again meanwhile stacked up several dialogs.
  bool _inviteFlowOpen = false;

  Future<void> _startInviteFlow() async {
    if (_inviteFlowOpen) return;
    _inviteFlowOpen = true;
    try {
      await _runInviteFlow();
    } finally {
      _inviteFlowOpen = false;
    }
  }

  Future<void> _runInviteFlow() async {
    if (adminFacilityIds.isEmpty) return;

    if (adminFacilityIds.length == 1) {
      await showInviteAssistantDialog(context, adminFacilityIds.first);
      return;
    }

    // More than one facility - ask which one this invite is for, since
    // there's no way to infer that otherwise.
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Invite Assistant To...'),
        children: adminFacilityIds.map((id) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, id),
            child: Text(facilityNames[id] ?? 'Unknown facility'),
          );
        }).toList(),
      ),
    );

    if (chosen != null && mounted) {
      await showInviteAssistantDialog(context, chosen);
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) return Colors.white;
          return color;
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) return color;
          return null;
        }),
        side: WidgetStateProperty.all(BorderSide(color: color.withValues(alpha: 0.6))),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        minimumSize: WidgetStateProperty.all(const Size(0, 34)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }

  // Anything that isn't active or deactivated is waiting on a decision -
  // same as before, just named once.
  bool _isOwnerUid(String uid) => facilityOwners.values.contains(uid);

  // Whether YOU own this facility - the only thing that lets you deactivate
  // a Co-admin in it.
  bool _viewerOwns(String facilityId) => facilityOwners[facilityId] == adminUid;

  // Who belongs in this list: the whole team - the facility's Admin (its
  // owner), Co-admins and Assistants - and you. Not a Platform Admin attached
  // for support, nor any other Admin who is neither the owner nor a Co-admin:
  // from here those can't be told apart from team members, and they aren't.
  bool _isListed(QueryDocumentSnapshot doc) {
    if (doc.id == adminUid) return true;
    final data = doc.data() as Map<String, dynamic>;
    if (data[Fields.role] == UserRole.assistant.key) return true;
    return data[Fields.role] == UserRole.admin.key && (RoleChangeService.isCoAdmin(data) || _isOwnerUid(doc.id));
  }

  // An Admin who is neither the owner nor a Co-admin (which can only ever be
  // you) counts as owner: this screen shows and treats the two the same.
  TeamMemberKind _kindOf(String uid, Map<String, dynamic> data) {
    if (data[Fields.role] == UserRole.assistant.key) return TeamMemberKind.assistant;
    if (RoleChangeService.isCoAdmin(data)) return TeamMemberKind.coAdmin;
    return TeamMemberKind.owner;
  }

  String _kindLabel(TeamMemberKind kind) {
    if (kind == TeamMemberKind.assistant) return 'Assistant';
    if (kind == TeamMemberKind.coAdmin) return 'Co-admin';
    return 'Admin';
  }

  // The order of authority: Admin first, then Co-admins, then Assistants.
  int _tier(TeamMemberKind kind) =>
      kind == TeamMemberKind.assistant ? 2 : (kind == TeamMemberKind.coAdmin ? 1 : 0);

  Widget _roleChip(TeamMemberKind kind) {
    final MaterialColor color = kind == TeamMemberKind.assistant
        ? Colors.blueGrey
        : (kind == TeamMemberKind.coAdmin ? Colors.teal : Colors.indigo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        _kindLabel(kind),
        style: TextStyle(color: color.shade700, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _note(String text, {bool strong = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: strong ? 13 : 12.5,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        color: strong ? primaryColor : Colors.grey[600],
      ),
    );
  }

  // Every row says something in its Actions cell, so none is ever blank:
  //
  //   you                      -> "You"
  //   the facility's Admin     -> "Facility admin" (what a Co-admin sees)
  //   a Co-admin, to the owner -> Deactivate / Reactivate
  //   a Co-admin, to a Co-admin-> "Co-admin"
  //   an Assistant             -> the usual approve / deactivate / reassign
  //
  // Deactivating a Co-admin is the owner's emergency brake, not a change of
  // role - a role is still only the Platform Admin's to change.
  List<Widget> _actionsFor(QueryDocumentSnapshot doc, Map<String, dynamic> data, String status, String facilityId) {
    if (_busyUserIds.contains(doc.id)) return [_workingNote()];
    if (doc.id == adminUid) return [_note('You', strong: true)];
    final kind = _kindOf(doc.id, data);
    if (kind == TeamMemberKind.owner) return [_note('Facility admin')];
    if (kind == TeamMemberKind.coAdmin) {
      if (!_viewerOwns(facilityId)) return [_note('Co-admin')];
      final bucket = _bucket(data);
      return [
        if (bucket == UserStatus.active.key)
          _actionButton(
            label: 'Deactivate',
            icon: Icons.pause_circle_outline,
            color: Colors.orange,
            onPressed: () => _confirmDeactivateCoAdmin(doc, data),
          ),
        if (bucket == UserStatus.deactivated.key)
          _actionButton(
            label: 'Reactivate',
            icon: Icons.play_circle_outline,
            color: Colors.green,
            onPressed: () => _setCoAdminStatus(doc, data, UserStatus.active.key),
          ),
        if (bucket == UserStatus.pending.key) _note('Co-admin'),
      ];
    }
    return _buildActionButtons(doc, status, facilityId);
  }

  Future<void> _confirmDeactivateCoAdmin(QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final name = (data['fullName'] ?? 'this co-admin').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate $name?'),
        content: SizedBox(
          width: 340,
          child: const Text(
            'They\'ll be signed out straight away and can\'t log in until you reactivate them. '
            'This doesn\'t change their role - only the platform administrator can do that.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirm == true) await _setCoAdminStatus(doc, data, UserStatus.deactivated.key);
  }

  Future<void> _setCoAdminStatus(QueryDocumentSnapshot doc, Map<String, dynamic> data, String newStatus) =>
      _runBusy(doc.id, () => _doSetCoAdminStatus(doc, data, newStatus));

  Future<void> _doSetCoAdminStatus(QueryDocumentSnapshot doc, Map<String, dynamic> data, String newStatus) async {
    final name = (data['fullName'] ?? 'This co-admin').toString();
    final facilityId = _facilityIdOf(data);
    final activating = newStatus == UserStatus.active.key;
    try {
      final me = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection(Collections.users).doc(doc.id).update({
        Fields.status: newStatus,
        'statusChangedBy': me?.email ?? me?.uid ?? 'Unknown',
        'statusChangedByRole': 'Facility Admin',
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      // Worth a line in the Activity Log - unlike an Assistant, a Co-admin
      // can do almost everything you can.
      if (facilityId.isNotEmpty) {
        final info = await ActivityLogger.getCurrentUserInfo();
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: info[Fields.userId] ?? '',
          userName: info['userName'],
          actionType: ActivityType.account.key,
          targetUserId: doc.id,
          description: '${activating ? 'Reactivated' : 'Deactivated'} co-admin $name',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name ${activating ? 'reactivated' : 'deactivated'}')),
      );
    } catch (e) {
      debugPrint('Error updating co-admin status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  List<String> _facilityIdsOf(Map<String, dynamic> data) =>
      ((data['facilityIds'] as List?) ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();

  // An Admin can own several facilities and is one row, so it says how many
  // rather than naming just the first.
  String _facilityText(Map<String, dynamic> data) {
    final ids = _facilityIdsOf(data);
    if (ids.isEmpty) return 'Unknown';
    if (ids.length > 1) return '${ids.length} facilities';
    return facilityNames[ids.first] ?? 'Unknown';
  }

  String _bucket(Map<String, dynamic> data) {
    // An Admin or Co-admin has no approval step, so no status means active -
    // only an Assistant waiting to be approved is "pending".
    final status = (data[Fields.status] ?? (data[Fields.role] == UserRole.assistant.key ? UserStatus.pending.key : UserStatus.active.key)).toString();
    if (status == UserStatus.active.key) return UserStatus.active.key;
    if (status == UserStatus.deactivated.key) return UserStatus.deactivated.key;
    return UserStatus.pending.key;
  }

  // Anything that isn't active or deactivated shows as pending - including an
  // unknown value, which fromKey reads as pending.
  Color _statusColor(String bucket) => switch (UserStatus.fromKey(bucket)) {
        UserStatus.active => Colors.green,
        UserStatus.deactivated => Colors.red,
        UserStatus.pending || UserStatus.rejected => Colors.orange,
      };

  String _statusLabel(String bucket) => switch (UserStatus.fromKey(bucket)) {
        UserStatus.active => 'Active',
        UserStatus.deactivated => 'Deactivated',
        UserStatus.pending || UserStatus.rejected => 'Pending',
      };

  // First facility id on the record, or '' - an empty list used to throw.
  String _facilityIdOf(Map<String, dynamic> data) {
    final ids = data['facilityIds'] as List?;
    return (ids != null && ids.isNotEmpty) ? ids.first.toString() : '';
  }

  // Shared between the card layout (narrow screens) and the table row
  // layout (wide screens) - the status-driven action logic is identical
  // either way, only the surrounding container differs.
  List<Widget> _buildActionButtons(QueryDocumentSnapshot doc, String status, String facilityId) {
    final data = doc.data() as Map<String, dynamic>;
    return [
      if (status == UserStatus.pending.key) ...[
        _actionButton(
          label: 'Approve',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          onPressed: () => _assistantAction(doc.id, data, 'approve'),
        ),
        // For someone you don't recognise. They're taken out of the facility
        // and, next time they sign in, asked for an invite code - not left
        // "waiting for approval" for ever.
        _actionButton(
          label: 'Reject',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          onPressed: () => _confirmReject(doc.id, data),
        ),
      ],
      if (status == UserStatus.active.key) ...[
        _actionButton(
          label: 'Deactivate',
          icon: Icons.pause_circle_outline,
          color: Colors.orange,
          onPressed: () => _assistantAction(doc.id, data, 'deactivate'),
        ),
        _actionButton(
          label: 'Reassign',
          icon: Icons.swap_horiz,
          color: Colors.teal,
          onPressed: () => _showFacilityPickerDialog(
            doc.id,
            name: (data['fullName'] ?? 'this assistant').toString(),
            currentFacilityId: facilityId,
          ),
        ),
      ],
      if (status == UserStatus.deactivated.key) ...[
        _actionButton(
          label: 'Reactivate',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          onPressed: () => _assistantAction(doc.id, data, 'reactivate'),
        ),
        _actionButton(
          label: 'Remove from Facility',
          icon: Icons.person_remove_outlined,
          color: Colors.grey[700]!,
          onPressed: () => _confirmRemoveFromFacility(doc.id, data, facilityId),
        ),
      ],
    ];
  }

  // One shape for every confirmation on this screen: a bounded width (a bare
  // dialog stretches across a wide screen), who it's about, and what will
  // happen, in plain words.
  Future<bool> _confirm({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> points,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 16),
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Icon(Icons.circle, size: 6, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _confirmRemoveFromFacility(String userId, Map<String, dynamic> data, String facilityId) async {
    final name = (data['fullName'] ?? 'This assistant').toString();
    final facility = facilityNames[facilityId] ?? 'your facility';
    final ok = await _confirm(
      icon: Icons.person_remove_outlined,
      color: Colors.red,
      title: 'Remove $name from $facility?',
      points: [
        "$name will no longer be part of $facility, and won't see its records.",
        "What $name recorded stays in $facility's history.",
        'Their account is kept. When they next sign in they can enter an invite code to join a facility again.',
      ],
      confirmLabel: 'Remove from facility',
    );
    if (ok) await removeFromFacility(userId, facilityId);
  }

  Future<void> _confirmReject(String userId, Map<String, dynamic> data) async {
    final name = (data['fullName'] ?? 'this person').toString();
    final facility = facilityNames[_facilityIdOf(data)] ?? 'your facility';
    final ok = await _confirm(
      icon: Icons.cancel_outlined,
      color: Colors.red,
      title: 'Reject $name?',
      points: [
        '$name is removed from $facility and is no longer waiting for approval.',
        "When they next sign in they'll see the request wasn't approved, and be asked for an invite code - they can join again with a new one.",
        "They aren't sent a message. Tell them yourself if you'd like them to know.",
      ],
      confirmLabel: 'Reject',
    );
    if (ok) await _assistantAction(userId, data, 'reject');
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
      _facilityFilter = 'All';
      _page = 1;
    });
  }

  PreferredSizeWidget _buildAppBar() {
    final narrow = MediaQuery.of(context).size.width < 600;
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Team Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text("Manage your team's access and status", style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _fetchAdminFacilities,
        ),
        // Same place Sales puts "Record Sale" - the primary action lives
        // in the app bar, not a floating button.
        if (narrow)
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Invite Assistant',
            onPressed: _startInviteFlow,
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _startInviteFlow,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invite Assistant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (adminUid.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(),
        body: const Center(child: Text('No logged in admin user found')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: !_facilitiesLoaded
          ? _buildLoadingSkeleton()
          : _facilitiesError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FirestoreErrorView(error: _facilitiesError),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _fetchAdminFacilities,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              : adminFacilityIds.isEmpty
              ? const Center(child: Text('No facilities found for your account.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _assistantsStream!,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: FirestoreErrorView(error: snapshot.error));
                    }
                    final snap = snapshot.data;
                    if (snap != null && !snap.metadata.isFromCache) _teamServerLoaded = true;
                    // Nothing real to show yet: no data at all, or only what this
                    // device remembered. A placeholder, not a half-empty list.
                    if (snap == null || (!_teamServerLoaded && !_teamLoadGaveUp)) {
                      return _buildLoadingSkeleton();
                    }
                    return _buildBody(snap.docs.where(_isListed).toList());
                  },
                ),
    );
  }

  Widget _buildBody(List<QueryDocumentSnapshot> all) {
    final counts = <String, int>{UserStatus.active.key: 0, UserStatus.deactivated.key: 0, UserStatus.pending.key: 0};
    for (final doc in all) {
      final b = _bucket(doc.data() as Map<String, dynamic>);
      counts[b] = (counts[b] ?? 0) + 1;
    }

    // A chosen facility can disappear if the list changes underneath it.
    final facility = (_facilityFilter == 'All' || facilityNames.containsKey(_facilityFilter)) ? _facilityFilter : 'All';

    final q = _searchQuery;
    final filtered = all.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_statusFilter != null && _bucket(data) != _statusFilter) return false;
      final ids = _facilityIdsOf(data);
      if (facility != 'All' && !ids.contains(facility)) return false;
      if (q.isNotEmpty) {
        final name = (data['fullName'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        final facilityName = ids.map((id) => (facilityNames[id] ?? '').toLowerCase()).join(' ');
        final roleName = _kindLabel(_kindOf(doc.id, data)).toLowerCase();
        if (!name.contains(q) && !phone.contains(q) && !facilityName.contains(q) && !roleName.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // By authority: the Admin first, then Co-admins, then Assistants. Within
    // each, you come first; then anyone waiting on a decision, then active,
    // then deactivated - so the people who need something from you are at the
    // top of the Assistants.
    int rank(String b) => b == UserStatus.pending.key ? 0 : (b == UserStatus.active.key ? 1 : 2);
    filtered.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;
      final byTier = _tier(_kindOf(a.id, da)).compareTo(_tier(_kindOf(b.id, db)));
      if (byTier != 0) return byTier;
      if ((a.id == adminUid) != (b.id == adminUid)) return a.id == adminUid ? -1 : 1;
      final byStatus = rank(_bucket(da)).compareTo(rank(_bucket(db)));
      if (byStatus != 0) return byStatus;
      return (da['fullName'] ?? '').toString().toLowerCase().compareTo((db['fullName'] ?? '').toString().toLowerCase());
    });

    final hasActiveFilters = q.isNotEmpty || _statusFilter != null || facility != 'All';
    // Just you, and nobody else yet.
    final onlySelf = all.isNotEmpty && all.every((d) => d.id == adminUid);

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    final page = _page > totalPages ? totalPages : _page;
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildCards(all.length, counts),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilters(facility, hasActiveFilters),
        ),
        Expanded(
          child: all.isEmpty
              ? _buildEmptyState()
              : filtered.isEmpty
                  ? _buildNoMatches()
                  : _buildResults(pageItems, showOnlySelfHint: onlySelf && _teamServerLoaded),
        ),
        if (all.isNotEmpty) _buildPaginationBar(total: total, page: page, totalPages: totalPages),
      ],
    );

    // Whose details are open. Looked up in the full list, not the filtered one,
    // so filtering doesn't close them - but if the person is gone (rejected,
    // removed) the panel closes.
    QueryDocumentSnapshot? selectedDoc;
    if (_selectedUserId != null) {
      for (final d in all) {
        if (d.id == _selectedUserId) {
          selectedDoc = d;
          break;
        }
      }
      if (selectedDoc == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedUserId != null) setState(() => _selectedUserId = null);
        });
      }
    }

    // Beside the list when there's room, as on the sales screen.
    final open = selectedDoc; // a final copy, so it can be relied on inside the closure
    return LayoutBuilder(
      builder: (context, constraints) {
        if (open == null || constraints.maxWidth < 1100) return body;
        return Row(
          children: [
            Expanded(child: body),
            const VerticalDivider(width: 1),
            SizedBox(width: 380, child: _buildDetailsPanel(open, showActions: true)),
          ],
        );
      },
    );
  }

  // ==================== CARDS ====================

  Widget _buildCards(int totalCount, Map<String, int> counts) {
    final cards = <Widget>[
      _card(
        label: 'Total',
        value: '$totalCount',
        hint: 'Across your facilities',
        icon: Icons.groups_outlined,
        color: primaryColor,
        filter: null,
      ),
      _card(
        label: 'Active',
        value: '${counts[UserStatus.active.key] ?? 0}',
        hint: 'Have access',
        icon: Icons.check_circle_outline,
        color: _statusColor(UserStatus.active.key),
        filter: UserStatus.active.key,
      ),
      _card(
        label: 'Deactivated',
        value: '${counts[UserStatus.deactivated.key] ?? 0}',
        hint: 'Access paused',
        icon: Icons.pause_circle_outline,
        color: _statusColor(UserStatus.deactivated.key),
        filter: UserStatus.deactivated.key,
      ),
      _card(
        label: 'Waiting Approval',
        value: '${counts[UserStatus.pending.key] ?? 0}',
        hint: 'Need your decision',
        icon: Icons.hourglass_empty,
        color: _statusColor(UserStatus.pending.key),
        filter: UserStatus.pending.key,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 600 ? 4 : 2,
            mainAxisExtent: 90,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: cards,
        );
      },
    );
  }

  // Same small card as Sales / Product Alerts. Tapping a status card
  // filters the table to it (tap again to clear); Total clears the filter.
  Widget _card({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
    required String? filter,
  }) {
    final selected = filter != null && _statusFilter == filter;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.7) : Colors.grey.withValues(alpha: 0.15),
        width: selected ? 1.5 : 1,
      ),
    );
    return Material(
      color: selected ? color.withValues(alpha: 0.06) : Colors.white,
      shape: shape,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        customBorder: shape,
        onTap: () => setState(() {
          _statusFilter = (filter == null || selected) ? null : filter;
          _page = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration:
                          BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                      child: Icon(icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                Text(hint, style: TextStyle(fontSize: 10.5, color: Colors.grey[400])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FILTERS ====================

  Widget _buildFilters(String facility, bool hasActiveFilters) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    );

    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name, phone or facility...',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: border,
        enabledBorder: border,
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _page = 1;
                  });
                },
              ),
      ),
      onChanged: (val) => setState(() {
        _searchQuery = val.trim().toLowerCase();
        _page = 1;
      }),
    );

    // Only worth showing when there's more than one facility to choose from.
    final showFacility = facilityNames.length > 1;
    final reset = hasActiveFilters ? TextButton(onPressed: _resetFilters, child: const Text('Reset')) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              if (showFacility || reset != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (showFacility) Expanded(child: _facilityDropdown(facility, expand: true)) else const Spacer(),
                    if (reset != null) ...[const SizedBox(width: 6), reset],
                  ],
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            if (showFacility) ...[const SizedBox(width: 10), _facilityDropdown(facility)],
            if (reset != null) ...[const SizedBox(width: 10), reset],
          ],
        );
      },
    );
  }

  Widget _facilityDropdown(String value, {bool expand = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: expand,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: primaryColor),
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('Facility: All')),
            ...facilityNames.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text('Facility: ${e.value}', overflow: TextOverflow.ellipsis)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _facilityFilter = val;
                _page = 1;
              });
            }
          },
        ),
      ),
    );
  }

  // ==================== TABLE ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No team members yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Use Invite Assistant to add your first team member.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // Centered, and part of the list - sitting right under your own row rather
  // than pinned to the bottom of the screen.
  Widget _buildOnlySelfHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_add_outlined, size: 44, color: Colors.teal.shade300),
              const SizedBox(height: 12),
              const Text('No assistants yet',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Use Invite Assistant to add your first team member.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _startInviteFlow,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Invite Assistant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No team members match your filters', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton(onPressed: _resetFilters, child: const Text('Reset filters')),
        ],
      ),
    );
  }

  Widget _buildResults(List<QueryDocumentSnapshot> items, {bool showOnlySelfHint = false}) {
    final extra = showOnlySelfHint ? 1 : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: items.length + extra,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                index == items.length ? _buildOnlySelfHint() : _buildNarrowCard(items[index]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
              child: Row(
                children: [
                  _headerCell('User name', flex: 4),
                  _headerCell('Role', flex: 2),
                  _headerCell('Phone', flex: 2),
                  _headerCell('Facility', flex: 3),
                  _headerCell('Status', flex: 2),
                  _headerCell('Actions', flex: 4),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length + extra,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
                itemBuilder: (context, index) =>
                    index == items.length ? _buildOnlySelfHint() : _buildRow(items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
    );
  }

  Widget _statusChip(String bucket) {
    final color = _statusColor(bucket);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(_statusLabel(bucket), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  // Wide layout: one table row. Tapping it opens that person's details.
  Widget _buildRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStatus = (data[Fields.status] ?? UserStatus.pending.key).toString();
    final bucket = _bucket(data);
    final facilityId = _facilityIdOf(data);
    final facilityName = _facilityText(data);
    final selected = _selectedUserId == doc.id;

    return InkWell(
      key: ValueKey(doc.id),
      onTap: () => _openDetails(doc),
      child: Container(
        // Coloured bar down the left edge - the account's state at a glance -
        // and a tint when this is the row whose details are open.
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.06) : null,
          border: Border(left: BorderSide(color: _statusColor(bucket), width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  InitialsAvatar(
                    avatarUrl: data['avatarUrl'] as String?,
                    name: data['fullName'] ?? '',
                    size: 36,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    foregroundColor: accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data['fullName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _roleChip(_kindOf(doc.id, data)))),
            Expanded(
              flex: 2,
              child: Text('${data['phone'] ?? ''}',
                  style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 3,
              child: Text(facilityName,
                  style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(bucket))),
            Expanded(
              flex: 4,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _actionsFor(doc, data, rawStatus, facilityId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Narrow layout (phones): the same information as a card per assistant.
  Widget _buildNarrowCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStatus = (data[Fields.status] ?? UserStatus.pending.key).toString();
    final bucket = _bucket(data);
    final facilityId = _facilityIdOf(data);
    final facilityName = _facilityText(data);

    return Container(
      key: ValueKey(doc.id),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      // Clipped so the bar down the left follows the card's rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _openDetails(doc),
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: _statusColor(bucket), width: 4))),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InitialsAvatar(
                        avatarUrl: data['avatarUrl'] as String?,
                        name: data['fullName'] ?? '',
                        size: 44,
                        backgroundColor: accentColor.withValues(alpha: 0.15),
                        foregroundColor: accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['fullName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                            const SizedBox(height: 2),
                            Text('${data['phone'] ?? ''}', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                            const SizedBox(height: 2),
                            Text(facilityName, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(height: 6),
                            _roleChip(_kindOf(doc.id, data)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(bucket),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _actionsFor(doc, data, rawStatus, facilityId),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== DETAILS ====================

  // A panel beside the list when there's room (like the sales screen), a
  // sheet from the bottom when there isn't.
  void _openDetails(QueryDocumentSnapshot doc) {
    if (MediaQuery.of(context).size.width >= 1100) {
      setState(() => _selectedUserId = doc.id);
    } else {
      _showDetailsSheet(doc);
    }
  }

  void _showDetailsSheet(QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _buildDetailsPanel(
          doc,
          showActions: false, // the card already has them
          scrollController: scrollController,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  DateTime? _ts(dynamic value) => value is Timestamp ? value.toDate() : null;

  String _when(DateTime? d) => d == null ? 'Not recorded' : DateFormat('dd MMM yyyy, HH:mm').format(d);

  Widget _panelField(IconData icon, String label, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 9, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(
    QueryDocumentSnapshot doc, {
    required bool showActions,
    VoidCallback? onClose,
    ScrollController? scrollController,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final kind = _kindOf(doc.id, data);
    final bucket = _bucket(data);
    final rawStatus = (data[Fields.status] ?? UserStatus.pending.key).toString();
    final facilityId = _facilityIdOf(data);
    final isSelf = doc.id == adminUid;
    final isAssistant = kind == TeamMemberKind.assistant;

    final created = _ts(data[Fields.createdAt]);
    final approved = _ts(data['approvedAt']);
    final statusChanged = _ts(data['statusChangedAt']);
    final lastActive = _ts(data['lastActiveAt']);
    final rejoined = _ts(data['rejoinedAt']);
    final approvedBy = (data['approvedBy'] ?? '').toString();
    final changedBy = (data['statusChangedBy'] ?? '').toString();
    final changedRole = (data['statusChangedByRole'] ?? '').toString();
    final email = (data['email'] ?? '').toString();

    // Newest first. Registration comes from the account itself; everything
    // after it from the history the server keeps with each change.
    final history = <({DateTime? at, Color color, String title, String by})>[
      (at: created, color: Colors.grey, title: 'Registered', by: ''),
    ];
    final rawHistory = data['statusHistory'];
    if (rawHistory is List) {
      const labels = {'approved': 'Approved', 'rejected': 'Rejected', 'deactivated': 'Deactivated', 'reactivated': 'Reactivated'};
      const colors = {
        'approved': Colors.green,
        'rejected': Colors.red,
        'deactivated': Colors.orange,
        'reactivated': Colors.green,
      };
      for (final h in rawHistory) {
        if (h is! Map) continue;
        final action = (h['action'] ?? '').toString();
        history.add((
          at: _ts(h['at']),
          color: colors[action] ?? Colors.grey,
          title: labels[action] ?? action,
          by: (h['by'] ?? '').toString(),
        ));
      }
    }
    history.sort((a, b) {
      if (a.at == null && b.at == null) return 0;
      if (a.at == null) return 1;
      if (b.at == null) return -1;
      return b.at!.compareTo(a.at!);
    });

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Team Member Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose ?? () => setState(() => _selectedUserId = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                InitialsAvatar(
                  avatarUrl: data['avatarUrl'] as String?,
                  name: data['fullName'] ?? '',
                  size: 56,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  foregroundColor: accentColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['fullName'] ?? ''}${isSelf ? '  (you)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [_roleChip(kind), _statusChip(bucket)]),
                    ],
                  ),
                ),
              ],
            ),
            if (showActions && !isSelf) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: _actionsFor(doc, data, rawStatus, facilityId)),
            ],
            const Divider(height: 28),
            _panelField(Icons.phone_outlined, 'Phone', '${data['phone'] ?? ''}'.isEmpty ? 'Not recorded' : '${data['phone']}'),
            _panelField(Icons.mail_outline, 'Email', email.isEmpty ? 'Not recorded' : email),
            _panelField(Icons.storefront_outlined, 'Facility', _facilityText(data)),
            const Divider(height: 28),
            _panelField(
              Icons.event_available_outlined,
              'Joined',
              _when(created),
              subtitle: rejoined != null ? 'Asked to join again: ${_when(rejoined)}' : null,
            ),
            if (isAssistant)
              _panelField(
                Icons.verified_outlined,
                'Approved',
                approved != null
                    ? _when(approved)
                    : (bucket == UserStatus.pending.key ? 'Waiting for approval' : 'Not recorded'),
                subtitle: approved != null
                    ? (approvedBy.isEmpty ? null : 'by $approvedBy')
                    : (bucket == UserStatus.pending.key ? null : 'Approved before approvals were recorded'),
              ),
            _panelField(
              Icons.update_outlined,
              'Last status change',
              _when(statusChanged),
              subtitle: changedBy.isEmpty ? null : 'by $changedBy${changedRole.isEmpty ? '' : ' ($changedRole)'}',
            ),
            _panelField(Icons.access_time, 'Last active', _when(lastActive)),
            const Divider(height: 28),
            const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 12),
            for (final h in history)
              _historyTile(h.color, h.title, '${_when(h.at)}${h.by.isEmpty ? '' : '  \u00b7  by ${h.by}'}'),
            if (!showActions && !isSelf) ...[
              const SizedBox(height: 4),
              Text(
                'Use the buttons on this person\'s card to approve, reject or remove them.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== LOADING PLACEHOLDER ====================

  // What shows while the team loads: the shape of the screen, softly pulsing,
  // instead of a lone spinner - and instead of drawing a half-loaded list.
  Widget _buildLoadingSkeleton() {
    Widget row() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: const [
              _SkeletonBlock(width: 36, height: 36, radius: 18),
              SizedBox(width: 12),
              Expanded(flex: 4, child: _SkeletonBlock(height: 14)),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _SkeletonBlock(height: 14)),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _SkeletonBlock(height: 14)),
              SizedBox(width: 16),
              Expanded(flex: 3, child: _SkeletonBlock(height: 14)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                  child: const _SkeletonBlock(height: 78, radius: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SkeletonBlock(height: 44, radius: 12),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(children: [for (var i = 0; i < 6; i++) row()]),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PAGINATION ====================

  Widget _buildPaginationBar({required int total, required int page, required int totalPages}) {
    final start = total == 0 ? 0 : (page - 1) * _pageSize + 1;
    final end = (page * _pageSize) > total ? total : page * _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text(
            total == 0 ? 'No assistants' : 'Showing $start to $end of $total assistant${total == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _page = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => setState(() => _page = page - 1) : null,
              ),
              Text('Page $page', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => setState(() => _page = page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A grey block that pulses gently - the placeholder for something still loading.
class _SkeletonBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const _SkeletonBlock({this.width, this.height = 14, this.radius = 6});

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(Colors.grey.shade200, Colors.grey.shade300, _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
