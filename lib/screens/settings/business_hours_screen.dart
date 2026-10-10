import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/facility_provider.dart';
import '../../data/collections.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {

  TimeOfDay _weekdayTime = const TimeOfDay(hour: 18, minute: 0);
  bool _weekdayClosed = false;
  TimeOfDay _saturdayTime = const TimeOfDay(hour: 18, minute: 0);
  bool _saturdayClosed = false;
  TimeOfDay _sundayTime = const TimeOfDay(hour: 14, minute: 0);
  bool _sundayClosed = false;
  bool _allowAnytime = false;

  bool _isSaving = false;
  bool _loadedFromExisting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedFromExisting) return;
    _loadedFromExisting = true;

    final hours = Provider.of<FacilityProvider>(context, listen: false).businessHours;
    if (hours == null) return;

    setState(() {
      _weekdayTime = _parseTime(hours['weekdayClosingTime']) ?? _weekdayTime;
      _weekdayClosed = hours['weekdayClosed'] == true;
      _saturdayTime = _parseTime(hours['saturdayClosingTime']) ?? _saturdayTime;
      _saturdayClosed = hours['saturdayClosed'] == true;
      _sundayTime = _parseTime(hours['sundayClosingTime']) ?? _sundayTime;
      _sundayClosed = hours['sundayClosed'] == true;
      _allowAnytime = hours['allowAnytime'] == true;
    });
  }

  TimeOfDay? _parseTime(dynamic raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeForStorage(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(TimeOfDay current, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityId).update({
        'businessHours': {
          'weekdayClosingTime': _formatTimeForStorage(_weekdayTime),
          'weekdayClosed': _weekdayClosed,
          'saturdayClosingTime': _formatTimeForStorage(_saturdayTime),
          'saturdayClosed': _saturdayClosed,
          'sundayClosingTime': _formatTimeForStorage(_sundayTime),
          'sundayClosed': _sundayClosed,
          'allowAnytime': _allowAnytime,
        },
      });
      if (!mounted) return;
      AppFeedback.success('Business hours saved');
    } catch (e, st) {
      AppFeedback.error("Couldn't save the business hours", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Business Hours', style: TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f20)),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        elevation: AppElevation.e0,
      ),
      body: Center(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sets when the "Generate Today\'s Report" button becomes active in View Reports.',
              style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s20),
            _dayGroupCard(
              title: 'Weekdays (Mon–Fri)',
              time: _weekdayTime,
              closed: _weekdayClosed,
              onTimeTap: () => _pickTime(_weekdayTime, (t) => setState(() => _weekdayTime = t)),
              onClosedChanged: (v) => setState(() => _weekdayClosed = v),
            ),
            const SizedBox(height: AppSpacing.s12),
            _dayGroupCard(
              title: 'Saturday',
              time: _saturdayTime,
              closed: _saturdayClosed,
              onTimeTap: () => _pickTime(_saturdayTime, (t) => setState(() => _saturdayTime = t)),
              onClosedChanged: (v) => setState(() => _saturdayClosed = v),
            ),
            const SizedBox(height: AppSpacing.s12),
            _dayGroupCard(
              title: 'Sunday',
              time: _sundayTime,
              closed: _sundayClosed,
              onTimeTap: () => _pickTime(_sundayTime, (t) => setState(() => _sundayTime = t)),
              onClosedChanged: (v) => setState(() => _sundayClosed = v),
            ),
            const SizedBox(height: AppSpacing.s20),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: AppAlpha.a05),
                borderRadius: BorderRadius.circular(AppRadius.r12),
                border: Border.all(color: context.colors.warning.withValues(alpha: AppAlpha.a30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Allow anytime', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Emergency override - makes the report button active regardless of the schedule above. '
                          'Turn this on for an early closure, and back off once things return to normal.',
                          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowAnytime,
                    activeColor: context.colors.warningStrong,
                    onChanged: (v) => setState(() => _allowAnytime = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                    : const Text('Save Business Hours', style: TextStyle(fontWeight: AppFontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _dayGroupCard({
    required String title,
    required TimeOfDay time,
    required bool closed,
    required VoidCallback onTimeTap,
    required ValueChanged<bool> onClosedChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
              Row(
                children: [
                  Text('Closed all day', style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
                  Switch(value: closed, activeColor: context.colors.primary, onChanged: onClosedChanged),
                ],
              ),
            ],
          ),
          if (!closed) ...[
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton.icon(
              onPressed: onTimeTap,
              icon: Icon(Icons.access_time, size: AppIconSize.i16, color: context.colors.primary),
              label: Text('Closes at ${time.format(context)}', style: TextStyle(color: context.colors.primary)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40))),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text('No closing time needed - closed all day.', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textHint)),
            ),
        ],
      ),
    );
  }
}
