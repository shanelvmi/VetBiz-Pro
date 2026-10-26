import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

/// The facility type as a small tag (FN1, docs/design/facility_name_display.md):
/// a classification shown beside or under the name, never joined to it, in
/// the facility picker and the Facilities cards (the business profile shows it
/// as a row). The type changes no behaviour; it only picks the tag's colour.
class FacilityTypeTag extends StatelessWidget {
  /// The stored type ('Agrovet', 'Other'...), compared as stored.
  final String type;

  /// An Other facility's own words (RW2b2), shown instead of "Other".
  final String? typeDetail;

  const FacilityTypeTag({super.key, required this.type, this.typeDetail});

  static Color _fill(BuildContext context, String type) {
    switch (type.toLowerCase()) {
      case 'agrovet':
        return context.colors.success;
      case 'vet clinic':
      case 'vet hospital':
      case 'ambulatory vet':
        return context.colors.info;
      default:
        return context.colors.chart4;
    }
  }

  // The fill keeps the type colour; the label is the same colour in light,
  // and in dark the chip label roles, lifted to 4.5 on that fill (K6).
  static Color _label(BuildContext context, String type) {
    final fill = _fill(context, type);
    if (fill == context.colors.info) return context.colors.infoChipLabel;
    if (fill == context.colors.chart4) return context.colors.chart4ChipLabel;
    return fill;
  }

  @override
  Widget build(BuildContext context) {
    final known = type.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: known ? _fill(context, type).withValues(alpha: AppAlpha.a10) : context.colors.textHint.withValues(alpha: AppAlpha.a10),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        known ? context.l10n.facilityTypeDisplay(type, typeDetail) : context.l10n.facilityPicker_typeNotSet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: known ? _label(context, type) : context.colors.textMuted,
          fontSize: AppFontSize.f11,
          fontWeight: AppFontWeight.semibold,
        ),
      ),
    );
  }
}
