import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/client.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/client_provider.dart';
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
      // A debt's own clientName/clientPhone are only ever a snapshot from
      // the moment it was created - if that client's details are later
      // edited (a corrected phone number, a name change), this screen
      // used to have no way of finding out, since it never listened to
      // the clients collection at all. That's a real problem here
      // specifically, unlike a receipt or a past sale record, because
      // this represents an active, ongoing relationship - someone might
      // be reading this exact phone number to call and collect what's
      // owed, so it needs to be current, not whatever it was when the
      // debt was first recorded.
      Provider.of<ClientProvider>(context, listen: false).listenToClients(facilityId);
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
    final clientProvider = Provider.of<ClientProvider>(context);
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

    // Filter out clients with zero debt, then apply the name search. Name
    // and phone are now resolved live against ClientProvider (falling
    // back to the debt's own denormalized copy only if that client
    // record can't be found - e.g. it was since deleted), rather than
    // trusting whatever was frozen onto the debt at creation time.
    final visibleClients = sortedClients.where((entry) {
      final totalOwed = entry.value.fold<double>(0, (sum, d) => sum + d.amountOwed);
      if (totalOwed <= 0) return false;

      if (_searchQuery.isEmpty) return true;
      final liveClient = clientProvider.getClientById(entry.key);
      final clientName =
          (liveClient?.name ?? entry.value.first.clientName ?? '').toLowerCase();
      return clientName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: visibleClients.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isEmpty ? 'No debtors found.' : 'No debtors match your search.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
          : _buildDebtorsGrid(visibleClients, clientProvider),
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

  Widget _buildDebtorsGrid(List<MapEntry<String, List>> visibleClients, ClientProvider clientProvider) {
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
            itemBuilder: (context, index) => _buildClientCard(visibleClients[index], clientProvider),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: visibleClients.length,
          itemBuilder: (context, index) => _buildClientCard(visibleClients[index], clientProvider),
        );
      },
    );
  }

  Widget _buildClientCard(MapEntry<String, List> entry, ClientProvider clientProvider) {
    final clientId = entry.key;
    final clientDebts = entry.value;

    final totalOwed = clientDebts.fold<double>(0.0, (sum, d) => sum + d.amountOwed);

    // Live client record takes priority - only falls back to the debt's
    // own frozen-at-creation copy if that client can no longer be found
    // (e.g. deleted while still owing money, an edge case worth
    // tolerating gracefully rather than crashing or showing nothing).
    final liveClient = clientProvider.getClientById(clientId);
    final clientName = liveClient?.name ?? clientDebts.first.clientName ?? 'Unknown';
    final clientPhone = liveClient?.phone ?? clientDebts.first.clientPhone ?? '';

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
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.hovered)) return const Color(0xFFFFC400);
                  return warmAmber;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.black),
              ),
              onPressed: () async {
                final selectedClient = Client(
                  id: clientId,
                  name: clientName,
                  phone: clientPhone,
                  address: '',
                  balance: 0.0,
                  types: const [],
                );
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPaymentScreen(
                      preselectedClient: selectedClient,
                      debtDocId: debtId,
                      amountOwed: amount,
                      facilityId:
                          Provider.of<FacilityProvider>(context, listen: false)
                              .selectedFacilityId,
                    ),
                  ),
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
