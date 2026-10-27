import 'package:flutter/material.dart';

import '../data/announcement_fields.dart';
import '../l10n/l10n.dart';
import '../services/announcement_service.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'announcement_message.dart';
import 'updates_parts.dart';

/// One slide, filling the Updates frame (the caller gives it the 16:9 box
/// and the corner). A poster is its image (BoxFit.cover) over a skeleton of
/// the same shape, or a neutral panel with its title if the image fails. A
/// text slide is a calm panel with the title and message centred.
class UpdateSlide extends StatelessWidget {
  const UpdateSlide({super.key, required this.announcement, required this.isNew, required this.image});

  final Announcement announcement;
  final bool isNew;

  /// The poster's image; null for a text slide or a poster without one.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (announcement.kind != AnnouncementKind.poster) return _TextPanel(announcement: announcement, isNew: isNew);
    if (image == null) return _TitlePanel(title: announcement.title);
    return Image(
      image: image,
      fit: BoxFit.cover,
      semanticLabel: announcement.title,
      // AN6: a poster already in the cache (warmed by UpdatesStore) shows at
      // once; one still loading fades in over its placeholder when decoded
      // (no fade under reduced motion).
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.colors.surfaceMuted),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.normal,
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, error, stack) => _TitlePanel(title: announcement.title),
    );
  }
}

class _TitlePanel extends StatelessWidget {
  const _TitlePanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceMuted,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold, color: context.colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// The title (two lines at most) and as many lines of the message as fit,
/// centred; when anything is cut, Read more opens the whole announcement.
class _TextPanel extends StatelessWidget {
  const _TextPanel({required this.announcement, required this.isNew});

  final Announcement announcement;
  final bool isNew;

  static const int _titleLines = 2;
  static const double _pad = AppSpacing.s16;
  static const double _gap = AppSpacing.s6;
  static const double _chipRow = AppSpacing.s24;

  void _readMore(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(announcement.title),
            content: SizedBox(
              width: AppSizes.dialogSm,
              child: SingleChildScrollView(child: AnnouncementMessage(data: {AnnouncementFields.message: announcement.message})),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.l10n.common_close))],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = announcement.urgent || isNew;
    // Measured with the style the Text really gets (the theme's line
    // height included), so the lines that fit are the lines drawn.
    final base = DefaultTextStyle.of(context).style;
    final titleStyle = base.merge(
      TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold, color: context.colors.primary),
    );
    final messageStyle = base.merge(TextStyle(fontSize: AppFontSize.f13, color: context.colors.textSecondary));
    final message = AnnouncementMessage.plainText(announcement.message);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return ColoredBox(
      color: context.colors.primary.withValues(alpha: AppAlpha.a10),
      child: LayoutBuilder(
        builder: (context, box) {
          // The chips' row is kept free above AND below, so the text stays
          // centred in the whole frame.
          final reserve = hasChips ? _chipRow : 0.0;
          final width = box.maxWidth - 2 * _pad;
          TextPainter painter(String text, TextStyle style, [int? lines]) =>
              TextPainter(text: TextSpan(text: text, style: style), maxLines: lines, textDirection: direction, textScaler: scaler)
                ..layout(maxWidth: width);

          final title = painter(announcement.title, titleStyle, _titleLines);
          final full = painter(message, messageStyle);
          final lineHeight = full.preferredLineHeight;
          final room = box.maxHeight - 2 * (_pad + reserve) - title.height;
          final allLines = message.isEmpty ? 0 : full.computeLineMetrics().length;
          final fitsWhole = !title.didExceedMaxLines && allLines * lineHeight + (allLines > 0 ? _gap : 0) <= room;
          // With Read more: its own fixed-height line, and as many message
          // lines as remain above it.
          final readMoreHeight = lineHeight + AppSpacing.s8;
          final lines =
              fitsWhole ? allLines : ((room - 2 * _gap - readMoreHeight) / lineHeight).floor().clamp(0, allLines).toInt();
          title.dispose();
          full.dispose();

          return Stack(
            children: [
              if (hasChips)
                Positioned(
                  top: _pad,
                  left: _pad,
                  child: Row(
                    children: [
                      if (announcement.urgent) const UpdateChip.important(),
                      if (announcement.urgent && isNew) const SizedBox(width: AppSpacing.s6),
                      if (isNew) const UpdateChip.fresh(),
                    ],
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _pad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        announcement.title,
                        textAlign: TextAlign.center,
                        maxLines: _titleLines,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      if (lines > 0) ...[
                        const SizedBox(height: _gap),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          maxLines: lines,
                          overflow: TextOverflow.ellipsis,
                          style: messageStyle,
                        ),
                      ],
                      if (!fitsWhole) ...[
                        const SizedBox(height: _gap),
                        SizedBox(
                          height: readMoreHeight,
                          child: TextButton(
                            onPressed: () => _readMore(context),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: messageStyle.copyWith(fontWeight: AppFontWeight.bold),
                            ),
                            child: Text(context.l10n.updates_readMore),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
