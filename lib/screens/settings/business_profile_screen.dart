import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';
import '../../data/collections.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

/// A dedicated home for facility-level branding (currently just the
/// logo) - built for discoverability, since the drawer's own
/// tap-to-change logo is a convenient shortcut but an easy one to miss
/// entirely (nothing about a static logo image visually suggests it's
/// tappable, beyond a hover tooltip). Admin-only, matching what the
/// Firestore rules already enforce for facility document writes.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {

  final ImagePicker _picker = ImagePicker();
  Uint8List? _pendingLogoBytes;
  bool _isUploading = false;

  Future<void> _changeLogo() async {
    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facilityId = facilityProvider.selectedFacility?['id'];
    if (facilityId == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() {
      _pendingLogoBytes = bytes;
      _isUploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child('facility_logos/$facilityId.png');
      await storageRef.putData(bytes);
      final rawDownloadUrl = await storageRef.getDownloadURL();
      // Firebase Storage returns the same URL for repeat uploads to the
      // same path (the access token doesn't change just because the
      // file content did) - without a cache-busting parameter here,
      // NetworkImage's own cache (which keys purely on the URL string)
      // would keep showing the previous logo indefinitely, even though
      // Firestore has the correct, current URL the whole time. This is
      // exactly why the logo appeared to "not persist" - it was saving
      // correctly, it just wasn't being re-fetched.
      final downloadUrl = '$rawDownloadUrl&cb=${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .set({'logoUrl': downloadUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
        AppFeedback.success('Logo updated');
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _pendingLogoBytes = null;
        });
        AppFeedback.error("Couldn't update the logo", error: e, stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityName = selectedFacility?['name'] ?? 'Your facility';
    final logoUrl = selectedFacility?['logoUrl'];

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Business Profile'),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              children: [
                Text(facilityName, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
                const SizedBox(height: AppSpacing.s24),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: context.colors.divider,
                      backgroundImage: _pendingLogoBytes != null
                          ? MemoryImage(_pendingLogoBytes!)
                          : (logoUrl != null
                              ? NetworkImage(logoUrl)
                              : const AssetImage('assets/vetbiz_pro_logo.png') as ImageProvider),
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black38,
                          child: CircularProgressIndicator(color: context.colors.onPrimary),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s6),
                      decoration: BoxDecoration(
                        color: context.colors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.colors.background, width: 2),
                      ),
                      child: Icon(Icons.camera_alt, size: AppIconSize.i16, color: context.colors.onPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'This logo appears on the dashboard, receipts, and anywhere your facility is shown throughout the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13),
                ),
                const SizedBox(height: AppSpacing.s24),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _changeLogo,
                  icon: const Icon(Icons.upload),
                  label: Text(logoUrl != null ? 'Change Logo' : 'Upload Logo'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return context.colors.accent;
                      return context.colors.primary;
                    }),
                    foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
