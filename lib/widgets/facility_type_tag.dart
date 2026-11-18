import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_dimens.dart';
import '../theme/app_layout.dart';
import '../theme/app_text.dart';
import '../theme/polish_metrics.dart';
import '../theme/theme_context.dart';

/// The facility type as a small tag (FN1, docs/design/facility_name_display.md):
/// a classification shown beside or under the name, never joined to it, in
/// the facility picker and the Facilities cards (the business profile shows it
/// as a row). The type changes no behaviour. POL7: a neutral hairline tag in
/// secondary text for every type (it was green, blue or purple by type).
class FacilityTypeTag extends StatelessWidget {
  /// The stored type ('Agrovet', 'Other'...), compared as stored.
  final String type;

  /// An Other facility's own words (RW2b2), shown instead of "Other".
  final String? typeDetail;

  const FacilityTypeTag({super.key, required this.type, this.typeDetail});

  @override
  Widget build(BuildContext context) {
    final known = type.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        // Drawn outside the edge, so the tag keeps its size and place.
        border: Border.all(color: context.colors.border, width: PolishMetrics.hairline, strokeAlign: BorderSide.strokeAlignOutside),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(
        known ? context.l10n.facilityTypeDisplay(type, typeDetail) : context.l10n.facilityPicker_typeNotSet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: known ? context.colors.textSecondary : context.colors.textMuted,
          // PH8b: 12 on a phone (S3: secondary text at least 12); 11 elsewhere,
          // as before.
          fontSize: AppLayout.isPhone(context) ? AppFontSize.f12 : AppFontSize.f11,
          fontWeight: AppFontWeight.semibold,
        ),
      ),
    );
  }
}
