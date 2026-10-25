import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'profile_avatar.dart';

/// The photo part of Edit Profile and sign-up: the avatar (or the photo just
/// picked), Change photo, and Remove photo when there is one.
class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.avatarUrl,
    required this.previewBytes,
    required this.name,
    required this.onChange,
    required this.onRemove,
    this.busy = false,
  });

  final String? avatarUrl;
  final Uint8List? previewBytes;
  final String name;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  /// A save or remove is running: both buttons wait.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = previewBytes != null || (avatarUrl != null && avatarUrl!.isNotEmpty);
    final avatar = previewBytes != null
        ? ClipOval(
            child: Image.memory(previewBytes!,
                width: AppSizes.profileAvatarEditor, height: AppSizes.profileAvatarEditor, fit: BoxFit.cover),
          )
        : ProfileAvatar(avatarUrl: avatarUrl, name: name, size: AppSizes.profileAvatarEditor);

    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.register_profilePhoto,
                  style: const TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
              const SizedBox(height: AppSpacing.s4),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onChange,
                    icon: const Icon(Icons.photo_library_outlined, size: AppIconSize.i18),
                    label: Text(context.l10n.profile_changePhoto),
                  ),
                  if (hasPhoto)
                    TextButton.icon(
                      onPressed: busy ? null : onRemove,
                      style: TextButton.styleFrom(foregroundColor: context.colors.dangerStrong),
                      icon: const Icon(Icons.delete_outline, size: AppIconSize.i18),
                      label: Text(context.l10n.profile_removePhoto),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
