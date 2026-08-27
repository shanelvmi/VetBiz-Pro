import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../widgets/hover_elevate_card.dart';
import '../../widgets/announcement_message.dart';

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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  bool _isUploadingPoster = false;
  bool _isUploadingLoginLogo = false;

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
              decoration: const InputDecoration(labelText: 'Link text'),
            ),
            const SizedBox(height: 8),
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
                    border: Border.all(color: Colors.grey.shade400),
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
    final dialogWidth = screenWidth > 700 ? 560.0 : screenWidth * 0.9;

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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(validationError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
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
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: urgent ? Colors.red.withValues(alpha: 0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: urgent ? Colors.red.withValues(alpha: 0.4) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, color: urgent ? Colors.red : Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mark as Urgent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              'While an urgent announcement is active, every other announcement is automatically paused - only urgent ones show, everywhere.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: urgent,
                        activeColor: Colors.red,
                        onChanged: (v) => setDialogState(() => urgent = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: messageController.text.isEmpty
                      ? Text('Message preview appears here', style: TextStyle(color: Colors.grey[600]))
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
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryColor;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
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
      await FirebaseFirestore.instance.collection('public_announcements').add({
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Announcement updated' : 'Announcement published'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _delete(String docId) async {
    await FirebaseFirestore.instance.collection('public_announcements').doc(docId).delete();
  }

  Future<void> _toggleHidden(String docId, bool currentlyHidden) async {
    await FirebaseFirestore.instance
        .collection('public_announcements')
        .doc(docId)
        .update({'hidden': !currentlyHidden});
  }

  Future<void> _toggleUrgent(String docId, bool currentlyUrgent) async {
    await FirebaseFirestore.instance
        .collection('public_announcements')
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
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('app_config').doc('login_poster').set({
        'posterUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload poster: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPoster = false);
    }
  }

  Future<void> _removePoster() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Poster?'),
        content: const Text('The login screen will fall back to its default illustration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('app_config').doc('login_poster').delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poster removed'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildPosterSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('app_config').doc('login_poster').snapshots(),
      builder: (context, snapshot) {
        final posterUrl = snapshot.data?.data() != null
            ? (snapshot.data!.data() as Map<String, dynamic>)['posterUrl'] as String?
            : null;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Login Screen Poster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Shown on the login screen for wide/desktop screens.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (posterUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      posterUrl,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 140,
                        child: Center(child: Text('Could not load current poster')),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('No poster set - using default illustration', style: TextStyle(color: Colors.grey[600])),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingPoster ? null : _uploadPoster,
                      icon: _isUploadingPoster
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload),
                      label: Text(posterUrl != null ? 'Replace Poster' : 'Upload Poster'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return warmAmber;
                          return primaryColor;
                        }),
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ),
                    if (posterUrl != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _removePoster,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Future<void> _uploadLoginLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _isUploadingLoginLogo = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('login_logo/logo.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      // A separate document from login_poster, deliberately - not just
      // a second field on that same one. login_poster's own "Remove"
      // deletes the whole document, not just that one field; sharing a
      // document would mean removing the poster also silently wipes
      // out the logo, and vice versa if this ever grew its own
      // whole-document removal too.
      await FirebaseFirestore.instance.collection('app_config').doc('login_logo').set({
        'logoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload logo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLoginLogo = false);
    }
  }

  Future<void> _removeLoginLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Logo?'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: const Text('Phone screens will fall back to the default illustration.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('app_config').doc('login_logo').delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo removed'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildLoginLogoSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('app_config').doc('login_logo').snapshots(),
      builder: (context, snapshot) {
        final logoUrl = snapshot.data?.data() != null
            ? (snapshot.data!.data() as Map<String, dynamic>)['logoUrl'] as String?
            : null;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Login Screen Logo (Phone Screens)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Shown on narrow/phone screens instead of the poster above.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      logoUrl,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 140,
                        child: Center(child: Text('Could not load current logo')),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('No logo set - using default illustration', style: TextStyle(color: Colors.grey[600])),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploadingLoginLogo ? null : _uploadLoginLogo,
                      icon: _isUploadingLoginLogo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload),
                      label: Text(logoUrl != null ? 'Replace Logo' : 'Upload Logo'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return warmAmber;
                          return primaryColor;
                        }),
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ),
                    if (logoUrl != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _removeLoginLogo,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        hoverColor: warmAmber,
        icon: const Icon(Icons.campaign),
        label: const Text('New Announcement'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_announcements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load announcements: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 80),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 700) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildPosterSection()),
                          Expanded(child: _buildLoginLogoSection()),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      _buildPosterSection(),
                      _buildLoginLogoSection(),
                    ],
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
                child: Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No announcements yet.', style: TextStyle(color: Colors.grey[600]))),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : null;
                      final isHidden = data['hidden'] == true;
                      final isUrgent = data['urgent'] == true;

                      final statusColor = isUrgent ? Colors.red : (isHidden ? Colors.grey : primaryColor);

                      return HoverElevateCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isHidden ? Colors.grey.shade100 : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: statusColor.withValues(alpha: 0.15),
                                    child: Icon(Icons.campaign_outlined, color: statusColor, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isUrgent || isHidden)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Wrap(
                                              spacing: 6,
                                              children: [
                                                if (isUrgent)
                                                  const Chip(
                                                    label: Text('URGENT', style: TextStyle(fontSize: 10, color: Colors.white)),
                                                    backgroundColor: Colors.red,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                if (isHidden)
                                                  Chip(
                                                    label: const Text('Hidden', style: TextStyle(fontSize: 10)),
                                                    backgroundColor: Colors.grey.shade300,
                                                    visualDensity: VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        AnnouncementMessage(data: data, fontSize: 14),
                                        if (ts != null) ...[
                                          const SizedBox(height: 6),
                                          Text(DateFormat('d MMM yyyy').format(ts), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
                                    icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () => _showAnnouncementDialog(context, existingDoc: doc),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isHidden ? Colors.grey : primaryColor,
                                      size: 20,
                                    ),
                                    tooltip: isHidden ? 'Show again' : 'Stop showing for now',
                                    onPressed: () => _toggleHidden(doc.id, isHidden),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.priority_high,
                                      color: isUrgent ? Colors.red : Colors.grey,
                                      size: 20,
                                    ),
                                    tooltip: isUrgent ? 'Unmark as urgent' : 'Mark as urgent',
                                    onPressed: () => _toggleUrgent(doc.id, isUrgent),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
