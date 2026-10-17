import 'package:flutter/material.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/subscription_plans.dart';
import '../../models/promotion.dart';
import '../../widgets/hover_elevate_card.dart';
import '../../widgets/firestore_error_view.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_breakpoints.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Promotions'),
        centerTitle: true,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
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
                      Icon(Icons.local_offer_outlined, size: AppIconSize.i56, color: context.colors.border),
                      const SizedBox(height: AppSpacing.s12),
                      Text('No promotions yet', style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f15)),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Create one for a seasonal sale or a renewal push.',
                        style: TextStyle(color: context.colors.textHint, fontSize: AppFontSize.f12_5),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.s16),
                itemCount: promotions.length,
                itemBuilder: (context, index) => _PromotionCard(promotion: promotions[index]),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        hoverColor: context.colors.accent,
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

  @override
  Widget build(BuildContext context) {
    final isLive = promotion.active && !promotion.hasEnded;
    final statusColor = isLive ? context.colors.success : (promotion.active ? context.colors.warning : context.colors.textHint);
    final statusLabel = isLive ? 'LIVE' : (promotion.active ? 'ENDED' : 'OFF');

    return HoverElevateCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The headline number - deliberately large, this is
                // the one thing that should catch the eye first.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.primary, context.colors.primary.withValues(alpha: AppAlpha.a70)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Text(
                    '${promotion.discountPercent.toStringAsFixed(promotion.discountPercent % 1 == 0 ? 0 : 1)}%\nOFF',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15, height: 1.1),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              promotion.label,
                              style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: AppAlpha.a10),
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLive)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: AppSpacing.s4),
                                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                  ),
                                Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: AppFontSize.f10_5, color: statusColor, fontWeight: AppFontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s6),
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
                              label: 'Ends ${AppDateFormat.dateNoPad.format(promotion.endsAt!)}',
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
                    icon: const Icon(Icons.play_circle_outline, size: AppIconSize.i18),
                    label: const Text('Activate'),
                    style: TextButton.styleFrom(foregroundColor: context.colors.success),
                  )
                else
                  TextButton.icon(
                    onPressed: () => FirebaseFirestore.instance
                        .collection(Collections.promotions)
                        .doc(promotion.id)
                        .update({Fields.active: false}),
                    icon: const Icon(Icons.pause_circle_outline, size: AppIconSize.i18),
                    label: const Text('Deactivate'),
                    style: TextButton.styleFrom(foregroundColor: context.colors.warning),
                  ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: context.colors.primary, size: AppIconSize.i20),
                  tooltip: 'Edit',
                  onPressed: () => _showPromotionEditor(context, existing: promotion),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: context.colors.dangerAccent, size: AppIconSize.i20),
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
                            child: Text('Delete', style: TextStyle(color: context.colors.dangerAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await FirebaseFirestore.instance.collection(Collections.promotions).doc(promotion.id).delete();
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.i12, color: context.colors.textSoft),
          const SizedBox(width: AppSpacing.s4),
          Text(label, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textSoft)),
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
        .collection(Collections.facilities)
        .where(FieldPath.documentId, whereIn: existing.targetFacilityIds.take(10).toList())
        .get();
    for (final doc in preselected.docs) {
      selectedFacilities[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
    }
  }
  DateTime? endsAt = existing?.endsAt;
  bool activateImmediately = existing?.active ?? false;
  String? validationError;

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = screenWidth > AppBreakpoints.dialogFixedWidth ? AppSizes.dialogMd : screenWidth * 0.9;

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
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: context.colors.danger.withValues(alpha: AppAlpha.a10),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                      border: Border.all(color: context.colors.danger.withValues(alpha: AppAlpha.a40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: context.colors.danger, size: AppIconSize.i18),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(validationError!, style: TextStyle(color: context.colors.danger, fontSize: AppFontSize.f13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
                TextField(
                  controller: labelController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [SentenceCapitalizationFormatter()],
                  decoration: const InputDecoration(labelText: 'Offer name', hintText: 'e.g. Nanenane Sale'),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount', suffixText: '%'),
                ),
                const SizedBox(height: AppSpacing.s16),
                const Text('Applies to', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
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
                const SizedBox(height: AppSpacing.s12),
                const Text('Who sees it', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13)),
                RadioGroup<String>(
                  groupValue: targetMode,
                  onChanged: (v) => setDialogState(() => targetMode = v!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Everyone'),
                        value: 'everyone',
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Only facilities expiring soon'),
                        subtitle: const Text('Within 7 days of their subscription ending', style: TextStyle(fontSize: AppFontSize.f11_5)),
                        value: 'expiringSoon',
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
                          style: const TextStyle(fontSize: AppFontSize.f11_5),
                        ),
                        value: 'specificFacilities',
                      ),
                    ],
                  ),
                ),
                if (targetMode == 'specificFacilities') ...[
                  const SizedBox(height: AppSpacing.s4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.storefront_outlined, size: AppIconSize.i18),
                    label: Text(selectedFacilities.isEmpty ? 'Choose Facilities' : 'Edit Selection'),
                    onPressed: () => _pickFacilities(context, selectedFacilities, setDialogState),
                  ),
                  if (selectedFacilities.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedFacilities.entries.map((entry) {
                        return Chip(
                          label: Text(entry.value, style: const TextStyle(fontSize: AppFontSize.f12)),
                          onDeleted: () => setDialogState(() => selectedFacilities.remove(entry.key)),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        endsAt != null ? 'Ends ${AppDateFormat.dateNoPad.format(endsAt!)}' : 'No end date set',
                        style: const TextStyle(fontSize: AppFontSize.f13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endsAt ?? DateTime.now().add(AppRanges.fortnight),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(AppRanges.year),
                        );
                        if (picked != null) setDialogState(() => endsAt = picked);
                      },
                      child: Text(endsAt != null ? 'Change' : 'Set End Date'),
                    ),
                    if (endsAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: AppIconSize.i18),
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
                  subtitle: const Text('Deactivates any other currently active offer', style: TextStyle(fontSize: AppFontSize.f11_5)),
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
                if (states.contains(WidgetState.hovered)) return context.colors.accent;
                return context.colors.primary;
              }),
              foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
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
    await FirebaseFirestore.instance.collection(Collections.promotions).doc(existing.id).update(promotionData);
    if (activateImmediately) await setActivePromotion(existing.id);
  } else {
    final docRef = await FirebaseFirestore.instance.collection(Collections.promotions).add({
      ...promotionData,
      Fields.active: false,
      Fields.createdAt: FieldValue.serverTimestamp(),
    });
    if (activateImmediately) await setActivePromotion(docRef.id);
  }
}

/// The one entry point for opening Promotions - same reasoning and
/// threshold as the other substantial Platform Admin screens: a
/// full-screen push on mobile, a large, centered, dismissable modal
/// on desktop/tablet-width screens.
Future<void> showPromotionsScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;

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
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      final modalWidth = (screenSize.width * 0.60).clamp(0, 940).toDouble();
      // Never shorter than 480px, fixed - 88% of screen height
      // comfortably exceeds that on most windows, but this guarantees
      // it even on a smaller one.
      final modalHeight = (screenSize.height * 0.88) < 480 ? 480.0 : screenSize.height * 0.88;
      return Center(
        child: SizedBox(
          width: modalWidth,
          height: modalHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
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
  final facilitiesSnap = await FirebaseFirestore.instance.collection(Collections.facilities).get();
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
        final dialogWidth = screenWidth > AppBreakpoints.dialogFixedWidth ? AppSizes.dialogSm : screenWidth * 0.9;

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
                const SizedBox(height: AppSpacing.s8),
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
                  if (states.contains(WidgetState.hovered)) return context.colors.accent;
                  return context.colors.primary;
                }),
                foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      });
    },
  );
}
