import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/facility_activation.dart';
import '../../utils/force_logout.dart';
import '../../constants/facility_types.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/vetbiz_loading_indicator.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_breakpoints.dart';

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
        widget.facilities.map((f) => firestore.collection(Collections.facilities).doc(f[Fields.facilityId] as String).get()),
      );
      for (final doc in facilityDocs) {
        if (doc.exists) {
          _detailsByFacility[doc.id] = doc.data() ?? {};
        }
      }

      // Staff counts - one query across all facility IDs (Firestore
      // caps arrayContainsAny at 30 values), grouped client-side rather
      // than one query per facility.
      final facilityIds = widget.facilities.map((f) => f[Fields.facilityId] as String).toList();
      if (facilityIds.isNotEmpty) {
        final assistantsSnap = await firestore
            .collection(Collections.users)
            .where(Fields.role, isEqualTo: UserRole.assistant.key)
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
        final userDoc = await firestore.collection(Collections.users).doc(uid).get();
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
    await FirebaseFirestore.instance.collection(Collections.users).doc(uid).update({'defaultFacilityId': facilityId});
    if (mounted) setState(() => _defaultFacilityId = facilityId);
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'agrovet':
        return context.colors.success;
      case 'vet clinic':
      case 'vet hospital':
      case 'ambulatory vet':
        return context.colors.info;
      default:
        return Colors.purple;
    }
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    return widget.facilities.where((f) {
      final name = (f['facilityName'] as String? ?? '').toLowerCase();
      final type = (f['facilityType'] as String? ?? '').toLowerCase();
      final details = _detailsByFacility[f[Fields.facilityId]];
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
      backgroundColor: context.colors.surfaceMuted,
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
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
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHero(),
                          const SizedBox(height: AppSpacing.s24),
                          _buildSearchAndFilter(),
                          const SizedBox(height: AppSpacing.s20),
                          _buildFacilityGrid(),
                          const SizedBox(height: AppSpacing.s24),
                          _buildFooter(),
                          const SizedBox(height: AppSpacing.s24),
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
      color: context.colors.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
            child: Text('VB',
                style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
          ),
          const SizedBox(width: AppSpacing.s10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppInfo.name, style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
              Text('Manage. Care. Grow.', style: TextStyle(color: context.colors.onPrimaryMuted, fontSize: AppFontSize.f10_5)),
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
                  backgroundColor: context.colors.surface,
                  foregroundColor: context.colors.primary,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(_currentUserName.isEmpty ? 'Account' : _currentUserName,
                    style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
                Icon(Icons.expand_more, color: context.colors.onPrimary, size: AppIconSize.i18),
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
        final isNarrow = constraints.maxWidth < AppBreakpoints.stackSections;
        final textColumn = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.storefront_outlined, color: context.colors.primary, size: AppIconSize.i24),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Your Facility',
                        style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f24, color: context.colors.primary)),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'Choose the facility you want to manage. You can switch between your facilities at any time from the top menu.',
                      style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13_5),
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
            const SizedBox(width: AppSpacing.s16),
            SizedBox(
              width: 110,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Icon(Icons.agriculture_outlined, color: context.colors.primary.withValues(alpha: AppAlpha.a30), size: AppIconSize.i56),
                  ),
                  Positioned(
                    right: 10,
                    top: 4,
                    child: Icon(Icons.cruelty_free, color: context.colors.accent.withValues(alpha: AppAlpha.a50), size: AppIconSize.i32),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 6,
                    child: Icon(Icons.pets, color: context.colors.primary.withValues(alpha: AppAlpha.a40), size: AppIconSize.i22),
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
              prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r10), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        PopupMenuButton<String?>(
          initialValue: _typeFilter,
          onSelected: (value) => setState(() => _typeFilter = value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All Types')),
            ...kFacilityTypes.map((t) => PopupMenuItem(value: t, child: Text(t))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(AppRadius.r10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list, size: AppIconSize.i18),
                const SizedBox(width: AppSpacing.s6),
                Text(_typeFilter ?? 'Filter', style: const TextStyle(fontSize: AppFontSize.f13)),
                const Icon(Icons.expand_more, size: AppIconSize.i18),
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
    final facilityId = facility[Fields.facilityId] as String;
    final name = facility['facilityName'] as String? ?? 'Unnamed Facility';
    final type = facility['facilityType'] as String? ?? '';
    final details = _detailsByFacility[facilityId];
    final logoUrl = details?['logoUrl'] as String?;
    final address = details?['address'] as String?;
    final status = details?[Fields.status] as String? ?? 'Active';
    final staffCount = _staffCountByFacility[facilityId] ?? 0;
    final isDefault = facilityId == _defaultFacilityId;
    final typeColor = _typeColor(type);

    return Container(
      decoration: BoxDecoration(
        color: isDefault ? context.colors.primary.withValues(alpha: AppAlpha.a05) : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: isDefault ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a20), width: isDefault ? 2 : 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? Image.network(logoUrl, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                    color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                    child: Icon(Icons.storefront_outlined, color: context.colors.primary)))
                            : Container(
                                color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                                child: Icon(Icons.storefront_outlined, color: context.colors.primary)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: AppSpacing.s4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                            decoration: BoxDecoration(
                              color: type.isNotEmpty ? typeColor.withValues(alpha: AppAlpha.a10) : context.colors.textHint.withValues(alpha: AppAlpha.a10),
                              borderRadius: BorderRadius.circular(AppRadius.r8),
                            ),
                            child: Text(type.isNotEmpty ? type : 'Type not set',
                                style: TextStyle(color: type.isNotEmpty ? typeColor : context.colors.textMuted, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: AppIconSize.i14, color: context.colors.textHint),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Text(
                        (address != null && address.isNotEmpty) ? address : 'Location not set',
                        style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: AppIconSize.i14, color: context.colors.textHint),
                    const SizedBox(width: AppSpacing.s4),
                    Text('$staffCount Staff', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                    const SizedBox(width: AppSpacing.s12),
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: status == 'Active' ? context.colors.success : context.colors.textHint, shape: BoxShape.circle)),
                    const SizedBox(width: AppSpacing.s4),
                    Text(status, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: isDefault
                          ? ElevatedButton.icon(
                              onPressed: () => activateFacilityAndGoToDashboard(context: context, facility: facility, role: widget.role),
                              icon: const Icon(Icons.arrow_forward, size: AppIconSize.i16),
                              label: const Text('Open Facility'),
                              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: context.colors.onPrimary),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => activateFacilityAndGoToDashboard(context: context, facility: facility, role: widget.role),
                              icon: const Icon(Icons.arrow_forward, size: AppIconSize.i16),
                              label: const Text('Open Facility'),
                              style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
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
                        padding: const EdgeInsets.all(AppSpacing.s10),
                        decoration: BoxDecoration(border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)), borderRadius: BorderRadius.circular(AppRadius.r8)),
                        child: const Icon(Icons.more_vert, size: AppIconSize.i16),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(AppRadius.r10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: AppIconSize.i12, color: context.colors.onPrimary),
                    SizedBox(width: AppSpacing.s3),
                    Text('Default', style: TextStyle(color: context.colors.onPrimary, fontSize: AppFontSize.f10, fontWeight: AppFontWeight.bold)),
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
        'Secure  â€¢  Reliable  â€¢  Built for Veterinary Businesses',
        style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f11_5),
      ),
    );
  }
}
