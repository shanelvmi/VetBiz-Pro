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

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color dangerColor = Colors.redAccent;
  final Color backgroundColor = const Color(0xFFFDFDF9);
  final Color warmAmber = const Color(0xFFFFB200);

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
        if (states.contains(WidgetState.hovered)) return warmAmber;
        return baseColor;
      }),
      foregroundColor: WidgetStateProperty.all(Colors.white),
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

    final platformAdminDoc = await FirebaseFirestore.instance.collection('platform_admins').doc(uid).get();
    final ownedFacilities =
        await FirebaseFirestore.instance.collection('facilities').where('createdBy', isEqualTo: uid).limit(1).get();

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Log Out of All Devices?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: const Text(
              'This will clear active sessions and log you out on all other phones, tablets, or computers currently signed into your account.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(primaryColor),
            child: const Text('Log Out Everywhere'),
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
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear other sessions: ${e.message}'),
          backgroundColor: dangerColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear other sessions: $e'),
          backgroundColor: dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingOutAll = false);
    }
  }

  // 🔹 Wipe all transactional business data
  void _wipeAllData() async {
    final facilityName = Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacility?['name'] ??
        'this facility';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Wipe All Data?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Its own prominent line, not buried mid-paragraph - the
              // one detail that matters most before confirming this,
              // especially for someone with more than one facility.
              Text('Business data for "$facilityName" will be permanently wiped.',
                  style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              const Text(
                  'All records of sales, products, clients, and transactions for this facility are erased. Other facilities you have are not affected. Your login credentials remain unaffected.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(dangerColor),
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final doubleCheck = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Confirm Action', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: _dialogWidth(context),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please type "ERASE" to finalize clearing all records:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  hintText: 'ERASE',
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: _actionButtonStyle(primaryColor),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (doubleCheck != 'ERASE') return;

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
        userId: userInfo['userId']!,
        userName: userInfo['userName'],
        actionType: 'Account',
        description: 'Wiped all business data for this facility',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All business data has been permanently wiped.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear records: ${e.message}'),
          backgroundColor: dangerColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear records: $e'),
          backgroundColor: dangerColor,
        ),
      );
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
          await FirebaseFirestore.instance.collection('platform_admins').doc(currentUid).get();
      if (platformAdminDoc.exists) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: backgroundColor,
            title: Text('Cannot Deactivate', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: _dialogWidth(context),
              child: const Text(
                  'This account has Platform Admin access, so it can\'t be deactivated - '
                  'not by you, and not by anyone else. This keeps the platform from ever '
                  'being locked out of its own oversight tools.'),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: _actionButtonStyle(primaryColor),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Deactivate Account', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: const Text(
              'Are you sure you want to deactivate your account? You\'ll be signed out '
              'immediately, and will need your facility admin (or Platform Admin) to '
              'reactivate it before you can sign back in.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: _actionButtonStyle(primaryColor),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Second layer, matching the weight given to Wipe Data - deactivation
    // is reversible, but it still ends your current session immediately,
    // so a single tap was too little friction for something grouped with
    // the other Danger Zone actions.
    final doubleCheck = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Confirm Deactivation', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: _dialogWidth(context),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type "DEACTIVATE" to confirm:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                  hintText: 'DEACTIVATE',
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: _actionButtonStyle(primaryColor),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (doubleCheck != 'DEACTIVATE') return;

    try {
      final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
      if (facilityId != null) {
        final userInfo = await ActivityLogger.getCurrentUserInfo();
        await ActivityLogger.logActivity(
          facilityId: facilityId,
          userId: userInfo['userId']!,
          userName: userInfo['userName'],
          actionType: 'Account',
          description: 'Deactivated their own account',
        );
      }

      await authService.deactivateAccount();
      if (!mounted) return;

      await forceLogoutAndShowLogin(
        message: 'Your account has been deactivated.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate account: $e'),
          backgroundColor: dangerColor,
        ),
      );
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
        backgroundColor: backgroundColor,
        title: Text('Delete Account', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Deleting your account is permanent and cannot be undone. All your data will be erased.'),
            const SizedBox(height: 12),
            TextField(
              controller: _deleteEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deletePasswordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
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
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
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
                          userId: userInfo['userId']!,
                          userName: userInfo['userName'],
                          actionType: 'Account',
                          description: 'Deleted their own account',
                        );
                      }

                      await authService.deleteAccount(
                        email: _deleteEmailController.text.trim(),
                        password: _deletePasswordController.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Your account has been deleted.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete account: $e'),
                          backgroundColor: dangerColor,
                        ),
                      );
                    } finally {
                      setState(() => _isDeleting = false);
                    }
                  },
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Delete Account'),
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
      deleteAccountSubtitle = 'Checking...';
    } else if (isPlatformAdminAccount) {
      deleteAccountSubtitle = "Platform Admin accounts can't be deleted from here.";
    } else if (blockedByOwnedFacilities) {
      deleteAccountSubtitle = 'Delete all facilities you own in View Facilities first.';
    } else {
      deleteAccountSubtitle = 'Permanently delete your account. This action cannot be undone.';
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Account'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: dangerColor, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: dangerColor.withValues(alpha: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: dangerColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: TextStyle(color: dangerColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'These actions affect your account and business data. Review carefully before proceeding.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.devices_other, color: primaryColor),
              title: const Text('Log Out of All Devices'),
              subtitle: const Text(
                  'Disconnect your active profile session from all other active platforms.'),
              onTap: inputDisabled ? null : _logoutOfAllDevices,
              trailing: _isLoggingOutAll
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (Provider.of<UserRoleProvider>(context).isAdmin)
          Card(
            elevation: 2,
            child: ListTile(
              leading: _isWipingData
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: dangerColor),
                    )
                  : Icon(Icons.phonelink_erase, color: primaryColor),
              title: const Text('Wipe All Business Data'),
              subtitle: Text(
                  _isWipingData
                      ? 'Erase in progress - please wait, this may take a moment...'
                      : 'Permanently delete records of transactions, sales, and products while keeping your log in profile.'),
              onTap: inputDisabled ? null : _wipeAllData,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('Deactivate Account'),
              subtitle: const Text(
                  'Temporarily disable your account. Can be reactivated later.'),
              onTap: inputDisabled ? null : _deactivateAccount,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              enabled: !(inputDisabled || deleteAccountBlocked),
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete Account'),
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