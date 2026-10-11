import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/subscription_plans.dart';
import '../../widgets/hover_elevate_card.dart';
import '../../utils/facility_limit_helper.dart';
import '../../utils/thousands_input_formatter.dart';
import 'promotions_screen.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_defaults.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

/// Platform-wide configuration - currently new-facility trial length and
/// subscription pricing. Deliberately separate from Overview: Overview
/// answers "how's the business doing right now" (stats you glance at),
/// this answers "how are the business rules configured" (forms you fill
/// in rarely) - two different things that don't belong on the same
/// screen. Embedded directly in the Platform Admin shell's content area
/// like every other section, reached via its own "Settings" entry under
/// the sidebar's "Others" group, rather than pushed as a separate
/// screen or shown as a modal.
class PlatformSettingsScreen extends StatelessWidget {
  const PlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
              HoverElevateCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  onTap: () => showPromotionsScreen(context),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s14),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer_outlined, color: context.colors.primary, size: AppIconSize.i22),
                        SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Promotions', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
                              SizedBox(height: AppSpacing.s2),
                              Text(
                                'Create seasonal sales or renewal offers for expiring facilities.',
                                style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textHint),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.colors.textHint),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const _PricingSettingsCard(),
              const SizedBox(height: AppSpacing.s16),
              const _TrialSettingsCard(),
              const SizedBox(height: AppSpacing.s16),
              const _FacilityLimitSettingsCard(),
              const SizedBox(height: AppSpacing.s16),
              const _MaintenanceModeCard(),
            ],
          ),
        ),
      );
  }
}

/// Lets a Platform Admin block every non-Platform-Admin user from
/// using the app - see MaintenanceGate, which watches this live so an
/// app already open reacts within seconds. The toggle itself saves
/// immediately on change (no separate Save step, since a delayed
/// effect here would be actively misleading during a real incident);
/// turning it ON asks for confirmation first, given how disruptive it
/// is, but turning it OFF never does, since restoring normal access
/// is always safe.
class _MaintenanceModeCard extends StatefulWidget {
  const _MaintenanceModeCard();

  @override
  State<_MaintenanceModeCard> createState() => _MaintenanceModeCardState();
}

