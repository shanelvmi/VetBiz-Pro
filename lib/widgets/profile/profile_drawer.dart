import 'package:flutter/material.dart';

/// One action in the profile drawer.
class ProfileDrawerAction {
  const ProfileDrawerAction({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Shown in the danger colour (Sign out).
  final bool destructive;
}

/// A compact row of the profile drawer: a leading icon and the label.
class ProfileDrawerRow extends StatelessWidget {
  const ProfileDrawerRow({super.key, required this.action});

  final ProfileDrawerAction action;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G2: ProfileDrawerRow');
}

/// The profile drawer: the avatar (display only), the name, the role, the
/// person's details as icon, label and value rows, then the actions.
class ProfileDrawerContent extends StatelessWidget {
  const ProfileDrawerContent({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.roleLabel,
    required this.email,
    required this.phone,
    required this.facility,
    required this.actions,
    required this.onClose,
  });

  final String? avatarUrl;
  final String name;
  final String roleLabel;
  final String email;
  final String phone;
  final String facility;
  final List<ProfileDrawerAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('G2: ProfileDrawerContent');
}
