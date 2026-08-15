import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/facility_provider.dart';

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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  static const Color backgroundColor = Color(0xFFFDFDF9);

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
          .collection('facilities')
          .doc(facilityId)
          .set({'logoUrl': downloadUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _pendingLogoBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update logo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityName = selectedFacility?['name'] as String? ?? 'Your facility';
    final logoUrl = selectedFacility?['logoUrl'] as String?;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Business Profile'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(facilityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 24),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _pendingLogoBytes != null
                          ? MemoryImage(_pendingLogoBytes!)
                          : (logoUrl != null
                              ? NetworkImage(logoUrl)
                              : const AssetImage('assets/vetbiz_pro_logo.png') as ImageProvider),
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black38,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: warmAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: backgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'This logo appears on the dashboard, receipts, and anywhere your facility is shown throughout the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _changeLogo,
                  icon: const Icon(Icons.upload),
                  label: Text(logoUrl != null ? 'Change Logo' : 'Upload Logo'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryColor;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
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
