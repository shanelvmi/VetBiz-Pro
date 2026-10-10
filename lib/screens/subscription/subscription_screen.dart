import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/facility_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../constants/subscription_plans.dart';
import '../../models/promotion.dart';
import 'subscription_history_screen.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/payment_submission_status.dart';
import '../../config/payment_methods.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_date_format.dart';
import '../../ui/feedback/app_feedback.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isModal;
  const SubscriptionScreen({super.key, this.isModal = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // The submit button's height: a size, not spacing (spec 4.3).
  static const double _submitButtonHeight = 48;


  final ImagePicker _picker = ImagePicker();

  // Starts with the static defaults so the plan picker isn't blank
  // while the real, Platform-Admin-configured prices load - _loadPlans
  // below swaps these in as soon as they're available.
  List<SubscriptionPlan> _plans = kSubscriptionPlans;
  SubscriptionPlan _selectedPlan = kSubscriptionPlans[2]; // Monthly default
  String _method = PaymentMethod.mPesa.key;
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
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.paymentSubmissions)
          .where(Fields.status, isEqualTo: PaymentSubmissionStatus.pending.key)
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
      AppFeedback.warning('Enter the payment reference / confirmation code');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? proofUrl;
      if (_proofBytes != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'payment_proofs/$facilityId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_proofBytes!).timeout(
          AppTimeouts.proofUpload,
          // A TimeoutException, so FriendlyError shows its "took too long"
          // sentence and this one appears under Details.
          onTimeout: () => throw TimeoutException(
              'The proof image took too long to upload. Please check your connection and try again.',
              AppTimeouts.proofUpload),
        );
        proofUrl = await ref.getDownloadURL();
      }

      final user = FirebaseAuth.instance.currentUser;
      final effectivePrice = _effectivePrice(_selectedPlan);
      final appliedPromo = (_activePromotion != null && _activePromotion!.appliesToPlan(_selectedPlan.id))
          ? _activePromotion
          : null;

      await FirebaseFirestore.instance
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.paymentSubmissions)
          .add({
        Fields.facilityId: facilityId,
        'facilityName': facilityName ?? 'Unknown',
        'planId': _selectedPlan.id,
        'planLabel': _selectedPlan.label,
        'amount': effectivePrice,
        'promotionLabel': appliedPromo?.label,
        'discountPercent': appliedPromo?.discountPercent,
        'method': _method,
        'reference': _referenceController.text.trim(),
        'proofImageUrl': proofUrl,
        Fields.status: PaymentSubmissionStatus.pending.key,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': user?.email ?? user?.uid ?? 'Unknown',
      });

      if (!mounted) return;
      _referenceController.clear();
      setState(() => _proofBytes = null);

      AppFeedback.success('Payment submitted', detail: 'It will be reviewed and confirmed shortly');
    } catch (e, st) {
      // The reference and proof are still in the form (they're cleared only
      // on success), so Retry simply submits again.
      AppFeedback.error("Couldn't submit the payment", error: e, stackTrace: st, onRetry: _submitPayment);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _statusColor(SubscriptionStatus status, AppColors colors) {
    switch (status) {
      case SubscriptionStatus.active:
        return colors.success;
      case SubscriptionStatus.trial:
        return colors.primary;
      case SubscriptionStatus.grace:
        return colors.warning;
      case SubscriptionStatus.locked:
        return colors.dangerAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    final sub = Provider.of<SubscriptionProvider>(context);
    final colors = context.colors;
    final statusColor = _statusColor(sub.status, colors);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Subscription'),
        centerTitle: true,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
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
          constraints: const BoxConstraints(maxWidth: AppSizes.formMax),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: AppAlpha.a10),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium, color: statusColor),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          sub.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: AppFontWeight.bold,
                            fontSize: AppFontSize.f15,
                          ),
                        ),
                      ],
                    ),
                    if (sub.expiresAt != null) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        sub.status == SubscriptionStatus.locked
                            ? 'Expired on ${AppDateFormat.dateTime24.format(sub.expiresAt!)}'
                            : sub.status == SubscriptionStatus.trial
                                ? 'Trial expires on ${AppDateFormat.dateTime24.format(sub.expiresAt!)}'
                                : 'Renews / expires on ${AppDateFormat.dateTime24.format(sub.expiresAt!)}',
                        style: const TextStyle(fontSize: AppFontSize.f13),
                      ),
                    ],
                    if (sub.status == SubscriptionStatus.locked)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.s8),
                        child: Text(
                          'Your account is in read-only mode. Submit a payment below to '
                          'restore full access - your data is safe and untouched.',
                          style: TextStyle(fontSize: AppFontSize.f12_5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              if (_activePromotion != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accent, colors.accent.withValues(alpha: AppAlpha.a70)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.r14),
                    boxShadow: [
                      BoxShadow(color: colors.accent.withValues(alpha: AppAlpha.a40), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: colors.onPrimary, size: AppIconSize.i24),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activePromotion!.label,
                              style: TextStyle(color: colors.onPrimary, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                            ),
                            Text(
                              '${_activePromotion!.discountPercent.toStringAsFixed(_activePromotion!.discountPercent % 1 == 0 ? 0 : 1)}% off'
                              '${_activePromotion!.appliesToAllPlans ? ' every plan' : ' select plans'} - applied automatically below.',
                              style: TextStyle(color: colors.onPrimary, fontSize: AppFontSize.f12_5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
              ],

              Text('Choose a Plan', style: TextStyle(fontWeight: AppFontWeight.bold, color: colors.primary)),
              const SizedBox(height: AppSpacing.s8),
              ..._plans.map((plan) {
                final effectivePrice = _effectivePrice(plan);
                final hasDiscount = effectivePrice < plan.priceTsh;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: RadioListTile<SubscriptionPlan>(
                    value: plan,
                    groupValue: _selectedPlan,
                    activeColor: colors.primary,
                    title: Text(plan.label),
                    subtitle: hasDiscount
                        ? Row(
                            children: [
                              Text(
                                Money.symbolPlain(plan.priceTsh),
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: colors.textHint,
                                  fontSize: AppFontSize.f12_5,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                Money.symbolPlain(effectivePrice),
                                style: TextStyle(
                                  color: colors.success,
                                  fontWeight: AppFontWeight.bold,
                                  fontSize: AppFontSize.f13_5,
                                ),
                              ),
                            ],
                          )
                        : Text(Money.symbolPlain(plan.priceTsh)),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedPlan = value);
                    },
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.s16),
              Text('Payment Details', style: TextStyle(fontWeight: AppFontWeight.bold, color: colors.primary)),
              const SizedBox(height: AppSpacing.s8),

              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                // New requests store the method's key ('Mixx by Yas', not the
                // old 'Tigo Pesa'); old requests keep what they stored.
                items: [
                  for (final m in PaymentMethod.subscription)
                    DropdownMenuItem(value: m.key, child: Text(m.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Transaction / Confirmation Code',
                  hintText: 'e.g. the M-Pesa confirmation code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              OutlinedButton.icon(
                onPressed: _pickProofImage,
                icon: const Icon(Icons.upload_file),
                label: Text(_proofBytes == null ? 'Attach Proof (optional)' : 'Proof attached'),
                style: OutlinedButton.styleFrom(foregroundColor: colors.primary),
              ),

              const SizedBox(height: AppSpacing.s24),
              Builder(builder: (context) {
                final effectivePrice = _effectivePrice(_selectedPlan);
                final priceUnavailable = effectivePrice <= 0;
                final isBlocked = _hasPendingSubmission || priceUnavailable;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasPendingSubmission)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: AppAlpha.a10),
                          borderRadius: BorderRadius.circular(AppRadius.r10),
                          border: Border.all(color: colors.warning.withValues(alpha: AppAlpha.a30)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top, size: AppIconSize.i18, color: colors.warning),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                              child: Text(
                                'Your last payment is still under review. Please wait for it to be '
                                'approved or rejected before submitting another.',
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: colors.warningStrong, fontWeight: AppFontWeight.semibold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (priceUnavailable)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: colors.textHint.withValues(alpha: AppAlpha.a10),
                          borderRadius: BorderRadius.circular(AppRadius.r10),
                          border: Border.all(color: colors.textHint.withValues(alpha: AppAlpha.a30)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: AppIconSize.i18, color: colors.textSoft),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                              child: Text(
                                'Pricing for this plan isn\'t available right now. Please try again '
                                'shortly or contact support.',
                                style: TextStyle(fontSize: AppFontSize.f12_5, color: colors.textPrimary, fontWeight: AppFontWeight.semibold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: _submitButtonHeight,
                      child: Opacity(
                        opacity: isBlocked ? 0.5 : 1.0,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || isBlocked) ? null : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onPrimary),
                                )
                              : Text(
                                  _hasPendingSubmission
                                      ? 'Awaiting Review'
                                      : priceUnavailable
                                          ? 'Pricing Unavailable'
                                          : 'Submit Payment for Review',
                                  style: const TextStyle(fontWeight: AppFontWeight.bold),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: AppSpacing.s24),
              Text('Recent Submissions', style: TextStyle(fontWeight: AppFontWeight.bold, color: colors.primary)),
              const SizedBox(height: AppSpacing.s8),
              if (facilityId != null) _SubmissionHistory(facilityId: facilityId, primaryColor: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Color submissionStatusColor(String status, AppColors colors) {
  switch (PaymentSubmissionStatus.fromKey(status)) {
    case PaymentSubmissionStatus.approved:
      return colors.success;
    case PaymentSubmissionStatus.rejected:
      return colors.dangerAccent;
    default:
      return colors.warning;
  }
}

Widget buildSubmissionCard(Map<String, dynamic> data, AppColors colors) {
  final status = (data[Fields.status] as String?) ?? PaymentSubmissionStatus.pending.key;
  final submittedAt =
      data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : null;
  // Saved by the platform admin when rejecting - empty if they left the
  // (optional) reason blank.
  final reviewNote = ((data['reviewNote'] as String?) ?? '').trim();
  return Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.s6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data['planLabel'] ?? ''} - ${Money.symbolAsStored(data['amount'] ?? 0)}',
                        style: const TextStyle(fontSize: AppFontSize.f14)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '${data['method'] ?? ''}'
                      '${submittedAt != null ? ' - ${AppDateFormat.dateTime24.format(submittedAt)}' : ''}',
                      style: TextStyle(fontSize: AppFontSize.f12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Chip(
                label: Text(status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(fontSize: AppFontSize.f11, color: colors.onPrimary)),
                backgroundColor: submissionStatusColor(status, colors),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          // Why it was rejected - previously only visible in the one-off
          // notification, gone from the history itself.
          if (status == PaymentSubmissionStatus.rejected.key) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              reviewNote.isNotEmpty ? 'Reason: $reviewNote' : 'No reason was given',
              style: TextStyle(
                fontSize: AppFontSize.f12,
                color: reviewNote.isNotEmpty ? colors.dangerStrong : colors.textMuted,
                fontStyle: reviewNote.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ],
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
          .collection(Collections.facilities)
          .doc(facilityId)
          .collection(Collections.paymentSubmissions)
          .orderBy('submittedAt', descending: true)
          .limit(_recentLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text('No submissions yet.', style: TextStyle(color: context.colors.textMuted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...docs.map((doc) => buildSubmissionCard(doc.data() as Map<String, dynamic>, context.colors)),
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
  final isWideScreen = context.screenWidth >= AppBreakpoints.medium;

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
              child: SubscriptionScreen(isModal: true),
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
