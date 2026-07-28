import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/client.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';
import 'add_payment_screen.dart';
import 'payment_history_screen.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';

    if (facilityId.isNotEmpty) {
      Provider.of<DebtProvider>(context, listen: false).listenToDebts(facilityId);
    }
  }

  Future<String> _getClientName(String clientId) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(clientId)
          .get();
      if (doc.exists) return doc.data()?['name'] ?? 'Unknown';
    } catch (_) {}
    return 'Unknown';
  }

  Future<String> _getClientPhone(String clientId) async {
    try {
      final facilityId =
          Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(clientId)
          .get();
      if (doc.exists) return doc.data()?['phone'] ?? '';
    } catch (_) {}
    return '';
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

    // Filter out clients with zero debt
    final visibleClients = sortedClients
        .where((entry) =>
            entry.value.fold<double>(0, (sum, d) => sum + d.amountOwed) > 0)
        .toList();

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        title: const Text('Active Debts', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: visibleClients.isEmpty
          ? const Center(
              child: Text(
                'No debtors found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            )
          : ListView(
              primary: true,
              physics: const BouncingScrollPhysics(),
              children: visibleClients.map((entry) {
                final clientId = entry.key;
                final clientDebts = entry.value;

                final totalOwed = clientDebts.fold<double>(
                    0.0, (sum, d) => sum + d.amountOwed);

                // Latest debt date
                clientDebts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                final lastDebtDate = clientDebts.first.timestamp;

                return FutureBuilder<List<String>>(
                  future: Future.wait([_getClientName(clientId), _getClientPhone(clientId)]),
                  builder: (context, snapshot) {
                    final clientName = snapshot.data?[0] ?? 'Loading...';
                    final clientPhone = snapshot.data?[1] ?? '';

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        key: PageStorageKey(clientId),
                        title: Text(
                          clientName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                          ...clientDebts.expand((debt) {
                            final debtDate = debt.timestamp;
                            final isSale = debt.saleId != null;
                            final debtSource = isSale ? 'Sale' : 'Service';

                            if (isSale) {
                              // Sale debts stay the same
                              final displayText = debt.items.isNotEmpty
                                  ? debt.items.map((e) {
                                      final name = e['name'] ?? 'Unknown';
                                      final qty = e['quantity'] ?? '';
                                      final unit = e['unit'] ?? '';
                                      if (qty != '') {
                                        return unit != '' ? '$name $qty$unit' : '$name $qty';
                                      }
                                      return name;
                                    }).join(', ')
                                  : 'No items';

                              return [
                                _buildDebtTile(context, clientId, clientName, clientPhone,
                                    debt.id, debtDate, debtSource, displayText, debt.amountOwed)
                              ];
                            } else {
                              // Service debts: show each service separately
                              return debt.items.isNotEmpty
                                  ? debt.items.map((e) {
                                      final serviceName = e['serviceName'] ?? 'Unknown';
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
                                  : [
                                      _buildDebtTile(context, clientId, clientName, clientPhone,
                                          debt.id, debtDate, debtSource, 'No services', debt.amountOwed)
                                    ];
                            }
                          }),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
          );
        },
        label: Text('Payment Records', style: TextStyle(color: offWhite)),
        icon: Icon(Icons.history, color: offWhite),
        backgroundColor: primaryDeepGreen,
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
                  type: 'Unknown',    // required
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
