import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_limits.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../utils/poster_image_check.dart';

/// The poster part of the Announcements form (AN1): a 16:9 preview of the
/// picked (or saved) image, an optional safe-zone overlay, and the picker.
/// A picked file goes through [PosterImageCheck] first; a refused one shows
/// its sentence here and never reaches the form. English: the operator
/// console is (spec 2.8).
class PosterPickerField extends StatefulWidget {
  const PosterPickerField({super.key, required this.picked, required this.onPicked, this.savedUrl, this.error, this.pick});

  /// A newly picked image, shown before [savedUrl].
  final PosterImage? picked;
  final ValueChanged<PosterImage> onPicked;

  /// The image already saved with the announcement being edited.
  final String? savedUrl;

  /// The form's own error (no image chosen).
  final String? error;

  /// Tests: returns the picked bytes instead of opening the gallery.
  final Future<Uint8List?> Function()? pick;

  static const safeZoneKey = Key('posterSafeZone');

  /// "16:9, 1600 x 900 px, JPG or WebP, under 1 MB", from the limits.
  static String get hint =>
      '16:9, ${AppLimits.posterImageMaxSide.round()} x ${(AppLimits.posterImageMaxSide / AppLimits.posterAspectRatio).round()} px, '
      'JPG or WebP, under ${AppLimits.posterMaxBytes ~/ (1024 * 1024)} MB';

  @override
  State<PosterPickerField> createState() => _PosterPickerFieldState();
}

class _PosterPickerFieldState extends State<PosterPickerField> {
  bool _showSafeZone = false;
  bool _checking = false;
  String? _checkError;

  Future<Uint8List?> _pickBytes() async {
    if (widget.pick != null) return widget.pick!();
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: AppLimits.posterImageMaxSide,
      // A 16:9 poster is held by its width; the height bound only scales
      // a portrait image, which the ratio check then refuses.
      maxHeight: AppLimits.posterImageMaxSide,
      imageQuality: AppLimits.pickedImageQuality,
    );
    return file?.readAsBytes();
  }

  Future<void> _choose() async {
    final bytes = await _pickBytes();
    if (bytes == null || !mounted) return;
    setState(() => _checking = true);
    final result = await PosterImageCheck.inspect(bytes);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checkError = result.error;
    });
    if (result.image != null) widget.onPicked(result.image!);
  }

  Widget _image() {
    final picked = widget.picked;
    if (picked != null) return Image.memory(picked.bytes, fit: BoxFit.cover);
    final url = widget.savedUrl;
    if (url != null) return Image.network(url, fit: BoxFit.cover);
    return Center(child: Icon(Icons.image_outlined, size: AppIconSize.i40, color: context.colors.textHint));
  }

  @override
  Widget build(BuildContext context) {
    final error = _checkError ?? widget.error;
    final hasImage = widget.picked != null || widget.savedUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Poster image', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
        const SizedBox(height: AppSpacing.s4),
        Text(PosterPickerField.hint, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.s8),
        AspectRatio(
          aspectRatio: AppLimits.posterAspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: error != null ? context.colors.danger : context.colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(),
                if (_showSafeZone)
                  Center(
                    child: FractionallySizedBox(
                      key: PosterPickerField.safeZoneKey,
                      widthFactor: AppLimits.posterSafeWidth,
                      heightFactor: AppLimits.posterSafeHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: context.colors.accent, width: 2)),
                      ),
                    ),
                  ),
                if (_checking) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.s6),
          Text(error, style: TextStyle(color: context.colors.danger, fontSize: AppFontSize.f12)),
        ],
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _checking ? null : _choose,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? 'Change image' : 'Choose image'),
            ),
            InkWell(
              onTap: () => setState(() => _showSafeZone = !_showSafeZone),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: _showSafeZone, onChanged: (v) => setState(() => _showSafeZone = v ?? false)),
                  const Text('Show safe zone'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
