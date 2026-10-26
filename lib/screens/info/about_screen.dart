import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../l10n/l10n.dart';
import '../../models/support_contact.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../widgets/hover_link.dart';
import '../../widgets/support_contact_dialog.dart';
import 'info_page.dart';

/// About {appName} (G4), opened from the sign-in footer. Every sentence is
/// proved in docs/design/footer_pages_content.md; the owner edits the
/// English in the ARB.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.contact});

  /// The footer's single read of app_config/support_contact, for the
  /// Help and contact link.
  final Future<SupportContact> contact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InfoPage(
      title: l10n.authFooter_about(AppInfo.name),
      children: [
        InfoParagraph(l10n.about_intro(AppInfo.name)),
        InfoParagraph(l10n.about_whoFor),
        InfoHeading(l10n.about_coversTitle),
        for (final area in [
          l10n.about_coverSales,
          l10n.about_coverStock,
          l10n.about_coverServices,
          l10n.about_coverClients,
          l10n.about_coverPayments,
          l10n.about_coverReports,
          l10n.about_coverTeam,
        ])
          _Bullet(area),
        const SizedBox(height: InfoPageMetrics.sectionGap),
        InfoParagraph(l10n.about_whoBuilds(AppInfo.name)),
        InfoParagraph(l10n.about_yourData),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: InfoPageMetrics.itemGap,
          children: [
            Text(l10n.about_questions, style: InfoPageText.body(context)),
            HoverLink(
              label: l10n.authFooter_helpContact,
              button: true,
              style: InfoPageText.body(context),
              onTap: () => showSupportContactDialog(context, contact: contact),
            ),
          ],
        ),
      ],
    );
  }
}

/// One area in the "What it covers" list.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = InfoPageText.body(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: InfoPageMetrics.itemGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The register page's benefit mark, centred on the first line.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Icon(Icons.check_circle_outline, size: AppIconSize.i18, color: context.colors.primary),
          ),
          const SizedBox(width: InfoPageMetrics.itemGap),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
