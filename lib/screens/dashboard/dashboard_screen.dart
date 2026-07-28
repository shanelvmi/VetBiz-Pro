import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../providers/product_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';

import '../../services/auth_service.dart';

import '../../widgets/summary_card.dart';

import '../products/products_screen.dart';
import '../clients/clients_screen.dart';
import '../services/services_screen.dart';
import '../sales/sales_screen.dart';
import '../transactions/transactions_screen.dart';
import '../facilities/facility_screen.dart';
import '../settings/settings_screen.dart';
import '../activity/activity_log_screen.dart';
import '../debtors/debtors_screen.dart';
import '../store/stockstore_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../sales/add_sale_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../services/add_edit_service_screen.dart';
import '../register_screen.dart';

class DrawerHoverItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const DrawerHoverItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<DrawerHoverItem> createState() => _DrawerHoverItemState();
}

class _DrawerHoverItemState extends State<DrawerHoverItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: _hovered ? Colors.teal.shade700 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: offWhite),
                const SizedBox(width: 16),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: offWhite,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HoverFab extends StatefulWidget {
  final String heroTag;
  final IconData icon;
  final String label;
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;

  const HoverFab({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.color,
    required this.hoverColor,
    required this.onPressed,
  });

  @override
  State<HoverFab> createState() => _HoverFabState();
}

