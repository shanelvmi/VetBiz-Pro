import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../providers/user_role_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/phone_form/form_action_bar.dart';
import 'trash_actions.dart';

/// One deleted record, of any kind.
class TrashItem {
  final TrashKind kind;
  final String id;
  final Map<String, dynamic> data;

  const TrashItem(this.kind, this.id, this.data);

  String get title => kind.titleOf(data);
  DateTime? get deletedAt => data['deletedAt'] is Timestamp ? (data['deletedAt'] as Timestamp).toDate() : null;
}

/// A deleted record's details on a phone, as a full page (R7): what it is,
/// who deleted it and when, when it leaves Trash for good; Restore and Delete
/// forever (today's question) for admins. The page closes after either.
class TrashDetailsPage extends StatefulWidget {
  final TrashItem item;
  final String deletedLine;
  final String facilityId;
  final FirebaseFirestore firestore;
  final Future<Map<String, String>> Function() currentUserInfo;

  const TrashDetailsPage({
    super.key,
    required this.item,
    required this.deletedLine,
    required this.facilityId,
    required this.firestore,
    required this.currentUserInfo,
  });

  @override
  State<TrashDetailsPage> createState() => TrashDetailsPageState();
}

class TrashDetailsPageState extends State<TrashDetailsPage> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final done = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final item = widget.item;
    final (expiry, expiryColor) = trashExpiry(context, item.deletedAt);
    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(l.common_details)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Row(
            children: [
              Icon(item.kind.icon, color: colors.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(item.kind.label(l), style: TextStyle(fontSize: PhoneListMetrics.subtitle, color: colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(item.title, style: const TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold)),
          const SizedBox(height: AppSpacing.s8),
          Text(widget.deletedLine, style: TextStyle(fontSize: PhoneListMetrics.subtitle, color: colors.textSoft)),
          if (expiry.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(expiry,
                style: TextStyle(fontSize: PhoneListMetrics.subtitle, color: expiryColor, fontWeight: AppFontWeight.semibold)),
          ],
        ],
      ),
      bottomNavigationBar: !isAdmin
          ? null
          : FormActionBar(
              primaryLabel: l.common_restore,
              busy: _busy,
              onPrimary: () => _run(() => restoreTrashed(
                    firestore: widget.firestore,
                    currentUserInfo: widget.currentUserInfo,
                    facilityId: widget.facilityId,
                    kind: item.kind,
                    id: item.id,
                    data: item.data,
                  )),
              secondaryLabel: l.trash_deleteForever,
              onSecondary: () => _run(() => deleteTrashedForever(
                    context,
                    firestore: widget.firestore,
                    currentUserInfo: widget.currentUserInfo,
                    facilityId: widget.facilityId,
                    trashCollection: item.kind.trashCollection,
                    id: item.id,
                    label: item.title,
                  )),
            ),
    );
  }
}
