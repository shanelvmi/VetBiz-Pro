import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/facility_activation.dart';
import '../../utils/force_logout.dart';
import '../../widgets/facility_pick_card.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/reveal/skeleton_box.dart';
import '../../data/collections.dart';
import '../../data/facility_status.dart';
import '../../data/fields.dart';
import '../../models/facility_entry.dart';
import '../../data/user_role.dart';
import '../../config/app_info.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_layout.dart';
import '../../l10n/l10n.dart';

/// Only ever shown for an Admin managing more than one facility - the
/// single-facility case (every Assistant, and most Admins) never
/// reaches this at all, going straight to Dashboard instead
/// (facilityLandingFor, lib/utils/facility_landing.dart).
///
/// Unlike main.dart's own login decision (deliberately lean - a single
/// extra fetch there was a past source of unreliable logins), this
/// screen does its own additional fetching once it's already showing -
/// facility address/logo/status, staff counts, and the current user's
/// own name/avatar/default-facility choice. That's a safe place for it:
/// this screen is only ever reached for the smaller subset of
/// multi-facility Admins, well after the time-critical login decision
/// has already been made.
///
/// UX9: flat cards in a centred grid (two side by side, three or more in
/// auto columns, one column on a phone), the whole card opening its
/// facility. No search or filter, unless there are more than
/// [FacilityPickerMetrics.searchAbove] facilities (a plain search box then).
class FacilityPickerScreen extends StatefulWidget {
  /// The facilities as the user document lists them, or the in-app maps: read
  /// through FacilityEntry (FX1), so an odd or web-shaped value never throws.
  final List<Object?> facilities;
  final String? role;

  /// Tests pass a fake Firestore and the signed-in uid; the app passes
  /// neither (the default instance and FirebaseAuth's current user).
  final FirebaseFirestore? firestore;
  final String? uid;

  const FacilityPickerScreen({super.key, required this.facilities, this.role, this.firestore, this.uid});

  @override
  State<FacilityPickerScreen> createState() => _FacilityPickerScreenState();
}

