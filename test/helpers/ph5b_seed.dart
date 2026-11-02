// PH5b: seeded clients, debts, payments and transactions for Clients,
// Debtors, Payments and Transactions, stored as the app stores them (with
// the daily transaction summaries the Cloud Functions would write).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vetbiz_pro/data/collections.dart';

import 'fake_firestore.dart';
import 'phone_list_harness.dart';

/// One client (a debtor when [balance] is above 0 and [oldestDebt] is set).
class Ph5Client {
  final String id;
  final String name;
  final String phone;
  final List<String> types;
  final String status;
  final DateTime created;
  final double balance;
  final DateTime? oldestDebt;

  const Ph5Client(this.id, this.name, this.created,
      {this.phone = '0712000000', this.types = const ['Farmer'], this.status = 'Active', this.balance = 0, this.oldestDebt});
}

class Ph5Debt {
  final String id;
  final String clientId;
  final DateTime when;
  final double amount;

  const Ph5Debt(this.id, this.clientId, this.when, this.amount);
}

class Ph5Payment {
  final String id;
  final DateTime when;
  final String? client;
  final String? clientId;
  final double amount;
  final String method;
  final String source;

  const Ph5Payment(this.id, this.when, {this.client, this.clientId, this.amount = 5000, this.method = 'cash', this.source = 'sale'});
}

class Ph5Tx {
  final String id;
  final DateTime when;
  final String type;
  final double amount;
  final String category;
  final String description;
  final String method;
  final int receipt;

  const Ph5Tx(this.id, this.when,
      {this.type = 'expense', this.amount = 3000, this.category = 'Fuel', this.description = 'Fuel for the car', this.method = 'cash', this.receipt = 1});
}

Future<void> ph5SeedClients(FirebaseFirestore fs, List<Ph5Client> clients) async {
  for (final c in clients) {
    await facilityCollection(fs, Collections.clients).doc(c.id).set({
      'name': c.name,
      'nameLower': c.name.toLowerCase(),
      'phone': c.phone,
      'address': 'Arusha',
      'types': c.types,
      'status': c.status,
      'createdAt': Timestamp.fromDate(c.created),
      'balance': c.balance,
      if (c.oldestDebt != null) 'oldestUnpaidDebtDate': Timestamp.fromDate(c.oldestDebt!),
    });
  }
}

Future<void> ph5SeedDebts(FirebaseFirestore fs, List<Ph5Debt> debts) async {
  for (final d in debts) {
    await facilityCollection(fs, Collections.debts).doc(d.id).set({
      'clientId': d.clientId,
      'source': 'Sale',
      'amountOwed': d.amount,
      'timestamp': Timestamp.fromDate(d.when),
      'items': [
        {'name': 'Albendazole', 'quantity': 2},
      ],
    });
  }
}

/// The payments, recorded by the test user (named [testUserName]).
Future<void> ph5SeedPayments(FirebaseFirestore fs, List<Ph5Payment> payments) async {
  await fs.collection(Collections.users).doc(testUserId).set({'fullName': testUserName}, SetOptions(merge: true));
  for (final p in payments) {
    await facilityCollection(fs, Collections.payments).doc(p.id).set({
      'timestamp': Timestamp.fromDate(p.when),
      'amount': p.amount,
      'source': p.source,
      'clientId': p.clientId,
      'clientName': p.client,
      'clientNameLower': p.client?.toLowerCase(),
      'paymentMethod': p.method,
      'paidById': testUserId,
    });
  }
}

Future<void> ph5SeedTransactions(FirebaseFirestore fs, List<Ph5Tx> txs) async {
  final days = <String, Map<String, double>>{};
  for (final t in txs) {
    await facilityCollection(fs, Collections.transactions).doc(t.id).set({
      'date': Timestamp.fromDate(t.when),
      'description': t.description,
      'amount': t.amount,
      'type': t.type,
      'category': t.category,
      'recordedBy': testUserName,
      'paymentMethod': t.method,
      'receiptNumber': t.receipt,
    });
    final d = days.putIfAbsent(ph5DayKey(t.when), () => {'totalExpense': 0, 'totalOtherIncome': 0});
    final field = t.type == 'expense' ? 'totalExpense' : 'totalOtherIncome';
    d[field] = d[field]! + t.amount;
  }
  for (final e in days.entries) {
    await facilityCollection(fs, Collections.dailyTransactionSummaries).doc(e.key).set(e.value);
  }
}
