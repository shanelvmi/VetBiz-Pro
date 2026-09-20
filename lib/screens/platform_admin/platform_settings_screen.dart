import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/sentence_capitalization_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../constants/subscription_plans.dart';
import '../../widgets/hover_elevate_card.dart';
import '../../utils/facility_limit_helper.dart';
import '../../utils/thousands_input_formatter.dart';
import 'promotions_screen.dart';

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

  static const Color primaryColor = Color(0xFF2F5D62);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
              HoverElevateCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showPromotionsScreen(context),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer_outlined, color: primaryColor, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Promotions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              SizedBox(height: 2),
                              Text(
                                'Create seasonal sales or renewal offers for expiring facilities.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _PricingSettingsCard(),
              const SizedBox(height: 16),
              const _TrialSettingsCard(),
              const SizedBox(height: 16),
              const _FacilityLimitSettingsCard(),
              const SizedBox(height: 16),
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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

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
      final doc = await FirebaseFirestore.instance.collection('platform_config').doc('settings').get();
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
              child: const Text('Turn On', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isTogglingMode = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('settings')
          .set({'maintenanceMode': value}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _isMaintenanceMode = value;
        _isTogglingMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Maintenance mode is now ON.' : 'Maintenance mode is now OFF.'),
          backgroundColor: value ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _saveMessage() async {
    setState(() => _isSavingMessage = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('settings')
          .set({'maintenanceMessage': _messageController.text.trim()}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isSavingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message saved.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined, color: _isMaintenanceMode ? Colors.orange : primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Blocks every user except Platform Admins from using the app until turned off.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else ...[
              Row(
                children: [
                  Switch(
                    value: _isMaintenanceMode,
                    onChanged: _isTogglingMode ? null : _setMaintenanceMode,
                    activeColor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMaintenanceMode ? 'Currently ON - users are blocked' : 'Currently OFF - app is live',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isMaintenanceMode ? Colors.orange[800] : Colors.grey[600],
                    ),
                  ),
                  if (_isTogglingMode) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSavingMessage ? null : _saveMessage,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryColor;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                  ),
                  child: _isSavingMessage
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

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
          await FirebaseFirestore.instance.collection('platform_config').doc('settings').get();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a whole number of days, greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('settings')
          .set({'trialDays': parsed}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _currentDays = parsed;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trial length set to $parsed day${parsed == 1 ? '' : 's'} - applies to facilities created from now on.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('New Facility Trial Length',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Only applies to facilities created from now on - never changes one already mid-trial.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return warmAmber;
                        return primaryColor;
                      }),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  Text('Currently: $_currentDays days', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

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
        _controllers[plan.id]?.text = NumberFormat.decimalPattern('en_US').format(plan.priceTsh.round());
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final updates = <String, double>{};
    for (final plan in kSubscriptionPlans) {
      final raw = _controllers[plan.id]?.text.trim() ?? '';
      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid price for ${plan.label}')),
        );
        return;
      }
      updates['${plan.id}PriceTsh'] = parseThousands(raw);
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('settings')
          .set(updates, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prices updated - applies to new payment submissions from now on.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sell_outlined, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Subscription Pricing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Applies to new payment submissions from now on - never changes what a facility already paid.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
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
                        prefixText: 'Tsh ',
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            if (!_isLoading)
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return warmAmber;
                    return primaryColor;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a whole number, greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('settings')
          .set({'maxFacilitiesPerAdmin': parsed}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _currentLimit = parsed;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facility limit set to $parsed per Admin account.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverElevateCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_outlined, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Facility Limit Per Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Caps how many facilities a single Admin account can create - mainly to prevent trial abuse via endless new facilities.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return warmAmber;
                        return primaryColor;
                      }),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  Text('Currently: $_currentLimit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
