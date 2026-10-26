import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'info_page.dart';

/// How to use it (G4), opened from the sign-in footer: a numbered
/// getting-started guide for the owner, then for an assistant. Screen and
/// button names are the app's own; every step is proved in
/// docs/design/footer_pages_content.md.
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owner = [
      l10n.howToUse_owner1,
      l10n.howToUse_owner2,
      l10n.howToUse_owner3,
      l10n.howToUse_owner4,
      l10n.howToUse_owner5,
      l10n.howToUse_owner6,
      l10n.howToUse_owner7,
      l10n.howToUse_owner8,
      l10n.howToUse_owner9,
      l10n.howToUse_owner10,
    ];
    final assistant = [
      l10n.howToUse_assistant1,
      l10n.howToUse_assistant2,
      l10n.howToUse_assistant3,
      l10n.howToUse_assistant4(l10n.entry_notActiveYet),
      l10n.howToUse_assistant5,
      l10n.howToUse_assistant6,
    ];
    return InfoPage(
      title: l10n.authFooter_howToUse,
      children: [
        InfoHeading(l10n.howToUse_ownerTitle),
        for (var i = 0; i < owner.length; i++) _Step(number: i + 1, text: owner[i]),
        InfoHeading(l10n.howToUse_assistantTitle),
        for (var i = 0; i < assistant.length; i++) _Step(number: i + 1, text: assistant[i]),
      ],
    );
  }
}

/// One numbered step: the number in a soft circle, then the sentence.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: InfoPageMetrics.itemGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: InfoPageMetrics.stepBadge,
            height: InfoPageMetrics.stepBadge,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.quickActionTintPrimary, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(fontSize: InfoPageFontSize.step, fontWeight: AppFontWeight.bold, color: context.colors.primary),
            ),
          ),
          const SizedBox(width: InfoPageMetrics.itemGap),
          Expanded(child: Text(text, style: InfoPageText.body(context))),
        ],
      ),
    );
  }
}