class _HoverFabState extends State<HoverFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..scale(0.97)) // Slight shrink on hover
            : Matrix4.identity(),
        child: FloatingActionButton.extended(
          heroTag: widget.heroTag,
          backgroundColor: _hovered ? widget.hoverColor : widget.color,
          icon: Icon(widget.icon, color: Colors.white),
          label: Text(widget.label, style: const TextStyle(color: Colors.white)),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final user = FirebaseAuth.instance.currentUser;
  late final userDoc = FirebaseFirestore.instance.collection('users').doc(user?.uid);

  Uint8List? _logoBytes; // Facility logo in memory
  Uint8List? _profileBytes; // Profile picture in memory
  final ImagePicker _picker = ImagePicker();

  String selectedFilter = 'Today';

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // PICK & SAVE FACILITY LOGO
  Future<void> pickLogoImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() => _logoBytes = bytes);

    final facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    final facilityId = facilityProvider.selectedFacility?['id'];
    if (facilityId == null) return;

    final storageRef = FirebaseStorage.instance.ref().child('facility_logos/$facilityId.png');
    await storageRef.putData(bytes);
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .set({'logoUrl': downloadUrl}, SetOptions(merge: true));
  }

  // PICK & SAVE USER PROFILE
  Future<void> pickProfileImage() async {
    if (user == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() => _profileBytes = bytes);

    try {
      final storageRef = FirebaseStorage.instance.ref().child('user_avatars/${user!.uid}.png');
      await storageRef.putData(bytes);
      final downloadUrl = await storageRef.getDownloadURL();
      await userDoc.update({'avatarUrl': downloadUrl});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile avatar updated successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile avatar.')),
      );
    }
  }

  void showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(color: primaryDeepGreen)),
        content: Text(content),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: primaryDeepGreen)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: warmAmber),
            child: Text('Confirm'),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: Text("Send password reset email to $email?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryDeepGreen),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Reset link sent to $email")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: Text("Send Link", style: TextStyle(color: offWhite)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final selectedFacility = facilityProvider.selectedFacility;

    // If facility is not yet loaded, show loading indicator
    if (selectedFacility == null) {
    // Facility is required; redirect back to login
    Future.microtask(() {
      Navigator.pushReplacementNamed(context, '/login');
    });
    return const SizedBox.shrink(); // Return empty widget temporarily
   }


    // Facility is loaded, we can safely access its fields
    final facilityName = selectedFacility['name'] ?? 'Facility';

    // Providers
    final productProvider = Provider.of<ProductProvider>(context);
    final clientProvider = Provider.of<ClientProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final saleProvider = Provider.of<SaleProvider>(context);
    final debtProvider = Provider.of<DebtProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);

    // Total product value
    double totalProductValue = productProvider.products.fold(
      0.0,
      (sum, p) => sum + (p.sellPrice * p.stockQty),
    );

    final formatter = NumberFormat.decimalPattern();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLargeScreen = constraints.maxWidth >= 1024;

        return Scaffold(
          backgroundColor: offWhite,
          appBar: AppBar(
            backgroundColor: primaryDeepGreen,
            elevation: 4,
            centerTitle: true,
            iconTheme: IconThemeData(color: offWhite),
            leadingWidth: isLargeScreen ? 220 : null,
            leading: isLargeScreen
                ? Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final now = DateTime.now();
                        final formattedDate =
                            DateFormat('EEE, MMM d, yyyy').format(now);
                        final formattedTime =
                            DateFormat('HH:mm:ss').format(now);

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formattedTime,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: offWhite),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 12, color: offWhite),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : null,
            title: StreamBuilder<DocumentSnapshot>(
              stream: userDoc.snapshots(),
              builder: (context, snapshot) {
                final rawData = snapshot.data?.data();
                final Map<String, dynamic> data = (rawData != null && rawData is Map)
                    ? Map<String, dynamic>.from(rawData)
                    : {};
                final fullName = data['fullName'] ?? '';

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$facilityName Dashboard',
                      style: TextStyle(color: offWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${greetingTime()}, $fullName',
                      style: TextStyle(fontSize: 10, color: offWhite),
                    ),
                  ],
                );
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: userDoc.snapshots(),
                      builder: (context, snapshot) {
                        final rawData = snapshot.data?.data();
                        final Map<String, dynamic> data =
                            (rawData != null && rawData is Map)
                                ? Map<String, dynamic>.from(rawData)
                                : {};
                        final avatarUrl = data['avatarUrl'] as String?;

                        return CircleAvatar(
                          radius: 16,
                          backgroundImage: (_profileBytes != null)
                              ? MemoryImage(_profileBytes!)
                              : (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child: (_profileBytes == null &&
                                  (avatarUrl == null || avatarUrl.isEmpty))
                              ? const Icon(Icons.person)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          drawer: isLargeScreen ? null : Drawer(child: _buildDrawerContent()),
          endDrawer: Drawer(child: _buildEndDrawerContent()),
          body: Column(
            children: [
              Container(height: 1.2, width: double.infinity, color: Colors.grey.shade400),
              Expanded(
                child: Row(
                  children: [
                    if (isLargeScreen) SizedBox(width: 250, child: _buildDrawerContent()),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 8,
                              children: ['Today', 'This Week', 'This Month', 'This Year']
                                  .map((filter) => ChoiceChip(
                                        label: Text(filter),
                                        selected: selectedFilter == filter,
                                        onSelected: (val) {
                                          setState(() {
                                            selectedFilter = filter;
                                          });
                                        },
                                        selectedColor: warmAmber,
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: GridView.count(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 1200 ? 4 : 2,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                children: [
                                  SummaryCard(
                                    title: 'Total Product Value',
                                    value: 'Tsh ${formatter.format(productProvider.totalProductValue)}',
                                    icon: Icons.inventory,
                                    color: primaryDeepGreen,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Total Sales ($selectedFilter)',
                                    value: 'Tsh ${formatter.format(saleProvider.totalSales)}',
                                    icon: Icons.shopping_cart,
                                    color: warmAmber,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Total Earnings',
                                    value:
                                        'Tsh ${formatter.format(saleProvider.totalEarnings + transactionProvider.totalOtherIncome + serviceProvider.totalPaid)}',
                                    icon: Icons.attach_money,
                                    color: primaryDeepGreen,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Total Profit',
                                    value: 
                                        'Tsh ${formatter.format(saleProvider.realizedProfit + serviceProvider.totalServiceProfit + transactionProvider.subProfit)}',
                                    icon: Icons.trending_up,
                                    color: primaryDeepGreen,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Total Expenses',
                                    value: 'Tsh ${formatter.format(transactionProvider.totalExpenses)}',
                                    icon: Icons.trending_down,
                                    color: Colors.red,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Outstanding Payment',
                                    value: 'Tsh ${formatter.format(debtProvider.totalOutstanding())}',
                                    icon: Icons.account_balance_wallet,
                                    color: warmAmber,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Total Clients',
                                    value: '${clientProvider.clients.length}',
                                    icon: Icons.people,
                                    color: warmAmber,
                                    shadow: true,
                                  ),
                                  SummaryCard(
                                    title: 'Completed Services',
                                    value: '${serviceProvider.services.length}',
                                    icon: Icons.design_services,
                                    color: Colors.purple,
                                    shadow: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFABs(),
        );
      },
    );
  }

// DRAWER CONTENTS
Widget _buildDrawerContent() {
  final facilityProvider = Provider.of<FacilityProvider>(context);
  final selectedFacility = facilityProvider.selectedFacility;

  final bool isSmallScreen =
      MediaQuery.of(context).size.height < 600 ||
      MediaQuery.of(context).size.width < 1024;

  // ---------- LOGO ----------
  Widget logoSection = Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    alignment: Alignment.center,
    child: Tooltip(
      message: 'Click to replace logo',
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: GestureDetector(
        onTap: pickLogoImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: offWhite,
              backgroundImage: _logoBytes != null
                  ? MemoryImage(_logoBytes!)
                  : (selectedFacility != null &&
                          selectedFacility['logoUrl'] != null
                      ? NetworkImage(selectedFacility['logoUrl'] as String)
                      : const AssetImage(
                          'assets/vetbiz_pro_logo.png',
                        ) as ImageProvider),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: warmAmber,
                shape: BoxShape.circle,
                border: Border.all(color: offWhite, width: 1.5),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ---------- DRAWER ITEMS ----------
  Widget items = Column(
    children: [
      DrawerHoverItem(
        icon: Icons.inventory,
        title: 'Products',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.people,
        title: 'Clients',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClientsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.design_services,
        title: 'Services',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServicesScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.attach_money,
        title: 'Sales',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SalesScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.receipt_long,
        title: 'Transactions',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TransactionScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.people_alt,
        title: 'Debtors',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtorsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.store,
        title: 'Stock Store',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StockStoreScreen()),
        ),
      ),
    ],
  );

  // ---------- SETTINGS ----------
  Widget settings = DrawerHoverItem(
    icon: Icons.settings,
    title: 'Settings',
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen()),
    ),
  );

  // ---------- FOOTER ----------
  Widget footer = Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      '@VetBiz Pro',
      style: TextStyle(fontSize: 12, color: offWhite),
    ),
  );

  // ---------- FINAL LAYOUT ----------
  Widget content = Column(
    children: [
      logoSection,
      Divider(thickness: 1.2, color: Colors.white54),
      items,
      Divider(thickness: 1.2, color: Colors.white54),
      settings,
    ],
  );

  return Container(
    width: 250,
    color: primaryDeepGreen,
    child: Column(
      children: [
        Expanded(
          child: isSmallScreen
              ? SingleChildScrollView(child: content)
              : content,
        ),
        footer,
      ],
    ),
  );
}



  // --------------------- END DRAWER ---------------------
  Widget _buildEndDrawerContent() {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.hovered)) return Colors.teal.shade700;
          if (states.contains(WidgetState.pressed)) return Colors.teal.shade800;
          return null;
        },
      ),
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        final rawData = snapshot.data?.data();
        final Map<String, dynamic> data =
            (rawData != null && rawData is Map) ? Map<String, dynamic>.from(rawData) : {};

        final role = data['role'] ?? 'Assistant';
        final avatarUrl = data['avatarUrl'] as String?;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar with grey border
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: offWhite,
                          backgroundImage: _profileBytes != null
                              ? MemoryImage(_profileBytes!)
                              : (avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null),
                          child: (_profileBytes == null &&
                                  (avatarUrl == null || avatarUrl.isEmpty))
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: warmAmber,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: pickProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // User Info
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Full Name: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['fullName'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Email: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['email'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Phone: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['phone'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Role: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _capitalize(role)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // Buttons
                ElevatedButton(
                  style: buttonStyle,
                  child: const Text('Edit Profile'),
                  onPressed: () async {
                    final snapshot = await userDoc.get();
                    if (!snapshot.exists) return;

                    final rawUserData = snapshot.data();
                    final userData = (rawUserData != null)
                        ? Map<String, dynamic>.from(rawUserData)
                        : <String, dynamic>{};

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          userData: userData,
                          isUpdating: true,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (role == 'admin') ...[
                  ElevatedButton(
                    style: buttonStyle,
                    child: const Text('Manage Assistants'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageAssistantsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: buttonStyle,
                    child: const Text('View Facilities'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FacilityScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  style: buttonStyle,
                  child: const Text('Change Password'),
                  onPressed: () {
                    final email = FirebaseAuth.instance.currentUser?.email;
                    if (email != null) _showChangePasswordDialog(email);
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: buttonStyle,
                  child: const Text('Activity Log'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ActivityLogScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 80),
              ],
            ),

            // Close X button
            Positioned(
              top: 16,
              right: 16,
              child: Tooltip(
                message: 'Close',
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Logout button
            Positioned(
              bottom: 16,
              right: 16,
              child: Tooltip(
                message: 'Logout',
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  hoverColor: Colors.teal.shade700,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('Logout', style: TextStyle(color: primaryDeepGreen)),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Cancel', style: TextStyle(color: primaryDeepGreen)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              Provider.of<FacilityProvider>(context, listen: false).clearFacility();
                              Provider.of<ProductProvider>(context, listen: false).clear();
                              await FirebaseAuth.instance.signOut();
                              if (!context.mounted) return;
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Ink(
                    decoration: const ShapeDecoration(
                      color: Color(0xFF2F5D62),
                      shape: CircleBorder(),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.power_settings_new, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --------------------- DRAWER ITEM ---------------------
  Widget _drawerItem(IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: offWhite),
      title: Text(title, style: TextStyle(color: offWhite)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  // --------------------- FLOATING ACTION BUTTONS ---------------------
  Widget _buildFABs() {
  final isLargeScreen = MediaQuery.of(context).size.width >= 1024;

  if (isLargeScreen) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HoverFab(
        heroTag: 'add_sale',
        icon: Icons.add_shopping_cart,
        label: 'Add Sale',
        color: warmAmber,
        hoverColor: const Color(0xFFFFC400),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddSaleScreen()),
        ),
      ),
      const SizedBox(width: 12),
      HoverFab(
        heroTag: 'add_product',
        icon: Icons.add_box,
        label: 'Add Product',
        color: primaryDeepGreen,
        hoverColor: const Color(0xFF3B6B6E),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditProductScreen()),
        ),
      ),
      const SizedBox(width: 12),
      HoverFab(
        heroTag: 'add_service',
        icon: Icons.design_services,
        label: 'Add Service',
        color: Colors.purple,
        hoverColor: const Color(0xFF800080),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditServiceScreen()),
        ),
      ),
    ],
  );
 }

  // Mobile → no hover
  return SpeedDial(
    icon: Icons.add,
    activeIcon: Icons.close,
    backgroundColor: primaryDeepGreen,
    foregroundColor: offWhite,
    overlayColor: Colors.black,
    overlayOpacity: 0.4,
    children: [
      SpeedDialChild(
        backgroundColor: warmAmber,
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: 'Add Sale',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddSaleScreen()),
        ),
      ),
      SpeedDialChild(
        backgroundColor: primaryDeepGreen,
        child: const Icon(Icons.add_box, color: Colors.white),
        label: 'Add Product',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditProductScreen()),
        ),
      ),
      SpeedDialChild(
        backgroundColor: Colors.purple,
        child: const Icon(Icons.design_services, color: Colors.white),
        label: 'Add Service',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditServiceScreen()),
        ),
      ),
    ],
  );
}

}
