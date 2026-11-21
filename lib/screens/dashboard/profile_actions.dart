import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/profile/profile_drawer.dart';

/// What each profile action does (the dashboard's handlers).
class ProfileHandlers {
  final VoidCallback editProfile;
  final VoidCallback team;
  final VoidCallback facilities;
  final VoidCallback changePassword;
  final VoidCallback language;
  final VoidCallback activityLog;
  final VoidCallback settings;
  final VoidCallback help;
  final VoidCallback signOut;

  const ProfileHandlers({
    required this.editProfile,
    required this.team,
    required this.facilities,
    required this.changePassword,
    required this.language,
    required this.activityLog,
    required this.settings,
    required this.help,
    required this.signOut,
  });
}

/// The profile menu's actions, their order and who sees them, as before;
/// Sign out is the last row (it was a round button in the corner). HUB4b:
/// ONE list for the wide drawer and the phone's profile page, so both keep
/// the same items and the same role gates (Team Members, View Facilities and
/// the Activity Log for admins, a Co-admin included).
List<ProfileDrawerAction> profileActionsFor(AppLocalizations l10n, {required bool isAdmin, required ProfileHandlers on, bool wide = false}) => [
      ProfileDrawerAction(
        item: ProfileItem.editProfile,
        icon: Icons.edit_outlined,
        label: l10n.common_editProfile,
        onTap: on.editProfile,
      ),
      // LAY7 (owner, 2026-11-18): on PC and tablet Team Members, View Facilities
      // and the Activity Log moved into Settings > Business; the panel keeps
      // personal items only. The phone list (wide: false) is unchanged.
      if (isAdmin && !wide) ...[
        ProfileDrawerAction(
          item: ProfileItem.team,
          icon: AppIcons.team.outlined,
          label: l10n.team_title,
          onTap: on.team,
        ),
        ProfileDrawerAction(
          item: ProfileItem.facilities,
          icon: AppIcons.facilities.outlined,
          label: l10n.dashboard_viewFacilities,
          onTap: on.facilities,
        ),
      ],
      ProfileDrawerAction(
        item: ProfileItem.changePassword,
        icon: Icons.lock_outline,
        label: l10n.dashboard_changePassword,
        onTap: on.changePassword,
      ),
      // LAY3 (owner, 2026-11-18): on PC and tablet the panel holds personal
      // items only. Settings is in the sidebar and Help in the top bar there,
      // so the wide panel drops both and gains a Language shortcut (Settings
      // keeps its own row). The phone list (wide: false) is unchanged.
      if (wide)
        ProfileDrawerAction(
          item: ProfileItem.language,
          icon: Icons.language_outlined,
          label: l10n.settings_languageBoth,
          onTap: on.language,
        ),
      if (isAdmin && !wide)
        ProfileDrawerAction(
          item: ProfileItem.activityLog,
          icon: AppIcons.activityLog.filled,
          label: l10n.export_activityLog,
          onTap: on.activityLog,
        ),
      // HUB1 (the owner's split): the profile menu is the person and
      // Settings, at every width; the action panel is daily work and the
      // Settings screen configuration. Help left Settings for here.
      if (!wide) ...[
        ProfileDrawerAction(
          item: ProfileItem.settings,
          icon: AppIcons.settings.outlined,
          label: l10n.settings_title,
          onTap: on.settings,
        ),
        ProfileDrawerAction(
          item: ProfileItem.help,
          icon: AppIcons.help.outlined,
          label: l10n.dashboard_help,
          onTap: on.help,
        ),
      ],
      ProfileDrawerAction(
        item: ProfileItem.signOut,
        icon: Icons.power_settings_new,
        label: l10n.common_logout,
        destructive: true,
        onTap: on.signOut,
      ),
    ];
