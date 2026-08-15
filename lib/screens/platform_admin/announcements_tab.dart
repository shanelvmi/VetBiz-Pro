import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  static const List<Map<String, dynamic>> _colorOptions = [
    {'name': 'Default', 'value': null},
    {'name': 'Red', 'value': 0xFFD32F2F},
    {'name': 'Amber', 'value': 0xFFFFB200},
    {'name': 'Green', 'value': 0xFF2E7D32},
    {'name': 'Blue', 'value': 0xFF1565C0},
  ];

  Future<void> _createAnnouncement(BuildContext context) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool bold = false;
    bool italic = false;
    bool uppercase = false;
    bool urgent = false;
    int? colorValue;

    final screenWidth = MediaQuery.of(context).size.width;
    // Comfortably wide on desktop, but never wider than the actual
    // screen on a phone - AlertDialog otherwise defaults to a fairly
    // narrow, cramped width regardless of how much room is available.
    final dialogWidth = screenWidth > 700 ? 560.0 : screenWidth * 0.9;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final previewStyle = TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: colorValue != null ? Color(colorValue!) : null,
        );

        return AlertDialog(
          title: const Text('New Announcement'),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 3,
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
                const SizedBox(height: 12),
                const Text('Message Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Bold'),
                      selected: bold,
                      onSelected: (v) => setDialogState(() => bold = v),
                    ),
                    FilterChip(
                      label: const Text('Italic'),
                      selected: italic,
                      onSelected: (v) => setDialogState(() => italic = v),
                    ),
                    FilterChip(
                      label: const Text('UPPERCASE'),
                      selected: uppercase,
                      onSelected: (v) => setDialogState(() => uppercase = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _colorOptions.map((opt) {
                    final isSelected = colorValue == opt['value'];
                    final swatchColor = opt['value'] != null ? Color(opt['value'] as int) : Colors.grey.shade400;
                    return GestureDetector(
                      onTap: () => setDialogState(() => colorValue = opt['value'] as int?),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: opt['value'] != null ? swatchColor : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade400,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: opt['value'] == null
                            ? Icon(Icons.format_color_reset, size: 16, color: Colors.grey.shade600)
                            : null,
                      ),
                    );
                  }).toList(),
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
                  child: Text(
                    messageController.text.isEmpty
                        ? 'Message preview appears here'
                        : (uppercase ? messageController.text.toUpperCase() : messageController.text),
                    style: previewStyle,
                  ),
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return primaryColor;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Publish'),
            ),
          ],
        );
      }),
    );

    if (confirmed != true) return;
    if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('public_announcements').add({
      'title': titleController.text.trim(),
      'message': messageController.text.trim(),
      // Was previously written as 'createdAt', but the login screen
      // queries and sorts by 'timestamp' - a genuine field-name mismatch
      // that meant an announcement published here likely never actually
      // appeared there at all (Firestore's orderBy excludes documents
      // missing the field it's sorting by).
      'timestamp': FieldValue.serverTimestamp(),
      'bold': bold,
      'italic': italic,
      'uppercase': uppercase,
      'color': colorValue,
      'urgent': urgent,
      'hidden': false,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement published'), backgroundColor: Colors.green),
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
                  'Shown in the center of the login screen for every facility. '
                  'Falls back to the default illustration if none is set.',
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
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAnnouncement(context),
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
              _buildPosterSection(),
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
                      final isBold = data['bold'] == true;
                      final isItalic = data['italic'] == true;
                      final isUppercase = data['uppercase'] == true;
                      final isHidden = data['hidden'] == true;
                      final isUrgent = data['urgent'] == true;
                      final colorValue = data['color'] as int?;
                      final messageText = (data['message'] ?? '').toString();
                      final messageStyle = TextStyle(
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                        color: colorValue != null ? Color(colorValue) : null,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isHidden ? Colors.grey.shade100 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                    Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      isUppercase ? messageText.toUpperCase() : messageText,
                                      style: messageStyle,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isHidden ? Colors.grey : primaryColor,
                                    ),
                                    tooltip: isHidden ? 'Show again' : 'Stop showing for now',
                                    onPressed: () => _toggleHidden(doc.id, isHidden),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.priority_high,
                                      color: isUrgent ? Colors.red : Colors.grey,
                                    ),
                                    tooltip: isUrgent ? 'Unmark as urgent' : 'Mark as urgent',
                                    onPressed: () => _toggleUrgent(doc.id, isUrgent),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _delete(doc.id),
                                  ),
                                  if (ts != null)
                                    Text(DateFormat('dd MMM').format(ts), style: const TextStyle(fontSize: 10)),
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
