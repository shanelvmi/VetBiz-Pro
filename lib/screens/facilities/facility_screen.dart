import 'package:flutter/material.dart';
import '../../services/activity_log_retention.dart';
import '../../services/membership_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../providers/facility_provider.dart';
import '../../models/product.dart';
import '../../services/usage_calculator_service.dart';
import '../../utils/facility_activation.dart';
import '../../utils/upload_size_check.dart';
import '../../services/facility_codes.dart';
import '../../constants/facility_types.dart';
import '../../services/sales_summary_service.dart';
import '../../utils/force_logout.dart';
import '../../utils/facility_limit_helper.dart';
import '../admin/manage_assistants_screen.dart';
import '../../data/collections.dart';
import '../../data/upload_content_types.dart';
import '../../data/facility_ownership.dart';
import '../../data/facility_status.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_ranges.dart';
import '../../config/app_rules.dart';
import '../../theme/activity_type_style.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../ui/feedback/friendly_error.dart';
import '../../l10n/l10n.dart';

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key});

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  // The facility list panel: below the details on a narrow window, beside
  // them on a wide one. Sizes, kept exact (D10).
  static const double _listPanelHeight = 360;
  static const double _listPanelWidth = 340;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final User? currentUser;
  List<Map<String, dynamic>> facilities = [];
  String? activeFacilityId;
  String? _adminFullName;
  bool isLoading = true;

  // Search - same expandable-icon pattern used everywhere else this
  // session (Manage Assistants, Sales, Products, Services). Matches
  // on name and code, since those are the two things someone actually
  // remembers about a specific facility.
  String _searchQuery = '';

  // Master-detail state - which facility's detail panel is showing,
  // which tab within it is active, and the list panel's own status
  // filter (All/Active/Inactive). Selecting a facility never replaces
  // or hides the list, on any screen width - narrow screens stack the
  // list above the detail content instead of switching between them.
  String? _selectedFacilityIdForDetail;
  int _selectedTabIndex = 0;
  String _listStatusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Same responsive dialog width already established in
  // manage_account_screen.dart - capped at a comfortable reading width
  // on desktop rather than stretching edge-to-edge, and a proportional
  // width on narrower screens rather than a fixed size that could
  // overflow.
  double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 700 ? 440.0 : screenWidth * 0.88;
  }

  // Assistants fetched once per facility list refresh, keyed by
  // facilityId, rather than re-querying inside a FutureBuilder every
  // time this widget rebuilds for any reason - the previous version's
  // future was recreated on every build(), causing a visible flicker
  // back to a loading state and a redundant Firestore read each time.
  final Map<String, List<Map<String, dynamic>>> _assistantsByFacility = {};

  // True while Delete Facility is checking, afresh, that no assistants remain.
  bool _checkingBeforeDelete = false;

  // Logo URL and quick stats (this month's sales, client count) per
  // facility - same reasoning as assistants above: fetched once per
  // refresh, not per-card inside build().
  final Map<String, String?> _logoByFacility = {};
  // Email/phone - same reasoning as _logoByFacility above: the facility
  // map passed around this screen is a denormalized {facilityId, name,
  // type} copy that never included this either, so it needs its own
  // fetch from the real facility document, same as the logo does.
  final Map<String, Map<String, String?>> _contactByFacility = {};
  // Additional per-facility detail fields (address, license, ownership,
  // timestamps) that the new detail view needs but the compact card
  // never did - kept in its own map rather than folded into
  // _contactByFacility, since that one's specifically for contact info.
  final Map<String, Map<String, dynamic>> _detailsByFacility = {};
  // Lazy-loaded, per-facility caches for the Inventory Summary and
  // Sales Summary tabs - unlike the aggregate counts in
  // _statsByFacility (fetched for every facility up front), these hold
  // the full product/sales lists those two tabs need, only fetched
  // once a tab is actually opened for a given facility.
  final Map<String, Future<QuerySnapshot>> _productsFutureByFacility = {};
  final Map<String, Future<QuerySnapshot>> _recentSalesFutureByFacility = {};
  final Map<String, Map<String, dynamic>> _statsByFacility = {};
  final SalesSummaryService _salesSummaryService = SalesSummaryService();

  // Logo upload - the ImagePicker instance is shared by both the Add
  // and Edit Facility dialogs.
  final ImagePicker _picker = ImagePicker();

  bool _isAddingFacility = false;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    fetchFacilities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches a facility's logo URL and this month's quick stats (sales
  /// count, revenue, client count) in one pass. Uses the precomputed
  /// dailySummaries aggregate rather than scanning every sale, and a
  /// server-side count() for clients rather than downloading every
  /// client document just to count them.
  Future<void> _fetchFacilityExtras(String facilityId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      // Started together rather than one at a time - none of these
      // four depend on another's result, so there's no reason for
      // each to wait on the previous one to finish before starting.
      final facilityDocFuture =
          FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).get();
      final salesTotalsFuture = _salesSummaryService.getRangeTotals(
        facilityId: facilityId,
        start: monthStart,
        end: now,
      );
      final clientCountFuture = FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.clients)
          .count()
          .get();
      // Same calculation Dashboard's own "Total Product Value" card
      // uses - read directly from raw product docs here rather than
      // through ProductProvider, since that's scoped to whichever
      // facility is currently active, not every facility a card in
      // this list represents.
      final productsFuture =
          FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).collection(Collections.products).get();

      final facilityDoc = await facilityDocFuture;
      final logoUrl = facilityDoc.data()?['logoUrl'] as String?;
      final email = facilityDoc.data()?['email'] as String?;
      final phone = facilityDoc.data()?['phone'] as String?;
      final address = facilityDoc.data()?['address'] as String?;
      final description = facilityDoc.data()?['description'] as String?;
      final tagline = facilityDoc.data()?['tagline'] as String?;
      final licenseNo = facilityDoc.data()?['licenseNo'] as String?;
      final tin = facilityDoc.data()?['tin'] as String?;
      final status = facilityDoc.data()?[Fields.status] as String? ?? FacilityStatus.active.key;
      final createdAtTs = facilityDoc.data()?[Fields.createdAt] as Timestamp?;
      final updatedAtTs = facilityDoc.data()?[Fields.updatedAt] as Timestamp?;
      final retentionDays = (facilityDoc.data()?['activityLogRetentionDays'] as num?)?.toInt() ?? AppRules.activityLogRetentionDefaultDays;
      final debtOverdueDays = (facilityDoc.data()?['debtOverdueDays'] as num?)?.toInt() ?? 30;
      final salesTotals = await salesTotalsFuture;
      final clientCountSnap = await clientCountFuture;
      final productsSnap = await productsFuture;

      double totalProductValue = 0.0;
      int sellableProductCount = 0;
      int lowStockCount = 0;
      int expiredCount = 0;
      final nowForExpiry = DateTime.now();
      for (final doc in productsSnap.docs) {
        final data = doc.data();
        final sellPrice = (data['sellPrice'] as num?)?.toDouble() ?? 0.0;
        final stockQty = (data['stockQty'] as num?)?.toDouble() ?? 0.0;
        final sellableQty = (data['sellableQty'] as num?)?.toDouble() ?? 0.0;
        totalProductValue += sellPrice * stockQty;

        if (sellableQty > 0) sellableProductCount++;

        final effectiveMinStock = ((data['lowStockThreshold'] ?? data['minStockLevel']) as num?)?.toInt() ??
            Product.defaultLowStockThreshold;

        // Same either-quantity-low check as StockAlertsScreen's own
        // definition, so this facility's headline number can never
        // quietly disagree with what the Dashboard's alerts consider
        // "low" for the same facility.
        if (stockQty <= effectiveMinStock ||
            sellableQty <= effectiveMinStock) {
          lowStockCount++;
        }

        final expiryTs = data['expiry'] as Timestamp?;
        if (expiryTs != null && expiryTs.toDate().isBefore(nowForExpiry)) {
          expiredCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _logoByFacility[facilityId] = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;
        _contactByFacility[facilityId] = {'email': email, 'phone': phone};
        _detailsByFacility[facilityId] = {
          // From the facility document: profiles no longer carry the code
          // (E4b, b3).
          FacilityCodes.field: facilityDoc.data()?[FacilityCodes.field] as String?,
          'address': address,
          'description': description,
          'tagline': tagline,
          'licenseNo': licenseNo,
          'tin': tin,
          Fields.status: status,
          Fields.createdAt: createdAtTs?.toDate(),
          Fields.updatedAt: updatedAtTs?.toDate(),
          'activityLogRetentionDays': retentionDays,
          'debtOverdueDays': debtOverdueDays,
        };
        _statsByFacility[facilityId] = {
          'saleCount': salesTotals['saleCount']?.toInt() ?? 0,
          'totalAmount': salesTotals['totalAmount'] ?? 0.0,
          'clientCount': clientCountSnap.count ?? 0,
          'totalProductValue': totalProductValue,
          'totalProducts': productsSnap.docs.length,
          'sellableProducts': sellableProductCount,
          'lowStockCount': lowStockCount,
          'expiredCount': expiredCount,
        };
      });
    } catch (e) {
      debugPrint('Could not load extras for facility $facilityId: $e');
    }
  }

  // Re-reads who is in each facility. The copy in _assistantsByFacility is
  // taken when this screen opens, so it goes stale the moment the Team Members
  // screen - which this screen links to - removes or moves someone.
  Future<void> _refreshAssistants() async {
    try {
      final fresh = <String, List<Map<String, dynamic>>>{};
      await Future.wait(facilities.map((f) async {
        final id = f[Fields.facilityId] as String?;
        if (id == null) return;
        fresh[id] = await _fetchAssistantsForFacility(id);
      }));
      if (!mounted) return;
      setState(() {
        _assistantsByFacility
          ..clear()
          ..addAll(fresh);
      });
    } catch (e) {
      debugPrint('Could not refresh who is in each facility: $e');
    }
  }

  Future<void> fetchFacilities() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection(Collections.users).doc(currentUser!.uid).get();
      final userData = userDoc.data();
      if (!mounted) return;

      if (userData != null && userData[Fields.role] == UserRole.admin.key) {
        final facilityList = List<Map<String, dynamic>>.from(userData['facilities'] ?? []);
        final selectedFacilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

        // Fetched once here, up front, instead of per-card inside
        // build() - see the _assistantsByFacility note above.
        //
        // Every facility's work starts at the same time, rather than
        // waiting for the previous facility to fully finish first -
        // with several facilities, each needing several of its own
        // sequential reads (including a full products download for
        // the stock-value total), doing this one facility at a time
        // meant total load time grew roughly linearly with facility
        // count. Now it's however long the single slowest fetch
        // across everything takes, not the sum of all of them.
        final assistantsMap = <String, List<Map<String, dynamic>>>{};
        final facilityFutures = <Future<void>>[];
        for (final f in facilityList) {
          final facilityId = f[Fields.facilityId] as String?;
          if (facilityId == null) continue;
          facilityFutures.add(() async {
            // Assistants and the extras (logo/stats/product value)
            // don't depend on each other either - started together
            // rather than one after the other.
            final assistantsFuture = _fetchAssistantsForFacility(facilityId);
            final extrasFuture = _fetchFacilityExtras(facilityId);
            assistantsMap[facilityId] = await assistantsFuture;
            await extrasFuture;
          }());
        }
        await Future.wait(facilityFutures);

        if (!mounted) return;
        setState(() {
          facilities = facilityList;
          activeFacilityId = selectedFacilityId;
          // Firebase Auth's own displayName is never actually set
          // anywhere in this app - registration stores the real name
          // in Firestore as 'fullName' instead - so this reads that
          // directly rather than a field that would always be empty.
          _adminFullName = userData['fullName'] as String?;
          _assistantsByFacility
            ..clear()
            ..addAll(assistantsMap);
          // Default the detail panel to the currently-active facility
          // if it's in this list, otherwise the first one - only when
          // nothing's been explicitly selected yet, so a later re-fetch
          // (e.g. after editing) doesn't pull the view back to a
          // different facility than the one already being looked at.
          if (_selectedFacilityIdForDetail == null && facilityList.isNotEmpty) {
            final activeStillExists = facilityList.any((f) => f[Fields.facilityId] == selectedFacilityId);
            _selectedFacilityIdForDetail =
                activeStillExists ? selectedFacilityId : facilityList.first[Fields.facilityId] as String?;
          }
        });
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(L10n.current.facilities_loadFailed, error: e);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAssistantsForFacility(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(Collections.users)
        .where(Fields.role, isEqualTo: UserRole.assistant.key)
        .where('facilityIds', arrayContains: facilityId)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _switchToFacility(Map<String, dynamic> facility) async {
    await activateFacilityAndGoToDashboard(
      context: context,
      facility: {
        Fields.facilityId: facility[Fields.facilityId],
        'facilityName': facility['name'],
        'facilityType': facility['type'],
      },
      role: UserRole.admin.key,
    );
  }

  // ==================== ADD FACILITY ====================

  Future<void> _showAddFacilityDialog() async {
    final maxFacilities = await loadMaxFacilitiesPerAdmin();
    if (facilities.length >= maxFacilities) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.facilities_limitTitle),
          content: Text(context.l10n.facilities_limitMessage(maxFacilities)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.common_ok, style: TextStyle(color: context.colors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    String? selectedType;
    String? dialogError;
    Uint8List? pendingLogoBytes;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.facilities_addTitle),
          content: SingleChildScrollView(
            child: SizedBox(
              width: _dialogWidth(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo - optional at creation time, same picker as Edit
                // Facility. Not every new facility has branding ready
                // immediately; it can always be added later via Edit.
                Center(
                  child: GestureDetector(
                    onTap: _isAddingFacility
                        ? null
                        : () async {
                            final picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: AppLimits.logoImageMaxSide,
                              maxHeight: AppLimits.logoImageMaxSide,
                              imageQuality: AppLimits.pickedImageQuality,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            if (!UploadSizeCheck.allow(bytes)) return;
                            setDialogState(() => pendingLogoBytes = bytes);
                          },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        border: Border.all(color: context.colors.border),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s6),
                      child: pendingLogoBytes != null
                          ? Image.memory(pendingLogoBytes!, fit: BoxFit.contain)
                          : Icon(Icons.add_a_photo_outlined, color: context.colors.textHint, size: AppIconSize.i24),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Center(
                  child: Text(
                    context.l10n.facilities_logoOptional,
                    style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: InputDecoration(labelText: context.l10n.facilities_nameLabel),
                ),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(labelText: context.l10n.common_type),
                  items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(context.l10n.facilityTypeLabel(t)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(dialogError!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                ],
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isAddingFacility ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: _isAddingFacility
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty || selectedType == null) {
                        setDialogState(() => dialogError = context.l10n.facilities_nameAndTypeRequired);
                        return;
                      }
                      setDialogState(() => dialogError = null);
                      setState(() => _isAddingFacility = true);

                      try {
                        final newFacility =
                            await _addFacility(name: name, type: selectedType!, logoBytes: pendingLogoBytes);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        // Only after the dialog above has actually closed -
                        // switching first and closing the dialog after was
                        // racing the dialog's own pop against the
                        // stack-replacing navigation this triggers.
                        if (mounted) await _switchToFacility(newFacility);
                      } catch (e) {
                        // The server's own wording: the facility limit, a
                        // connection problem, and so on.
                        setDialogState(() => dialogError = MembershipService.errorMessage(e));
                      } finally {
                        if (mounted) setState(() => _isAddingFacility = false);
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: _isAddingFacility
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                        ),
                        SizedBox(width: AppSpacing.s8),
                        Text(context.l10n.facilities_adding),
                      ],
                    )
                  : Text(context.l10n.common_add),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _addFacility({required String name, required String type, Uint8List? logoBytes}) async {
    // The server creates the facility, works out its trial, checks the facility
    // limit, and adds it to this person's lists. None of that can be written
    // from the app any more - it's what stopped people writing themselves
    // into facilities that weren't theirs.
    final newFacilityEntry = await MembershipService().addFacility(name: name, type: type);
    final newFacilityId = newFacilityEntry[Fields.facilityId] as String;

    // Logo upload needs a facilityId to key the Storage path on, so it can
    // only happen after the facility above already exists. (The logo is an
    // ordinary facility setting, which an admin of it may write.)
    if (logoBytes != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('facility_logos/$newFacilityId.png');
        await storageRef.putData(logoBytes, UploadContentTypes.png);
        final rawDownloadUrl = await storageRef.getDownloadURL();
        final downloadUrl = '$rawDownloadUrl&cb=${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseFirestore.instance
            .collection(Collections.facilities)
            .doc(newFacilityId)
            .set({'logoUrl': downloadUrl}, SetOptions(merge: true));
      } catch (e) {
        // The facility itself was created successfully - a failed logo
        // upload shouldn't be treated as a failed facility creation.
        // It can always be added afterward via Edit.
        debugPrint('Logo upload failed for new facility $newFacilityId: $e');
      }
    }

    if (mounted) {
      AppFeedback.success(L10n.current.facilities_added);
      await fetchFacilities();
    }

    return newFacilityEntry;
  }

  // ==================== EDIT FACILITY ====================

  Future<void> _showEditFacilityDialog(Map<String, dynamic> facility) async {
    final nameController = TextEditingController(text: facility['name'] as String? ?? '');
    final existingContact = _contactByFacility[facility[Fields.facilityId]];
    final emailController = TextEditingController(text: existingContact?['email'] ?? '');
    final phoneController = TextEditingController(text: existingContact?['phone'] ?? '');
    final existingDetails = _detailsByFacility[facility[Fields.facilityId]];
    final addressController = TextEditingController(text: existingDetails?['address'] as String? ?? '');
    final licenseController = TextEditingController(text: existingDetails?['licenseNo'] as String? ?? '');
    final tinController = TextEditingController(text: existingDetails?['tin'] as String? ?? '');
    final descriptionController =
        TextEditingController(text: existingDetails?['description'] as String? ?? '');
    final taglineController =
        TextEditingController(text: existingDetails?['tagline'] as String? ?? '');
    String? selectedOwnership = existingDetails?['ownership'] as String?;
    String selectedStatus = existingDetails?[Fields.status] as String? ?? FacilityStatus.active.key;
    String selectedRestockFrequency = existingDetails?['restockFrequency'] as String? ??
        UsageCalculatorService.defaultRestockFrequency;
    String? selectedType = facility['type'] as String?;
    String? dialogError;
    bool isSaving = false;
    Uint8List? pendingLogoBytes;
    // True once the user has explicitly chosen to remove the existing
    // logo - kept separate from "no change made" so _editFacility
    // knows to actually delete it, not just leave it untouched.
    bool logoMarkedForRemoval = false;
    final existingLogoUrl = _logoByFacility[facility[Fields.facilityId]];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.facilities_editTitle),
          content: SingleChildScrollView(
            child: SizedBox(
              width: _dialogWidth(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Logo - shown and changed right alongside name/type,
                // rather than a separate tap-the-card-logo interaction.
                Center(
                  child: GestureDetector(
                    onTap: isSaving
                        ? null
                        : () async {
                            final picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: AppLimits.logoImageMaxSide,
                              maxHeight: AppLimits.logoImageMaxSide,
                              imageQuality: AppLimits.pickedImageQuality,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            if (!UploadSizeCheck.allow(bytes)) return;
                            // Picking a new logo implicitly cancels any
                            // pending removal - the user is replacing
                            // it, not removing it.
                            setDialogState(() {
                              pendingLogoBytes = bytes;
                              logoMarkedForRemoval = false;
                            });
                          },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                            border: Border.all(color: context.colors.border),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.s6),
                          child: pendingLogoBytes != null
                              ? Image.memory(pendingLogoBytes!, fit: BoxFit.contain)
                              : (existingLogoUrl != null && !logoMarkedForRemoval
                                  ? Image.network(
                                      existingLogoUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i32),
                                    )
                                  : Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i32)),
                        ),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color: context.colors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.colors.surface, width: 1.5),
                          ),
                          child: Icon(Icons.camera_alt, size: AppIconSize.i12, color: context.colors.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Center(
                  child: Text(
                    context.l10n.facilities_tapToChangeLogo,
                    style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted),
                  ),
                ),
                if ((pendingLogoBytes != null || existingLogoUrl != null) && !logoMarkedForRemoval) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isSaving
                          ? null
                          : () => setDialogState(() {
                                pendingLogoBytes = null;
                                logoMarkedForRemoval = true;
                              }),
                      child: Text(
                        context.l10n.facilities_removeLogo,
                        style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.dangerAccent),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: InputDecoration(labelText: context.l10n.facilities_nameLabel),
                ),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(labelText: context.l10n.common_type),
                  items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(context.l10n.facilityTypeLabel(t)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_businessEmailOptional,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_businessPhoneOptional,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: addressController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_addressOptional,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_descriptionOptional,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: taglineController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_taglineOptional,
                    hintText: context.l10n.facilities_taglineHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: licenseController,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_licenseOptional,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: tinController,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_tinOptional,
                    hintText: context.l10n.facilities_tinHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String>(
                  initialValue: selectedOwnership,
                  decoration: InputDecoration(labelText: context.l10n.facilities_ownershipOptional),
                  // Shows the label; the facility stores the English value.
                  items: [
                    for (final o in FacilityOwnership.values)
                      DropdownMenuItem(value: o, child: Text(context.l10n.facilityOwnershipLabel(o))),
                  ],
                  onChanged: (val) => setDialogState(() => selectedOwnership = val),
                ),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(labelText: context.l10n.common_status),
                  items: [
                    DropdownMenuItem(value: FacilityStatus.active.key, child: Text(context.l10n.facilityStatusLabel(FacilityStatus.active.key))),
                    DropdownMenuItem(value: FacilityStatus.inactive.key, child: Text(context.l10n.facilityStatusLabel(FacilityStatus.inactive.key))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRestockFrequency,
                  decoration: InputDecoration(
                    labelText: context.l10n.facilities_restockQuestion,
                    helperText: context.l10n.facilities_restockHelper,
                    helperMaxLines: 2,
                  ),
                  items: UsageCalculatorService.restockFrequencyOptions
                      // Shows the label; the facility stores the frequency name.
                      .map((f) => DropdownMenuItem(value: f, child: Text(context.l10n.restockFrequencyLabel(f))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRestockFrequency = val);
                  },
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(dialogError!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                ],
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty || selectedType == null) {
                        setDialogState(() => dialogError = context.l10n.facilities_nameAndTypeRequired);
                        return;
                      }
                      setDialogState(() {
                        dialogError = null;
                        isSaving = true;
                      });

                      try {
                        await _editFacility(
                          facilityId: facility[Fields.facilityId] as String,
                          name: name,
                          type: selectedType!,
                          logoBytes: pendingLogoBytes,
                          removeLogo: logoMarkedForRemoval,
                          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          tagline: taglineController.text.trim().isEmpty
                              ? null
                              : taglineController.text.trim(),
                          licenseNo: licenseController.text.trim().isEmpty ? null : licenseController.text.trim(),
                          tin: tinController.text.trim().isEmpty ? null : tinController.text.trim(),
                          ownership: selectedOwnership,
                          status: selectedStatus,
                          restockFrequency: selectedRestockFrequency,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          dialogError = L10n.current.facilities_saveFailed(FriendlyError.messageFor(e));
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: isSaving
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                    )
                  : Text(context.l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  /// Updates a facility's details: the real facilities/{facilityId} document,
  /// then asks the server to bring every denormalized copy of its name and
  /// type (on the profile of everyone who belongs to it) into line.
  /// Deliberately does NOT touch main.dart's login path or how it reads this
  /// data - that path was specifically built to avoid extra Firestore fetches
  /// during sign-in (a documented, previously-fixed source of login
  /// reliability problems), so instead of eliminating the denormalized copies,
  /// they're kept correct at the moment a rename actually happens.
  Future<void> _editFacility({
    required String facilityId,
    required String name,
    required String type,
    Uint8List? logoBytes,
    bool removeLogo = false,
    String? email,
    String? phone,
    String? address,
    String? description,
    String? tagline,
    String? licenseNo,
    String? tin,
    String? ownership,
    String? status,
    String? restockFrequency,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (logoBytes != null) {
      final storageRef = FirebaseStorage.instance.ref().child('facility_logos/$facilityId.png');
      await storageRef.putData(logoBytes, UploadContentTypes.png);
      final rawDownloadUrl = await storageRef.getDownloadURL();
      // Same cache-busting reasoning as before: Storage returns the
      // same URL for repeat uploads to the same path, so without this,
      // NetworkImage's own cache would keep showing the old logo.
      final downloadUrl = '$rawDownloadUrl&cb=${DateTime.now().millisecondsSinceEpoch}';
      await firestore.collection(Collections.facilities).doc(facilityId).set(
        {'logoUrl': downloadUrl},
        SetOptions(merge: true),
      );
      _logoByFacility[facilityId] = downloadUrl;
    } else if (removeLogo) {
      // Deletes the actual file from Storage too, not just the
      // Firestore reference to it - otherwise the file sits there
      // forever, orphaned, silently taking up storage space.
      try {
        await FirebaseStorage.instance.ref().child('facility_logos/$facilityId.png').delete();
      } catch (e) {
        // File may not exist (e.g. this facility never actually had
        // a logo file, just a stale reference) - not fatal either
        // way, since the Firestore field below is what actually
        // controls what's shown.
        debugPrint('Could not delete logo file (may already be gone): $e');
      }
      await firestore.collection(Collections.facilities).doc(facilityId).update({'logoUrl': FieldValue.delete()});
      _logoByFacility[facilityId] = null;
    }

    await firestore.collection(Collections.facilities).doc(facilityId).update({
      'name': name,
      'type': type,
      'email': email,
      'phone': phone,
      'address': address,
      'description': description,
      'tagline': tagline,
      'licenseNo': licenseNo,
      'tin': tin,
      'ownership': ownership,
      Fields.status: status,
      'restockFrequency': restockFrequency,
      Fields.updatedAt: FieldValue.serverTimestamp(),
    });
    _contactByFacility[facilityId] = {'email': email, 'phone': phone};
    _detailsByFacility[facilityId] = {
      ...?_detailsByFacility[facilityId],
      'address': address,
      'description': description,
      'tagline': tagline,
      'licenseNo': licenseNo,
      'tin': tin,
      'ownership': ownership,
      Fields.status: status,
      'restockFrequency': restockFrequency,
      // The server timestamp itself isn't known client-side until the
      // next fetch re-reads it - using "now" here is a reasonable
      // local approximation so the detail view doesn't show a stale
      // "Last Updated" until fetchFacilities runs again.
      Fields.updatedAt: DateTime.now(),
    };

    // Every member's profile carries a copy of this facility's name and type,
    // which the screens read without a second lookup. The app can't write
    // other people's profiles any more, so the server brings them all into
    // line - asked for here so the change shows at once. (A trigger on the
    // facility document does the same for any other way a name changes, as a
    // safety net.) If this call fails the edit itself has still been saved.
    try {
      await MembershipService().syncFacilityDetails(facilityId);
    } catch (e) {
      debugPrint('Could not refresh the facility details on members\' profiles: $e');
    }

    if (!mounted) return;
    AppFeedback.success(L10n.current.facilities_updated);
    await fetchFacilities();
  }

  // ==================== DELETE FACILITY ====================

  /// Entry point - checks for assigned assistants first and blocks
  /// entirely if any exist, before even offering the confirmation
  /// dialog. This is also re-checked server-side inside the Cloud
  /// Function itself, since a client-side check alone could always be
  /// bypassed - this is purely to give a clear, immediate explanation
  /// rather than letting someone reach a typed-confirmation dialog for
  /// something that's going to be rejected anyway.
  Future<void> _showDeleteFacilityDialog(Map<String, dynamic> facility) async {
    final facilityId = facility[Fields.facilityId] as String;
    if (_checkingBeforeDelete) return;

    // Looked at afresh, NOT read from the copy loaded when this screen opened:
    // that went stale as soon as the last assistant was removed, and Delete
    // Facility kept refusing until the owner signed out and back in. The
    // server re-checks too, so this is only about telling the truth promptly.
    setState(() => _checkingBeforeDelete = true);
    AppFeedback.info(L10n.current.facilities_checkingAssistants);
    List<Map<String, dynamic>> assistants;
    try {
      assistants = await _fetchAssistantsForFacility(facilityId);
      if (mounted) setState(() => _assistantsByFacility[facilityId] = assistants);
    } catch (e) {
      debugPrint('Could not re-check assistants, using the last known list: $e');
      assistants = _assistantsByFacility[facilityId] ?? [];
    } finally {
      if (mounted) setState(() => _checkingBeforeDelete = false);
    }
    if (!mounted) return;
    AppFeedback.messengerKey.currentState?.hideCurrentSnackBar();

    if (assistants.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.facilities_cannotDeleteTitle),
          content: Text(context.l10n.facilities_cannotDeleteMessage(assistants.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_ok),
            ),
          ],
        ),
      );
      return;
    }

    await _showDeleteConfirmationDialog(facility);
  }

  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> facility) async {
    final facilityId = facility[Fields.facilityId] as String;
    // The text to type, compared below: stays the stored name (or this
    // English fallback) in every language. Only the sentences around it are
    // localised.
    final facilityName = facility['name'] as String? ?? 'this facility';
    final isOnlyFacility = facilities.length == 1;
    final confirmController = TextEditingController();
    bool canConfirm = false;
    bool isDeleting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.facilities_deleteTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.facilities_deleteWarning(facilityName),
                  style: const TextStyle(fontSize: AppFontSize.f13),
                ),
                if (isOnlyFacility) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(color: context.colors.dangerAccent.withValues(alpha: AppAlpha.a30)),
                    ),
                    child: Text(
                      context.l10n.facilities_onlyFacilityWarning,
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.dangerAccent, fontWeight: AppFontWeight.semibold),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                Text(context.l10n.facilities_typeToConfirm(facilityName), style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold)),
                const SizedBox(height: AppSpacing.s8),
                TextField(
                  controller: confirmController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) => setDialogState(() => canConfirm = val.trim() == facilityName),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.s10),
                  Text(errorMessage!, style: TextStyle(color: context.colors.dangerAccent, fontSize: AppFontSize.f12_5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
              ),
              child: Text(context.l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: (!canConfirm || isDeleting)
                  ? null
                  : () async {
                      setDialogState(() {
                        isDeleting = true;
                        errorMessage = null;
                      });
                      try {
                        await _deleteFacility(facilityId, isOnlyFacility: isOnlyFacility);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isDeleting = false;
                          errorMessage = L10n.current.facilities_deleteFailed(FriendlyError.messageFor(e));
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(context.colors.dangerAccent),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: isDeleting
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                    )
                  : Text(context.l10n.common_delete),
            ),
          ],
        ),
      ),
    );
  }

  /// Calls the deleteFacility Cloud Function, which does the actual
  /// work - verifying ownership, re-checking for assistants
  /// server-side, cleaning up the Storage logo, updating this admin's
  /// own account, and recursively deleting the facility document and
  /// every subcollection beneath it. This method only handles what
  /// happens client-side afterward: refreshing the list, and moving
  /// the user somewhere sensible if they just deleted the facility
  /// they were actively using.
  Future<void> _deleteFacility(String facilityId, {required bool isOnlyFacility}) async {
    final wasActive = facilityId == activeFacilityId;

    final callable = FirebaseFunctions.instance.httpsCallable('deleteOwnFacility');
    await callable.call({'facilityId': facilityId});

    if (!mounted) return;
    AppFeedback.success(L10n.current.facilities_deleted);

    await fetchFacilities();
    if (!mounted) return;

    // If the facility that was just deleted was the one currently
    // open, this account can't stay "on" it - either move to another
    // facility that still exists, or sign out entirely if none remain,
    // rather than leaving the dashboard pointed at something that's
    // now gone.
    if (wasActive) {
      if (facilities.isNotEmpty) {
        await _switchToFacility(facilities.first);
      } else {
        // Stay signed in and land on the account's own "no facility" screen,
        // where a new facility can be added or the account deleted. This used
        // to sign them out with "Register a new one" - misleading, since
        // signing back in only showed a bare message, and the account's
        // Delete Account (which needs no facilities) was unreachable.
        await returnToAccountDecision();
      }
    }
  }

  Widget buildStatusChip(String status) {
    final chipColor = switch (FacilityStatus.fromKey(status)) {
      FacilityStatus.active => context.colors.success,
      FacilityStatus.inactive => context.colors.danger,
      FacilityStatus.pending => context.colors.warning,
      null => context.colors.textHint,
    };
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: AppAlpha.a20),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Text(context.l10n.facilityStatusLabel(status), style: TextStyle(color: chipColor, fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f12)),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.l10n.facilities_title, style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text(context.l10n.facilities_subtitle,
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.common_refresh,
          onPressed: fetchFacilities,
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: _showAddFacilityDialog,
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: Text(context.l10n.facilities_addTitle),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Builder(
        builder: (context) {
          if (isLoading) return const Center(child: CircularProgressIndicator());
          if (facilities.isEmpty) return Center(child: Text(context.l10n.facilities_noneFound));

          final filtered = facilities.where((f) {
            final name = (f['name'] ?? '').toString().toLowerCase();
            final code = (_detailsByFacility[f[Fields.facilityId]]?[FacilityCodes.field] ?? '').toString().toLowerCase();
            final matchesSearch =
                _searchQuery.isEmpty || name.contains(_searchQuery) || code.contains(_searchQuery);
            final status = _detailsByFacility[f[Fields.facilityId]]?[Fields.status] as String? ?? FacilityStatus.active.key;
            final matchesStatus = _listStatusFilter == 'All' || status == _listStatusFilter;
            return matchesSearch && matchesStatus;
          }).toList();

          Map<String, dynamic>? selectedFacility;
          if (filtered.isNotEmpty) {
            for (final f in filtered) {
              if (f[Fields.facilityId] == _selectedFacilityIdForDetail) {
                selectedFacility = f;
                break;
              }
            }
            selectedFacility ??= filtered.first;
          }

          final detailArea = selectedFacility != null
              ? _buildDetailPanelContent(selectedFacility)
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Center(
                    child: Text(
                      context.l10n.facilities_noMatchFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ),
                );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.medium;

              if (!isWide) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: _listPanelHeight, child: _buildListPanel(filtered)),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: detailArea,
                      ),
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: _listPanelWidth, child: _buildListPanel(filtered)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selectedFacility != null
                        ? SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.s20), child: detailArea)
                        : detailArea,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ==================== LIST PANEL ====================

  Widget _buildListPanel(List<Map<String, dynamic>> filtered) {
    return Container(
      color: context.colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.facilities_searchHint,
                    prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: AppSpacing.s10),
                Row(
                  children: [
                    _statusFilterChip('All'),
                    const SizedBox(width: AppSpacing.s8),
                    _statusFilterChip(FacilityStatus.active.key),
                    const SizedBox(width: AppSpacing.s8),
                    _statusFilterChip(FacilityStatus.inactive.key),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Center(
                      child: Text(
                        context.l10n.facilities_noMatchFilter,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildFacilityListRow(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(String value) {
    final isSelected = _listStatusFilter == value;
    return InkWell(
      onTap: () => setState(() => _listStatusFilter = value),
      borderRadius: BorderRadius.circular(AppRadius.r20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r20),
          border: Border.all(color: isSelected ? context.colors.primary : context.colors.textHint.withValues(alpha: AppAlpha.a30)),
        ),
        // Shows the label; the filter keeps the stored status.
        child: Text(
          value == 'All' ? context.l10n.common_all : context.l10n.facilityStatusLabel(value),
          style: TextStyle(
            fontSize: AppFontSize.f12_5,
            color: isSelected ? context.colors.onPrimary : context.colors.textPrimary,
            fontWeight: isSelected ? AppFontWeight.semibold : AppFontWeight.regular,
          ),
        ),
      ),
    );
  }

  /// A facility's name with its type folded in - "Ukuli Agrovet"
  /// rather than just "Ukuli" - falling back to the name alone if
  /// type isn't set.
  String _nameWithType(Map<String, dynamic> facility) {
    final name = (facility['name'] as String?) ?? context.l10n.common_facility;
    final type = facility['type'] as String?;
    return (type != null && type.isNotEmpty) ? context.l10n.facilities_nameWithType(name, context.l10n.facilityTypeLabel(type)) : name;
  }

  Widget _buildFacilityListRow(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    final isSelected = facilityId == _selectedFacilityIdForDetail;
    final logoUrl = _logoByFacility[facilityId];
    final address = _detailsByFacility[facilityId]?['address'] as String?;
    final status = _detailsByFacility[facilityId]?[Fields.status] as String? ?? FacilityStatus.active.key;

    return InkWell(
      onTap: () => setState(() {
        _selectedFacilityIdForDetail = facilityId;
        _selectedTabIndex = 0;
      }),
      borderRadius: BorderRadius.circular(AppRadius.r10),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s6),
        padding: const EdgeInsets.all(AppSpacing.s10),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a10) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r10),
          border: isSelected ? Border.all(color: context.colors.primary.withValues(alpha: AppAlpha.a30)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.r8),
                border: Border.all(color: context.colors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: logoUrl != null
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i18),
                    )
                  : Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i18),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameWithType(facility),
                    style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && address.isNotEmpty)
                    Text(
                      address,
                      style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: AppSpacing.s3),
                  buildStatusChip(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DETAIL PANEL ====================

  Widget _buildDetailPanelContent(Map<String, dynamic> facility) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumbAndActions(facility),
        const SizedBox(height: AppSpacing.s16),
        _buildHeaderCard(facility),
        const SizedBox(height: AppSpacing.s20),
        _buildMetricsRow(facility),
        const SizedBox(height: AppSpacing.s20),
        _buildTabsRow(),
        const SizedBox(height: AppSpacing.s16),
        _buildTabContent(facility),
      ],
    );
  }

  Widget _buildBreadcrumbAndActions(Map<String, dynamic> facility) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.facilities_title, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f14)),
              Icon(Icons.chevron_right, size: AppIconSize.i16, color: context.colors.textMuted),
              Text(
                facility['name'] ?? context.l10n.common_facility,
                style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: context.l10n.facilities_moreActionsTooltip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.more_vert, size: AppIconSize.i18),
                const SizedBox(width: AppSpacing.s4),
                Text(context.l10n.facilities_moreActions, style: const TextStyle(fontSize: AppFontSize.f13)),
              ],
            ),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditFacilityDialog(facility);
            } else if (value == 'switch') {
              _switchToFacility(facility);
            } else if (value == 'delete') {
              _showDeleteFacilityDialog(facility);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(context.l10n.facilities_editTitle)),
            if (facility[Fields.facilityId] != activeFacilityId)
              PopupMenuItem(value: 'switch', child: Text(context.l10n.facilities_switchToThis)),
            PopupMenuItem(
              value: 'delete',
              child: Text(context.l10n.facilities_deleteTitle, style: TextStyle(color: context.colors.dangerSoft)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    final logoUrl = _logoByFacility[facilityId];
    final contact = _contactByFacility[facilityId];
    final details = _detailsByFacility[facilityId];
    final status = details?[Fields.status] as String? ?? FacilityStatus.active.key;
    final createdAt = details?[Fields.createdAt] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reuses the same logo as the compact list row and card,
          // just larger - a genuinely separate exterior photo upload
          // is out of scope for now.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(color: context.colors.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.s10),
            child: logoUrl != null
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i40),
                  )
                : Icon(Icons.business, color: context.colors.primary, size: AppIconSize.i40),
          ),
          const SizedBox(width: AppSpacing.s20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _nameWithType(facility),
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),
                if (details?['address'] != null && (details!['address'] as String).isNotEmpty)
                  _infoRow(Icons.location_on_outlined, details['address'] as String),
                if (contact?['phone'] != null && contact!['phone']!.isNotEmpty)
                  _infoRow(Icons.phone_outlined, contact['phone']!),
                if (contact?['email'] != null && contact!['email']!.isNotEmpty)
                  _infoRow(Icons.email_outlined, contact['email']!),
                _infoRow(Icons.person_outline, context.l10n.facilities_managerLine(_adminFullName ?? context.l10n.team_you)),
                if (createdAt != null)
                  _infoRow(Icons.calendar_today_outlined, context.l10n.facilities_joinedOn(_formatDate(createdAt))),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s20),
          Container(
            width: 170,
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.facilities_code, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
                Row(
                  children: [
                    Text(
                      (details?[FacilityCodes.field] as String?) ?? '-',
                      style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: AppIconSize.i16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: (details?[FacilityCodes.field] as String?) ?? ''));
                        AppFeedback.success(L10n.current.invite_copied);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),
                Text(context.l10n.facilities_licenseNo, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
                Row(
                  children: [
                    Text(
                      (details?['licenseNo'] as String?)?.isNotEmpty == true
                          ? details!['licenseNo'] as String
                          : context.l10n.facilities_notSet,
                      style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14),
                    ),
                    if ((details?['licenseNo'] as String?)?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.copy, size: AppIconSize.i16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: details!['licenseNo'] as String));
                          AppFeedback.success(L10n.current.invite_copied);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.i16, color: context.colors.textMuted),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: AppFontSize.f13_5))),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(d)}, $hour:$minute $period';
  }

  // ==================== ACTIVITY (shared by the Overview tab's
  // "Recent Activity" and the Activity Log tab) ====================
  //
  // Queries facility-scoped activity_logs directly, rather than
  // reusing ActivityLogScreen - that screen reads its facility from
  // FacilityProvider (the currently-active one), not a passed-in id,
  // so it would show the wrong facility's activity whenever this
  // detail panel is browsing one that isn't the active facility.

  Widget _buildActivityList(String facilityId, {required int limit}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.activityLogs)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            child: Text(context.l10n.dashboard_noActivityYet, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13)),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final actionType = (data['actionType'] as String?) ?? '';
            final description = (data['description'] as String?) ?? '';
            final timestampTs = data['timestamp'] as Timestamp?;
            final color = ActivityTypeStyle.color(actionType, context.colors);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a15), shape: BoxShape.circle),
                    child: Icon(ActivityTypeStyle.icon(actionType), color: color, size: AppIconSize.i18),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionType.isEmpty ? context.l10n.facilities_activityFallback : context.l10n.activityTypeLabel(actionType),
                          style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13),
                        ),
                        Text(description, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
                      ],
                    ),
                  ),
                  if (timestampTs != null)
                    Text(
                      _formatDateTime(timestampTs.toDate()),
                      style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ==================== METRICS ROW ====================

  Widget _buildMetricsRow(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    final stats = _statsByFacility[facilityId];
    final totalProducts = stats?['totalProducts'] as int? ?? 0;
    final sellableProducts = stats?['sellableProducts'] as int? ?? 0;
    final lowStockCount = stats?['lowStockCount'] as int? ?? 0;
    final expiredCount = stats?['expiredCount'] as int? ?? 0;
    final totalAmount = stats?['totalAmount'] as double? ?? 0.0;

    final metrics = [
      (context.l10n.products_totalProducts, '$totalProducts', Icons.inventory_2_outlined, context.colors.brandTeal, context.l10n.facilities_viewProducts, 2),
      (context.l10n.products_sellableTitle, '$sellableProducts', Icons.shopping_cart_outlined, context.colors.success, context.l10n.facilities_viewAll, 2),
      (context.l10n.facilities_lowStockItems, '$lowStockCount', Icons.warning_amber_outlined, context.colors.warning, context.l10n.facilities_viewItems, 2),
      (context.l10n.facilities_expiredItems, '$expiredCount', Icons.remove_shopping_cart_outlined, context.colors.danger, context.l10n.facilities_viewItems, 2),
      (
        context.l10n.facilities_totalSalesThisMonth,
        Money.compact(totalAmount),
        Icons.trending_up,
        context.colors.primary,
        context.l10n.facilities_viewReport,
        3,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < AppBreakpoints.stackSections;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isNarrow ? 2 : 5,
          childAspectRatio: isNarrow ? 2.0 : 1.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: metrics
              .map((m) => _metricCard(
                    label: m.$1,
                    value: m.$2,
                    icon: m.$3,
                    color: m.$4,
                    linkLabel: m.$5,
                    linkTabIndex: m.$6,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String linkLabel,
    required int linkTabIndex,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
                child: Icon(icon, color: color, size: AppIconSize.i16),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.s4),
          InkWell(
            onTap: () => setState(() => _selectedTabIndex = linkTabIndex),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(linkLabel, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
                Icon(Icons.arrow_forward, size: AppIconSize.i12, color: context.colors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TABS ====================

  // In tab order: _buildTabContent switches on the index.
  List<String> _tabLabels() => [
        context.l10n.facilities_tabOverview,
        context.l10n.team_title,
        context.l10n.facilities_tabInventory,
        context.l10n.facilities_tabSales,
        context.l10n.export_activityLog,
        context.l10n.settings_title,
      ];

  /// The Team Members tab, which shows the assistant count.
  static const int _teamTabIndex = 1;

  Widget _buildTabsRow() {
    final facilityId = _selectedFacilityIdForDetail;
    final assistantCount = _assistantsByFacility[facilityId]?.length ?? 0;
    final tabLabels = _tabLabels();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabLabels.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final label = tabLabels[index];
          return InkWell(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? context.colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSize.f13_5,
                      fontWeight: isSelected ? AppFontWeight.bold : AppFontWeight.regular,
                      color: isSelected ? context.colors.primary : context.colors.textPrimary,
                    ),
                  ),
                  // By index, not by the label (the label is translated).
                  if (index == _teamTabIndex && assistantCount > 0) ...[
                    const SizedBox(width: AppSpacing.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: context.colors.divider,
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                      ),
                      child: Text('$assistantCount', style: const TextStyle(fontSize: AppFontSize.f11)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(Map<String, dynamic> facility) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab(facility);
      case 1:
        // Team Members is deliberately just a link into the existing,
        // full Manage Assistants screen rather than a rebuilt view -
        // there's no separate "team members" concept to maintain here.
        return _buildComingSoonTab(
          context.l10n.team_title,
          context.l10n.facilities_teamTabMessage,
          actionLabel: context.l10n.facilities_openTeamMembers,
          onAction: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageAssistantsScreen(initialSearchQuery: facility['name'] as String?),
              ),
            );
            // Whatever was done there (assistants removed or moved) must show
            // here straight away - Delete Facility depends on it.
            if (mounted) await _refreshAssistants();
          },
        );
      case 2:
        return _buildInventorySummaryTab(facility);
      case 3:
        return _buildSalesSummaryTab(facility);
      case 4:
        return _buildActivityLogTab(facility);
      case 5:
        return _buildSettingsTab(facility);
      default:
        return _buildOverviewTab(facility);
    }
  }

  // ==================== INVENTORY SUMMARY ====================

  Future<QuerySnapshot> _getProductsFuture(String facilityId) {
    return _productsFutureByFacility.putIfAbsent(
      facilityId,
      () => FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.products)
          .get(),
    );
  }

  Widget _buildInventorySummaryTab(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    if (facilityId == null) return const SizedBox.shrink();

    return FutureBuilder<QuerySnapshot>(
      future: _getProductsFuture(facilityId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.r14),
              border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
            ),
            child: Text(context.l10n.facilities_noProducts, style: TextStyle(color: context.colors.textMuted)),
          );
        }

        // Category breakdown - a simple count per category, using
        // whatever value each product actually has (falling back to
        // "Uncategorized" the same way the catalog screens do).
        final categoryCounts = <String, int>{};
        final needsAttention = <Map<String, dynamic>>[];
        final now = DateTime.now();

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final category = (data['category'] as String?)?.isNotEmpty == true
              ? data['category'] as String
              : 'Uncategorized';
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

          final stockQty = (data['stockQty'] as num?)?.toDouble() ?? 0;
          final sellableQty = (data['sellableQty'] as num?)?.toDouble() ?? 0;
          final expiryTs = data['expiry'] as Timestamp?;
          final isExpired = expiryTs != null && expiryTs.toDate().isBefore(now);
          final effectiveMinStock = ((data['lowStockThreshold'] ?? data['minStockLevel']) as num?)?.toInt() ??
              Product.defaultLowStockThreshold;
          final isLow = stockQty <= effectiveMinStock ||
              sellableQty <= effectiveMinStock;

          if (isExpired || isLow) {
            needsAttention.add({
              'name': data['name'] as String? ?? context.l10n.reports_colProduct,
              'isExpired': isExpired,
              'isLow': isLow,
              'stockQty': stockQty.toInt(),
              'expiry': expiryTs?.toDate(),
            });
          }
        }

        final sortedCategories = categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.facilities_byCategory, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                  const SizedBox(height: AppSpacing.s12),
                  ...sortedCategories.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Grouped by the stored category; shown through its label.
                            Text(context.l10n.productCategoryLabel(e.key), style: const TextStyle(fontSize: AppFontSize.f13_5)),
                            Text('${e.value}',
                                style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.notifications_needsAttention, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                  const SizedBox(height: AppSpacing.s12),
                  if (needsAttention.isEmpty)
                    Text(context.l10n.facilities_nothingNeedsAttention,
                        style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13))
                  else
                    ...needsAttention.take(10).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(p['name'] as String, style: const TextStyle(fontSize: AppFontSize.f13_5)),
                              ),
                              if (p['isExpired'] as bool)
                                _miniBadge(context.l10n.products_statusExpired, context.colors.danger)
                              else if (p['isLow'] as bool)
                                _miniBadge(context.l10n.products_statusLowStock, context.colors.warning),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppAlpha.a10),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: color.withValues(alpha: AppAlpha.a40)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: AppFontSize.f11, fontWeight: AppFontWeight.semibold)),
    );
  }

  // ==================== SALES SUMMARY ====================

  Future<QuerySnapshot> _getRecentSalesFuture(String facilityId) {
    return _recentSalesFutureByFacility.putIfAbsent(
      facilityId,
      () => FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.sales)
          .orderBy('timestamp', descending: true)
          .limit(AppLimits.facilityRecentSales)
          .get(),
    );
  }

  Widget _buildSalesSummaryTab(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    if (facilityId == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(AppRanges.day);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _salesSummaryService.getRangeTotals(facilityId: facilityId, start: thisMonthStart, end: now),
        _salesSummaryService.getRangeTotals(facilityId: facilityId, start: lastMonthStart, end: lastMonthEnd),
        _getRecentSalesFuture(facilityId),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final thisMonth = snapshot.data![0] as Map<String, double>;
        final lastMonth = snapshot.data![1] as Map<String, double>;
        final recentSales = (snapshot.data![2] as QuerySnapshot).docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _monthComparisonColumn(context.l10n.payments_thisMonth, thisMonth['totalAmount'] ?? 0,
                        (thisMonth['saleCount'] ?? 0).toInt()),
                  ),
                  Container(width: 1, height: 50, color: context.colors.textHint.withValues(alpha: AppAlpha.a20)),
                  Expanded(
                    child: _monthComparisonColumn(context.l10n.export_lastMonth, lastMonth['totalAmount'] ?? 0,
                        (lastMonth['saleCount'] ?? 0).toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.facilities_recentSales, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                  const SizedBox(height: AppSpacing.s12),
                  if (recentSales.isEmpty)
                    Text(context.l10n.facilities_noSalesYet, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13))
                  else
                    ...recentSales.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final clientName = data['clientName'] as String?;
                      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                      final ts = data['timestamp'] as Timestamp?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                clientName?.isNotEmpty == true ? clientName! : context.l10n.facilities_walkInSale,
                                style: const TextStyle(fontSize: AppFontSize.f13_5),
                              ),
                            ),
                            if (ts != null)
                              Text(_formatDate(ts.toDate()),
                                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textHint)),
                            const SizedBox(width: AppSpacing.s10),
                            Text(Money.compact(totalAmount),
                                style: const TextStyle(fontSize: AppFontSize.f13_5, fontWeight: AppFontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _monthComparisonColumn(String label, double amount, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.s4),
        Text(Money.compact(amount), style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f18)),
        Text(context.l10n.facilities_saleCount(count), style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
      ],
    );
  }

  Widget _buildActivityLogTab(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.export_activityLog, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
          const SizedBox(height: AppSpacing.s12),
          if (facilityId != null) _buildActivityList(facilityId, limit: AppLimits.facilityActivityLog),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    final details = _detailsByFacility[facilityId];
    final status = (details?[Fields.status] as String?) ?? FacilityStatus.active.key;
    final retentionDays = (details?['activityLogRetentionDays'] as int?) ?? AppRules.activityLogRetentionDefaultDays;
    final debtOverdueDays = (details?['debtOverdueDays'] as int?) ?? 30;
    final isActive = FacilityStatus.fromKey(status) == FacilityStatus.active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r14),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.facilities_actionsTitle, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              const SizedBox(height: AppSpacing.s4),
              Text(
                context.l10n.facilities_actionsIntro,
                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.s16),
              _settingsActionRow(
                icon: Icons.edit_outlined,
                label: context.l10n.facilities_editDetails,
                subtitle: context.l10n.facilities_editDetailsHint,
                onTap: () => _showEditFacilityDialog(facility),
              ),
              const Divider(height: 24),
              _settingsActionRow(
                icon: isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                label: isActive ? context.l10n.facilities_deactivateThis : context.l10n.facilities_reactivateThis,
                subtitle: isActive
                    ? context.l10n.facilities_deactivateHint
                    : context.l10n.facilities_reactivateHint,
                onTap: () => _confirmToggleFacilityStatus(facility, currentStatus: status),
              ),
              const Divider(height: 24),
              _settingsActionRow(
                icon: Icons.delete_outline,
                label: context.l10n.facilities_deleteThis,
                subtitle: context.l10n.facilities_deleteThisHint,
                iconColor: context.colors.danger,
                onTap: () => _showDeleteFacilityDialog(facility),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r14),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.facilities_retentionTitle,
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      context.l10n.facilities_retentionText(retentionDays),
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: facilityId == null
                    ? null
                    : () => _showFacilityRetentionDialog(facilityId, currentRetention: retentionDays),
                style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
                child: Text(context.l10n.common_change),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r14),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.facilities_overdueTitle,
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      context.l10n.facilities_overdueText(debtOverdueDays),
                      style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: facilityId == null
                    ? null
                    : () => _showDebtOverdueDialog(facilityId, currentThreshold: debtOverdueDays),
                style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
                child: Text(context.l10n.common_change),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsActionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? context.colors.primary, size: AppIconSize.i20),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f13_5)),
                  Text(subtitle, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: AppIconSize.i18, color: context.colors.textDisabled),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggleFacilityStatus(Map<String, dynamic> facility, {required String currentStatus}) async {
    final facilityId = facility[Fields.facilityId] as String?;
    if (facilityId == null) return;
    final isActive = FacilityStatus.fromKey(currentStatus) == FacilityStatus.active;
    final newStatus = isActive ? FacilityStatus.inactive.key : FacilityStatus.active.key;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? context.l10n.facilities_deactivateConfirmTitle : context.l10n.facilities_reactivateConfirmTitle),
        content: Text(
          isActive
              ? context.l10n.facilities_deactivateConfirm('${facility['name']}')
              : context.l10n.facilities_reactivateConfirm('${facility['name']}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? context.l10n.team_deactivate : context.l10n.team_reactivate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).update({
        Fields.status: newStatus,
        Fields.updatedAt: FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _detailsByFacility[facilityId] = {
          ...?_detailsByFacility[facilityId],
          Fields.status: newStatus,
          Fields.updatedAt: DateTime.now(),
        };
      });
      // Saved the stored status; the message shows its label.
      AppFeedback.success(L10n.current.facilities_markedStatus(L10n.current.facilityStatusLabel(newStatus)));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(L10n.current.team_updateStatusFailed, error: e);
    }
  }

  // Direct, facilityId-parameterized replica of ActivityLogScreen's own
  // retention dialog and cleanup logic - that screen reads its
  // facility from FacilityProvider (the active one), not a parameter,
  // so this can't just call into it without risking changing the
  // wrong facility's retention setting.
  static const List<int> _retentionOptions = AppRules.activityLogRetentionOptions;

  Future<void> _showFacilityRetentionDialog(String facilityId, {required int currentRetention}) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.facilities_keepLogsFor),
        content: RadioGroup<int>(
          groupValue: currentRetention,
          onChanged: (val) => Navigator.pop(ctx, val),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _retentionOptions.map((days) {
              return RadioListTile<int>(
                value: days,
                activeColor: context.colors.primary,
                title: Text(context.l10n.debtors_daysCount(days)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_cancel)),
        ],
      ),
    );

    if (selected == null || selected == currentRetention) return;

    // Shrinking the window is the one direction that's actually
    // destructive - picking a shorter window deletes everything
    // outside it immediately, not just going forward. Growing the
    // window deletes nothing and doesn't need this extra step.
    if (selected < currentRetention) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.facilities_deleteOlderLogsTitle),
          content: Text(context.l10n.facilities_deleteOlderLogsMessage(currentRetention, selected)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.common_cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.facilities_deleteAndSwitch(selected), style: TextStyle(color: context.colors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .set({'activityLogRetentionDays': selected}, SetOptions(merge: true));

      // Shrinking the window deletes right away (growing it deletes
      // nothing). Reported honestly - this used to swallow any failure and
      // say "Logs will now be kept for N days" regardless.
      var deleted = 0;
      String? problem;
      if (selected < currentRetention) {
        try {
          deleted = await ActivityLogRetention.deleteExpired(facilityId, selected);
        } catch (e) {
          problem = ActivityLogRetention.explainFailure(e);
        }
      }

      if (!mounted) return;
      setState(() {
        _detailsByFacility[facilityId] = {
          ...?_detailsByFacility[facilityId],
          'activityLogRetentionDays': selected,
        };
      });
      if (problem != null) {
        // explainFailure's text is written to be shown; it is the second line.
        AppFeedback.warning(L10n.current.facilities_retentionSavedNotDeleted(selected),
            detail: problem);
      } else {
        AppFeedback.success(deleted > 0
            ? L10n.current.facilities_retentionSavedDeleted(selected, deleted)
            : L10n.current.facilities_retentionSaved(selected));
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(L10n.current.facilities_saveSettingFailed, error: e);
    }
  }

  static const List<int> _debtOverdueOptions = [7, 14, 30, 60, 90];

  Future<void> _showDebtOverdueDialog(String facilityId, {required int currentThreshold}) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.facilities_overdueAfterTitle),
        content: RadioGroup<int>(
          groupValue: currentThreshold,
          onChanged: (val) => Navigator.pop(ctx, val),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _debtOverdueOptions.map((days) {
              return RadioListTile<int>(
                value: days,
                activeColor: context.colors.primary,
                title: Text(context.l10n.debtors_daysCount(days)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_cancel)),
        ],
      ),
    );

    if (selected == null || selected == currentThreshold) return;

    try {
      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .set({'debtOverdueDays': selected}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _detailsByFacility[facilityId] = {
          ...?_detailsByFacility[facilityId],
          'debtOverdueDays': selected,
        };
      });
      AppFeedback.success(L10n.current.facilities_overdueSaved(selected));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(L10n.current.facilities_saveSettingFailed, error: e);
    }
  }

  Widget _buildComingSoonTab(String title, String message, {String? actionLabel, VoidCallback? onAction}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
          const SizedBox(height: AppSpacing.s6),
          Text(message, style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f13_5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.s12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> facility) {
    final facilityId = facility[Fields.facilityId] as String?;
    final details = _detailsByFacility[facilityId];
    final description = details?['description'] as String?;
    final createdAt = details?[Fields.createdAt] as DateTime?;
    final updatedAt = details?[Fields.updatedAt] as DateTime?;

    final aboutCard = Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.facilities_aboutTitle, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
          const SizedBox(height: AppSpacing.s10),
          if (description != null && description.isNotEmpty) ...[
            Text(description, style: const TextStyle(fontSize: AppFontSize.f13_5, height: 1.5)),
            const SizedBox(height: AppSpacing.s14),
          ],
          _aboutField(context.l10n.facilities_facilityType, context.l10n.facilityTypeLabel(facility['type'] as String? ?? '-')),
          _aboutField(
            context.l10n.facilities_ownership,
            (details?['ownership'] as String?) != null
                ? context.l10n.facilityOwnershipLabel(details!['ownership'] as String)
                : context.l10n.facilities_notSet,
          ),
          _aboutFieldWithChip(context.l10n.common_status, (details?[Fields.status] as String?) ?? FacilityStatus.active.key),
          _aboutField(context.l10n.facilities_createdBy, _adminFullName ?? context.l10n.team_you),
          if (createdAt != null) _aboutField(context.l10n.services_createdOn, _formatDateTime(createdAt)),
          if (updatedAt != null) _aboutField(context.l10n.facilities_lastUpdated, _formatDateTime(updatedAt)),
        ],
      ),
    );

    final activityCard = Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.dashboard_recentActivity, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.facilities_viewAllActivity,
                        style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.primary, fontWeight: AppFontWeight.semibold)),
                    Icon(Icons.arrow_forward, size: AppIconSize.i12, color: context.colors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (facilityId != null) _buildActivityList(facilityId, limit: AppLimits.facilityActivityPreview),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.stackSections;
        if (!isWide) {
          return Column(
            children: [
              aboutCard,
              const SizedBox(height: AppSpacing.s16),
              activityCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: aboutCard),
            const SizedBox(width: AppSpacing.s16),
            Expanded(child: activityCard),
          ],
        );
      },
    );
  }

  Widget _aboutField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutFieldWithChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
          buildStatusChip(value),
        ],
      ),
    );
  }
}
