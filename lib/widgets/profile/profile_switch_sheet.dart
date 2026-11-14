import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/facility_entry.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../utils/facility_display.dart';
import '../app_sheet.dart';
import '../facility_type_tag.dart';

/// HUB4b: the Switch facility sheet: the person's facilities (the name
/// alone, the type tag, a check on [currentId]). A tap closes the sheet;
/// another facility goes to [onPick] (the facility picker's activation path).
Future<void> showSwitchFacilitySheet(
  BuildContext context, {
  required List<FacilityEntry> facilities,
  required String? currentId,
  required ValueChanged<FacilityEntry> onPick,
}) {
  return showAppSheet<void>(
    context,
    title: context.l10n.profile_switchFacility,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in facilities)
          _SwitchRow(
            entry: f,
            current: f.id == currentId,
            onTap: () {
              Navigator.of(sheetContext).pop();
              if (f.id != currentId) onPick(f);
            },
          ),
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  final FacilityEntry entry;
  final bool current;
  final VoidCallback onTap;

  const _SwitchRow({required this.entry, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = entry.type ?? '';
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        key: ValueKey('switch-facility-${entry.id}'),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FacilityDisplay.name(entry.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.f15,
                          fontWeight: current ? AppFontWeight.semibold : AppFontWeight.medium,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s4),
                        FacilityTypeTag(type: type, typeDetail: entry.typeDetail),
                      ],
                    ],
                  ),
                ),
                if (current) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Icon(Icons.check, color: colors.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
