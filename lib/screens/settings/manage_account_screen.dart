import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../providers/facility_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/activity_logger.dart';
import '../../utils/force_logout.dart';
import '../../data/collections.dart';
import '../../data/fields.dart';
import '../../data/activity_type.dart';
import '../../config/app_limits.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../l10n/l10n.dart';

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  // The words to type before a wipe or a deactivation. They stay English in
  // every language: the sentence around them is translated, the word is what
  // is compared.
  static const _eraseWord = 'ERASE';
  static const _deactivateWord = 'DEACTIVATE';

  Color get dangerColor => context.colors.dangerAccent;

  // Comfortably wide on desktop, but never wider than the actual screen
  // on a phone - AlertDialog otherwise defaults to a fairly narrow,
  // cramped width regardless of how much room is available. Used by
  // every dialog in this file for a consistent feel across all of them,
  // and across screen sizes.
  double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 700 ? 440.0 : screenWidth * 0.88;
  }

  // Same amber-on-hover shift used throughout the rest of the app
  // (Platform Admin's dialogs, for one) - applied here too so hovering
  // any action button anywhere in this file feels identical to hovering
  // one anywhere else in the app, not just consistent within this
  // screen alone.
  ButtonStyle _actionButtonStyle(Color baseColor) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) return context.colors.accent;
        return baseColor;
      }),
      foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
    );
  }

  final _deleteEmailController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _isDeleting = false;
  bool _isWipingData = false;
  bool _isLoggingOutAll = false;

  // Both null while still being checked - not assumed safe in the
  // meantime, since a brief "enabled" flash that then suddenly
  // disables would be more confusing than a moment of "not yet
  // available" while these two quick reads complete.
  bool? _isPlatformAdminAccount;
  bool? _hasOwnedFacility;

  @override
  void initState() {
    super.initState();
    _checkDeleteEligibility();
  }

  // Determines upfront whether Delete Account should even be tappable,
  // rather than letting someone tap it and only then finding out it's
  // blocked:
  // - A Platform Admin never deletes their own account via this
  //   self-service path, whether or not they've also added themselves
  //   to a regular facility - the same protection Firestore's own
  //   rules already give a Platform Admin's account against
  //   deactivation extends here too.
  // - A regular Admin who still owns any facility (created by them,
  //   not just one they belong to) needs to delete those first, via
  //   View Facilities - deleting the account underneath them would
  //   leave those facilities orphaned, with real subscriptions and
  //   real staff, and nobody left who could ever manage or delete
  //   them again.
  Future<void> _checkDeleteEligibility() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final platformAdminDoc = await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(uid).get();
    final ownedFacilities =
        await FirebaseFirestore.instance.collection(Collections.facilities).where('createdBy', isEqualTo: uid).limit(AppLimits.single).get();

    if (!mounted) return;
    setState(() {
      _isPlatformAdminAccount = platformAdminDoc.exists;
      _hasOwnedFacility = ownedFacilities.docs.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _deleteEmailController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  // 🔹 Log out of all active devices
  void _logoutOfAllDevices() async {
    // Read before the awaits: this device must still be logged out after
    // the other sessions are revoked.
    final authService = Provider.of<AuthService>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Text(context.l10n.account_logoutAllTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Text(context.l10n.account_logoutAllBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(context.colors.primary),
            child: Text(context.l10n.account_logoutEverywhere),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOutAll = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('revokeAllSessions');
      await callable.call();

      // "Log out everywhere" should include this device too - otherwise
      // this session would keep working until its cached token naturally
      // expires, which doesn't match what the button says it does.
      await authService.logout();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e, st) {
      // FriendlyError shows a Functions error's own message, as before.
      AppFeedback.error(L10n.current.account_logoutAllFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoggingOutAll = false);
    }
  }

  // 🔹 Wipe all transactional business data
  void _wipeAllData() async {
    final facilityName = Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacility?['name'] ??
        context.l10n.account_thisFacility;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Text(context.l10n.account_wipeTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Its own prominent line, not buried mid-paragraph - the
              // one detail that matters most before confirming this,
              // especially for someone with more than one facility.
              Text(context.l10n.account_wipeFacility(facilityName),
                  style: TextStyle(color: dangerColor, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15)),
              const SizedBox(height: AppSpacing.s10),
              Text(context.l10n.account_wipeBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(dangerColor),
            child: Text(context.l10n.account_wipe),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final doubleCheck = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: context.colors.raisedSurface,
          title: Text(context.l10n.account_confirmTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
          content: SizedBox(
            width: _dialogWidth(context),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.account_typeErase(_eraseWord)),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.primary)),
                  hintText: _eraseWord,
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: _actionButtonStyle(context.colors.primary),
              child: Text(context.l10n.common_confirm),
            ),
          ],
        );
      },
    );

    if (doubleCheck != _eraseWord || !mounted) return;

    setState(() => _isWipingData = true);

    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

      if (facilityId == null || facilityId.isEmpty) {
        throw Exception('No facility selected.');
      }

      final callable = FirebaseFunctions.instance.httpsCallable('wipeFacilityData');
      await callable.call({'facilityId': facilityId});

      if (!mounted) return;

      // Clear every provider's in-memory cache so the UI doesn't keep
      // showing data that no longer exists server-side.
      Provider.of<SaleProvider>(context, listen: false).clear();
      Provider.of<ProductProvider>(context, listen: false).clear();
      Provider.of<ClientProvider>(context, listen: false).clear();
      Provider.of<ServiceProvider>(context, listen: false).clear();
      Provider.of<TransactionProvider>(context, listen: false).clear();
      Provider.of<DebtProvider>(context, listen: false).clear();

      final userInfo = await ActivityLogger.getCurrentUserInfo();
      await ActivityLogger.logActivity(
        facilityId: facilityId,
        userId: userInfo[Fields.userId]!,
        userName: userInfo['userName'],
        actionType: ActivityType.account.key,
        description: 'Wiped all business data for this facility',
      );

      AppFeedback.success(L10n.current.account_wiped);
    } catch (e, st) {
      // FriendlyError shows a Functions error's own message, as before.
      AppFeedback.error(L10n.current.account_wipeFailed, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isWipingData = false);
    }
  }

  // 🔹 Deactivate account
  void _deactivateAccount() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final platformAdminDoc =
          await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(currentUid).get();
      if (platformAdminDoc.exists) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: context.colors.raisedSurface,
            title: Text(context.l10n.account_cannotDeactivateTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
            content: SizedBox(
              width: _dialogWidth(context),
              child: Text(context.l10n.account_cannotDeactivateBody),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: _actionButtonStyle(context.colors.primary),
                child: Text(context.l10n.common_ok),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Text(context.l10n.account_deactivateTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Text(context.l10n.account_deactivateBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(context.colors.primary),
            child: Text(context.l10n.team_deactivate),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Second layer, matching the weight given to Wipe Data - deactivation
    // is reversible, but it still ends your current session immediately,
    // so a single tap was too little friction for something grouped with
    // the other Danger Zone actions.
    final doubleCheck = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: context.colors.raisedSurface,
          title: Text(context.l10n.account_confirmDeactivation, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
          content: SizedBox(
            width: _dialogWidth(context),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.account_typeToConfirm(_deactivateWord)),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: context.colors.primary)),
                  hintText: _deactivateWord,
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: _actionButtonStyle(context.colors.primary),
              child: Text(context.l10n.common_confirm),
            ),
          ],
        );
      },
    );

    if (doubleCheck != _deactivateWord || !mounted) return;

    try {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId != null) {
        final userInfo = await ActivityLogger.getCurrentUserInfo();
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: userInfo[Fields.userId]!,
          userName: userInfo['userName'],
          actionType: ActivityType.account.key,
          description: 'Deactivated their own account',
        );
      }

      await authService.deactivateAccount();
      if (!mounted) return;

      await forceLogoutAndShowLogin(
        message: L10n.current.account_deactivated,
      );
    } catch (e, st) {
      AppFeedback.error(L10n.current.account_deactivateFailed, error: e, stackTrace: st);
    }
  }

  // 🔹 Delete account permanently
  void _deleteAccount() async {
    // Re-derived directly here rather than trusted from the tile's own
    // disabled state - account deletion is irreversible, so this
    // refuses to even show the confirmation dialog if blocked, not
    // just rely on onTap having been null.
    final isPlatformAdminAccount = _isPlatformAdminAccount == true;
    final blockedByOwnedFacilities =
        Provider.of<UserRoleProvider>(context, listen: false).isAdmin && _hasOwnedFacility == true;
    if (isPlatformAdminAccount || blockedByOwnedFacilities) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.raisedSurface,
        title: Text(context.l10n.account_deleteTitle, style: TextStyle(color: context.colors.primary, fontWeight: AppFontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.account_deleteWarning),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _deleteEmailController,
              decoration: InputDecoration(
                labelText: context.l10n.common_email,
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _deletePasswordController,
              decoration: InputDecoration(
                labelText: context.l10n.common_password,
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _deleteEmailController.clear();
              _deletePasswordController.clear();
              Navigator.pop(context);
            },
            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
          ),
          ElevatedButton(
            style: _actionButtonStyle(dangerColor),
            onPressed: _isDeleting
                ? null
                : () async {
                    setState(() => _isDeleting = true);
                    final authService =
                        Provider.of<AuthService>(context, listen: false);
                    try {
                      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
                      if (facilityId != null) {
                        final userInfo = await ActivityLogger.getCurrentUserInfo();
                        await ActivityLogger.logActivity(
                          facilityId: facilityId,
                          userId: userInfo[Fields.userId]!,
                          userName: userInfo['userName'],
                          actionType: ActivityType.account.key,
                          description: 'Deleted their own account',
                        );
                      }

                      await authService.deleteAccount(
                        email: _deleteEmailController.text.trim(),
                        password: _deletePasswordController.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      AppFeedback.info(L10n.current.account_deleted);
                    } catch (e, st) {
                      AppFeedback.error(L10n.current.account_deleteFailed, error: e, stackTrace: st);
                    } finally {
                      setState(() => _isDeleting = false);
                    }
                  },
            child: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.surface,
                    ),
                  )
                : Text(context.l10n.account_deleteTitle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool inputDisabled = _isWipingData || _isLoggingOutAll;

    final userRoleProvider = Provider.of<UserRoleProvider>(context);
    final stillCheckingDeleteEligibility = _isPlatformAdminAccount == null || _hasOwnedFacility == null;
    final isPlatformAdminAccount = _isPlatformAdminAccount == true;
    final blockedByOwnedFacilities = userRoleProvider.isAdmin && _hasOwnedFacility == true;
    final deleteAccountBlocked = stillCheckingDeleteEligibility || isPlatformAdminAccount || blockedByOwnedFacilities;

    final String deleteAccountSubtitle;
    if (stillCheckingDeleteEligibility) {
      deleteAccountSubtitle = context.l10n.account_checking;
    } else if (isPlatformAdminAccount) {
      deleteAccountSubtitle = context.l10n.account_platformAdminNoDelete;
    } else if (blockedByOwnedFacilities) {
      deleteAccountSubtitle = context.l10n.account_deleteOwnedFirst;
    } else {
      deleteAccountSubtitle = context.l10n.account_deleteHint;
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.account_title),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              border: Border.all(color: dangerColor, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.r12),
              color: dangerColor.withValues(alpha: AppAlpha.a05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: dangerColor, size: AppIconSize.i20),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      context.l10n.account_dangerZone,
                      style: TextStyle(color: dangerColor, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  context.l10n.account_dangerHint,
                  style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSoft),
                ),
                const SizedBox(height: AppSpacing.s12),
                Card(
            elevation: AppElevation.e2,
            child: ListTile(
              leading: Icon(Icons.devices_other, color: context.colors.primary),
              title: Text(context.l10n.account_logoutAll),
              subtitle: Text(context.l10n.account_logoutAllHint),
              onTap: inputDisabled ? null : _logoutOfAllDevices,
              trailing: _isLoggingOutAll
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (Provider.of<UserRoleProvider>(context).isAdmin)
          Card(
            elevation: AppElevation.e2,
            child: ListTile(
              leading: _isWipingData
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: dangerColor),
                    )
                  : Icon(Icons.phonelink_erase, color: context.colors.primary),
              title: Text(context.l10n.account_wipeAll),
              subtitle: Text(
                  _isWipingData
                      ? context.l10n.account_wipeInProgress
                      : context.l10n.account_wipeHint),
              onTap: inputDisabled ? null : _wipeAllData,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Card(
            elevation: AppElevation.e2,
            child: ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(context.l10n.account_deactivateTitle),
              subtitle: Text(context.l10n.account_deactivateHint),
              onTap: inputDisabled ? null : _deactivateAccount,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Card(
            elevation: AppElevation.e2,
            child: ListTile(
              enabled: !(inputDisabled || deleteAccountBlocked),
              leading: const Icon(Icons.delete_forever),
              title: Text(context.l10n.account_deleteTitle),
              subtitle: Text(deleteAccountSubtitle),
              onTap: (inputDisabled || deleteAccountBlocked) ? null : _deleteAccount,
            ),
          ),
              ],
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}
