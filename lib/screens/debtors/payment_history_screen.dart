import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/facility_provider.dart';
import '../../models/payment.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color offWhite = const Color(0xFFFDFDF9);
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');

  Future<List<Payment>> _fetchPayments() async {
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (facilityId == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .get();

    List<Payment> payments = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final clientId = data['clientId'] ?? '';

      // Fetch client info
      final clientDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .collection('clients')
          .doc(clientId)
          .get();

      final clientData = clientDoc.data();
      final clientName = clientData?['name'] ?? 'Unknown';
      final clientPhone = clientData?['phone'] ?? '';

      payments.add(Payment.fromFirestore(doc.data(), doc.id,
          clientName: clientName, clientPhone: clientPhone));
    }

    return payments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        title: const Text('Payment Records', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Payment>>(
        future: _fetchPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return const Center(
              child: Text(
                'No payments found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          // Group payments by clientId
          final Map<String, List<Payment>> groupedPayments = {};
          for (var p in payments) {
            groupedPayments.putIfAbsent(p.clientId, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: groupedPayments.entries.map((entry) {
              final clientPayments = entry.value;
              final clientName = clientPayments.first.clientName ?? 'Unknown';
              final clientPhone = clientPayments.first.clientPhone ?? '';

              final totalPaid = clientPayments.fold<double>(
                  0.0, (sum, p) => sum + p.amount);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  collapsedBackgroundColor: offWhite,
                  backgroundColor: offWhite,
                  title: Text(
                    clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${clientPhone.isNotEmpty ? "$clientPhone • " : ""}Total Paid: Tsh ${currencyFormat.format(totalPaid)}',
                  ),
                  children: clientPayments.map((payment) {
                    final formattedDate =
                        DateFormat('dd MMM yyyy, hh:mm a').format(payment.timestamp);

                    String displayText;
                    if (payment.saleId != null) {
                      displayText = payment.items.map((i) {
                        final name = i['name'] ?? 'Unknown';
                        final qty = i['quantity']?.toString() ?? '';
                        final unit = i['unit'] ?? '';
                        return qty.isNotEmpty ? '$name $qty $unit' : name;
                      }).join(', ');
                    } else if (payment.serviceId != null) {
                      displayText = payment.items
                          .map((i) => i['serviceName'] ?? 'Unknown')
                          .join(', ');
                    } else {
                      displayText = 'Unknown';
                    }

                    return ListTile(
                      title: Text('Tsh ${currencyFormat.format(payment.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('$displayText\n$formattedDate'),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Paid',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
