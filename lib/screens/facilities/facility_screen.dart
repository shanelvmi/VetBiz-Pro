import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../providers/facility_provider.dart';
import '../../utils/facility_code_generator.dart';
import '../../utils/facility_activation.dart';
import '../../constants/facility_types.dart';
import '../../services/sales_summary_service.dart';
import '../../utils/force_logout.dart';

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
  final Map<String, Map<String, dynamic>> _statsByFacility = {};
  final SalesSummaryService _salesSummaryService = SalesSummaryService();

  bool _isAddingFacility = false;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    fetchFacilities();
  }

  /// Fetches a facility's logo URL and this month's quick stats (sales
  /// count, revenue, client count) in one pass. Uses the precomputed
  /// dailySummaries aggregate rather than scanning every sale, and a
  /// server-side count() for clients rather than downloading every
  /// client document just to count them.
  Future<void> _fetchFacilityExtras(String facilityId) async {
    try {
      final facilityDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .get();
      final logoUrl = facilityDoc.data()?['logoUrl'] as String?;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final salesTotals = await _salesSummaryService.getRangeTotals(
        facilityId: facilityId,
        start: monthStart,
        end: now,
      );

      final clientCountSnap = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .count()
          .get();

      if (!mounted) return;
      setState(() {
        _logoByFacility[facilityId] = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;
        _statsByFacility[facilityId] = {
          'saleCount': salesTotals['saleCount']?.toInt() ?? 0,
          'totalAmount': salesTotals['totalAmount'] ?? 0.0,
          'clientCount': clientCountSnap.count ?? 0,
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
        final assistantsMap = <String, List<Map<String, dynamic>>>{};
        for (final f in facilityList) {
          final facilityId = f['facilityId'] as String?;
          if (facilityId == null) continue;
          assistantsMap[facilityId] = await _fetchAssistantsForFacility(facilityId);
          await _fetchFacilityExtras(facilityId);
        }

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
    final nameController = TextEditingController();
    String? selectedType;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Facility'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        await _addFacility(name: name, type: selectedType!);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() => dialogError = 'Could not add facility: $e');
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

  Future<void> _addFacility({required String name, required String type}) async {
    final uid = currentUser!.uid;
    final code = await generateUniqueFacilityCode();

    final docRef = await FirebaseFirestore.instance.collection('facilities').add({
      'name': name,
      'type': type,
      'code': code,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facility added'), backgroundColor: Colors.green),
    );
    await fetchFacilities();
  }

  // ==================== EDIT FACILITY ====================

  Future<void> _showEditFacilityDialog(Map<String, dynamic> facility) async {
    final nameController = TextEditingController(text: facility['name'] as String? ?? '');
    String? selectedType = facility['type'] as String?;
    String? dialogError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Facility'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
  }) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('facilities').doc(facilityId).update({
      'name': name,
      'type': type,
    });

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

  Widget buildFacilityCard(Map<String, dynamic> facility) {
    final isActive = facility['facilityId'] == activeFacilityId;
    final assistants = _assistantsByFacility[facility['facilityId']] ?? [];
    final logoUrl = _logoByFacility[facility['facilityId']];
    final stats = _statsByFacility[facility['facilityId']];

    return Card(
      color: Colors.white,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The facility's own uploaded logo when it has one -
                // ClipOval + Image.network with a graceful fallback to
                // the generic building icon, both for facilities that
                // never uploaded one and for a failed image load.
                ClipOval(
                  child: logoUrl != null
                      ? Image.network(
                          logoUrl,
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.business, color: deepGreen),
                        )
                      : Icon(Icons.business, color: deepGreen),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facility['name'] ?? 'Facility',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deepGreen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Facility',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return deepGreen;
                    }),
                  ),
                  onPressed: () => _showEditFacilityDialog(facility),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete Facility',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return Colors.red.shade900;
                      return Colors.redAccent;
                    }),
                  ),
                  onPressed: () => _showDeleteFacilityDialog(facility),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: warmAmber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Opened',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Code: ${facility['code']}",
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Code',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return deepGreen;
                    }),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: facility['code'] ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Copied to clipboard!")),
                    );
                  },
                ),
              ],
            ),
            Text("Type: ${facility['type']}", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            // This month's quick numbers - the whole point of a
            // multi-facility owner opening this screen is usually "how
            // are my shops doing right now", and previously answering
            // that meant switching into each one individually just to
            // check.
            if (stats != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: deepGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn('${stats['saleCount']}', 'Sales this month'),
                    _statColumn(
                      'Tsh ${_formatCompact((stats['totalAmount'] as double?) ?? 0.0)}',
                      'Revenue this month',
                    ),
                    _statColumn('${stats['clientCount']}', 'Clients'),
                  ],
                ),
              ),
            Text("Admin: ${_adminFullName ?? 'You'}", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            const Text("Assistants:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (assistants.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text('None yet', style: TextStyle(fontSize: 13, color: Colors.grey)),
              )
            else
              ...assistants.map((a) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(a['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 14))),
                        buildStatusChip(a['status'] ?? 'pending'),
                      ],
                    ),
                  )),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Currently Open'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[500],
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _switchToFacility(facility),
                      icon: const Icon(Icons.sync_alt, size: 18),
                      label: const Text('Switch to This Facility'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) return warmAmber;
                          return deepGreen;
                        }),
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;

        if (isLargeScreen) {
          return MasonryGridView.count(
            padding: const EdgeInsets.symmetric(vertical: 8),
            crossAxisCount: 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            itemCount: facilities.length,
            itemBuilder: (context, index) => buildFacilityCard(facilities[index]),
          );
        }

        return ListView.builder(
          itemCount: facilities.length,
          itemBuilder: (context, index) => buildFacilityCard(facilities[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: deepGreen,
        iconTheme: const IconThemeData(color: offWhite),
        title: const Text(
          'My Facilities',
          style: TextStyle(color: offWhite),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: offWhite),
            tooltip: 'Refresh Facilities',
            onPressed: fetchFacilities,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : facilities.isEmpty
              ? const Center(child: Text("No facilities found."))
              : _buildFacilitiesList(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: deepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Facility'),
        onPressed: _showAddFacilityDialog,
      ),
    );
  }
}