class _MaintenanceModeCardState extends State<_MaintenanceModeCard> {

  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  bool _isTogglingMode = false;
  bool _isSavingMessage = false;
  bool _isMaintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentValue() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.platformConfig).doc('settings').get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _isMaintenanceMode = data?['maintenanceMode'] as bool? ?? false;
          _messageController.text = (data?['maintenanceMessage'] as String?) ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setMaintenanceMode(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn on maintenance mode?'),
          content: const Text(
            'Every user except Platform Admins will be immediately blocked from using '
            'the app, everywhere, until this is turned back off.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Turn On', style: TextStyle(color: context.colors.dangerAccent)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isTogglingMode = true);
    try {
      await FirebaseFirestore.instance
          .collection(Collections.platformConfig)
          .doc('settings')
          .set({'maintenanceMode': value}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _isMaintenanceMode = value;
        _isTogglingMode = false;
      });
      if (value) {
        AppFeedback.warning('Maintenance mode is now ON');
      } else {
        AppFeedback.success('Maintenance mode is now OFF');
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isTogglingMode = false);
      AppFeedback.error("Couldn't save maintenance mode", error: e, stackTrace: st);
    }
  }

  Future<void> _saveMessage() async {
    setState(() => _isSavingMessage = true);
    try {
      await FirebaseFirestore.instance
          .collection(Collections.platformConfig)
          .doc('settings')
          .set({'maintenanceMessage': _messageController.text.trim()}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isSavingMessage = false);
      AppFeedback.success('Message saved');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isSavingMessage = false);
      AppFeedback.error("Couldn't save the maintenance message", error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined, color: _isMaintenanceMode ? context.colors.warning : context.colors.primary, size: AppIconSize.i20),
                const SizedBox(width: AppSpacing.s8),
                const Text('Maintenance Mode', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Blocks every user except Platform Admins from using the app until turned off.',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.s8), child: CircularProgressIndicator()))
            else ...[
              Row(
                children: [
                  Switch(
                    value: _isMaintenanceMode,
                    onChanged: _isTogglingMode ? null : _setMaintenanceMode,
                    activeColor: context.colors.warning,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    _isMaintenanceMode ? 'Currently ON - users are blocked' : 'Currently OFF - app is live',
                    style: TextStyle(
                      fontSize: AppFontSize.f13,
                      fontWeight: AppFontWeight.semibold,
                      color: _isMaintenanceMode ? context.colors.warningStrong : context.colors.textMuted,
                    ),
                  ),
                  if (_isTogglingMode) ...[
                    const SizedBox(width: AppSpacing.s8),
                    const SizedBox(width: AppSpacing.s14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _messageController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [SentenceCapitalizationFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Message shown to blocked users (optional)',
                  hintText: "We're currently performing scheduled maintenance...",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSavingMessage ? null : _saveMessage,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return context.colors.accent;
                      return context.colors.primary;
                    }),
                    foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                  ),
                  child: _isSavingMessage
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                        )
                      : const Text('Save Message'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lets a Platform Admin configure how many days a brand-new
/// facility's trial lasts. Deliberately only ever read at
/// facility-creation time (see computeNewFacilityTrialExpiry) - a
/// change here only affects facilities created after that change,
/// never retroactively changing one already mid-trial.
class _TrialSettingsCard extends StatefulWidget {
  const _TrialSettingsCard();

  @override
  State<_TrialSettingsCard> createState() => _TrialSettingsCardState();
}

class _TrialSettingsCardState extends State<_TrialSettingsCard> {

  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentDays = kDefaultTrialDays;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentValue() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection(Collections.platformConfig).doc('settings').get();
      final configured = (doc.data()?['trialDays'] as num?)?.toInt();
      if (mounted) {
        setState(() {
          _currentDays = (configured != null && configured > 0) ? configured : kDefaultTrialDays;
          _controller.text = _currentDays.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _controller.text = _currentDays.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) {
      AppFeedback.warning('Enter a whole number of days, greater than 0');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection(Collections.platformConfig)
          .doc('settings')
          .set({'trialDays': parsed}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _currentDays = parsed;
        _isSaving = false;
      });
      AppFeedback.success(
        'Trial length set to $parsed day${parsed == 1 ? '' : 's'}',
        detail: 'Applies to facilities created from now on',
      );
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.error("Couldn't save the trial length", error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: context.colors.primary, size: AppIconSize.i20),
                const SizedBox(width: AppSpacing.s8),
                const Text('New Facility Trial Length',
                    style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Only applies to facilities created from now on - never changes one already mid-trial.',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.s8), child: CircularProgressIndicator()))
            else
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: 'days',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return context.colors.accent;
                        return context.colors.primary;
                      }),
                      foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Text('Currently: $_currentDays days', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Lets a Platform Admin set real prices for all four plans, replacing
/// what were previously hardcoded placeholder values in
/// subscription_plans.dart requiring a code deploy to change - now a
/// straightforward Firestore write, same platform_config/settings
/// document the trial length uses.
class _PricingSettingsCard extends StatefulWidget {
  const _PricingSettingsCard();

  @override
  State<_PricingSettingsCard> createState() => _PricingSettingsCardState();
}

class _PricingSettingsCardState extends State<_PricingSettingsCard> {

  final Map<String, TextEditingController> _controllers = {
    for (final plan in kSubscriptionPlans) plan.id: TextEditingController(),
  };
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentValues() async {
    // Falls back to the static defaults on any read failure (e.g.
    // offline), same reasoning as loadSubscriptionPlans() itself -
    // the fields should never be left blank.
    final plans = await loadSubscriptionPlans();
    if (!mounted) return;
    setState(() {
      for (final plan in plans) {
        _controllers[plan.id]?.text = Money.decimal(plan.priceTsh.round());
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final updates = <String, double>{};
    for (final plan in kSubscriptionPlans) {
      final raw = _controllers[plan.id]?.text.trim() ?? '';
      if (raw.isEmpty) {
        AppFeedback.warning('Enter a valid price for ${plan.label}');
        return;
      }
      updates['${plan.id}PriceTsh'] = parseThousands(raw);
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection(Collections.platformConfig)
          .doc('settings')
          .set(updates, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.success('Prices updated', detail: 'Applies to new payment submissions from now on');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.error("Couldn't save the prices", error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sell_outlined, color: context.colors.primary, size: AppIconSize.i20),
                const SizedBox(width: AppSpacing.s8),
                const Text('Subscription Pricing',
                    style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Applies to new payment submissions from now on - never changes what a facility already paid.',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.s8), child: CircularProgressIndicator()))
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kSubscriptionPlans.map((plan) {
                  return SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _controllers[plan.id],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                      decoration: InputDecoration(
                        labelText: plan.label,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixText: '${AppDefaults.currencySymbol} ',
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: AppSpacing.s12),
            if (!_isLoading)
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return context.colors.accent;
                    return context.colors.primary;
                  }),
                  foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                      )
                    : const Text('Save All Prices'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lets a Platform Admin configure how many facilities a single Admin
/// account can create - primarily to prevent one account from
/// spinning up endless facilities purely to keep generating fresh
/// trial periods on each new one. Enforced in firestore.rules'
/// isUnderFacilityLimit(), not just here - this card only controls
/// the configured number, the actual enforcement lives at the data
/// layer.
class _FacilityLimitSettingsCard extends StatefulWidget {
  const _FacilityLimitSettingsCard();

  @override
  State<_FacilityLimitSettingsCard> createState() => _FacilityLimitSettingsCardState();
}

class _FacilityLimitSettingsCardState extends State<_FacilityLimitSettingsCard> {

  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentLimit = kDefaultMaxFacilitiesPerAdmin;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentValue() async {
    final limit = await loadMaxFacilitiesPerAdmin();
    if (mounted) {
      setState(() {
        _currentLimit = limit;
        _controller.text = limit.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) {
      AppFeedback.warning('Enter a whole number, greater than 0');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection(Collections.platformConfig)
          .doc('settings')
          .set({'maxFacilitiesPerAdmin': parsed}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _currentLimit = parsed;
        _isSaving = false;
      });
      AppFeedback.success('Facility limit set to $parsed per Admin account');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.error("Couldn't save the facility limit", error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_outlined, color: context.colors.primary, size: AppIconSize.i20),
                const SizedBox(width: AppSpacing.s8),
                const Text('Facility Limit Per Admin',
                    style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Caps how many facilities a single Admin account can create - mainly to prevent trial abuse via endless new facilities.',
              style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.s8), child: CircularProgressIndicator()))
            else
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: 'max',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return context.colors.accent;
                        return context.colors.primary;
                      }),
                      foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Text('Currently: $_currentLimit', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
