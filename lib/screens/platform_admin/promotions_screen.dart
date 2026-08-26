import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../constants/subscription_plans.dart';
import '../../models/promotion.dart';
import '../../widgets/hover_elevate_card.dart';
import '../../widgets/firestore_error_view.dart';

/// Manage subscription discounts/offers - "Nanenane Sale", a
/// month-end push, a renew-now discount for facilities about to
/// expire. Built as a real list-management screen from day one (not
/// a single settings card), since that's the shape V2 (several
/// coexisting promotions) actually needs - V1 just happens to only
/// ever have one active at a time, enforced in setActivePromotion(),
/// not by this screen's own structure.
class PromotionsScreen extends StatelessWidget {
  final bool isModal;
  const PromotionsScreen({super.key, this.isModal = false});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDF9),
      appBar: AppBar(
        title: const Text('Promotions'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !isModal,
        leading: isModal
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: StreamBuilder<List<Promotion>>(
            stream: streamAllPromotions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return FirestoreErrorView(error: snapshot.error);
              }

              final promotions = snapshot.data ?? [];

              if (promotions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No promotions yet', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Create one for a seasonal sale or a renewal push.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: promotions.length,
                itemBuilder: (context, index) => _PromotionCard(promotion: promotions[index]),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('New Promotion'),
        onPressed: () => _showPromotionEditor(context),
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  final Promotion promotion;
  const _PromotionCard({required this.promotion});

  static const Color primaryColor = PromotionsScreen.primaryColor;

  @override
  Widget build(BuildContext context) {
    final isLive = promotion.active && !promotion.hasEnded;
    final statusColor = isLive ? Colors.green : (promotion.active ? Colors.orange : Colors.grey);
    final statusLabel = isLive ? 'LIVE' : (promotion.active ? 'ENDED' : 'OFF');

    return HoverElevateCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The headline number - deliberately large, this is
                // the one thing that should catch the eye first.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${promotion.discountPercent.toStringAsFixed(promotion.discountPercent % 1 == 0 ? 0 : 1)}%\nOFF',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              promotion.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLive)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                  ),
                                Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.sell_outlined,
                            label: promotion.appliesToAllPlans
                                ? 'All plans'
                                : promotion.appliesToPlans
                                    .map((id) => planById(id)?.label ?? id)
                                    .join(', '),
                          ),
                          _InfoChip(
                            icon: promotion.isTargetedToSpecificFacilities
                                ? Icons.storefront_outlined
                                : (promotion.targetExpiringOnly ? Icons.timer_outlined : Icons.public),
                            label: promotion.isTargetedToSpecificFacilities
                                ? '${promotion.targetFacilityIds.length} specific ${promotion.targetFacilityIds.length == 1 ? 'facility' : 'facilities'}'
                                : (promotion.targetExpiringOnly ? 'Expiring soon only' : 'Everyone'),
                          ),
                          if (promotion.endsAt != null)
                            _InfoChip(
                              icon: Icons.event_outlined,
                              label: 'Ends ${DateFormat('d MMM yyyy').format(promotion.endsAt!)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!promotion.active || promotion.hasEnded)
                  TextButton.icon(
                    onPressed: () => setActivePromotion(promotion.id),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Activate'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  )
                else
                  TextButton.icon(
                    onPressed: () => FirebaseFirestore.instance
                        .collection('promotions')
                        .doc(promotion.id)
                        .update({'active': false}),
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    label: const Text('Deactivate'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                  tooltip: 'Edit',
                  onPressed: () => _showPromotionEditor(context, existing: promotion),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Promotion?'),
                        content: Text('"${promotion.label}" will be permanently removed.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await FirebaseFirestore.instance.collection('promotions').doc(promotion.id).delete();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

Future<void> _showPromotionEditor(BuildContext context, {Promotion? existing}) async {
  final isEditing = existing != null;
  final labelController = TextEditingController(text: existing?.label ?? '');
  final discountController =
      TextEditingController(text: existing != null ? existing.discountPercent.toStringAsFixed(0) : '');

  bool allPlans = existing?.appliesToAllPlans ?? true;
  final selectedPlans = <String>{...(existing?.appliesToPlans ?? [])};
  // A single mutually-exclusive choice rather than two separate
  // booleans - "everyone", "expiringSoon", and "specificFacilities"
  // can never apply at once, so one string is clearer than juggling
  // combinations that shouldn't exist.
  String targetMode = (existing?.targetFacilityIds.isNotEmpty ?? false)
      ? 'specificFacilities'
      : ((existing?.targetExpiringOnly ?? false) ? 'expiringSoon' : 'everyone');
  // Keyed by facilityId so selection survives the search filter
  // changing what's visible; name kept alongside purely for display
  // (the chips below the picker), since selectedFacilities.keys alone
  // can't render a label without another lookup.
  final selectedFacilities = <String, String>{};
  if (existing != null && existing.targetFacilityIds.isNotEmpty) {
    // Resolves real names for facilities this promotion already
    // targets, rather than showing raw ids as placeholder labels
    // until someone happens to re-search for them.
    final preselected = await FirebaseFirestore.instance
        .collection('facilities')
        .where(FieldPath.documentId, whereIn: existing.targetFacilityIds.take(10).toList())
        .get();
    for (final doc in preselected.docs) {
      selectedFacilities[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
    }
  }
  DateTime? endsAt = existing?.endsAt;
  bool activateImmediately = existing?.active ?? false;
  String? validationError;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = screenWidth > 700 ? 500.0 : screenWidth * 0.9;

      return AlertDialog(
        title: Text(isEditing ? 'Edit Promotion' : 'New Promotion'),
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
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Offer name', hintText: 'e.g. Nanenane Sale'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount', suffixText: '%'),
                ),
                const SizedBox(height: 16),
                const Text('Applies to', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('All plans'),
                  value: allPlans,
                  onChanged: (v) => setDialogState(() => allPlans = v),
                ),
                if (!allPlans)
                  Wrap(
                    spacing: 8,
                    children: kSubscriptionPlans.map((plan) {
                      final isSelected = selectedPlans.contains(plan.id);
                      return FilterChip(
                        label: Text(plan.label),
                        selected: isSelected,
                        onSelected: (v) => setDialogState(() {
                          if (v) {
                            selectedPlans.add(plan.id);
                          } else {
                            selectedPlans.remove(plan.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                const Text('Who sees it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Everyone'),
                  value: 'everyone',
                  groupValue: targetMode,
                  onChanged: (v) => setDialogState(() => targetMode = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Only facilities expiring soon'),
                  subtitle: const Text('Within 7 days of their subscription ending', style: TextStyle(fontSize: 11.5)),
                  value: 'expiringSoon',
                  groupValue: targetMode,
                  onChanged: (v) => setDialogState(() => targetMode = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Specific facilities'),
                  subtitle: Text(
                    // A reward/relationship-based offer (e.g. a
                    // facility that consistently pays on time) rather
                    // than an urgency-based one - independent of
                    // where they are in their billing cycle.
                    selectedFacilities.isEmpty
                        ? 'Pick which facilities see this, regardless of billing status'
                        : '${selectedFacilities.length} selected',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: 'specificFacilities',
                  groupValue: targetMode,
                  onChanged: (v) => setDialogState(() => targetMode = v!),
                ),
                if (targetMode == 'specificFacilities') ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(selectedFacilities.isEmpty ? 'Choose Facilities' : 'Edit Selection'),
                    onPressed: () => _pickFacilities(context, selectedFacilities, setDialogState),
                  ),
                  if (selectedFacilities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedFacilities.entries.map((entry) {
                        return Chip(
                          label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setDialogState(() => selectedFacilities.remove(entry.key)),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        endsAt != null ? 'Ends ${DateFormat('d MMM yyyy').format(endsAt!)}' : 'No end date set',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endsAt ?? DateTime.now().add(const Duration(days: 14)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => endsAt = picked);
                      },
                      child: Text(endsAt != null ? 'Change' : 'Set End Date'),
                    ),
                    if (endsAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Remove end date',
                        onPressed: () => setDialogState(() => endsAt = null),
                      ),
                  ],
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Activate immediately'),
                  subtitle: const Text('Deactivates any other currently active offer', style: TextStyle(fontSize: 11.5)),
                  value: activateImmediately,
                  onChanged: (v) => setDialogState(() => activateImmediately = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(discountController.text.trim());
              if (labelController.text.trim().isEmpty) {
                setDialogState(() => validationError = 'Enter an offer name');
                return;
              }
              if (discount == null || discount <= 0 || discount > 100) {
                setDialogState(() => validationError = 'Enter a discount between 1 and 100');
                return;
              }
              if (!allPlans && selectedPlans.isEmpty) {
                setDialogState(() => validationError = 'Select at least one plan, or switch on "All plans"');
                return;
              }
              if (targetMode == 'specificFacilities' && selectedFacilities.isEmpty) {
                setDialogState(() => validationError = 'Choose at least one facility, or pick a different targeting option');
                return;
              }
              Navigator.pop(context, true);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return PromotionsScreen.warmAmber;
                return PromotionsScreen.primaryColor;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      );
    }),
  );

  if (confirmed != true) return;

  final promotionData = {
    'label': labelController.text.trim(),
    'discountPercent': double.parse(discountController.text.trim()),
    'appliesToPlans': allPlans ? <String>[] : selectedPlans.toList(),
    'targetExpiringOnly': targetMode == 'expiringSoon',
    'targetFacilityIds': targetMode == 'specificFacilities' ? selectedFacilities.keys.toList() : <String>[],
    'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
  };

  if (isEditing) {
    await FirebaseFirestore.instance.collection('promotions').doc(existing!.id).update(promotionData);
    if (activateImmediately) await setActivePromotion(existing!.id);
  } else {
    final docRef = await FirebaseFirestore.instance.collection('promotions').add({
      ...promotionData,
      'active': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (activateImmediately) await setActivePromotion(docRef.id);
  }
}

/// The one entry point for opening Promotions - same reasoning and
/// threshold as the other substantial Platform Admin screens: a
/// full-screen push on mobile, a large, centered, dismissable modal
/// on desktop/tablet-width screens.
Future<void> showPromotionsScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PromotionsScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Promotions',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      return Center(
        child: SizedBox(
          width: screenSize.width * 0.8,
          height: screenSize.height * 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const Material(
              child: PromotionsScreen(isModal: true),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Search-and-multi-select facility picker, same pattern as the "Add
/// to Facility" search dialog in user_detail_screen.dart, but
/// multi-select via checkboxes rather than tap-once-and-close. Edits
/// a local, temporary copy - changes only commit back to the editor's
/// own selection if "Done" is actually pressed, not on every checkbox
/// tap, so cancelling this picker never partially applies a change.
Future<void> _pickFacilities(
  BuildContext context,
  Map<String, String> selectedFacilities,
  StateSetter setEditorState,
) async {
  final facilitiesSnap = await FirebaseFirestore.instance.collection('facilities').get();
  if (!context.mounted) return;

  final tempSelected = Map<String, String>.from(selectedFacilities);

  await showDialog<void>(
    context: context,
    builder: (context) {
      String query = '';
      return StatefulBuilder(builder: (context, setPickerState) {
        // Comfortably wide on desktop, but never wider than the
        // actual screen on a phone - same reasoning as every other
        // dialog width in this app.
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 700 ? 460.0 : screenWidth * 0.9;

        final filtered = facilitiesSnap.docs.where((doc) {
          if (query.isEmpty) return true;
          final name = (doc.data()['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        return AlertDialog(
          title: const Text('Choose Facilities'),
          content: SizedBox(
            width: dialogWidth,
            height: 420,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search facility name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setPickerState(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matching facility.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final doc = filtered[i];
                            final data = doc.data();
                            final name = (data['name'] ?? '').toString();
                            final isSelected = tempSelected.containsKey(doc.id);
                            return CheckboxListTile(
                              dense: true,
                              title: Text(name),
                              subtitle: Text((data['type'] ?? '').toString()),
                              value: isSelected,
                              onChanged: (v) => setPickerState(() {
                                if (v == true) {
                                  tempSelected[doc.id] = name;
                                } else {
                                  tempSelected.remove(doc.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                selectedFacilities
                  ..clear()
                  ..addAll(tempSelected);
                setEditorState(() {});
                Navigator.pop(context);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return PromotionsScreen.warmAmber;
                  return PromotionsScreen.primaryColor;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      });
    },
  );
}
