import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_limits.dart';
import '../data/announcement_fields.dart';
import '../l10n/l10n.dart';
import '../services/announcement_service.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_context.dart';
import '../ui/feedback/app_feedback.dart';
import '../utils/social_link.dart';
import 'announcement_message.dart';
import 'auth_footer.dart';
import 'update_slide.dart';

/// A poster's image from its URL: NetworkImage in the app, a fake in tests.
typedef PosterImageFor = ImageProvider Function(String url);

ImageProvider _network(String url) => NetworkImage(url);

/// An announcement's optional button (AN2, AN3): its label, opening its
/// address outside the app, and only when that address passes SocialLink
/// (http or https with a host). Nothing at all otherwise.
class AnnouncementLinkButton extends StatelessWidget {
  const AnnouncementLinkButton({super.key, required this.announcement, this.launcher = launchUrl});

  final Announcement announcement;
  final AuthFooterLauncher launcher;

  /// The address to open, or null when there is no safe one with a label.
  static String? addressOf(Announcement a) {
    final address = SocialLink.sanitize(a.linkUrl);
    return address == null || address.isEmpty || a.linkLabel.trim().isEmpty ? null : address;
  }

  Future<void> _open(String address) async {
    final uri = Uri.parse(address);
    // Checked again here: only http and https ever leave the app.
    if (!SocialLink.isLaunchable(uri)) return;
    final opened = await launcher(uri, mode: LaunchMode.externalApplication);
    if (!opened) AppFeedback.info(L10n.current.common_linkFailed);
  }

  @override
  Widget build(BuildContext context) {
    final address = addressOf(announcement);
    if (address == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => _open(address),
      icon: const Icon(Icons.open_in_new, size: AppIconSize.i16),
      label: Text(announcement.linkLabel.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// A poster's 16:9 thumbnail, [AppSizes.posterThumbnail] wide, for a row:
/// a skeleton while it loads, a neutral panel if it fails.
class AnnouncementThumbnail extends StatelessWidget {
  const AnnouncementThumbnail({super.key, required this.announcement, this.imageFor});

  final Announcement announcement;
  final PosterImageFor? imageFor;

  static const fallbackKey = Key('posterThumbnailFallback');

  @override
  Widget build(BuildContext context) {
    final url = announcement.imageUrl;
    final fallback = ColoredBox(
      key: fallbackKey,
      color: context.colors.surfaceMuted,
      child: Icon(Icons.image_outlined, size: AppIconSize.i16, color: context.colors.textHint),
    );
    return SizedBox(
      width: AppSizes.posterThumbnail,
      child: AspectRatio(
        aspectRatio: AppLimits.posterAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          child: url == null
              ? fallback
              : Image(
                  image: (imageFor ?? _network)(url),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, sync) =>
                      frame == null && !sync ? ColoredBox(color: context.colors.surfaceMuted) : child,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}

/// The whole poster: the same 16:9 frame and slide as the login page's
/// Updates (skeleton, and the title on a neutral panel if the image fails),
/// then its message and its link button.
class AnnouncementPosterView extends StatelessWidget {
  const AnnouncementPosterView({super.key, required this.announcement, this.imageFor, this.launcher = launchUrl});

  final Announcement announcement;
  final PosterImageFor? imageFor;
  final AuthFooterLauncher launcher;

  static const frameKey = Key('announcementPosterFrame');

  @override
  Widget build(BuildContext context) {
    final url = announcement.imageUrl;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            key: frameKey,
            aspectRatio: AppLimits.posterAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r12),
              child: UpdateSlide(
                announcement: announcement,
                isNew: false,
                image: url == null ? null : (imageFor ?? _network)(url),
              ),
            ),
          ),
          if (announcement.message.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            AnnouncementMessage(data: {AnnouncementFields.message: announcement.message}),
          ],
          if (AnnouncementLinkButton.addressOf(announcement) != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnnouncementLinkButton(announcement: announcement, launcher: launcher),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens [announcement]'s poster full size in a dialog, with Close.
Future<void> showAnnouncementPoster(
  BuildContext context,
  Announcement announcement, {
  PosterImageFor? imageFor,
  AuthFooterLauncher launcher = launchUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(announcement.title),
      content: SizedBox(
        width: AppSizes.dialogLg,
        child: AnnouncementPosterView(announcement: announcement, imageFor: imageFor, launcher: launcher),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.common_close)),
      ],
    ),
  );
}
