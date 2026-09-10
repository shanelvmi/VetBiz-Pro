import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/facility_activation.dart';
import '../../utils/force_logout.dart';
import '../../constants/facility_types.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/vetbiz_loading_indicator.dart';

/// Only ever shown for an Admin managing more than one facility - the
/// single-facility case (every Assistant, and most Admins) never
/// reaches this at all, going straight to Dashboard instead.
///
/// Unlike main.dart's own login decision (deliberately lean - a single
/// extra fetch there was a past source of unreliable logins), this
/// screen does its own additional fetching once it's already showing -
/// facility address/logo/status, staff counts, and the current user's
/// own name/avatar/default-facility choice. That's a safe place for it:
/// this screen is only ever reached for the smaller subset of
/// multi-facility Admins, well after the time-critical login decision
/// has already been made.
class FacilityPickerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> facilities;
  final String? role;

  const FacilityPickerScreen({super.key, required this.facilities, this.role});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  @override
  State<FacilityPickerScreen> createState() => _FacilityPickerScreenState();
}

class _FacilityPickerScreenState extends State<FacilityPickerScreen> {
  bool _isLoading = true;
  final Map<String, Map<String, dynamic>> _detailsByFacility = {};
  final Map<String, int> _staffCountByFacility = {};
  String? _defaultFacilityId;
  String _searchQuery = '';
  String? _typeFilter;
  String _currentUserName = '';
  String? _currentUserAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadEnrichedData();
  }

  Future<void> _loadEnrichedData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;

      // Facility details (address, status, logoUrl) - one get per
      // facility, run in parallel rather than one at a time.
      final facilityDocs = await Future.wait(
        widget.facilities.map((f) => firestore.collection('facilities').doc(f['facilityId'] as String).get()),
      );
      for (final doc in facilityDocs) {
        if (doc.exists) {
          _detailsByFacility[doc.id] = doc.data() ?? {};
        }
      }

      // Staff counts - one query across all facility IDs (Firestore
      // caps arrayContainsAny at 30 values), grouped client-side rather
      // than one query per facility.
      final facilityIds = widget.facilities.map((f) => f['facilityId'] as String).toList();
      if (facilityIds.isNotEmpty) {
        final assistantsSnap = await firestore
            .collection('users')
            .where('role', isEqualTo: 'assistant')
            .where('facilityIds', arrayContainsAny: facilityIds.take(30).toList())
            .get();
        for (final doc in assistantsSnap.docs) {
          final docFacilityIds = (doc.data()['facilityIds'] as List?)?.cast<String>() ?? [];
          for (final fid in docFacilityIds) {
            if (facilityIds.contains(fid)) {
              _staffCountByFacility[fid] = (_staffCountByFacility[fid] ?? 0) + 1;
            }
          }
        }
      }

      // Current user's own name/avatar/default-facility choice.
      if (uid != null) {
        final userDoc = await firestore.collection('users').doc(uid).get();
        final userData = userDoc.data();
        _currentUserName = userData?['fullName'] as String? ?? '';
        _currentUserAvatarUrl = userData?['avatarUrl'] as String?;
        _defaultFacilityId = userData?['defaultFacilityId'] as String?;
      }
    } catch (e) {
      // Non-fatal - the screen still works with just name/type per
      // card if this enrichment fetch fails for any reason.
      debugPrint('[FacilityPickerScreen] enrichment fetch failed: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _setAsDefault(String facilityId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'defaultFacilityId': facilityId});
    if (mounted) setState(() => _defaultFacilityId = facilityId);
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'agrovet':
        return Colors.green;
      case 'vet clinic':
      case 'vet hospital':
      case 'ambulatory vet':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    return widget.facilities.where((f) {
      final name = (f['facilityName'] as String? ?? '').toLowerCase();
      final type = (f['facilityType'] as String? ?? '').toLowerCase();
      final details = _detailsByFacility[f['facilityId']];
      final address = (details?['address'] as String? ?? '').toLowerCase();

      if (_typeFilter != null && f['facilityType'] != _typeFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!name.contains(q) && !type.contains(q) && !address.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: _isLoading
            ? const VetBizLoadingIndicator(key: ValueKey('loading'), style: VetBizLoadingStyle.compact)
            : Column(
                key: const ValueKey('content'),
                children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHero(),
                          const SizedBox(height: 24),
                          _buildSearchAndFilter(),
                          const SizedBox(height: 20),
                          _buildFacilityGrid(),
                          const SizedBox(height: 24),
                          _buildFooter(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: FacilityPickerScreen.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Text('VB',
                style: TextStyle(color: FacilityPickerScreen.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VetBiz Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Manage. Care. Grow.', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') forceLogoutAndShowLogin();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Log Out')),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(
                  avatarUrl: _currentUserAvatarUrl,
                  name: _currentUserName,
                  size: 32,
                  backgroundColor: Colors.white,
                  foregroundColor: FacilityPickerScreen.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(_currentUserName.isEmpty ? 'Account' : _currentUserName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const Icon(Icons.expand_more, color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final textColumn = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FacilityPickerScreen.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.storefront_outlined, color: FacilityPickerScreen.primaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Your Facility',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: FacilityPickerScreen.primaryColor)),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the facility you want to manage. You can switch between your facilities at any time from the top menu.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isNarrow) return textColumn;

        return Row(
          children: [
            textColumn,
            const SizedBox(width: 16),
            SizedBox(
              width: 110,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Icon(Icons.agriculture_outlined, color: FacilityPickerScreen.primaryColor.withValues(alpha: 0.25), size: 56),
                  ),
                  Positioned(
                    right: 10,
                    top: 4,
                    child: Icon(Icons.cruelty_free, color: FacilityPickerScreen.warmAmber.withValues(alpha: 0.5), size: 30),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 6,
                    child: Icon(Icons.pets, color: FacilityPickerScreen.primaryColor.withValues(alpha: 0.35), size: 22),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search facility by name, location or type...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String?>(
          initialValue: _typeFilter,
          onSelected: (value) => setState(() => _typeFilter = value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All Types')),
            ...kFacilityTypes.map((t) => PopupMenuItem(value: t, child: Text(t))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list, size: 18),
                const SizedBox(width: 6),
                Text(_typeFilter ?? 'Filter', style: const TextStyle(fontSize: 13)),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityGrid() {
    final filtered = _filteredFacilities;
    return LayoutBuilder(
      builder: (context, constraints) {
        const idealCardWidth = 360.0;
        final maxColumnsForWidth = (constraints.maxWidth / idealCardWidth).floor().clamp(1, 4);
        // Never more columns than there are cards to fill them - with
        // only 2 facilities, this keeps them as 2 wide columns rather
        // than 2 narrow ones sitting centered inside a 4-column layout.
        final columns = filtered.isEmpty ? maxColumnsForWidth : maxColumnsForWidth.clamp(1, filtered.length);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final facility in filtered)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                child: _buildFacilityCard(facility),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String;
    final name = facility['facilityName'] as String? ?? 'Unnamed Facility';
    final type = facility['facilityType'] as String? ?? '';
    final details = _detailsByFacility[facilityId];
    final logoUrl = details?['logoUrl'] as String?;
    final address = details?['address'] as String?;
    final status = details?['status'] as String? ?? 'Active';
    final staffCount = _staffCountByFacility[facilityId] ?? 0;
    final isDefault = facilityId == _defaultFacilityId;
    final typeColor = _typeColor(type);

    return Container(
      decoration: BoxDecoration(
        color: isDefault ? FacilityPickerScreen.primaryColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDefault ? FacilityPickerScreen.primaryColor : Colors.grey.withValues(alpha: 0.2), width: isDefault ? 2 : 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? Image.network(logoUrl, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                    color: FacilityPickerScreen.primaryColor.withValues(alpha: 0.1),
                                    child: Icon(Icons.storefront_outlined, color: FacilityPickerScreen.primaryColor)))
                            : Container(
                                color: FacilityPickerScreen.primaryColor.withValues(alpha: 0.1),
                                child: Icon(Icons.storefront_outlined, color: FacilityPickerScreen.primaryColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: type.isNotEmpty ? typeColor.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(type.isNotEmpty ? type : 'Type not set',
                                style: TextStyle(color: type.isNotEmpty ? typeColor : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (address != null && address.isNotEmpty) ? address : 'Location not set',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('$staffCount Staff', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: status == 'Active' ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: isDefault
                          ? ElevatedButton.icon(
                              onPressed: () => activateFacilityAndGoToDashboard(context: context, facility: facility, role: widget.role),
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Open Facility'),
                              style: ElevatedButton.styleFrom(backgroundColor: FacilityPickerScreen.primaryColor, foregroundColor: Colors.white),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => activateFacilityAndGoToDashboard(context: context, facility: facility, role: widget.role),
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Open Facility'),
                              style: OutlinedButton.styleFrom(foregroundColor: FacilityPickerScreen.primaryColor),
                            ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'default') _setAsDefault(facilityId);
                      },
                      itemBuilder: (context) => [
                        if (!isDefault) const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.more_vert, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isDefault)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: FacilityPickerScreen.primaryColor, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 10, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Default', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Secure  •  Reliable  •  Built for Veterinary Businesses',
        style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
      ),
    );
  }
}
