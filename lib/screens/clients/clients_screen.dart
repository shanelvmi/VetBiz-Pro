import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../models/client.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacilityId;

    if (facilityId != null && facilityId.isNotEmpty) {
      Provider.of<ClientProvider>(context, listen: false)
          .listenToClients(facilityId);
    }
  }

  Future<void> _confirmDelete(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: offWhite,
        title: Text('Delete Client',
            style: TextStyle(color: primaryDeepGreen)),
        content: Text('Delete "${client.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: primaryDeepGreen)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.delete, color: warmAmber),
            label: Text('Delete',
                style: TextStyle(color: warmAmber)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false)
            .selectedFacilityId;

    if (facilityId != null) {
      await Provider.of<ClientProvider>(context, listen: false)
          .deleteClient(facilityId, client.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        title: const Text('Clients'),
        actions: [
          Container(
            width: 180,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TextField(
              cursorColor: primaryDeepGreen,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search...',
                filled: true,
                fillColor: offWhite,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          final clients = provider.clients.where((c) {
            return _searchQuery.isEmpty ||
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.phone.contains(_searchQuery);
          }).toList();

          if (clients.isEmpty) {
            return const Center(child: Text('No clients found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          client.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryDeepGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          client.type,
                          style: TextStyle(
                            color: primaryDeepGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(client.phone),
                  children: [
                    _infoRow('Address', client.address),
                    if (client.farmerSubType != null)
                      _infoRow('Farmer Type', client.farmerSubType!),
                    if (client.crops.isNotEmpty)
                      _infoRow(
                          'Crops', client.crops.join(', ')),
                    if (client.animalSpecies.isNotEmpty)
                      _infoRow('Animals',
                          client.animalSpecies.join(', ')),
                    if (client.vetPracticeType != null)
                      _infoRow('Practice',
                          client.vetPracticeType!),
                    if (client.businessName != null)
                      _infoRow(
                          'Business', client.businessName!),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.edit,
                              color: primaryDeepGreen),
                          label: Text('Edit',
                              style: TextStyle(
                                  color: primaryDeepGreen)),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddClientScreen(client: client),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.delete,
                              color: warmAmber),
                          label: Text('Delete',
                              style:
                                  TextStyle(color: warmAmber)),
                          onPressed: () => _confirmDelete(client),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: warmAmber,
        foregroundColor: Colors.black87,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddClientScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryDeepGreen,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
