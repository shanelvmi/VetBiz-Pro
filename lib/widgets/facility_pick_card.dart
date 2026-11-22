import 'package:flutter/material.dart';

import '../data/facility_status.dart';
import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/polish_metrics.dart';
import '../theme/theme_context.dart';
import '../ui/polish/app_status.dart';
import 'facility_type_tag.dart';
import 'reveal/reveal_image.dart';
import 'reveal/skeleton_box.dart';

/// UX9: one facility on the Select Facility screen. A flat hairline card;
/// the WHOLE card opens the facility (tap, click, or Enter/Space once
/// focused), with a hover and focus state. The ⋮ menu sits in its own
/// corner and never opens the facility. Only the highlighted card (the
/// user's chosen Default) carries the accent: its outline, its tile tint,
/// its badge and its "Open facility" row.
class FacilityPickCard extends StatelessWidget {
  const FacilityPickCard({
    super.key,
    required this.name,
    required this.type,
    this.typeDetail,
    this.logoUrl,
    this.address,
    required this.status,
    required this.staffCount,
    required this.isDefault,
    required this.onOpen,
    this.onSetDefault,
  });

  final String name;

  /// The stored type, compared as stored (the tag shows its label).
  final String type;
  final String? typeDetail;
  final String? logoUrl;
  final String? address;

  /// The stored status ('active' ...), shown through its lookup.
  final String status;
  final int staffCount;
  final bool isDefault;
  final VoidCallback onOpen;

  /// The ⋮ menu's only action. Null hides the menu (the Default card, which
  /// has nothing to offer there: no empty menu).
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(FacilityPickerMetrics.cardRadius);
    final hasAddress = address != null && address!.isNotEmpty;
    final active = FacilityStatus.fromKey(status) == FacilityStatus.active;
    final openColour = isDefault ? colors.primary : colors.textPrimary;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isDefault ? colors.primary : colors.border,
          width: isDefault ? FacilityPickerMetrics.selectedOutline : PolishMetrics.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('facilityPickCard-tap'),
        onTap: onOpen,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(FacilityPickerMetrics.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LogoTile(name: name, logoUrl: logoUrl, highlighted: isDefault),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, color: colors.textPrimary)),
                          const SizedBox(height: AppSpacing.s4),
                          // The type chip, and the Default badge beside it (under it
                          // when the words are long): never squeezing the name.
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FacilityTypeTag(type: type, typeDetail: typeDetail),
                              if (isDefault) _DefaultBadge(label: l10n.facilityPicker_default),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isDefault && onSetDefault != null)
                      PopupMenuButton<String>(
                        key: const ValueKey('facilityPickCard-menu'),
                        icon: Icon(Icons.more_vert, size: AppIconSize.i18, color: colors.textSecondary),
                        onSelected: (value) {
                          if (value == 'default') onSetDefault!();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'default', child: Text(context.l10n.facilityPicker_setAsDefault)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: AppIconSize.i14, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Text(
                        hasAddress ? address! : l10n.facilityPicker_locationNotSet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFontSize.f12, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                // The two pairs wrap onto a second line when the words are
                // long (Kiswahili, large text, a narrow column).
                Wrap(
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: AppIconSize.i14, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.s4),
                        Flexible(
                          child: Text(l10n.facilityPicker_staffCount(staffCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppFontSize.f12, color: colors.textSecondary)),
                        ),
                      ],
                    ),
                    StatusDot(status: active ? AppStatus.success : AppStatus.neutral, label: l10n.facilityStatusLabel(status)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Divider(height: PolishMetrics.hairline, thickness: PolishMetrics.hairline, color: colors.border),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: Text(l10n.facilityPicker_openFacility,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold, color: openColour)),
                    ),
                    Icon(Icons.arrow_forward, size: AppIconSize.i18, color: openColour),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The facility's logo, or two initials on a tile when there is none.
/// Neutral, except on the highlighted card (the accent tint).
class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.name, required this.logoUrl, required this.highlighted});

  final String name;
  final String? logoUrl;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = Container(
      key: const ValueKey('facilityPickCard-initials'),
      alignment: Alignment.center,
      color: highlighted ? colors.primary.withValues(alpha: AppAlpha.a10) : colors.surfaceMuted,
      child: Text(facilityInitials(name),
          style: TextStyle(
              fontSize: FacilityPickerMetrics.initialsText,
              fontWeight: AppFontWeight.bold,
              color: highlighted ? colors.primary : colors.textSecondary)),
    );
    final url = logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(FacilityPickerMetrics.logoTileRadius),
      child: SizedBox(
        width: FacilityPickerMetrics.logoTile,
        height: FacilityPickerMetrics.logoTile,
        child: url != null && url.isNotEmpty
            ? RevealImage.fill(key: const ValueKey('facilityPickCard-logo'), url: url, fit: BoxFit.cover, placeholder: initials)
            : initials,
      ),
    );
  }
}

/// Up to two letters for a facility's tile: the first letters of its first
/// two words, or the first two of a single word ("Mifugo Clinic" -> MC,
/// "Kilimo" -> KI). Empty when the name has no letters to show.
String facilityInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    final w = words.first.characters;
    return w.take(2).toString().toUpperCase();
  }
  return '${words[0].characters.first}${words[1].characters.first}'.toUpperCase();
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('facilityPickCard-default'),
      padding: const EdgeInsets.symmetric(horizontal: PolishMetrics.pillPaddingH, vertical: PolishMetrics.pillPaddingV),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: PolishMetrics.pillAlpha),
        borderRadius: BorderRadius.circular(PolishMetrics.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: AppIconSize.i12, color: colors.primary),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.primary, fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold)),
          ),
        ],
      ),
    );
  }
}

/// The card's shape while the details load: the same padding, tile, lines
/// and divider, as soft boxes (no spinner). Pulsed by the screen's one
/// SkeletonPulse.
class FacilityPickCardSkeleton extends StatelessWidget {
  const FacilityPickCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('facilityPickCard-skeleton'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(FacilityPickerMetrics.cardRadius),
        border: Border.all(color: colors.border, width: PolishMetrics.hairline),
      ),
      padding: const EdgeInsets.all(FacilityPickerMetrics.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: FacilityPickerMetrics.logoTile, height: FacilityPickerMetrics.logoTile, radius: FacilityPickerMetrics.logoTileRadius),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(widthFactor: 0.7, child: const SkeletonBox(height: AppSpacing.s16)),
                    const SizedBox(height: AppSpacing.s8),
                    const SkeletonBox(width: AppIconSize.i64, height: AppSpacing.s14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          FractionallySizedBox(widthFactor: 0.5, child: const SkeletonBox(height: AppSpacing.s12)),
          const SizedBox(height: AppSpacing.s8),
          FractionallySizedBox(widthFactor: 0.6, child: const SkeletonBox(height: AppSpacing.s12)),
          const SizedBox(height: AppSpacing.s12),
          Divider(height: PolishMetrics.hairline, thickness: PolishMetrics.hairline, color: colors.border),
          const SizedBox(height: AppSpacing.s12),
          FractionallySizedBox(widthFactor: 0.4, child: const SkeletonBox(height: AppSpacing.s14)),
        ],
      ),
    );
  }
}
