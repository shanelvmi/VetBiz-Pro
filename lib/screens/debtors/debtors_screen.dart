import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/client.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import 'add_payment_screen.dart';
import '../payments/payments_screen.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';

    if (facilityId.isNotEmpty) {
      Provider.of<DebtProvider>(context, listen: false).listenToDebts(facilityId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtProvider = Provider.of<DebtProvider>(context);
    final debts = debtProvider.debts;

    // Group debts by clientId
    final Map<String, List> debtsByClient = {};
    for (var debt in debts) {
      debtsByClient.putIfAbsent(debt.clientId, () => []).add(debt);
    }

    // Sort clients by total owed
    final sortedClients = debtsByClient.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.fold<double>(0, (sum, d) => sum + d.amountOwed);
        final totalB = b.value.fold<double>(0, (sum, d) => sum + d.amountOwed);
        return totalB.compareTo(totalA);
      });

    // Filter out clients with zero debt, then apply the name search - both
    // clientName and clientPhone now come straight off the Debt record
    // itself (denormalized at creation time), instead of a live Firestore
    // lookup per client on every render.
    final visibleClients = sortedClients.where((entry) {
      final totalOwed = entry.value.fold<double>(0, (sum, d) => sum + d.amountOwed);
      if (totalOwed <= 0) return false;

      if (_searchQuery.isEmpty) return true;
      final clientName = (entry.value.first.clientName ?? '').toLowerCase();
      return clientName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${visibleClients.length} debtor${visibleClients.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
          Expanded(
            child: visibleClients.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No debtors found.'
                          : 'No debtors match your search.',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  )
                : _buildDebtorsGrid(visibleClients),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search debtors...',
                hintStyle: TextStyle(color: offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: offWhite),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            )
          : const Text('Active Debts', style: TextStyle(color: Colors.white)),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _isSearchExpanded = true),
          ),
      ],
    );
  }

  // Same responsive pattern used across the app: 1 column on phones, 2 on
  // wide screens.
  Widget _buildDebtorsGrid(List<MapEntry<String, List>> visibleClients) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;

        if (isLargeScreen) {
          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            itemCount: visibleClients.length,
            itemBuilder: (context, index) => _buildClientCard(visibleClients[index]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: visibleClients.length,
          itemBuilder: (context, index) => _buildClientCard(visibleClients[index]),
        );
      },
    );
  }

  /// One-tap reminder, not automated bulk sending - opens WhatsApp or
  /// SMS with a pre-filled message ready to review and send. There's no
  /// backend here to send these on a schedule; this is a daily-follow-up
  /// convenience, one debtor at a time.
  Future<void> _showReminderOptions(
      BuildContext context, String clientName, String phone, double amountOwed) async {
    final facilityName =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityName ?? 'us';
    final formatter = NumberFormat('#,##0', 'en_US');
    final message =
        'Hi $clientName, this is a reminder from $facilityName that you have an outstanding '
        'balance of Tsh ${formatter.format(amountOwed)}. Kindly settle at your earliest '
        'convenience. Thank you!';

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Text('Remind $clientName about their Tsh ${formatter.format(amountOwed)} balance via:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'sms'),
            child: const Text('SMS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'whatsapp'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encodedMessage = Uri.encodeComponent(message);

    final uri = choice == 'whatsapp'
        ? Uri.parse('https://wa.me/${digitsOnly.replaceAll('+', '')}?text=$encodedMessage')
        : Uri.parse('sms:$digitsOnly?body=$encodedMessage');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${choice == 'whatsapp' ? 'WhatsApp' : 'Messages'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reminder: $e')),
        );
      }
    }
  }

  Widget _buildClientCard(MapEntry<String, List> entry) {
    final clientId = entry.key;
    final clientDebts = entry.value;

    final totalOwed = clientDebts.fold<double>(0.0, (sum, d) => sum + d.amountOwed);
    final clientName = clientDebts.first.clientName ?? 'Unknown';
    final clientPhone = clientDebts.first.clientPhone ?? '';

    // Latest debt date
    clientDebts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastDebtDate = clientDebts.first.timestamp;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        key: PageStorageKey(clientId),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                clientName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.notifications_active_outlined, size: 20, color: Colors.orange[700]),
              tooltip: 'Send Reminder',
              onPressed: clientPhone.isEmpty
                  ? null
                  : () => _showReminderOptions(context, clientName, clientPhone, totalOwed),
            ),
            IconButton(
              icon: Icon(Icons.history, size: 20, color: primaryDeepGreen),
              tooltip: 'Payment History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentsScreen(
                      initialClientId: clientId,
                      initialClientName: clientName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owes: Tsh ${currencyFormat.format(totalOwed)}'
              '${clientPhone.isNotEmpty ? ' • $clientPhone' : ''}',
              style: TextStyle(color: Colors.red[700]),
            ),
            Text(
              'Last debt: ${lastDebtDate.day}/${lastDebtDate.month}/${lastDebtDate.year}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        children: [
          ...clientDebts.expand<Widget>((debt) {
            final debtDate = debt.timestamp;
            final isSale = debt.saleId != null;
            final debtSource = isSale ? 'Sale' : 'Service';

            if (isSale) {
              final displayText = debt.items.isNotEmpty
                  ? debt.items.map<String>((e) {
                      final name = (e['name'] ?? 'Unknown').toString();
                      final qty = (e['quantity'] ?? '').toString();
                      final unit = (e['unit'] ?? '').toString();
                      if (qty != '') {
                        return unit != '' ? '$name $qty$unit' : '$name $qty';
                      }
                      return name;
                    }).join(', ')
                  : 'No items';

              return <Widget>[
                _buildDebtTile(context, clientId, clientName, clientPhone,
                    debt.id, debtDate, debtSource, displayText, debt.amountOwed)
              ];
            } else {
              return debt.items.isNotEmpty
                  ? debt.items.map<Widget>((e) {
                      final serviceName = (e['serviceName'] ?? 'Unknown').toString();
                      return _buildDebtTile(
                          context,
                          clientId,
                          clientName,
                          clientPhone,
                          debt.id,
                          debtDate,
                          debtSource,
                          serviceName,
                          debt.amountOwed);
                    }).toList()
                  : <Widget>[
                      _buildDebtTile(context, clientId, clientName, clientPhone,
                          debt.id, debtDate, debtSource, 'No services', debt.amountOwed)
                    ];
            }
          }),
        ],
      ),
    );
  }

  Widget _buildDebtTile(BuildContext context, String clientId, String clientName,
      String clientPhone, String debtId, DateTime debtDate, String source,
      String displayText, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date: ${debtDate.day}/${debtDate.month}/${debtDate.year} • Source: $source',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            source == 'Sale' ? 'Items: $displayText' : 'Service: $displayText',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Amount: Tsh ${currencyFormat.format(amount)}',
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: warmAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final selectedClient = Client(
                  id: clientId,
                  name: clientName,
                  phone: clientPhone,
                  address: '',
                  balance: 0.0,       // optional
                  types: const [],
                );
                final result = await showAddPaymentScreen(
                  context,
                  preselectedClient: selectedClient,
                  debtDocId: debtId,
                  amountOwed: amount,
                  facilityId:
                      Provider.of<FacilityProvider>(context, listen: false)
                          .selectedFacilityId,
                );

                if (result == true) {
                  final facilityId =
                      Provider.of<FacilityProvider>(context, listen: false)
                          .selectedFacilityId;
                  if (facilityId != null) {
                    Provider.of<DebtProvider>(context, listen: false)
                        .listenToDebts(facilityId);
                  }
                }
              },
              child: const Text('Pay'),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
