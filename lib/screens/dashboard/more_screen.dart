import 'package:flutter/material.dart';

/// Everything the More page can show (phone_shell.md D5 and section 4).
enum MoreItem {
  clients,
  debtors,
  services,
  payments,
  transactions,
  reports,
  insights,
  stockStore,
  team,
  facilities,
  settings,
  trash,
  export,
  businessHours,
  subscription,
  activityLog,
  help,
  platformAdmin,
}

/// The items the role may use, in order. The gates are today's: the
/// profile drawer's (Team Members, Facilities, Activity log: admins),
/// Settings' (Subscription, Trash, Export, Business Hours: admins) and the
/// sidebar's (Platform Admin: platform admins only).
List<MoreItem> moreItemsFor({required bool isAdmin, bool isPlatformAdmin = false}) => throw UnimplementedError();

/// The item's label: the label the sidebar, drawer or settings already use.
String moreItemLabel(BuildContext context, MoreItem item) => throw UnimplementedError();

/// PH3 (5): the More page, a grid of round icons; each opens the existing
/// screen as today (pushed, full screen over the bar).
class MoreScreen extends StatelessWidget {
  final bool isAdmin;
  final bool isPlatformAdmin;

  /// Opens an item; null: the app's own screens ([openMoreItem]).
  final Future<void> Function(BuildContext context, MoreItem item)? onOpen;

  /// After a pushed screen returns (the dashboard refreshes, as it does
  /// after the sidebar's screens).
  final VoidCallback? onReturned;

  const MoreScreen({super.key, required this.isAdmin, this.isPlatformAdmin = false, this.onOpen, this.onReturned});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// Opens [item]'s existing screen, as the sidebar, drawer and settings do.
Future<void> openMoreItem(BuildContext context, MoreItem item) => throw UnimplementedError();
