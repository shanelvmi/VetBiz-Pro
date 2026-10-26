import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import 'info_page.dart';

/// FAQs (G4), opened from the sign-in footer: twelve questions, each
/// opening to its answer. Every answer is proved in
/// docs/design/footer_pages_content.md.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (l10n.faq_startQ, l10n.faq_startA),
      (l10n.faq_trialQ, l10n.faq_trialA),
      (l10n.faq_teamQ, l10n.faq_teamA),
      (l10n.faq_assistantQ, l10n.faq_assistantA),
      (l10n.faq_saleQ, l10n.faq_saleA),
      (l10n.faq_serviceQ, l10n.faq_serviceA),
      (l10n.faq_printQ, l10n.faq_printA),
      (l10n.faq_deletedQ, l10n.faq_deletedA),
      (l10n.faq_passwordQ, l10n.faq_passwordA),
      (l10n.faq_languageQ, l10n.faq_languageA),
      (l10n.faq_themeQ, l10n.faq_themeA),
      (l10n.faq_supportQ, l10n.faq_supportA(AppInfo.name)),
    ];
    return InfoPage(
      title: l10n.authFooter_faq,
      children: [
        for (final (question, answer) in items)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: InfoPageMetrics.itemGap),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            shape: Border(bottom: BorderSide(color: context.colors.divider)),
            collapsedShape: Border(bottom: BorderSide(color: context.colors.divider)),
            iconColor: context.colors.primary,
            collapsedIconColor: context.colors.textMuted,
            title: Text(question, style: InfoPageText.question(context)),
            children: [Text(answer, style: InfoPageText.body(context))],
          ),
      ],
    );
  }
}
