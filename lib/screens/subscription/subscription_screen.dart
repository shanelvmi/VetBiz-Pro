import 'dart:async';
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
import '../../models/promotion.dart';
import 'subscription_history_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isModal;
  const SubscriptionScreen({super.key, this.isModal = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color backgroundColor = const Color(0xFFFDFDF9);

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');
  final ImagePicker _picker = ImagePicker();

  // Starts with the static defaults so the plan picker isn't blank
  // while the real, Platform-Admin-configured prices load - _loadPlans
  // below swaps these in as soon as they're available.
  List<SubscriptionPlan> _plans = kSubscriptionPlans;
  SubscriptionPlan _selectedPlan = kSubscriptionPlans[2]; // Monthly default
  String _method = 'M-Pesa';
  final TextEditingController _referenceController = TextEditingController();

  Uint8List? _proofBytes;
  bool _isSubmitting = false;

  // Kept open for the screen's lifetime rather than a one-time fetch -
  // a price change from a Platform Admin should show up immediately
  // if this screen is already open, not require closing and reopening
  // it. Cancelled in dispose().
  StreamSubscription<List<SubscriptionPlan>>? _plansSubscription;

  // Same live reasoning as the price stream above - an offer a
  // Platform Admin activates should show up immediately here too.
  Promotion? _activePromotion;
  StreamSubscription<Promotion?>? _promoSubscription;

  // Blocks a second submission while one is already awaiting review -
  // prevents duplicate/conflicting payment claims for a Platform
  // Admin to untangle. Live for the same reason as the streams above:
  // getting approved or rejected while this screen is open should
  // unblock (or re-block) the button immediately, not just on reopen.
  bool _hasPendingSubmission = false;
  StreamSubscription<QuerySnapshot>? _pendingSubscription;

  @override
  void initState() {
    super.initState();
    _plansSubscription = streamSubscriptionPlans().listen((plans) {
      if (!mounted) return;
      setState(() {
        _plans = plans;
        // Keeps the same plan selected (by id, not list position) -
        // each new stream event produces fresh SubscriptionPlan
        // instances, so re-resolving by id (rather than keeping the
        // stale object reference) is what keeps the radio selection
        // from silently breaking every time a price updates.
        _selectedPlan = plans.firstWhere(
          (p) => p.id == _selectedPlan.id,
          orElse: () => plans[2],
        );
      });
    });

    // Same <=7-day window used throughout the rest of the app (the
    // urgent subscription banner, the notification cards) - a
    // targeted offer honors the exact same definition of "expiring
    // soon" everywhere, not a separate one just for promotions.
    final sub = Provider.of<SubscriptionProvider>(context, listen: false);
    final isExpiringSoon = (sub.status == SubscriptionStatus.trial || sub.status == SubscriptionStatus.active) &&
        sub.daysRemaining != null &&
        sub.daysRemaining! <= 7;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId != null) {
      _promoSubscription =
          streamApplicablePromotion(facilityId: facilityId, isExpiringSoon: isExpiringSoon).listen((promo) {
        if (!mounted) return;
        setState(() => _activePromotion = promo);
      });

      _pendingSubscription = FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payment_submissions')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        setState(() => _hasPendingSubmission = snapshot.docs.isNotEmpty);
      });
    }
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    _promoSubscription?.cancel();
    _pendingSubscription?.cancel();
    _referenceController.dispose();
    super.dispose();
  }

  // The price actually charged for a given plan right now - the
  // promotion's discounted price if it applies to this specific plan,
  // otherwise the plan's own regular price unchanged.
  double _effectivePrice(SubscriptionPlan plan) {
    final promo = _activePromotion;
    if (promo == null || !promo.appliesToPlan(plan.id)) return plan.priceTsh;
    return promo.discountedPrice(plan.priceTsh);
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
        await ref.putData(_proofBytes!).timeout(
          const Duration(seconds: 25),
          onTimeout: () => throw Exception(
              'The proof image took too long to upload. Please check your connection and try again.'),
        );
        proofUrl = await ref.getDownloadURL();
      }

      final user = FirebaseAuth.instance.currentUser;
      final effectivePrice = _effectivePrice(_selectedPlan);
      final appliedPromo = (_activePromotion != null && _activePromotion!.appliesToPlan(_selectedPlan.id))
          ? _activePromotion
          : null;

      await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payment_submissions')
          .add({
        'facilityId': facilityId,
        'facilityName': facilityName ?? 'Unknown',
        'planId': _selectedPlan.id,
        'planLabel': _selectedPlan.label,
        'amount': effectivePrice,
        'promotionLabel': appliedPromo?.label,
        'discountPercent': appliedPromo?.discountPercent,
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
        automaticallyImplyLeading: !widget.isModal,
        leading: widget.isModal
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
                            : sub.status == SubscriptionStatus.trial
                                ? 'Trial expires on ${DateFormat('dd MMM yyyy').format(sub.expiresAt!)}'
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

              if (_activePromotion != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [warmAmber, warmAmber.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: warmAmber.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activePromotion!.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${_activePromotion!.discountPercent.toStringAsFixed(_activePromotion!.discountPercent % 1 == 0 ? 0 : 1)}% off'
                              '${_activePromotion!.appliesToAllPlans ? ' every plan' : ' select plans'} - applied automatically below.',
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text('Choose a Plan', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              ..._plans.map((plan) {
                final effectivePrice = _effectivePrice(plan);
                final hasDiscount = effectivePrice < plan.priceTsh;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<SubscriptionPlan>(
                    value: plan,
                    groupValue: _selectedPlan,
                    activeColor: primaryColor,
                    title: Text(plan.label),
                    subtitle: hasDiscount
                        ? Row(
                            children: [
                              Text(
                                'Tsh ${_moneyFormat.format(plan.priceTsh)}',
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tsh ${_moneyFormat.format(effectivePrice)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          )
                        : Text('Tsh ${_moneyFormat.format(plan.priceTsh)}'),
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
                label: Text(_proofBytes == null ? 'Attach Proof (optional)' : 'Proof attached'),
                style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
              ),

              const SizedBox(height: 24),
              Builder(builder: (context) {
                final effectivePrice = _effectivePrice(_selectedPlan);
                final priceUnavailable = effectivePrice <= 0;
                final isBlocked = _hasPendingSubmission || priceUnavailable;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasPendingSubmission)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top, size: 18, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your last payment is still under review. Please wait for it to be '
                                'approved or rejected before submitting another.',
                                style: TextStyle(fontSize: 12.5, color: Colors.orange[800], fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (priceUnavailable)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pricing for this plan isn\'t available right now. Please try again '
                                'shortly or contact support.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey[800], fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 48,
                      child: Opacity(
                        opacity: isBlocked ? 0.5 : 1.0,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || isBlocked) ? null : _submitPayment,
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
                              : Text(
                                  _hasPendingSubmission
                                      ? 'Awaiting Review'
                                      : priceUnavailable
                                          ? 'Pricing Unavailable'
                                          : 'Submit Payment for Review',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              }),

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

Color submissionStatusColor(String status) {
  switch (status) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.redAccent;
    default:
      return Colors.orange;
  }
}

Widget buildSubmissionCard(Map<String, dynamic> data) {
  final status = (data['status'] as String?) ?? 'pending';
  final submittedAt =
      data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : null;
  return Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      dense: true,
      title: Text('${data['planLabel'] ?? ''} - Tsh ${data['amount'] ?? 0}'),
      subtitle: Text(
        '${data['method'] ?? ''}'
        '${submittedAt != null ? ' - ${DateFormat('dd MMM yyyy, HH:mm').format(submittedAt)}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Chip(
        label: Text(status[0].toUpperCase() + status.substring(1),
            style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: submissionStatusColor(status),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

class _SubmissionHistory extends StatelessWidget {
  final String facilityId;
  final Color primaryColor;

  const _SubmissionHistory({required this.facilityId, required this.primaryColor});

  // Genuinely "recent" rather than the previous 10, which was already
  // most of a full history on its own - the full list is a tap away
  // via "View all" below, so this section only needs to show a
  // glance, not double as the history itself.
  static const int _recentLimit = 5;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('payment_submissions')
          .orderBy('submittedAt', descending: true)
          .limit(_recentLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text('No submissions yet.', style: TextStyle(color: Colors.grey[600]));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...docs.map((doc) => buildSubmissionCard(doc.data() as Map<String, dynamic>)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionHistoryScreen(facilityId: facilityId, primaryColor: primaryColor),
                ),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, foregroundColor: primaryColor),
              child: const Text('View all'),
            ),
          ],
        );
      },
    );
  }
}

/// The one entry point for opening Subscription - same reasoning and
/// threshold as showActivityLog: a full-screen push on mobile (no
/// spare room for an overlay), a large, centered, dismissable modal
/// on desktop/tablet-width screens, so it stays visually consistent
/// with the rest of the "modern desktop" screens rather than the
/// last one still doing an abrupt full-screen navigation.
Future<void> showSubscriptionScreen(BuildContext context) async {
  final isWideScreen = MediaQuery.of(context).size.width >= 900;

  if (!isWideScreen) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Subscription',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenSize = MediaQuery.of(context).size;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: screenSize.height * 0.85,
          ),
          child: SizedBox(
            width: screenSize.width * 0.8,
            height: screenSize.height * 0.85,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const Material(
                child: SubscriptionScreen(isModal: true),
              ),
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
