import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// One answer of a step that asks the person to pick (register_wizard.md
/// section 3): a radio, an optional icon, a title and an optional line under
/// it. The whole card is the tap target. Chosen = the Select Facility
/// card's roles (K6): selectedCardFill with a selectableCardInk outline and
/// ink, which is the primary in light and a lifted primary in dark, so the
/// text keeps 4.5 on the fill. The outline is also thicker, so the choice
/// does not rely on colour alone.
class WizardOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// UI8, the phone register page's step 1: taller, a larger corner, the
  /// icon in a tile at the left (the header's tint, the surface when chosen)
  /// and the radio at the right. The roles are the same.
  final bool large;

  /// For tests: the icon's tile ([large]).
  static const tileKey = ValueKey<String>('wizard-option-tile');

  const WizardOptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.selectableCardInk;
    final titleColor = selected ? ink : colors.textStrong;
    // The full ink, not the K6 type line's 85%: that measured 4.41 on the
    // Pasture fill in light.
    final subtitleColor = selected ? ink : colors.textMuted;
    final markColor = selected ? ink : colors.textMuted;
    final radio = Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      size: WizardMetrics.optionIcon,
      color: markColor,
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.selectedCardFill : colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(large ? AuthPhoneMetrics.optionRadius : WizardMetrics.optionRadius),
          side: BorderSide(
            color: selected ? ink : colors.border,
            width: selected ? WizardMetrics.optionBorderSelected : WizardMetrics.optionBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: large ? AuthPhoneMetrics.optionMinHeight : WizardMetrics.optionMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WizardMetrics.optionPaddingH,
                vertical: WizardMetrics.optionPaddingV,
              ),
              child: Row(
                children: [
                  if (large) ...[
                    if (icon != null) ...[_tile(context), const SizedBox(width: WizardMetrics.optionGap)],
                  ] else ...[
                    radio,
                    const SizedBox(width: WizardMetrics.optionGap),
                    if (icon != null) ...[
                      Icon(icon, size: WizardMetrics.optionIcon, color: markColor),
                      const SizedBox(width: WizardMetrics.optionGap),
                    ],
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: WizardFontSize.optionTitle,
                            fontWeight: AppFontWeight.semibold,
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: WizardMetrics.optionTextGap),
                          Text(
                            subtitle!,
                            style: TextStyle(fontSize: WizardFontSize.optionSubtitle, color: subtitleColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (large) ...[const SizedBox(width: WizardMetrics.optionGap), radio],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on WizardOptionCard {
  // The icon in its tile: the phone header's tint (authFooterFill) with the
  // signed-out headings' icon role; the surface and the card's ink when chosen.
  Widget _tile(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: WizardOptionCard.tileKey,
      width: AuthPhoneMetrics.optionTile,
      height: AuthPhoneMetrics.optionTile,
      decoration: BoxDecoration(
        color: selected ? colors.surface : colors.authFooterFill,
        borderRadius: BorderRadius.circular(AuthPhoneMetrics.optionTileRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: WizardMetrics.optionIcon, color: selected ? colors.selectableCardInk : colors.authPanelIcon),
    );
  }
}