class _FacilityPickerScreenState extends State<FacilityPickerScreen> {
  late final List<FacilityEntry> _entries = FacilityEntry.listFrom(widget.facilities);
  bool _isLoading = true;
  final Map<String, Map<String, dynamic>> _detailsByFacility = {};
  final Map<String, int> _staffCountByFacility = {};
  String? _defaultFacilityId;
  String _searchQuery = '';
  String _currentUserName = '';
  String? _currentUserAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadEnrichedData();
  }

  Future<void> _loadEnrichedData() async {
    try {
      final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
      final firestore = widget.firestore ?? FirebaseFirestore.instance;

      // Facility details (address, status, logoUrl) - one get per
      // facility, run in parallel rather than one at a time.
      final facilityDocs = await Future.wait(
        _entries.map((f) => firestore.collection(Collections.facilities).doc(f.id).get()),
      );
      for (final doc in facilityDocs) {
        if (doc.exists) {
          _detailsByFacility[doc.id] = doc.data() ?? {};
        }
      }

      // Staff counts - one query across all facility IDs (Firestore
      // caps arrayContainsAny at 30 values), grouped client-side rather
      // than one query per facility.
      final facilityIds = [for (final f in _entries) f.id!];
      if (facilityIds.isNotEmpty) {
        final assistantsSnap = await firestore
            .collection(Collections.users)
            .where(Fields.role, isEqualTo: UserRole.assistant.key)
            .where('facilityIds', arrayContainsAny: facilityIds.take(30).toList())
            .get();
        for (final doc in assistantsSnap.docs) {
          final rawIds = doc.data()['facilityIds'];
          final docFacilityIds = rawIds is List ? rawIds.whereType<String>() : const <String>[];
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
        _currentUserName = FacilityEntry.safeString(userData?['fullName']) ?? '';
        _currentUserAvatarUrl = FacilityEntry.safeString(userData?['avatarUrl']);
        _defaultFacilityId = FacilityEntry.safeString(userData?['defaultFacilityId']);
      }
    } catch (e) {
      // Non-fatal - the screen still works with just name/type per
      // card if this enrichment fetch fails for any reason.
      debugPrint('[FacilityPickerScreen] enrichment fetch failed: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _setAsDefault(String facilityId) async {
    final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await (widget.firestore ?? FirebaseFirestore.instance)
        .collection(Collections.users)
        .doc(uid)
        .update({'defaultFacilityId': facilityId});
    if (mounted) setState(() => _defaultFacilityId = facilityId);
  }

  /// UX9: search exists only above [FacilityPickerMetrics.searchAbove]
  /// facilities; with fewer, every facility shows.
  bool get _hasSearch => _entries.length > FacilityPickerMetrics.searchAbove;

  List<FacilityEntry> get _shownFacilities {
    final q = _searchQuery.trim().toLowerCase();
    if (!_hasSearch || q.isEmpty) return _entries;
    return _entries.where((f) {
      final name = (f.name ?? '').toLowerCase();
      // The type as shown (an Other facility's own words, RW2b2) is what a
      // search matches; the location too, as the field's hint says.
      final type = context.l10n.facilityTypeDisplay(f.type, f.typeDetail).toLowerCase();
      final address = (FacilityEntry.safeString(_detailsByFacility[f.id]?['address']) ?? '').toLowerCase();
      return name.contains(q) || type.contains(q) || address.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceMuted,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                // PH8b: the 16 px gutter on a phone (24 on a tablet or computer).
                padding: EdgeInsets.all(_phone ? AppSpacing.s16 : AppSpacing.s24),
                child: Center(
                  // UX9: never wider than the content column, centred.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: FacilityPickerMetrics.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHero(),
                        const SizedBox(height: AppSpacing.s24),
                        if (_hasSearch) ...[
                          _buildSearch(),
                          const SizedBox(height: AppSpacing.s16),
                        ],
                        // UX9: one skeleton set in the cards' shape until the
                        // details arrive, then the cards (no spinner).
                        AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _isLoading
                              ? SkeletonPulse(
                                  key: const ValueKey('loading'),
                                  child: _grid([for (final _ in _entries) const FacilityPickCardSkeleton()]),
                                )
                              : KeyedSubtree(key: const ValueKey('content'), child: _buildFacilityGrid()),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PH8b: the phone fixes (the gutter, a 48 px account menu); UX9 keeps
  // them, the cards now one shared design at every width.
  bool get _phone => AppLayout.isPhone(context);

  // At least 48 x 48 on a phone; untouched elsewhere.
  Widget _phoneTapTarget(Widget child) =>
      _phone
          ? ConstrainedBox(
              constraints: const BoxConstraints(minWidth: AppSizes.minTapTarget, minHeight: AppSizes.minTapTarget),
              child: child,
            )
          : child;

  Widget _buildHeader() {
    return Container(
      color: context.colors.brandSurface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s14),
      // UI1: the brand (the mark and the name) at the left, the profile menu
      // in the right corner. Each side may take half the bar, so on a phone
      // the names shorten with an ellipsis instead of overflowing (FX1); with
      // the brand an Expanded, the menu used to sit in the middle.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.onBrandSurface, shape: BoxShape.circle),
                  child: Text(AppInfo.logoInitials,
                      style: TextStyle(color: context.colors.brandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
                ),
                const SizedBox(width: AppSpacing.s10),
                Flexible(
                  child: Text(AppInfo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                ),
              ],
            ),
          ),
          Flexible(
            child: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') forceLogoutAndShowLogin();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'logout', child: Text(context.l10n.facilityPicker_logOut)),
            ],
            child: _phoneTapTarget(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(
                  avatarUrl: _currentUserAvatarUrl,
                  name: _currentUserName,
                  size: 32,
                  backgroundColor: context.colors.onBrandSurface,
                  foregroundColor: context.colors.brandSurface,
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(_currentUserName.isEmpty ? context.l10n.dashboard_account : _currentUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13)),
                ),
                Icon(Icons.expand_more, color: context.colors.onBrandSurface, size: AppIconSize.i18),
              ],
            )),
          ),
          ),
        ],
      ),
    );
  }


  // UX9: the page header centred at every width: "Welcome back, <name>"
  // (only when the profile has a name), then the title and its subtitle.
  // UI1's store icon in its accent circle is gone: on this page only the
  // Default card carries the accent.
  Widget _buildHero() {
    final l10n = context.l10n;
    return Column(
      children: [
        if (_currentUserName.isNotEmpty) ...[
          Text(l10n.facilityPicker_welcomeBack(_currentUserName),
              key: const ValueKey('facilityPicker-welcome'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textSecondary, fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
          const SizedBox(height: AppSpacing.s4),
        ],
        Text(l10n.facilityPicker_title,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f24, color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.s6),
        Text(
          l10n.facilityPicker_intro,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: AppFontSize.f13_5),
        ),
      ],
    );
  }

  // UX9: only with more than FacilityPickerMetrics.searchAbove facilities.
  Widget _buildSearch() {
    return TextField(
      key: const ValueKey('facilityPicker-search'),
      decoration: InputDecoration(
        hintText: context.l10n.facilityPicker_searchHint,
        prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r10),
          borderSide: BorderSide(color: context.colors.border, width: PolishMetrics.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r10),
          borderSide: BorderSide(color: context.colors.border, width: PolishMetrics.hairline),
        ),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  /// How many columns [count] cards take in [width]: one on a phone; two
  /// facilities side by side; three or more as many columns as fit at
  /// [FacilityPickerMetrics.minCardWidth], never more than there are cards.
  int _columnsFor(int count, double width) {
    if (_phone || count <= 1) return 1;
    const gap = FacilityPickerMetrics.gridGap;
    final fit = ((width + gap) / (FacilityPickerMetrics.minCardWidth + gap)).floor();
    if (count == 2) return fit >= 2 ? 2 : 1;
    return fit.clamp(1, count);
  }

  /// [cards] in equal columns, left to right, rows top to bottom.
  Widget _grid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = FacilityPickerMetrics.gridGap;
        final columns = _columnsFor(cards.length, constraints.maxWidth);
        // Floored, so rounding never pushes the last card of a row down.
        final cardWidth = ((constraints.maxWidth - (columns - 1) * gap) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: cardWidth, child: card)],
        );
      },
    );
  }

  Widget _buildFacilityGrid() {
    final shown = _shownFacilities;
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
        child: Text(
          _entries.isEmpty ? context.l10n.facilities_noneFound : context.l10n.clients_noMatches,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: AppFontSize.f14),
        ),
      );
    }
    return _grid([for (final f in shown) _buildFacilityCard(f)]);
  }

  Widget _buildFacilityCard(FacilityEntry facility) {
    final facilityId = facility.id!; // listFrom keeps only entries with an id
    final details = _detailsByFacility[facilityId];
    final isDefault = facilityId == _defaultFacilityId;
    return FacilityPickCard(
      key: ValueKey('facilityPickCard-$facilityId'),
      name: facility.name ?? context.l10n.facilityPicker_unnamedFacility,
      type: facility.type ?? '',
      typeDetail: facility.typeDetail,
      logoUrl: FacilityEntry.safeString(details?['logoUrl']),
      address: FacilityEntry.safeString(details?['address']),
      status: FacilityEntry.safeString(details?[Fields.status]) ?? FacilityStatus.active.key,
      staffCount: _staffCountByFacility[facilityId] ?? 0,
      isDefault: isDefault,
      onOpen: () => activateFacilityAndGoToDashboard(context: context, facility: facility.toMap(), role: widget.role),
      // The ⋮ menu's one action; the Default card has none, so no menu.
      onSetDefault: isDefault ? null : () => _setAsDefault(facilityId),
    );
  }
}
