import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../../utils/subscription_status_utils.dart';
import '../../constants/subscription_plans.dart';

class FacilityDetailScreen extends StatefulWidget {
  final String facilityId;
  const FacilityDetailScreen({super.key, required this.facilityId});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

  ButtonStyle get _accentButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) return warmAmber;
          return primaryColor;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
      );

  /// Manual override - for payments collected outside the normal
  /// submission flow (cash handed to you directly, a bank transfer you
  /// can already see cleared, etc.), for correcting a mistake, or for
  /// granting a facility free access for a custom number of days. Writes
  /// straight onto the facility document, same fields the normal
  /// approval flow writes - nothing else in the app needs to know this
  /// didn't go through a submission.
  Future<void> _manualOverride(BuildContext context, Map<String, dynamic> facilityData) async {
    SubscriptionPlan selectedPlan = kSubscriptionPlans[2];
    bool isFree = false;
    final freeDaysController = TextEditingController(text: '30');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manual Subscription Update'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Use this for payments collected outside the app, or to grant free access.'),
                const SizedBox(height: 12),
                ...kSubscriptionPlans.map((plan) {
                  return RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${plan.label} - Tsh ${plan.priceTsh.toStringAsFixed(0)}'),
                    value: plan.id,
                    groupValue: isFree ? 'free' : selectedPlan.id,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setDialogState(() {
                        isFree = false;
                        selectedPlan = plan;
                      });
                    },
                  );
                }),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Free (custom number of days)'),
                  value: 'free',
                  groupValue: isFree ? 'free' : selectedPlan.id,
                  activeColor: primaryColor,
                  onChanged: (value) => setDialogState(() => isFree = true),
                ),
                if (isFree)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                    child: TextField(
                      controller: freeDaysController,
                      keyboardType: TextInputType.number,
                      cursorColor: primaryColor,
                      decoration: const InputDecoration(
                        labelText: 'Number of free days',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: _accentButtonStyle,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    int durationDays;
    double priceForRecord;
    String planIdForRecord;
    String planLabelForRecord;

    if (isFree) {
      durationDays = int.tryParse(freeDaysController.text.trim()) ?? 0;
      if (durationDays <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid number of days'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
      priceForRecord = 0;
      planIdForRecord = 'free';
      planLabelForRecord = 'Free ($durationDays days)';
    } else {
      durationDays = selectedPlan.durationDays;
      priceForRecord = selectedPlan.priceTsh;
      planIdForRecord = selectedPlan.id;
      planLabelForRecord = selectedPlan.label;
    }

    final currentExpires = facilityData['subscriptionExpiresAt'];
    final currentExpiresDate = currentExpires is Timestamp ? currentExpires.toDate() : null;
    final now = DateTime.now();
    final base = (currentExpiresDate != null && currentExpiresDate.isAfter(now)) ? currentExpiresDate : now;
    final newExpiry = base.add(Duration(days: durationDays));

    final admin = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('facilities').doc(widget.facilityId).set({
      'subscriptionPlan': planIdForRecord,
      'subscriptionExpiresAt': Timestamp.fromDate(newExpiry),
      'lastPaymentAt': FieldValue.serverTimestamp(),
      // 0 for free grants, so "Revenue This Month" on the Overview tab
      // never gets inflated by a facility that didn't actually pay.
      'lastPaymentAmount': priceForRecord,
      'lastManualOverrideBy': admin?.email ?? admin?.uid ?? 'Unknown',
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ($planLabelForRecord) - now runs until ${DateFormat('dd MMM yyyy').format(newExpiry)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool _isDeleting = false;

  /// Permanently deletes this facility - every business record, and the
  /// facility itself, plus removing it from every user (admin or
  /// assistant) who currently has it. Requires typing the facility's
  /// exact name to confirm, not just a generic word, so there's no
  /// ambiguity about which facility is actually being deleted when a
  /// Platform Admin is working across many of them.
  Future<void> _deleteFacility(BuildContext context, String facilityName) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final matches = controller.text.trim() == facilityName;
          return AlertDialog(
            title: const Text('Delete Facility'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently deletes every sale, product, client, service, '
                    'transaction, and record for this facility, and removes it from '
                    'every admin or assistant currently assigned to it. This cannot '
                    'be undone.',
                  ),
                  const SizedBox(height: 16),
                  Text('Type "$facilityName" to confirm:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: facilityName,
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: matches ? () => Navigator.pop(dialogContext, true) : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: const Text('Delete Permanently'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    setState(() => _isDeleting = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteFacility');
      await callable.call({'facilityId': widget.facilityId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$facilityName has been deleted.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not delete this facility.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete this facility: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Details'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('facilities').doc(widget.facilityId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Facility not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final expiresAtField = data['subscriptionExpiresAt'];
          final expiresAt = expiresAtField is Timestamp ? expiresAtField.toDate() : null;
          final trialExpiresAtField = data['trialExpiresAt'];
          final trialExpiresAt = trialExpiresAtField is Timestamp ? trialExpiresAtField.toDate() : null;
          final status = computeSubscriptionStatus(expiresAt, trialExpiresAt);
          final createdAtField = data['createdAt'];
          final createdAt = createdAtField is Timestamp ? createdAtField.toDate() : null;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(data['name'] ?? 'Unnamed facility', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(data['type'] ?? '', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${subscriptionStatusLabel(status)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (expiresAt != null)
                            Text('Expires: ${DateFormat('dd MMM yyyy').format(expiresAt)}'),
                          if (createdAt != null)
                            Text('Signed up: ${DateFormat('dd MMM yyyy').format(createdAt)}',
                                style: const TextStyle(fontSize: 12)),
                          if (data['lastPaymentAmount'] != null)
                            Text('Last payment: Tsh ${_moneyFormat.format(data['lastPaymentAmount'])}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _manualOverride(context, data),
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Manual Subscription Update'),
                    style: _accentButtonStyle,
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('facilities')
                        .doc(widget.facilityId)
                        .collection('payment_submissions')
                        .orderBy('submittedAt', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, subSnapshot) {
                      final subDocs = subSnapshot.data?.docs ?? [];
                      if (subDocs.isEmpty) {
                        return Text('No submissions yet.', style: TextStyle(color: Colors.grey[600]));
                      }
                      return Column(
                        children: subDocs.map((doc) {
                          final subData = doc.data() as Map<String, dynamic>;
                          final submittedAt = subData['submittedAt'] is Timestamp
                              ? (subData['submittedAt'] as Timestamp).toDate()
                              : null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text('${subData['planLabel'] ?? ''} - Tsh ${subData['amount'] ?? 0}'),
                              subtitle: Text(
                                '${subData['method'] ?? ''}'
                                '${submittedAt != null ? ' • ${DateFormat('dd MMM yyyy').format(submittedAt)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                (subData['status'] as String? ?? '').toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.redAccent),
                  const SizedBox(height: 8),
                  const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text(
                    'Permanently deletes this facility and every record in it - sales, products, clients, and more. This cannot be undone.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isDeleting ? null : () => _deleteFacility(context, data['name'] ?? 'this facility'),
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                          )
                        : const Icon(Icons.delete_forever, color: Colors.redAccent),
                    label: Text(_isDeleting ? 'Deleting...' : 'Delete Facility'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
