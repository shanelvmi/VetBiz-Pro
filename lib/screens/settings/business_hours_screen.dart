import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/facility_provider.dart';
import '../../data/collections.dart';
import '../../theme/app_text.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../theme/app_layout.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/phone_form/form_action_bar.dart';

class BusinessHoursScreen extends StatefulWidget {
  // Null: the app's own Firestore. Tests pass a fake one (PH8a seam; no
  // behaviour change).
  final FirebaseFirestore? firestore;

  const BusinessHoursScreen({super.key, this.firestore});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  // PH8a: on a phone 14 px text, 48 px rows, the closing time chosen in a
  // sheet and Save in the PH6 action bar; tablets and computers keep today's.
  bool get _phone => AppLayout.isPhone(context);

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

  Future<void> _pickTime(TimeOfDay current, ValueChanged<TimeOfDay> onPicked, {required String title}) async {
    final picked = _phone
        ? await showAppSheet<TimeOfDay>(context, title: title, builder: (context) => _TimeSheet(initial: current))
        : await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return;

    setState(() => _isSaving = true);
    try {
      await _db.collection(Collections.facilities).doc(facilityId).update({
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
      AppFeedback.success(L10n.current.hours_saved);
    } catch (e, st) {
      AppFeedback.error(L10n.current.hours_saveFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(context.l10n.hours_title, style: const TextStyle(fontWeight: AppFontWeight.semibold, fontSize: AppFontSize.f20)),
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
              context.l10n.hours_intro,
              style: TextStyle(fontSize: _phone ? AppFontSize.f14 : AppFontSize.f13, color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s20),
            _dayGroupCard(
              title: context.l10n.hours_weekdays,
              time: _weekdayTime,
              closed: _weekdayClosed,
              onTimeTap: () => _pickTime(_weekdayTime, (t) => setState(() => _weekdayTime = t), title: context.l10n.hours_weekdays),
              onClosedChanged: (v) => setState(() => _weekdayClosed = v),
            ),
            const SizedBox(height: AppSpacing.s12),
            _dayGroupCard(
              title: context.l10n.hours_saturday,
              time: _saturdayTime,
              closed: _saturdayClosed,
              onTimeTap: () => _pickTime(_saturdayTime, (t) => setState(() => _saturdayTime = t), title: context.l10n.hours_saturday),
              onClosedChanged: (v) => setState(() => _saturdayClosed = v),
            ),
            const SizedBox(height: AppSpacing.s12),
            _dayGroupCard(
              title: context.l10n.hours_sunday,
              time: _sundayTime,
              closed: _sundayClosed,
              onTimeTap: () => _pickTime(_sundayTime, (t) => setState(() => _sundayTime = t), title: context.l10n.hours_sunday),
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
                        Text(context.l10n.hours_allowAnytime, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          context.l10n.hours_allowAnytimeHint,
                          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowAnytime,
                    activeThumbColor: context.colors.warningStrong,
                    onChanged: (v) => setState(() => _allowAnytime = v),
                  ),
                ],
              ),
            ),
            // On a phone Save is in the action bar below.
            if (!_phone) ...[
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
                    : Text(context.l10n.hours_save, style: const TextStyle(fontWeight: AppFontWeight.bold)),
              ),
            ),
            ],
          ],
        ),
      ),
      ),
      ),
      bottomNavigationBar: _phone
          ? FormActionBar(primaryLabel: context.l10n.hours_save, onPrimary: _isSaving ? null : _save, busy: _isSaving)
          : null,
    );
  }

  Widget _dayGroupCard({
    required String title,
    required TimeOfDay time,
    required bool closed,
    required VoidCallback onTimeTap,
    required ValueChanged<bool> onClosedChanged,
  }) {
    if (_phone) return _phoneDayGroupCard(title: title, time: time, closed: closed, onTimeTap: onTimeTap, onClosedChanged: onClosedChanged);
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
                  Text(context.l10n.hours_closedAllDay, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textSoft)),
                  Switch(value: closed, activeThumbColor: context.colors.primary, onChanged: onClosedChanged),
                ],
              ),
            ],
          ),
          if (!closed) ...[
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton.icon(
              onPressed: onTimeTap,
              icon: Icon(Icons.access_time, size: AppIconSize.i16, color: context.colors.primary),
              label: Text(context.l10n.hours_closesAt(time.format(context)), style: TextStyle(color: context.colors.primary)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: context.colors.primary.withValues(alpha: AppAlpha.a40))),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(context.l10n.hours_noClosingTime, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textHint)),
            ),
        ],
      ),
    );
  }
}

extension on _BusinessHoursScreenState {
  /// PH8a: a day on a phone: its name, a 48 px "Closed all day" row, then the
  /// closing time as a full-width 48 px button (or why there is none).
  Widget _phoneDayGroupCard({
    required String title,
    required TimeOfDay time,
    required bool closed,
    required VoidCallback onTimeTap,
    required ValueChanged<bool> onClosedChanged,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s8, AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: colors.textHint.withValues(alpha: AppAlpha.a30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: PhoneFormMetrics.body)),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Row(
              children: [
                Expanded(
                  child: Text(context.l10n.hours_closedAllDay,
                      style: TextStyle(fontSize: PhoneFormMetrics.body, color: colors.textSoft)),
                ),
                Switch(value: closed, activeThumbColor: colors.primary, onChanged: onClosedChanged),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: closed
                ? Text(context.l10n.hours_noClosingTime, style: TextStyle(fontSize: PhoneFormMetrics.body, color: colors.textHint))
                : OutlinedButton.icon(
                    onPressed: onTimeTap,
                    icon: Icon(Icons.access_time, size: AppIconSize.i18, color: colors.primary),
                    label: Text(context.l10n.hours_closesAt(time.format(context)),
                        style: TextStyle(color: colors.primary, fontSize: PhoneFormMetrics.body)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinInteractiveDimension),
                      side: BorderSide(color: colors.primary.withValues(alpha: AppAlpha.a40)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// PH8a: a closing time chosen on a phone, in a sheet: the wheels and Done.
/// Pops the time; closing the sheet keeps the old one.
class _TimeSheet extends StatefulWidget {
  final TimeOfDay initial;

  const _TimeSheet({required this.initial});

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late TimeOfDay _time = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: PhoneFormMetrics.timeWheelHeight,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              initialDateTime: DateTime(2000, 1, 1, widget.initial.hour, widget.initial.minute),
              onDateTimeChanged: (d) => _time = TimeOfDay(hour: d.hour, minute: d.minute),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _time),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(PhoneFormMetrics.buttonHeight)),
            child: Text(context.l10n.common_done),
          ),
        ],
      ),
    );
  }
}
