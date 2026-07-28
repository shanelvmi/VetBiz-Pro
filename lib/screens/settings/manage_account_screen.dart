import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  final Color primaryColor = const Color(0xFF2F5D62);
  final Color dangerColor = Colors.redAccent;
  final Color backgroundColor = const Color(0xFFFDFDF9);

  final _deleteEmailController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _isDeleting = false;
  bool _isWipingData = false;
  bool _isLoggingOutAll = false;

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
        content: const Text(
            'This will clear active sessions and log you out on all other phones, tablets, or computers currently signed into your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Log Out Everywhere'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOutAll = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // TODO: Implement logoutAllDevices() inside your AuthService
      // await authService.logoutAllDevices();
      
      await Future.delayed(const Duration(seconds: 1)); // Placeholder for smooth UX
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully logged out of all other sessions.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear other sessions: $e'),
          backgroundColor: dangerColor,
        ),
      );
    } finally {
      setState(() => _isLoggingOutAll = false);
    }
  }

  // 🔹 Wipe all transactional business data
  void _wipeAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Wipe All Data?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: const Text(
            'This will permanently delete all records of sales, products, clients, and transactions. Your login credentials will remain unaffected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
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
          content: Column(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (doubleCheck != 'ERASE') return;

    setState(() => _isWipingData = true);

    try {
      // TODO: Call your provider deletion functions here
      await Future.delayed(const Duration(seconds: 2)); // Placeholder
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been successfully wiped.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear records: $e'),
          backgroundColor: dangerColor,
        ),
      );
    } finally {
      setState(() => _isWipingData = false);
    }
  }

  // 🔹 Deactivate account
  void _deactivateAccount() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: const Text(
            'Are you sure you want to deactivate your account? You can reactivate it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await authService.deactivateAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deactivated.'),
          backgroundColor: Colors.orange,
        ),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () {
              _deleteEmailController.clear();
              _deletePasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
            onPressed: _isDeleting
                ? null
                : () async {
                    setState(() => _isDeleting = true);
                    final authService =
                        Provider.of<AuthService>(context, listen: false);
                    try {
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Account'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.phonelink_erase, color: primaryColor),
              title: const Text('Wipe All Business Data'),
              subtitle: const Text(
                  'Permanently delete records of transactions, sales, and products while keeping your log in profile.'),
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
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete Account'),
              subtitle: const Text(
                  'Permanently delete your account. This action cannot be undone.'),
              onTap: inputDisabled ? null : _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}