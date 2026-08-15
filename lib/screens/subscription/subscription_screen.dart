import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../constants/subscription_plans.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');
  final ImagePicker _picker = ImagePicker();

  SubscriptionPlan _selectedPlan = kSubscriptionPlans[2]; // Monthly default
  String _method = 'M-Pesa';
  final TextEditingController _referenceController = TextEditingController();

  Uint8List? _proofBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _proofBytes = bytes);
  }

  Future<void> _submitPayment() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final facilityName =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityName;

    if (facilityId == null) return;

    if (_referenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the payment reference / confirmation code')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? proofUrl;
      if (_proofBytes != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'payment_proofs/$facilityId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_proofBytes!);
        proofUrl = await ref.getDownloadURL();
      }

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payment_submissions')
          .add({
        'facilityId': facilityId,
        'facilityName': facilityName ?? 'Unknown',
        'planId': _selectedPlan.id,
        'planLabel': _selectedPlan.label,
        'amount': _selectedPlan.priceTsh,
        'method': _method,
        'reference': _referenceController.text.trim(),
        'proofImageUrl': proofUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': user?.email ?? user?.uid ?? 'Unknown',
      });

      if (!mounted) return;
      _referenceController.clear();
      setState(() => _proofBytes = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted - it will be reviewed and confirmed shortly.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _statusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.trial:
        return primaryColor;
      case SubscriptionStatus.grace:
        return Colors.orange;
      case SubscriptionStatus.locked:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final sub = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Subscription'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor(sub.status).withValues(alpha: 0.1),
                  border: Border.all(color: _statusColor(sub.status)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium, color: _statusColor(sub.status)),
                        const SizedBox(width: 8),
                        Text(
                          sub.statusLabel,
                          style: TextStyle(
                            color: _statusColor(sub.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    if (sub.expiresAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        sub.status == SubscriptionStatus.locked
                            ? 'Expired on ${DateFormat('dd MMM yyyy').format(sub.expiresAt!)}'
                            : 'Renews / expires on ${DateFormat('dd MMM yyyy').format(sub.expiresAt!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    if (sub.status == SubscriptionStatus.locked)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Your account is in read-only mode. Submit a payment below to '
                          'restore full access - your data is safe and untouched.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Choose a Plan', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              ...kSubscriptionPlans.map((plan) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<SubscriptionPlan>(
                    value: plan,
                    groupValue: _selectedPlan,
                    activeColor: primaryColor,
                    title: Text(plan.label),
                    subtitle: Text('Tsh ${_moneyFormat.format(plan.priceTsh)}'),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedPlan = value);
                    },
                  ),
                );
              }),

              const SizedBox(height: 16),
              Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                  DropdownMenuItem(value: 'Tigo Pesa', child: Text('Tigo Pesa')),
                  DropdownMenuItem(value: 'Airtel Money', child: Text('Airtel Money')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Transaction / Confirmation Code',
                  hintText: 'e.g. the M-Pesa confirmation code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _pickProofImage,
                icon: const Icon(Icons.upload_file),
                label: Text(_proofBytes == null ? 'Attach Proof (optional)' : 'Proof attached ✓'),
                style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Submit Payment for Review', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),
              Text('Recent Submissions', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              if (facilityId != null) _SubmissionHistory(facilityId: facilityId, primaryColor: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionHistory extends StatelessWidget {
  final String facilityId;
  final Color primaryColor;

  const _SubmissionHistory({required this.facilityId, required this.primaryColor});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payment_submissions')
          .orderBy('submittedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text('No submissions yet.', style: TextStyle(color: Colors.grey[600]));
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String?) ?? 'pending';
            final submittedAt = data['submittedAt'] is Timestamp
                ? (data['submittedAt'] as Timestamp).toDate()
                : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text('${data['planLabel'] ?? ''} - Tsh ${data['amount'] ?? 0}'),
                subtitle: Text(
                  '${data['method'] ?? ''}'
                  '${submittedAt != null ? ' • ${DateFormat('dd MMM yyyy').format(submittedAt)}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Chip(
                  label: Text(status[0].toUpperCase() + status.substring(1),
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: _statusColor(status),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
