import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../facility_type_tag.dart';
import 'profile_avatar.dart';
import 'profile_drawer.dart';

export 'profile_switch_sheet.dart' show showSwitchFacilitySheet;

/// HUB4b: a group of the phone profile page.
enum ProfileGroup { account, business, app }

/// The page's groups and the items each holds, top to bottom. Sign out is
/// not in a group: it is the red button at the bottom.
const profilePageGroups = {
  ProfileGroup.account: [ProfileItem.editProfile, ProfileItem.changePassword],
  ProfileGroup.business: [ProfileItem.team, ProfileItem.facilities, ProfileItem.activityLog],
  ProfileGroup.app: [ProfileItem.settings, ProfileItem.help],
};

String profileGroupTitle(AppLocalizations l10n, ProfileGroup group) => switch (group) {
      ProfileGroup.account => l10n.dashboard_account,
      ProfileGroup.business => l10n.expenseGroup_business,
      ProfileGroup.app => l10n.more_sectionApp,
    };

/// The [actions] (the drawer's own list, already filtered by role) placed in
/// the groups, each group in [profilePageGroups]' order; an action with no
/// known place goes at the end of App, so nothing is ever lost. Groups left
/// empty (an assistant's Business) are left out. Sign out is not included.
List<({ProfileGroup group, List<ProfileDrawerAction> actions})> profilePageSections(List<ProfileDrawerAction> actions) {
  final placed = {for (final items in profilePageGroups.values) ...items, ProfileItem.signOut};
  return [
    for (final entry in profilePageGroups.entries)
      (
        group: entry.key,
        actions: [
          for (final item in entry.value) ...actions.where((a) => a.item == item),
          if (entry.key == ProfileGroup.app) ...actions.where((a) => !placed.contains(a.item)),
        ],
      ),
  ].where((s) => s.actions.isNotEmpty).toList();
}

/// HUB4b: the phone's full-screen profile (a pushed page, the app's page
/// transition), in place of the end drawer: the large avatar, the name and
/// the role, the email and phone, the Current facility card (tappable with a
/// chevron when [onSwitchFacility] is given: two or more facilities), the
/// drawer's actions in groups, and Sign out as a red text button. Back
/// returns to Home as it was. Reads nothing: the dashboard hands it what it
/// already holds. Tablets and computers keep the drawer.
class ProfilePage extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String roleLabel;
  final String email;
  final String phone;

  /// The current facility, its name alone (FacilityDisplay.name), and its
  /// stored type with an Other facility's own words.
  final String facility;
  final String facilityType;
  final String? facilityTypeDetail;

  /// The profile drawer's actions, with the same role gates.
  final List<ProfileDrawerAction> actions;

  /// Opens the Switch facility sheet; null for one facility (no tap).
  final VoidCallback? onSwitchFacility;

  const ProfilePage({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.roleLabel,
    required this.email,
    required this.phone,
    required this.facility,
    required this.actions,
    this.facilityType = '',
    this.facilityTypeDetail,
    this.onSwitchFacility,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final signOut = actions.where((a) => a.item == ProfileItem.signOut).firstOrNull;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(l10n.profile_pageTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('profile-page-list'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s24),
          children: [
            Center(child: ProfileAvatar(avatarUrl: avatarUrl, name: name, size: AppSizes.profileAvatarPage)),
            const SizedBox(height: AppSpacing.s12),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.bold, color: colors.textStrong),
            ),
            if (roleLabel.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                roleLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppFontSize.f14, color: colors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            ProfileDetailRow(icon: Icons.email_outlined, label: l10n.common_email, value: email),
            ProfileDetailRow(icon: Icons.phone_outlined, label: l10n.common_phone, value: phone),
            const SizedBox(height: AppSpacing.s8),
            _CurrentFacilityCard(
              facility: facility,
              type: facilityType,
              typeDetail: facilityTypeDetail,
              onTap: onSwitchFacility,
            ),
            for (final section in profilePageSections(actions)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s20, AppSpacing.s12, AppSpacing.s4),
                child: Text(
                  profileGroupTitle(l10n, section.group),
                  key: ValueKey('profile-group-${section.group.name}'),
                  style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: colors.textMuted),
                ),
              ),
              _GroupCard(children: [for (final action in section.actions) ProfileDrawerRow(action: action)]),
            ],
            if (signOut != null) ...[
              const SizedBox(height: AppSpacing.s24),
              Center(
                child: TextButton(
                  key: const ValueKey('profile-sign-out'),
                  onPressed: signOut.onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.dangerStrong,
                    minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                  ),
                  child: Text(
                    signOut.label,
                    style: const TextStyle(fontSize: AppFontSize.f15, fontWeight: AppFontWeight.semibold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A group's rows on one surface card.
class _GroupCard extends StatelessWidget {
  final List<Widget> children;

  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        side: BorderSide(color: context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// "Current facility" over the name alone, the type as the small tag; with
/// [onTap] (two or more facilities) the card is a button with a chevron.
class _CurrentFacilityCard extends StatelessWidget {
  final String facility;
  final String type;
  final String? typeDetail;
  final VoidCallback? onTap;

  const _CurrentFacilityCard({required this.facility, required this.type, required this.onTap, this.typeDetail});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Semantics(
      button: onTap != null,
      child: Material(
        key: const ValueKey('profile-facility-card'),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
              child: Row(
                children: [
                  Icon(Icons.store_outlined, size: AppIconSize.i20, color: colors.textMuted),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.profile_currentFacility,
                            style: TextStyle(fontSize: AppFontSize.f12, color: colors.textMuted)),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          facility,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: AppFontSize.f15, fontWeight: AppFontWeight.semibold, color: colors.textPrimary),
                        ),
                        if (type.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s4),
                          FacilityTypeTag(type: type, typeDetail: typeDetail),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
