import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/facility_provider.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  String selectedFilter = 'All';
  String searchQuery = '';
  int _daysToShow = 30; // Default 30 days
  
  FacilityProvider? _facilityProvider;

  final actionTypes = [
    'All',
    'Products',
    'Inventory Move',
    'Sales',
    'Services',
    'Clients',
    'Debtors',
    'Settings',
    'Admin'
  ];

  // Date range options
  final Map<String, int> dateRanges = {
    'Last 7 Days': 7,
    'Last 30 Days': 30,
    'Last 90 Days': 90,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _facilityProvider = Provider.of<FacilityProvider>(context, listen: false);
    _facilityProvider!.addListener(_onFacilityChange);
  }

  @override
  void dispose() {
    _facilityProvider?.removeListener(_onFacilityChange);
    super.dispose();
  }

  void _onFacilityChange() {
    if (!mounted) return;
    setState(() {
      selectedFilter = 'All';
      searchQuery = '';
    });
  }

  // 🧹 Auto-delete logs older than 90 days
  Future<void> _cleanupOldLogs(String facilityId) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      final oldLogs = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (oldLogs.docs.isEmpty) {
        debugPrint('✅ No old logs to delete');
        return;
      }

      // Delete in batches (Firestore limit: 500 operations per batch)
      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
        count++;
        
        if (count >= 500) break; // Safety limit
      }

      await batch.commit();
      debugPrint('🧹 Deleted $count old activity logs (>90 days)');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old logs: $e');
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'inventory move':
        return Colors.blue;
      case 'products':
        return Colors.green;
      case 'sales':
        return warmAmber;
      case 'services':
        return Colors.purple;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      case 'admin':
        return Colors.red;
      default:
        return primaryDeepGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider =
        Provider.of<FacilityProvider>(context, listen: false);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityId = selectedFacility?['id'];

    if (facilityId == null) {
      return Scaffold(
        backgroundColor: offWhite,
        appBar: AppBar(
          title: const Text(
            'Activity Log',
            style: TextStyle(color: Color(0xFFFDFDF9)),
          ),
          backgroundColor: primaryDeepGreen,
          centerTitle: true,
        ),
        body: const Center(child: Text('No facility selected.')),
      );
    }

    // 🧹 Run cleanup on screen load (runs once per session)
    Future.delayed(Duration.zero, () => _cleanupOldLogs(facilityId));

    // Query based on selected date range
    final cutoffDate = DateTime.now().subtract(Duration(days: _daysToShow));
    
    final logStream = FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('activity_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
        .orderBy('timestamp', descending: true)
        .limit(500) // Performance limit
        .snapshots();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        title: const Text(
          'Activity Log',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: Color(0xFFFDFDF9),
          ),
        ),
        backgroundColor: primaryDeepGreen,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFDFDF9)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 1024;

          return Column(
            children: [
              // Stats card
              _buildStatsCard(facilityId),
              
              // Filters Row
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: isLargeScreen
                    ? Row(
                        children: [
                          Expanded(child: _filterDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _dateRangeDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _searchField()),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _filterDropdown()),
                              const SizedBox(width: 8),
                              Expanded(child: _dateRangeDropdown()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _searchField(),
                        ],
                      ),
              ),
              
              const SizedBox(height: 8),
              
              // Activity Log List
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: logStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: primaryDeepGreen,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, 
                              size: 64, 
                              color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No activity logs found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logs auto-delete after 90 days',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter logs
                    final logs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final actionType = data['actionType'] ?? '';
                      final description = data['description'] ?? '';

                      final matchesType = selectedFilter == 'All' ||
                          actionType.toString().toLowerCase() ==
                              selectedFilter.toLowerCase();
                      final matchesSearch =
                          description.toLowerCase().contains(searchQuery.toLowerCase());

                      return matchesType && matchesSearch;
                    }).toList();

                    if (logs.isEmpty) {
                      return const Center(
                        child: Text('No logs match the selected filters.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = logs[index].data();
                        final user = data['userName'] ?? 'Unknown';
                        final action = data['description'] ?? '';
                        final type = data['actionType'] ?? '';
                        final timestamp = data['timestamp'];
                        String dateStr = '';
                        if (timestamp != null && timestamp is Timestamp) {
                          dateStr = DateFormat('dd MMM yyyy – HH:mm:ss')
                              .format(timestamp.toDate().toLocal());
                        }

                        final actionColor = _getActionColor(type);
                        final actionIcon = _getActionIcon(type);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: actionColor.withValues(alpha: 0.2),
                              child: Icon(
                                actionIcon,
                                color: actionColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              action,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person, 
                                      size: 14, 
                                      color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      user,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, 
                                      size: 14, 
                                      color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: actionColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: actionColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(String facilityId) {
    final cutoffDate = DateTime.now().subtract(Duration(days: _daysToShow));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('activity_logs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final totalLogs = docs.length;
        
        // Count by type
        final typeCounts = <String, int>{};
        for (final doc in docs) {
          final type = doc['actionType'] ?? 'Unknown';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDeepGreen, primaryDeepGreen.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryDeepGreen.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: offWhite, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Activity Summary',
                        style: TextStyle(
                          color: offWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: offWhite.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_delete, color: offWhite, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '90d auto-delete',
                          style: TextStyle(
                            color: offWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _statChip('Total', totalLogs.toString(), Icons.list),
                  if (typeCounts['Inventory Move'] != null)
                    _statChip('Moves', typeCounts['Inventory Move'].toString(), 
                      Icons.swap_horiz),
                  if (typeCounts['Products'] != null)
                    _statChip('Products', typeCounts['Products'].toString(), 
                      Icons.inventory_2),
                  if (typeCounts['Sales'] != null)
                    _statChip('Sales', typeCounts['Sales'].toString(), 
                      Icons.shopping_cart),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: offWhite.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: offWhite, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: offWhite,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Date range dropdown with custom styling
  Widget _dateRangeDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _daysToShow,
      decoration: InputDecoration(
        labelText: 'Date Range',
        labelStyle: TextStyle(color: Colors.grey[700]),
        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryDeepGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        prefixIcon: Icon(Icons.calendar_today, color: primaryDeepGreen),
      ),
      items: dateRanges.entries
          .map((entry) => DropdownMenuItem(
                value: entry.value,
                child: Text(entry.key),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null && mounted) {
          setState(() => _daysToShow = val);
        }
      },
    );
  }

  Widget _filterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedFilter,
      decoration: InputDecoration(
        labelText: 'Filter by Action',
        labelStyle: TextStyle(color: Colors.grey[700]),
        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryDeepGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        prefixIcon: Icon(Icons.filter_list, color: primaryDeepGreen),
      ),
      items: actionTypes
          .map((type) => DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(_getActionIcon(type), 
                      size: 18, 
                      color: _getActionColor(type)),
                    const SizedBox(width: 8),
                    Text(type),
                  ],
                ),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null && mounted) setState(() => selectedFilter = val);
      },
    );
  }

  Widget _searchField() {
    return TextFormField(
      cursorColor: primaryDeepGreen,
      decoration: InputDecoration(
        labelText: 'Search',
        labelStyle: TextStyle(color: Colors.grey[700]),
        floatingLabelStyle: TextStyle(color: primaryDeepGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryDeepGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        prefixIcon: Icon(Icons.search, color: primaryDeepGreen),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  if (mounted) setState(() => searchQuery = '');
                },
              )
            : null,
      ),
      onChanged: (val) {
        if (mounted) setState(() => searchQuery = val.trim());
      },
    );
  }
}