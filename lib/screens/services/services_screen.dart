import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/service_provider.dart';
import 'add_edit_service_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  @override
  Widget build(BuildContext context) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final numberFormat = NumberFormat.decimalPattern('en_US');

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        title: const Text(
          'Attended Services',
          style: TextStyle(color: Color(0xFFFDFDF9)),
        ),
        backgroundColor: primaryDeepGreen,
        iconTheme: const IconThemeData(color: Color(0xFFFDFDF9)),
      ),
      body: serviceProvider.services.isEmpty
          ? const Center(child: Text('No services yet.'))
          : ListView.builder(
              primary: true,
              itemCount: serviceProvider.services.length,
              itemBuilder: (context, index) {
                final service = serviceProvider.services[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: offWhite,
                  child: ExpansionTile(
                    title: Text(
                      service.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total Paid
                        Text(
                          'Total Paid • Tsh ${numberFormat.format(service.totalPaid ?? 0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black54),
                        ),
                        // Date in its own subtitle line
                        if (service.serviceDate != null)
                          Text(
                            'Date: ${DateFormat.yMMMd().format(service.serviceDate!)}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: [
                      // Total Amount at top
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total Amount: Tsh ${numberFormat.format(service.totalAmount ?? 0)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Description
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Description: ${service.description}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Category
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Category: ${service.category}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Client
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Client: ${service.clientName ?? 'N/A'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Provided By
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Provided By: ${service.providedByName ?? 'N/A'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Delete button
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Service',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: Text(
                                    'Are you sure you want to delete "${service.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              try {
                                await serviceProvider
                                    .deleteService(service.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to delete service: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: warmAmber,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditServiceScreen(),
            ),
          );
        },
      ),
    );
  }
}
