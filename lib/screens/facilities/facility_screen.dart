import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../providers/facility_provider.dart';
import '../../models/product.dart';
import '../../utils/facility_code_generator.dart';
import '../../utils/facility_activation.dart';
import '../../constants/facility_types.dart';
import '../../services/sales_summary_service.dart';
import '../../utils/force_logout.dart';
import '../../utils/trial_period_helper.dart';
import '../../utils/facility_limit_helper.dart';
import '../../widgets/hover_elevate_card.dart';
import '../admin/manage_assistants_screen.dart';

const Color deepGreen = Color(0xFF2F5D62);
const Color warmAmber = Color(0xFFFFB200);
const Color offWhite = Color(0xFFFDFDF9);

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key});

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
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
  bool _isSearchExpanded = false;
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
          FirebaseFirestore.instance.collection('facilities').doc(facilityId).get();
      final salesTotalsFuture = _salesSummaryService.getRangeTotals(
        facilityId: facilityId,
        start: monthStart,
        end: now,
      );
      final clientCountFuture = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .count()
          .get();
      // Same calculation Dashboard's own "Total Product Value" card
      // uses - read directly from raw product docs here rather than
      // through ProductProvider, since that's scoped to whichever
      // facility is currently active, not every facility a card in
      // this list represents.
      final productsFuture =
          FirebaseFirestore.instance.collection('facilities').doc(facilityId).collection('products').get();

      final facilityDoc = await facilityDocFuture;
      final logoUrl = facilityDoc.data()?['logoUrl'] as String?;
      final email = facilityDoc.data()?['email'] as String?;
      final phone = facilityDoc.data()?['phone'] as String?;
      final address = facilityDoc.data()?['address'] as String?;
      final description = facilityDoc.data()?['description'] as String?;
      final tagline = facilityDoc.data()?['tagline'] as String?;
      final licenseNo = facilityDoc.data()?['licenseNo'] as String?;
      final ownership = facilityDoc.data()?['ownership'] as String?;
      final status = facilityDoc.data()?['status'] as String? ?? 'Active';
      final createdAtTs = facilityDoc.data()?['createdAt'] as Timestamp?;
      final updatedAtTs = facilityDoc.data()?['updatedAt'] as Timestamp?;
      final retentionDays = (facilityDoc.data()?['activityLogRetentionDays'] as num?)?.toInt() ?? 90;
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

        final effectiveMinStock = (data['minStockLevel'] as num?)?.toInt() ?? Product.defaultLowStockThreshold;

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
          'address': address,
          'description': description,
          'tagline': tagline,
          'licenseNo': licenseNo,
          'ownership': ownership,
          'status': status,
          'createdAt': createdAtTs?.toDate(),
          'updatedAt': updatedAtTs?.toDate(),
          'activityLogRetentionDays': retentionDays,
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

  Future<void> fetchFacilities() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final userData = userDoc.data();

      if (userData != null && userData['role'] == 'admin') {
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
          final facilityId = f['facilityId'] as String?;
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
            final activeStillExists = facilityList.any((f) => f['facilityId'] == selectedFacilityId);
            _selectedFacilityIdForDetail =
                activeStillExists ? selectedFacilityId : facilityList.first['facilityId'] as String?;
          }
        });
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load facilities: $e")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAssistantsForFacility(String facilityId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'assistant')
        .where('facilityIds', arrayContains: facilityId)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _switchToFacility(Map<String, dynamic> facility) async {
    await activateFacilityAndGoToDashboard(
      context: context,
      facility: {
        'facilityId': facility['facilityId'],
        'facilityName': facility['name'],
        'facilityType': facility['type'],
      },
      role: 'admin',
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
          title: const Text('Facility Limit Reached'),
          content: Text(
            "You've reached the limit of $maxFacilities facilities per account. "
            'Contact support if you need more.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: deepGreen)),
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

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Facility'),
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
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 85,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            setDialogState(() => pendingLogoBytes = bytes);
                          },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: pendingLogoBytes != null
                          ? Image.memory(pendingLogoBytes!, fit: BoxFit.contain)
                          : Icon(Icons.add_a_photo_outlined, color: Colors.grey[500], size: 26),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Logo (optional)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Facility Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
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
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isAddingFacility
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty || selectedType == null) {
                        setDialogState(() => dialogError = 'Enter a name and select a type');
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
                        final message = e.toString().contains('permission-denied')
                            ? "You've reached the facility limit for your account."
                            : 'Could not add facility: $e';
                        setDialogState(() => dialogError = message);
                      } finally {
                        if (mounted) setState(() => _isAddingFacility = false);
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: _isAddingFacility
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _addFacility({required String name, required String type, Uint8List? logoBytes}) async {
    final uid = currentUser!.uid;
    final code = await generateUniqueFacilityCode();
    final trialExpiresAt = await computeNewFacilityTrialExpiry();

    final docRef = await FirebaseFirestore.instance.collection('facilities').add({
      'name': name,
      'type': type,
      'code': code,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'trialExpiresAt': Timestamp.fromDate(trialExpiresAt),
    });

    // Logo upload needs a facilityId to key the Storage path on, so it
    // can only happen after the document above already exists.
    if (logoBytes != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('facility_logos/${docRef.id}.png');
        await storageRef.putData(logoBytes);
        final rawDownloadUrl = await storageRef.getDownloadURL();
        final downloadUrl = '$rawDownloadUrl&cb=${DateTime.now().millisecondsSinceEpoch}';
        await docRef.set({'logoUrl': downloadUrl}, SetOptions(merge: true));
      } catch (e) {
        // The facility itself was created successfully - a failed logo
        // upload shouldn't be treated as a failed facility creation.
        // It can always be added afterward via Edit.
        debugPrint('Logo upload failed for new facility ${docRef.id}: $e');
      }
    }

    final newFacilityEntry = {
      'facilityId': docRef.id,
      'name': name,
      'type': type,
      'code': code,
    };

    // Both arrays need updating - 'facilities' is what this screen (and
    // the facility picker) actually displays, while 'facilityIds' is
    // what every Firestore rule's isInFacility() check relies on for
    // actual data access. Adding to one without the other would either
    // show a facility that can't be opened, or grant access to one
    // that's invisible in the UI.
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'facilities': FieldValue.arrayUnion([newFacilityEntry]),
      'facilityIds': FieldValue.arrayUnion([docRef.id]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility added'), backgroundColor: Colors.green),
      );
      await fetchFacilities();
    }

    return newFacilityEntry;
  }

  // ==================== EDIT FACILITY ====================

  Future<void> _showEditFacilityDialog(Map<String, dynamic> facility) async {
    final nameController = TextEditingController(text: facility['name'] as String? ?? '');
    final existingContact = _contactByFacility[facility['facilityId']];
    final emailController = TextEditingController(text: existingContact?['email'] ?? '');
    final phoneController = TextEditingController(text: existingContact?['phone'] ?? '');
    final existingDetails = _detailsByFacility[facility['facilityId']];
    final addressController = TextEditingController(text: existingDetails?['address'] as String? ?? '');
    final licenseController = TextEditingController(text: existingDetails?['licenseNo'] as String? ?? '');
    final descriptionController =
        TextEditingController(text: existingDetails?['description'] as String? ?? '');
    final taglineController =
        TextEditingController(text: existingDetails?['tagline'] as String? ?? '');
    String? selectedOwnership = existingDetails?['ownership'] as String?;
    String selectedStatus = existingDetails?['status'] as String? ?? 'Active';
    String? selectedType = facility['type'] as String?;
    String? dialogError;
    bool isSaving = false;
    Uint8List? pendingLogoBytes;
    // True once the user has explicitly chosen to remove the existing
    // logo - kept separate from "no change made" so _editFacility
    // knows to actually delete it, not just leave it untouched.
    bool logoMarkedForRemoval = false;
    final existingLogoUrl = _logoByFacility[facility['facilityId']];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Facility'),
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
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 85,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: pendingLogoBytes != null
                              ? Image.memory(pendingLogoBytes!, fit: BoxFit.contain)
                              : (existingLogoUrl != null && !logoMarkedForRemoval
                                  ? Image.network(
                                      existingLogoUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.business, color: deepGreen, size: 32),
                                    )
                                  : Icon(Icons.business, color: deepGreen, size: 32)),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: warmAmber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Tap to change logo',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
                if ((pendingLogoBytes != null || existingLogoUrl != null) && !logoMarkedForRemoval) ...[
                  const SizedBox(height: 2),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isSaving
                          ? null
                          : () => setDialogState(() {
                                pendingLogoBytes = null;
                                logoMarkedForRemoval = true;
                              }),
                      child: const Text(
                        'Remove logo',
                        style: TextStyle(fontSize: 11, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Facility Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: kFacilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Business Email (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Business Phone (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taglineController,
                  decoration: const InputDecoration(
                    labelText: 'Tagline (optional)',
                    hintText: 'e.g. Agrovet & Animal Care',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Number (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedOwnership,
                  decoration: const InputDecoration(labelText: 'Ownership (optional)'),
                  items: const [
                    DropdownMenuItem(value: 'Owned', child: Text('Owned')),
                    DropdownMenuItem(value: 'Rented', child: Text('Rented')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedOwnership = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
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
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty || selectedType == null) {
                        setDialogState(() => dialogError = 'Enter a name and select a type');
                        return;
                      }
                      setDialogState(() {
                        dialogError = null;
                        isSaving = true;
                      });

                      try {
                        await _editFacility(
                          facilityId: facility['facilityId'] as String,
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
                          ownership: selectedOwnership,
                          status: selectedStatus,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          dialogError = 'Could not save changes: $e';
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Updates a facility's name/type everywhere it's stored - the real
  /// facilities/{facilityId} document, plus every denormalized copy of
  /// it (the editing Admin's own account, and every Assistant belonging
  /// to this facility). Deliberately does NOT touch main.dart's login
  /// path or how it reads this data - that path was specifically built
  /// to avoid extra Firestore fetches during sign-in (a documented,
  /// previously-fixed source of login reliability problems), so instead
  /// of eliminating the denormalized copies, this keeps every one of
  /// them correct at the moment a rename actually happens.
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
    String? ownership,
    String? status,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (logoBytes != null) {
      final storageRef = FirebaseStorage.instance.ref().child('facility_logos/$facilityId.png');
      await storageRef.putData(logoBytes);
      final rawDownloadUrl = await storageRef.getDownloadURL();
      // Same cache-busting reasoning as before: Storage returns the
      // same URL for repeat uploads to the same path, so without this,
      // NetworkImage's own cache would keep showing the old logo.
      final downloadUrl = '$rawDownloadUrl&cb=${DateTime.now().millisecondsSinceEpoch}';
      await firestore.collection('facilities').doc(facilityId).set(
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
      await firestore.collection('facilities').doc(facilityId).update({'logoUrl': FieldValue.delete()});
      _logoByFacility[facilityId] = null;
    }

    await firestore.collection('facilities').doc(facilityId).update({
      'name': name,
      'type': type,
      'email': email,
      'phone': phone,
      'address': address,
      'description': description,
      'tagline': tagline,
      'licenseNo': licenseNo,
      'ownership': ownership,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _contactByFacility[facilityId] = {'email': email, 'phone': phone};
    _detailsByFacility[facilityId] = {
      ...?_detailsByFacility[facilityId],
      'address': address,
      'description': description,
      'tagline': tagline,
      'licenseNo': licenseNo,
      'ownership': ownership,
      'status': status,
      // The server timestamp itself isn't known client-side until the
      // next fetch re-reads it - using "now" here is a reasonable
      // local approximation so the detail view doesn't show a stale
      // "Last Updated" until fetchFacilities runs again.
      'updatedAt': DateTime.now(),
    };

    final batch = firestore.batch();

    // The editing Admin's own account.
    final selfRef = firestore.collection('users').doc(currentUser!.uid);
    final selfDoc = await selfRef.get();
    final selfFacilities = List<Map<String, dynamic>>.from(selfDoc.data()?['facilities'] ?? []);
    final updatedSelfFacilities = selfFacilities.map((f) {
      if (f['facilityId'] == facilityId) {
        return {...f, 'name': name, 'type': type};
      }
      return f;
    }).toList();
    batch.update(selfRef, {'facilities': updatedSelfFacilities});

    // Every Assistant belonging to this facility.
    final assistantsSnap = await firestore
        .collection('users')
        .where('role', isEqualTo: 'assistant')
        .where('facilityIds', arrayContains: facilityId)
        .get();

    for (final doc in assistantsSnap.docs) {
      final assistantFacilities = List<Map<String, dynamic>>.from(doc.data()['facilities'] ?? []);
      final updatedAssistantFacilities = assistantFacilities.map((f) {
        if (f['facilityId'] == facilityId) {
          return {...f, 'name': name, 'type': type};
        }
        return f;
      }).toList();
      batch.update(doc.reference, {'facilities': updatedAssistantFacilities});
    }

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facility updated'), backgroundColor: Colors.green),
    );
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
    final facilityId = facility['facilityId'] as String;
    final assistants = _assistantsByFacility[facilityId] ?? [];

    if (assistants.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Facility'),
          content: Text(
            'This facility still has ${assistants.length} assistant${assistants.length == 1 ? '' : 's'} '
            'assigned. Remove or reassign ${assistants.length == 1 ? 'them' : 'all of them'} first, '
            'then try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await _showDeleteConfirmationDialog(facility);
  }

  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> facility) async {
    final facilityId = facility['facilityId'] as String;
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
          title: const Text('Delete Facility'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This permanently deletes "$facilityName" and everything in it - '
                  'products, sales, clients, debts, payments, and history. This cannot be undone.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (isOnlyFacility) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'This is your only facility. Deleting it will leave your account with no facility at all.',
                      style: TextStyle(fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Type "$facilityName" to confirm:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) => setDialogState(() => canConfirm = val.trim() == facilityName),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return warmAmber;
                  return deepGreen;
                }),
              ),
              child: const Text('Cancel'),
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
                          errorMessage = 'Could not delete: $e';
                        });
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.redAccent),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facility deleted'), backgroundColor: Colors.green),
    );

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
        await forceLogoutAndShowLogin(
          message: isOnlyFacility
              ? 'Your facility was deleted. Register a new one, or ask your Platform Admin for help.'
              : 'That facility was deleted.',
        );
      }
    }
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: deepGreen)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
      ],
    );
  }

  /// "1,200,000" -> "1.2M", "45,000" -> "45K" - keeps the stats row
  /// readable at a glance instead of a long, precise figure that
  /// doesn't matter for a quick "how's this shop doing" check.
  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'active':
        chipColor = Colors.green;
        break;
      case 'inactive':
        chipColor = Colors.red;
        break;
      case 'pending':
        chipColor = Colors.orange;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: chipColor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }


  @override
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
      toolbarHeight: 72,
      title: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Facilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.black87)),
          Text('Manage all your veterinary facilities and branches',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: fetchFacilities,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: _showAddFacilityDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Facility'),
            style: ElevatedButton.styleFrom(
              backgroundColor: deepGreen,
              foregroundColor: offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Builder(
        builder: (context) {
          if (isLoading) return const Center(child: CircularProgressIndicator());
          if (facilities.isEmpty) return const Center(child: Text("No facilities found."));

          final filtered = facilities.where((f) {
            final name = (f['name'] ?? '').toString().toLowerCase();
            final code = (f['code'] ?? '').toString().toLowerCase();
            final matchesSearch =
                _searchQuery.isEmpty || name.contains(_searchQuery) || code.contains(_searchQuery);
            final status = _detailsByFacility[f['facilityId']]?['status'] as String? ?? 'Active';
            final matchesStatus = _listStatusFilter == 'All' || status == _listStatusFilter;
            return matchesSearch && matchesStatus;
          }).toList();

          Map<String, dynamic>? selectedFacility;
          if (filtered.isNotEmpty) {
            for (final f in filtered) {
              if (f['facilityId'] == _selectedFacilityIdForDetail) {
                selectedFacility = f;
                break;
              }
            }
            selectedFacility ??= filtered.first;
          }

          final detailArea = selectedFacility != null
              ? _buildDetailPanelContent(selectedFacility)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No facilities match your filters. Try a different search or status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (!isWide) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 360, child: _buildListPanel(filtered)),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: detailArea,
                      ),
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: _buildListPanel(filtered)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selectedFacility != null
                        ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: detailArea)
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
      color: offWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search facilities...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statusFilterChip('All'),
                    const SizedBox(width: 8),
                    _statusFilterChip('Active'),
                    const SizedBox(width: 8),
                    _statusFilterChip('Inactive'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No facilities match this filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? deepGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? deepGreen : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFacilityListRow(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    final isSelected = facilityId == _selectedFacilityIdForDetail;
    final logoUrl = _logoByFacility[facilityId];
    final address = _detailsByFacility[facilityId]?['address'] as String?;
    final status = _detailsByFacility[facilityId]?['status'] as String? ?? 'Active';

    return InkWell(
      onTap: () => setState(() {
        _selectedFacilityIdForDetail = facilityId;
        _selectedTabIndex = 0;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? deepGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: deepGreen.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(4),
              child: logoUrl != null
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.business, color: deepGreen, size: 18),
                    )
                  : Icon(Icons.business, color: deepGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility['name'] ?? 'Facility',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && address.isNotEmpty)
                    Text(
                      address,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
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

  Widget _buildDetailPanel(Map<String, dynamic> facility) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildDetailPanelContent(facility),
    );
  }

  Widget _buildDetailPanelContent(Map<String, dynamic> facility) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumbAndActions(facility),
        const SizedBox(height: 16),
        _buildHeaderCard(facility),
        const SizedBox(height: 20),
        _buildMetricsRow(facility),
        const SizedBox(height: 20),
        _buildTabsRow(),
        const SizedBox(height: 16),
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
              Text('Facilities', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
              Text(
                facility['name'] ?? 'Facility',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_vert, size: 18),
                SizedBox(width: 4),
                Text('More Actions', style: TextStyle(fontSize: 13)),
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
            const PopupMenuItem(value: 'edit', child: Text('Edit Facility')),
            if (facility['facilityId'] != activeFacilityId)
              const PopupMenuItem(value: 'switch', child: Text('Switch to This Facility')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete Facility', style: TextStyle(color: Colors.red[400])),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    final logoUrl = _logoByFacility[facilityId];
    final contact = _contactByFacility[facilityId];
    final details = _detailsByFacility[facilityId];
    final status = details?['status'] as String? ?? 'Active';
    final createdAt = details?['createdAt'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(10),
            child: logoUrl != null
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.business, color: deepGreen, size: 40),
                  )
                : Icon(Icons.business, color: deepGreen, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        facility['name'] ?? 'Facility',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 10),
                if (details?['address'] != null && (details!['address'] as String).isNotEmpty)
                  _infoRow(Icons.location_on_outlined, details['address'] as String),
                if (contact?['phone'] != null && contact!['phone']!.isNotEmpty)
                  _infoRow(Icons.phone_outlined, contact['phone']!),
                if (contact?['email'] != null && contact!['email']!.isNotEmpty)
                  _infoRow(Icons.email_outlined, contact['email']!),
                _infoRow(Icons.person_outline, '${_adminFullName ?? 'You'} (Manager)'),
                if (createdAt != null)
                  _infoRow(Icons.calendar_today_outlined, 'Joined on ${_formatDate(createdAt)}'),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: offWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Facility Code', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Row(
                  children: [
                    Text(
                      facility['code'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 15),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: facility['code'] ?? ''));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('License No.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Row(
                  children: [
                    Text(
                      (details?['licenseNo'] as String?)?.isNotEmpty == true
                          ? details!['licenseNo'] as String
                          : 'Not set',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if ((details?['licenseNo'] as String?)?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 15),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: details!['licenseNo'] as String));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
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

  IconData _activityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _activityColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'inventory move':
        return Colors.blue;
      case 'products':
        return Colors.green;
      case 'sales':
        return warmAmber;
      case 'services':
        return Colors.purple;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      case 'admin':
        return Colors.red;
      default:
        return deepGreen;
    }
  }

  Widget _buildActivityList(String facilityId, {required int limit}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No activity yet.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final actionType = (data['actionType'] as String?) ?? '';
            final description = (data['description'] as String?) ?? '';
            final timestampTs = data['timestamp'] as Timestamp?;
            final color = _activityColor(actionType);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(_activityIcon(actionType), color: color, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionType.isEmpty ? 'Activity' : actionType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(description, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                  if (timestampTs != null)
                    Text(
                      _formatDateTime(timestampTs.toDate()),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
    final facilityId = facility['facilityId'] as String?;
    final stats = _statsByFacility[facilityId];
    final totalProducts = stats?['totalProducts'] as int? ?? 0;
    final sellableProducts = stats?['sellableProducts'] as int? ?? 0;
    final lowStockCount = stats?['lowStockCount'] as int? ?? 0;
    final expiredCount = stats?['expiredCount'] as int? ?? 0;
    final totalAmount = stats?['totalAmount'] as double? ?? 0.0;

    final metrics = [
      ('Total Products', '$totalProducts', Icons.inventory_2_outlined, const Color(0xFF3E8E82), 'View Products', 2),
      ('Sellable Products', '$sellableProducts', Icons.shopping_cart_outlined, Colors.green, 'View All', 2),
      ('Low Stock Items', '$lowStockCount', Icons.warning_amber_outlined, Colors.orange, 'View Items', 2),
      ('Expired Items', '$expiredCount', Icons.remove_shopping_cart_outlined, Colors.red, 'View Items', 2),
      (
        'Total Sales (This Month)',
        'TZS ${_formatCompact(totalAmount)}',
        Icons.trending_up,
        deepGreen,
        'View Report',
        3,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
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
                    BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _selectedTabIndex = linkTabIndex),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(linkLabel, style: TextStyle(fontSize: 11.5, color: deepGreen, fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_forward, size: 12, color: deepGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TABS ====================

  static const List<String> _tabLabels = [
    'Overview',
    'Team Members',
    'Inventory Summary',
    'Sales Summary',
    'Activity Log',
    'Settings',
  ];

  Widget _buildTabsRow() {
    final facilityId = _selectedFacilityIdForDetail;
    final assistantCount = _assistantsByFacility[facilityId]?.length ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabLabels.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final label = _tabLabels[index];
          return InkWell(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? deepGreen : Colors.transparent,
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
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? deepGreen : Colors.black87,
                    ),
                  ),
                  if (label == 'Team Members' && assistantCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$assistantCount', style: const TextStyle(fontSize: 11)),
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
          'Team Members',
          'Manage this facility\'s team from the Manage Assistants screen.',
          actionLabel: 'Open Manage Assistants',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageAssistantsScreen(initialSearchQuery: facility['name'] as String?),
              ),
            );
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
          .collection('facilities')
          .doc(facilityId)
          .collection('products')
          .get(),
    );
  }

  Widget _buildInventorySummaryTab(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Text('No products in this facility yet.', style: TextStyle(color: Colors.grey[600])),
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
          final effectiveMinStock = (data['minStockLevel'] as num?)?.toInt() ?? Product.defaultLowStockThreshold;
          final isLow = stockQty <= effectiveMinStock ||
              sellableQty <= effectiveMinStock;

          if (isExpired || isLow) {
            needsAttention.add({
              'name': data['name'] as String? ?? 'Product',
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...sortedCategories.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(fontSize: 13.5)),
                            Text('${e.value}',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Needs Attention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (needsAttention.isEmpty)
                    Text('Nothing low on stock or expired right now.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13))
                  else
                    ...needsAttention.take(10).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(p['name'] as String, style: const TextStyle(fontSize: 13.5)),
                              ),
                              if (p['isExpired'] as bool)
                                _miniBadge('Expired', Colors.red)
                              else if (p['isLow'] as bool)
                                _miniBadge('Low Stock', Colors.orange),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== SALES SUMMARY ====================

  Future<QuerySnapshot> _getRecentSalesFuture(String facilityId) {
    return _recentSalesFutureByFacility.putIfAbsent(
      facilityId,
      () => FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('sales')
          .orderBy('timestamp', descending: true)
          .limit(8)
          .get(),
    );
  }

  Widget _buildSalesSummaryTab(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    if (facilityId == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));

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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _monthComparisonColumn('This Month', thisMonth['totalAmount'] ?? 0,
                        (thisMonth['saleCount'] ?? 0).toInt()),
                  ),
                  Container(width: 1, height: 50, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: _monthComparisonColumn('Last Month', lastMonth['totalAmount'] ?? 0,
                        (lastMonth['saleCount'] ?? 0).toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (recentSales.isEmpty)
                    Text('No sales recorded yet.', style: TextStyle(color: Colors.grey[600], fontSize: 13))
                  else
                    ...recentSales.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final clientName = data['clientName'] as String?;
                      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                      final ts = data['timestamp'] as Timestamp?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                clientName?.isNotEmpty == true ? clientName! : 'Walk-in sale',
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                            if (ts != null)
                              Text(_formatDate(ts.toDate()),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 10),
                            Text('Tsh ${_formatCompact(totalAmount)}',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text('Tsh ${_formatCompact(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text('$count sale${count == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActivityLogTab(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          if (facilityId != null) _buildActivityList(facilityId, limit: 50),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    final details = _detailsByFacility[facilityId];
    final status = (details?['status'] as String?) ?? 'Active';
    final retentionDays = (details?['activityLogRetentionDays'] as int?) ?? 90;
    final isActive = status.toLowerCase() == 'active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Facility Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                'Settings specific to this facility. For your account, notifications, '
                'printer, currency, and app-wide preferences, use the main Settings screen.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _settingsActionRow(
                icon: Icons.edit_outlined,
                label: 'Edit Facility Details',
                subtitle: 'Name, type, logo, contact info, license, and more.',
                onTap: () => _showEditFacilityDialog(facility),
              ),
              const Divider(height: 24),
              _settingsActionRow(
                icon: isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                label: isActive ? 'Deactivate This Facility' : 'Reactivate This Facility',
                subtitle: isActive
                    ? 'Marks this facility as inactive. It stays in your list but is flagged as not operating.'
                    : 'Marks this facility as active again.',
                onTap: () => _confirmToggleFacilityStatus(facility, currentStatus: status),
              ),
              const Divider(height: 24),
              _settingsActionRow(
                icon: Icons.delete_outline,
                label: 'Delete This Facility',
                subtitle: 'Permanently removes this facility and its data. This cannot be undone.',
                iconColor: Colors.red,
                onTap: () => _showDeleteFacilityDialog(facility),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Activity Log Retention',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Logs older than this are automatically deleted for this facility. Currently: $retentionDays days.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: facilityId == null
                    ? null
                    : () => _showFacilityRetentionDialog(facilityId, currentRetention: retentionDays),
                style: OutlinedButton.styleFrom(foregroundColor: deepGreen),
                child: const Text('Change'),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? deepGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggleFacilityStatus(Map<String, dynamic> facility, {required String currentStatus}) async {
    final facilityId = facility['facilityId'] as String?;
    if (facilityId == null) return;
    final isActive = currentStatus.toLowerCase() == 'active';
    final newStatus = isActive ? 'Inactive' : 'Active';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate Facility?' : 'Reactivate Facility?'),
        content: Text(
          isActive
              ? '${facility['name']} will be marked Inactive. It stays in your facilities list but is flagged as not operating.'
              : '${facility['name']} will be marked Active again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('facilities').doc(facilityId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _detailsByFacility[facilityId] = {
          ...?_detailsByFacility[facilityId],
          'status': newStatus,
          'updatedAt': DateTime.now(),
        };
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Facility marked $newStatus'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update status: $e'), backgroundColor: Colors.redAccent));
    }
  }

  // Direct, facilityId-parameterized replica of ActivityLogScreen's own
  // retention dialog and cleanup logic - that screen reads its
  // facility from FacilityProvider (the active one), not a parameter,
  // so this can't just call into it without risking changing the
  // wrong facility's retention setting.
  static const List<int> _retentionOptions = [14, 30, 60, 90];

  Future<void> _showFacilityRetentionDialog(String facilityId, {required int currentRetention}) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep Logs For'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _retentionOptions.map((days) {
            return RadioListTile<int>(
              value: days,
              groupValue: currentRetention,
              activeColor: deepGreen,
              title: Text('$days days'),
              onChanged: (val) => Navigator.pop(ctx, val),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (selected == null || selected == currentRetention) return;

    // Shrinking the window is the one direction that's actually
    // destructive - picking a shorter window deletes everything
    // outside it immediately, not just going forward. Growing the
    // window deletes nothing and doesn't need this extra step.
    if (selected < currentRetention) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Older Logs Now?'),
          content: Text(
            'Logs are currently kept for $currentRetention days. Switching to $selected days '
            'will permanently delete every log older than $selected days right now - '
            'not just going forward. This cannot be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete and switch to $selected days', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .set({'activityLogRetentionDays': selected}, SetOptions(merge: true));

      if (selected < currentRetention) {
        await _cleanupOldFacilityLogs(facilityId, retentionDays: selected);
      }

      if (!mounted) return;
      setState(() {
        _detailsByFacility[facilityId] = {
          ...?_detailsByFacility[facilityId],
          'activityLogRetentionDays': selected,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logs will now be kept for $selected days'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _cleanupOldFacilityLogs(String facilityId, {required int retentionDays}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final oldLogs = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (oldLogs.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 500) break; // Safety limit, same as ActivityLogScreen's own cleanup.
      }
      await batch.commit();
      debugPrint('Deleted $count old activity logs (>$retentionDays days) for $facilityId');
    } catch (e) {
      debugPrint('Failed to cleanup old logs for $facilityId: $e');
    }
  }

  Widget _buildComingSoonTab(String title, String message, {String? actionLabel, VoidCallback? onAction}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(foregroundColor: deepGreen),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> facility) {
    final facilityId = facility['facilityId'] as String?;
    final details = _detailsByFacility[facilityId];
    final description = details?['description'] as String?;
    final createdAt = details?['createdAt'] as DateTime?;
    final updatedAt = details?['updatedAt'] as DateTime?;

    final aboutCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this facility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (description != null && description.isNotEmpty) ...[
            Text(description, style: const TextStyle(fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 14),
          ],
          _aboutField('Facility Type', facility['type'] as String? ?? '-'),
          _aboutField('Ownership', (details?['ownership'] as String?) ?? 'Not set'),
          _aboutFieldWithChip('Status', (details?['status'] as String?) ?? 'Active'),
          _aboutField('Created By', _adminFullName ?? 'You'),
          if (createdAt != null) _aboutField('Created On', _formatDateTime(createdAt)),
          if (updatedAt != null) _aboutField('Last Updated', _formatDateTime(updatedAt)),
        ],
      ),
    );

    final activityCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all activity',
                        style: TextStyle(fontSize: 12.5, color: deepGreen, fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_forward, size: 12, color: deepGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (facilityId != null) _buildActivityList(facilityId, limit: 4),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (!isWide) {
          return Column(
            children: [
              aboutCard,
              const SizedBox(height: 16),
              activityCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: aboutCard),
            const SizedBox(width: 16),
            Expanded(child: activityCard),
          ],
        );
      },
    );
  }

  Widget _aboutField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutFieldWithChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          buildStatusChip(value),
        ],
      ),
    );
  }
}
