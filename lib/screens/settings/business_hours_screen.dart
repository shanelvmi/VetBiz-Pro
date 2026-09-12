import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/facility_provider.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  static const Color primaryDeepGreen = Color(0xFF2F5D62);

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
      await FirebaseFirestore.instance.collection('facilities').doc(facilityId).update({
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business hours saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Business Hours', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        backgroundColor: primaryDeepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sets when the "Generate Today\'s Report" button becomes active in View Reports.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _dayGroupCard(
              title: 'Weekdays (Mon–Fri)',
              time: _weekdayTime,
              closed: _weekdayClosed,
              onTimeTap: () => _pickTime(_weekdayTime, (t) => setState(() => _weekdayTime = t)),
              onClosedChanged: (v) => setState(() => _weekdayClosed = v),
            ),
            const SizedBox(height: 12),
            _dayGroupCard(
              title: 'Saturday',
              time: _saturdayTime,
              closed: _saturdayClosed,
              onTimeTap: () => _pickTime(_saturdayTime, (t) => setState(() => _saturdayTime = t)),
              onClosedChanged: (v) => setState(() => _saturdayClosed = v),
            ),
            const SizedBox(height: 12),
            _dayGroupCard(
              title: 'Sunday',
              time: _sundayTime,
              closed: _sundayClosed,
              onTimeTap: () => _pickTime(_sundayTime, (t) => setState(() => _sundayTime = t)),
              onClosedChanged: (v) => setState(() => _sundayClosed = v),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Allow anytime', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Emergency override - makes the report button active regardless of the schedule above. '
                          'Turn this on for an early closure, and back off once things return to normal.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowAnytime,
                    activeColor: Colors.orange[800],
                    onChanged: (v) => setState(() => _allowAnytime = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDeepGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Business Hours', style: TextStyle(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                children: [
                  Text('Closed all day', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                  Switch(value: closed, activeColor: primaryDeepGreen, onChanged: onClosedChanged),
                ],
              ),
            ],
          ),
          if (!closed) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onTimeTap,
              icon: Icon(Icons.access_time, size: 16, color: primaryDeepGreen),
              label: Text('Closes at ${time.format(context)}', style: TextStyle(color: primaryDeepGreen)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: primaryDeepGreen.withValues(alpha: 0.4))),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No closing time needed - closed all day.', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }
}
