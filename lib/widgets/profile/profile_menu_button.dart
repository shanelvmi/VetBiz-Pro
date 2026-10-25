import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'profile_avatar.dart';

/// The person's button in the top bar; a tap opens the profile drawer.
/// Below AppBreakpoints.compact: the avatar only, in its highlighted
/// circle. Wider: the avatar, the name and the role in a plain row with a
/// small chevron, at least 48 px high.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key, required this.avatarUrl, required this.name, required this.roleLabel, required this.onTap});

  final String? avatarUrl;
  final String name;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final avatar = ProfileAvatar(avatarUrl: avatarUrl, name: name, size: AppSizes.profileAvatarBar);
    final shownName = name.isNotEmpty ? name : context.l10n.dashboard_account;

    if (compact) {
      // The highlighted circle: an accent ring on hover, as before.
      return Tooltip(
        message: context.l10n.dashboard_account,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            hoverColor: context.colors.accent.withValues(alpha: AppAlpha.a20),
            onTap: onTap,
            child: SizedBox.square(dimension: kMinInteractiveDimension, child: Center(child: avatar)),
          ),
        ),
      );
    }

    return Tooltip(
      message: context.l10n.dashboard_account,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: InkWell(
          // Plain: no fill until hovered or pressed.
          borderRadius: BorderRadius.circular(AppRadius.r12),
          hoverColor: context.colors.surfaceMuted,
          highlightColor: context.colors.surfaceMuted,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(width: AppSpacing.s10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppSizes.profileNameMax),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary),
                        ),
                        if (roleLabel.isNotEmpty)
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Icon(Icons.keyboard_arrow_down, size: AppIconSize.i18, color: context.colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
