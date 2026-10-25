import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'profile_avatar.dart';

/// One action in the profile drawer.
class ProfileDrawerAction {
  const ProfileDrawerAction({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Shown in the danger colour (Sign out).
  final bool destructive;
}

/// A compact row of the profile drawer: a leading icon and the label, 48 px
/// high (Material's touch target), no card around it.
class ProfileDrawerRow extends StatelessWidget {
  const ProfileDrawerRow({super.key, required this.action});

  final ProfileDrawerAction action;

  @override
  Widget build(BuildContext context) {
    final ink = action.destructive ? context.colors.dangerStrong : context.colors.textPrimary;
    final iconInk = action.destructive ? context.colors.dangerStrong : context.colors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r8),
      hoverColor: context.colors.surfaceMuted,
      onTap: action.onTap,
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          child: Row(
            children: [
              Icon(action.icon, size: AppIconSize.i20, color: iconInk),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSize.f15, fontWeight: AppFontWeight.medium, color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The profile drawer: the avatar (display only; the photo is changed in
/// Edit Profile), the name, the role, the person's details as icon, label
/// and value rows, then the actions as compact rows.
class ProfileDrawerContent extends StatelessWidget {
  const ProfileDrawerContent({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.roleLabel,
    required this.email,
    required this.phone,
    required this.facility,
    required this.actions,
    required this.onClose,
  });

  final String? avatarUrl;
  final String name;
  final String roleLabel;
  final String email;
  final String phone;
  final String facility;
  final List<ProfileDrawerAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s24),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: context.l10n.common_close,
              icon: Icon(Icons.close, color: context.colors.textSecondary),
              onPressed: onClose,
            ),
          ),
          Center(child: ProfileAvatar(avatarUrl: avatarUrl, name: name, size: AppSizes.profileAvatarDrawer)),
          const SizedBox(height: AppSpacing.s12),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold, color: context.colors.textStrong),
          ),
          if (roleLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              roleLabel,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.s20),
          _DetailRow(icon: Icons.email_outlined, label: context.l10n.common_email, value: email),
          _DetailRow(icon: Icons.phone_outlined, label: context.l10n.common_phone, value: phone),
          _DetailRow(icon: Icons.store_outlined, label: context.l10n.common_facility, value: facility),
          const SizedBox(height: AppSpacing.s8),
          Divider(height: AppSpacing.s16, color: context.colors.divider),
          for (final action in actions) ProfileDrawerRow(action: action),
        ],
      ),
    );
  }
}

/// Icon, label and value; a long value wraps to two lines, then ellipsis.
/// An empty value leaves the row out.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Icon(icon, size: AppIconSize.i18, color: context.colors.textMuted),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppFontSize.f14, color: context.colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
