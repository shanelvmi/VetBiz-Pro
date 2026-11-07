import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

/// PH8b-2 P3: the logo at the top of the phone Add and Edit Facility forms,
/// as the dialogs show it: the picked logo, else the facility's (Edit), else
/// a placeholder; a tap picks one; Edit adds the camera badge and Remove logo
/// while there is a logo. Labels are 12 px on a phone (S3).
class FacilityLogoField extends StatelessWidget {
  final bool isEdit;
  final Uint8List? bytes;
  final String? existingUrl;
  final bool removed;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  const FacilityLogoField({
    super.key,
    required this.isEdit,
    required this.bytes,
    required this.existingUrl,
    required this.removed,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final hasLogo = (bytes != null || existingUrl != null) && !removed;
    final placeholder = Icon(isEdit ? Icons.business : Icons.add_a_photo_outlined,
        color: isEdit ? colors.primary : colors.textHint, size: AppIconSize.i32);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: PhoneFacilityMetrics.headerLogo,
                height: PhoneFacilityMetrics.headerLogo,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(AppSpacing.s6),
                child: bytes != null
                    ? Image.memory(bytes!, fit: BoxFit.contain)
                    : (existingUrl != null && !removed
                        ? Image.network(existingUrl!,
                            fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => placeholder)
                        : placeholder),
              ),
              if (isEdit)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt, size: AppIconSize.i12, color: colors.onPrimary),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          isEdit ? l10n.facilities_tapToChangeLogo : l10n.facilities_logoOptional,
          style: TextStyle(fontSize: PhoneListMetrics.detailLabel, color: colors.textMuted),
        ),
        if (isEdit && hasLogo)
          TextButton(
            onPressed: onRemove,
            child: Text(l10n.facilities_removeLogo,
                style: TextStyle(fontSize: PhoneListMetrics.detailLabel, color: colors.dangerAccent)),
          ),
      ],
    );
  }
}
