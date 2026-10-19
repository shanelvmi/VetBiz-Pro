import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:markdown/markdown.dart' as md;

import '../../widgets/hover_elevate_card.dart';
import '../../widgets/announcement_message.dart';
import '../../data/collections.dart';
import '../../data/upload_content_types.dart';
import '../../data/fields.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../ui/feedback/friendly_error.dart';

/// Manages everything shown on the login screen's left/center panels -
/// broadcast announcements (the `public_announcements` collection) and
/// the poster image, both from one place instead of one being editable
/// here and the other being a file baked into the app itself.
class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  // Space under the announcements list so the floating "New Announcement"
  // button does not cover the last card. A size (above the spacing
  // ladder), kept exact.
  static const double _fabClearance = 80;

  bool _isUploadingPoster = false;

  // A curated, modern spread across the hue spectrum plus neutrals -
  // genuinely more choice than the previous 5 swatches, without the
  // complexity/risk of a full canvas-based hue-wheel picker. Stored as
  // hex strings rather than Color objects since only hex-to-Color
  // construction is needed (safe, standard) - never Color-to-hex,
  // which has had breaking API changes across Flutter versions.
  static const List<String> _colorPalette = [
    '#D32F2F', '#E64A19', '#F57C00', '#FFB200',
    '#FBC02D', '#AFB42B', '#689F38', '#2E7D32',
    '#00897B', '#00ACC1', '#0288D1', '#1565C0',
    '#3949AB', '#5E35B1', '#8E24AA', '#D81B60',
    '#6D4C41', '#616161', '#37474F', '#000000',
  ];

  // Wraps the current text selection in markdown syntax (prefix+suffix),
  // or inserts an empty prefix+suffix pair at the cursor with the
  // cursor placed between them if nothing's selected - the standard
  // "click Bold, type, it's bold" behavior of a real toolbar, rather
  // than requiring the Admin to type ** or _ manually.
  void _wrapSelection(
    TextEditingController controller,
    String prefix,
    String suffix,
    void Function(void Function()) setDialogState,
  ) {
    final selection = controller.selection;
    final text = controller.text;

    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.isValid ? selection.baseOffset : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      setDialogState(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor + prefix.length),
        );
      });
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selectedText = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
    setDialogState(() {
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    });
  }

  // Prompts for link text (pre-filled from the current selection, if
  // any) and a URL, then inserts [link text](url) at the right spot -
  // replacing the selection if there was one, otherwise at the cursor.
  Future<void> _insertLink(
    BuildContext dialogContext,
    TextEditingController controller,
    void Function(void Function()) setDialogState,
  ) async {
    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final selectedText = hasSelection ? controller.text.substring(selection.start, selection.end) : '';

    final linkTextController = TextEditingController(text: selectedText);
    final urlController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (linkDialogContext) => AlertDialog(
        title: const Text('Insert Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: linkTextController,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [SentenceCapitalizationFormatter()],
              decoration: const InputDecoration(labelText: 'Link text'),
            ),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL', hintText: 'https://...'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(linkDialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(linkDialogContext, true), child: const Text('Insert')),
        ],
      ),
    );

    if (confirmed != true) return;
    final linkText = linkTextController.text.trim();
    final url = urlController.text.trim();
    if (linkText.isEmpty || url.isEmpty) return;

    final markdownLink = '[$linkText]($url)';
    final text = controller.text;

    if (hasSelection) {
      final newText = text.replaceRange(selection.start, selection.end, markdownLink);
      setDialogState(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + markdownLink.length),
        );
      });
    } else {
      final cursor = selection.isValid ? selection.baseOffset : text.length;
      final newText = text.replaceRange(cursor, cursor, markdownLink);
      setDialogState(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor + markdownLink.length),
        );
      });
    }
  }

  // Opens a palette of curated colors, then wraps the current
  // selection (or inserts at the cursor if nothing's selected) in the
  // custom {color:#hex}...{/color} syntax - same selection-wrapping
  // pattern as bold/italic/link, so all four toolbar buttons behave
  // consistently.
  Future<void> _pickColor(
    BuildContext dialogContext,
    TextEditingController controller,
    void Function(void Function()) setDialogState,
  ) async {
    final chosenHex = await showDialog<String>(
      context: dialogContext,
      builder: (colorDialogContext) => AlertDialog(
        title: const Text('Choose a Color'),
        content: SizedBox(
          width: 260,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorPalette.map((hex) {
              return GestureDetector(
                onTap: () => Navigator.pop(colorDialogContext, hex),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.borderStrong),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(colorDialogContext), child: const Text('Cancel')),
        ],
      ),
    );

    if (chosenHex == null) return;

    final selection = controller.selection;
    final text = controller.text;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final wrapped = '{color:$chosenHex}$selectedText{/color}';
      final newText = text.replaceRange(selection.start, selection.end, wrapped);
      setDialogState(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + wrapped.length),
        );
      });
    } else {
      final cursor = selection.isValid ? selection.baseOffset : text.length;
      final openTag = '{color:$chosenHex}';
      final wrapped = '$openTag{/color}';
      final newText = text.replaceRange(cursor, cursor, wrapped);
      setDialogState(() {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor + openTag.length),
        );
      });
    }
  }

  // Handles both creating a new announcement and editing an existing
  // one - existingDoc null means create, provided means edit (title/
  // message/urgent pre-filled from it, saving updates that document
  // instead of adding a new one).
  Future<void> _showAnnouncementDialog(BuildContext context, {DocumentSnapshot? existingDoc}) async {
    final isEditing = existingDoc != null;
    final existingData = existingDoc?.data() as Map<String, dynamic>?;

    final titleController = TextEditingController(text: existingData?['title'] as String? ?? '');
    final messageController = TextEditingController(text: existingData?['message'] as String? ?? '');
    bool urgent = existingData?['urgent'] == true;
    // Shown inline in the dialog rather than closing it silently -
    // previously, publishing with an empty title or message just
    // closed the dialog with no feedback at all, leaving no way to
    // tell why nothing happened.
    String? validationError;

    final screenWidth = MediaQuery.of(context).size.width;
    // Comfortably wide on desktop, but never wider than the actual
    // screen on a phone - AlertDialog otherwise defaults to a fairly
    // narrow, cramped width regardless of how much room is available.
    final dialogWidth = screenWidth > AppBreakpoints.dialogFixedWidth ? AppSizes.dialogLg : screenWidth * 0.9;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (validationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: context.colors.danger.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(color: context.colors.danger.withValues(alpha: AppAlpha.a40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: context.colors.danger, size: AppIconSize.i18),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(validationError!, style: TextStyle(color: context.colors.danger, fontSize: AppFontSize.f13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
                TextField(controller: titleController, textCapitalization: TextCapitalization.sentences, inputFormatters: [SentenceCapitalizationFormatter()], decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: AppSpacing.s8),
                // Formatting toolbar - select text in the message field
                // below, then tap one of these to wrap the selection in
                // the matching markdown syntax (or, with nothing
                // selected, insert it at the cursor to type inside).
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.format_bold),
                      tooltip: 'Bold',
                      onPressed: () => _wrapSelection(messageController, '**', '**', setDialogState),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_italic),
                      tooltip: 'Italic',
                      onPressed: () => _wrapSelection(messageController, '_', '_', setDialogState),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link),
                      tooltip: 'Insert link',
                      onPressed: () => _insertLink(context, messageController, setDialogState),
                    ),
                    IconButton(
                      icon: const Icon(Icons.palette_outlined),
                      tooltip: 'Text color',
                      onPressed: () => _pickColor(context, messageController, setDialogState),
                    ),
                  ],
                ),
                TextField(
                  controller: messageController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: urgent ? context.colors.danger.withValues(alpha: AppAlpha.a10) : context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    border: Border.all(color: urgent ? context.colors.danger.withValues(alpha: AppAlpha.a40) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, color: urgent ? context.colors.danger : context.colors.textHint, size: AppIconSize.i20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mark as Urgent', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
                            Text(
                              'While an urgent announcement is active, every other announcement is automatically paused - only urgent ones show, everywhere.',
                              style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textSoft),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: urgent,
                        activeThumbColor: context.colors.danger,
                        onChanged: (v) => setDialogState(() => urgent = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                const Text('Preview', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
                const SizedBox(height: AppSpacing.s6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: messageController.text.isEmpty
                      ? Text('Message preview appears here', style: TextStyle(color: context.colors.textMuted))
                      : MarkdownBody(
                          data: messageController.text,
                          extensionSet: md.ExtensionSet(
                            md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                            [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, ColorSyntax()],
                          ),
                          builders: {'coloredspan': ColorBuilder()},
                        ),
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                  setDialogState(() => validationError = 'Both a title and a message are required.');
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: Text(isEditing ? 'Save' : 'Publish'),
            ),
          ],
        );
      }),
    );

    if (confirmed != true) return;

    if (isEditing) {
      await existingDoc.reference.update({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'urgent': urgent,
        // hidden status untouched - editing content is a separate
        // action from showing/hiding it, shouldn't silently change
        // together.
      });
    } else {
      await FirebaseFirestore.instance.collection(Collections.publicAnnouncements).add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        // Was previously written as 'createdAt', but the login screen
        // queries and sorts by 'timestamp' - a genuine field-name mismatch
        // that meant an announcement published here likely never actually
        // appeared there at all (Firestore's orderBy excludes documents
        // missing the field it's sorting by).
        'timestamp': FieldValue.serverTimestamp(),
        // All formatting - bold, italic, links, and color - is inline
        // within the message itself via markdown syntax, applied
        // through the toolbar above. No separate whole-message flags.
        'urgent': urgent,
        'hidden': false,
      });
    }

    AppFeedback.success(isEditing ? 'Announcement updated' : 'Announcement published');
  }

  Future<void> _delete(String docId) async {
    await FirebaseFirestore.instance.collection(Collections.publicAnnouncements).doc(docId).delete();
  }

  Future<void> _toggleHidden(String docId, bool currentlyHidden) async {
    await FirebaseFirestore.instance
        .collection(Collections.publicAnnouncements)
        .doc(docId)
        .update({'hidden': !currentlyHidden});
  }

  Future<void> _toggleUrgent(String docId, bool currentlyUrgent) async {
    await FirebaseFirestore.instance
        .collection(Collections.publicAnnouncements)
        .doc(docId)
        .update({'urgent': !currentlyUrgent});
  }

  Future<void> _uploadPoster() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _isUploadingPoster = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('login_poster/poster.jpg');
      await ref.putData(bytes, UploadContentTypes.jpeg);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection(Collections.appConfig).doc('login_poster').set({
        'posterUrl': url,
        Fields.updatedAt: FieldValue.serverTimestamp(),
      });

      AppFeedback.success('Background image updated');
    } catch (e, st) {
      AppFeedback.error("Couldn't upload the background image", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isUploadingPoster = false);
    }
  }

  Future<void> _removePoster() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Background Image?'),
        content: const Text('The login screen will fall back to its default background image.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.danger, foregroundColor: context.colors.onPrimary),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection(Collections.appConfig).doc('login_poster').delete();
    AppFeedback.success('Background image removed');
  }

  Widget _buildPosterSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(Collections.appConfig).doc('login_poster').snapshots(),
      builder: (context, snapshot) {
        final posterUrl = snapshot.data?.data() != null
            ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
            : null;

        return Card(
          margin: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, AppSpacing.s4),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Background Image', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Shown as the full background of the login screen for every facility. '
                      'Falls back to the default background image if none is set.',
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    if (posterUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        child: Image.network(
                          posterUrl,
                          height: 140,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 140,
                            child: Center(child: Text('Could not load current background image')),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                        child: Text('No background image set - using default background', style: TextStyle(color: context.colors.textMuted)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingPoster ? null : _uploadPoster,
                      icon: _isUploadingPoster
                          ? SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                          : const Icon(Icons.upload),
                      label: Text(posterUrl != null ? 'Replace Background Image' : 'Upload Background Image'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return context.colors.accent;
                          return context.colors.primary;
                        }),
                        foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                      ),
                    ),
                    if (posterUrl != null) ...[
                      const SizedBox(width: AppSpacing.s8),
                      TextButton(
                        onPressed: _removePoster,
                        style: TextButton.styleFrom(foregroundColor: context.colors.danger),
                        child: const Text('Remove'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAnnouncementDialog(context),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        hoverColor: context.colors.accent,
        icon: const Icon(Icons.campaign),
        label: const Text('New Announcement'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(Collections.publicAnnouncements)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load announcements: ${FriendlyError.messageFor(snapshot.error!)}'));
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.s12, 0, _fabClearance),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < AppBreakpoints.stackSections) {
                    return Column(
                      children: [_buildPosterSection(), const _ContactDetailsCard()],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildPosterSection()),
                        const Expanded(child: _ContactDetailsCard()),
                      ],
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s16, AppSpacing.s12, AppSpacing.s4),
                child: Text('Announcements', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              ),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Center(child: Text('No announcements yet.', style: TextStyle(color: context.colors.textMuted))),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : null;
                      final isHidden = data['hidden'] == true;
                      final isUrgent = data['urgent'] == true;

                      final statusColor = isUrgent ? context.colors.danger : (isHidden ? context.colors.textHint : context.colors.primary);

                      return HoverElevateCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                        color: isHidden ? context.colors.surfaceMuted : context.colors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: AppAlpha.a15),
                                    child: Icon(Icons.campaign_outlined, color: statusColor, size: AppIconSize.i20),
                                  ),
                                  const SizedBox(width: AppSpacing.s10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isUrgent || isHidden)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                                            child: Wrap(
                                              spacing: 6,
                                              children: [
                                                if (isUrgent)
                                                  Chip(
                                                    label: Text('URGENT', style: TextStyle(fontSize: AppFontSize.f10, color: context.colors.onPrimary)),
                                                    backgroundColor: context.colors.danger,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                if (isHidden)
                                                  Chip(
                                                    label: const Text('Hidden', style: TextStyle(fontSize: AppFontSize.f10)),
                                                    backgroundColor: context.colors.border,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        Text(data['title'] ?? '', style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                                        const SizedBox(height: AppSpacing.s4),
                                        AnnouncementMessage(data: data, fontSize: AppFontSize.f14),
                                        if (ts != null) ...[
                                          const SizedBox(height: AppSpacing.s6),
                                          Text(AppDateFormat.dateNoPad.format(ts), style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: AppIconSize.i20),
                                    tooltip: 'Edit',
                                    onPressed: () => _showAnnouncementDialog(context, existingDoc: doc),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isHidden ? context.colors.textHint : context.colors.primary,
                                      size: AppIconSize.i20,
                                    ),
                                    tooltip: isHidden ? 'Show again' : 'Stop showing for now',
                                    onPressed: () => _toggleHidden(doc.id, isHidden),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.priority_high,
                                      color: isUrgent ? context.colors.danger : context.colors.textHint,
                                      size: AppIconSize.i20,
                                    ),
                                    tooltip: isUrgent ? 'Unmark as urgent' : 'Mark as urgent',
                                    onPressed: () => _toggleUrgent(doc.id, isUrgent),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: context.colors.dangerAccent, size: AppIconSize.i20),
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(doc.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Contact Details card, split out as its own widget specifically so
/// its save button's spin-while-saving state stays scoped to just this
/// card. Living inside the main tab's State previously meant every
/// setState() here re-ran the *entire* tab's build() - including
/// recreating the background Image.network fresh each time, which
/// blanked out and reloaded visibly (the reported "full screen
/// blinking"). Isolated like this, saving only ever rebuilds this
/// card.
class _ContactDetailsCard extends StatefulWidget {
  const _ContactDetailsCard();

  @override
  State<_ContactDetailsCard> createState() => _ContactDetailsCardState();
}

class _ContactDetailsCardState extends State<_ContactDetailsCard> {

  // Loaded once on open (not a live StreamBuilder, since that would
  // fight with whatever the admin is actively typing), edited freely,
  // saved explicitly. All four are optional; the Dashboard help
  // dialog only ever needs at least one filled in.
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadContactDetails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadContactDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.appConfig).doc('support_contact').get();
      final data = doc.data();
      if (mounted && data != null) {
        _emailController.text = (data['email'] as String?) ?? '';
        _phoneController.text = (data['phone'] as String?) ?? '';
        _whatsappController.text = (data['whatsapp'] as String?) ?? '';
        _addressController.text = (data['address'] as String?) ?? '';
      }
    } catch (_) {
      // Leaves the fields blank rather than blocking the rest of the
      // page - the admin can still fill them in and save from scratch.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveContactDetails() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection(Collections.appConfig).doc('support_contact').set({
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'address': _addressController.text.trim(),
        Fields.updatedAt: FieldValue.serverTimestamp(),
      });
      AppFeedback.success('Contact details saved');
    } catch (e, st) {
      AppFeedback.error("Couldn't save the contact details", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, AppSpacing.s4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact Details', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Shown when someone taps Help on the Dashboard. All optional - '
              'at least one filled in is enough for the help dialog to have something to show.',
              style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone call',
                  prefixIcon: Icon(Icons.call_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  prefixIcon: Icon(Icons.chat_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _addressController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Physical address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveContactDetails,
                icon: _isSaving
                    ? SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Contact Details'),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return context.colors.accent;
                    return context.colors.primary;
                  }),
                  foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
