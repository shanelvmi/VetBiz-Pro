import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../config/app_links.dart';
import '../l10n/l10n.dart';
import '../models/support_contact.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import '../ui/feedback/app_feedback.dart';

/// The Help dialog: the dashboard's Help button and the sign-in footer's
/// "Help and contact" both open this one, so they always show the same rows.
///
/// Reads whatever Platform Admin has filled in under Branding >
/// Contact Details - each field is optional, so this only shows rows
/// for what's actually set, and falls back to the original generic
/// message if none of the four have been configured yet. [contact] is a
/// read already made (the footer reads once per page); without it the
/// document is read now ([firestore], or the default instance).
Future<void> showSupportContactDialog(
  BuildContext context, {
  Future<SupportContact>? contact,
  FirebaseFirestore? firestore,
}) async {
  // A failed fetch gives an empty contact (SupportContact.load), so the
  // generic message still shows - it shouldn't block someone from at
  // least seeing that dialog.
  final details = await (contact ?? SupportContact.load(firestore));
  final email = details.email;
  final phone = details.phone;
  final whatsapp = details.whatsapp;
  final address = details.address;

  if (!context.mounted) return;

  Future<void> launch(Uri uri, String failureMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppFeedback.info(failureMessage);
    }
  }

  // Clickable rows (email/phone/WhatsApp) get a tinted, rounded
  // background and a trailing chevron so they visually read as
  // tappable - the plain address row below has neither, so the one
  // row with nothing to tap doesn't invite a tap.
  Widget contactRow({
    required IconData icon,
    required String label,
    String? sublabel,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: AppFontSize.f13_5)),
              if (sublabel != null)
                Text(sublabel, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
            ],
          ),
        ),
        if (onTap != null) Icon(Icons.chevron_right, size: AppIconSize.i18, color: context.colors.textDisabled),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s4),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Material(
        color: context.colors.primary.withValues(alpha: AppAlpha.a05),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s8),
            child: row,
          ),
        ),
      ),
    );
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      title: Text(context.l10n.dashboard_contactSupport),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always shown, regardless of whether any contact
            // details are configured - the statement itself already
            // names Platform Admin explicitly.
            Text(context.l10n.dashboard_supportIntro(AppInfo.name),
                style: const TextStyle(fontSize: AppFontSize.f13_5)),
            if (email.isNotEmpty || phone.isNotEmpty || whatsapp.isNotEmpty || address.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s10),
              if (email.isNotEmpty)
                contactRow(
                  icon: Icons.email_outlined,
                  label: email,
                  onTap: () {
                    Navigator.pop(ctx);
                    launch(AppLinks.mailto(email), context.l10n.dashboard_emailAppFailed);
                  },
                ),
              if (phone.isNotEmpty)
                contactRow(
                  icon: Icons.call_outlined,
                  label: phone,
                  onTap: () {
                    Navigator.pop(ctx);
                    launch(AppLinks.tel(phone), context.l10n.common_dialerFailed);
                  },
                ),
              if (whatsapp.isNotEmpty)
                contactRow(
                  icon: Icons.chat_outlined,
                  label: whatsapp,
                  sublabel: context.l10n.debtors_viaWhatsApp,
                  onTap: () {
                    Navigator.pop(ctx);
                    launch(AppLinks.whatsApp(whatsapp), context.l10n.debtors_whatsAppFailed);
                  },
                ),
              if (address.isNotEmpty)
                contactRow(icon: Icons.location_on_outlined, label: address),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_close)),
      ],
    ),
  );
}
