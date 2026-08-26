import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
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

  static const List<String> _clientTypes = ['All', 'Farmer', 'Vet', 'Wholesaler', 'Retailer'];

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Search results live separately from the paginated browse list -
  // searching queries Firestore directly (by name), rather than
  // filtering whatever's already been paginated in, since that would
  // only ever find matches among however many clients happen to be
  // loaded locally so far.
  List<Client>? _searchResults;
  bool _isSearchLoading = false;

  String _selectedType = 'All';
  String? _facilityId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId != null && facilityId.isNotEmpty && facilityId != _facilityId) {
      _facilityId = facilityId;
      Provider.of<ClientProvider>(context, listen: false)
          .listenToClientsPaginated(facilityId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    setState(() => _searchQuery = trimmed);

    _searchDebounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearchLoading = false;
      });
      return;
    }

    setState(() => _isSearchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (_facilityId == null) return;
      final results = await Provider.of<ClientProvider>(context, listen: false)
          .searchClientsByName(_facilityId!, trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    });
  }

  void _onTypeSelected(String type) {
    setState(() => _selectedType = type);
    if (_facilityId == null) return;
    Provider.of<ClientProvider>(context, listen: false).listenToClientsPaginated(
      _facilityId!,
      typeFilter: type == 'All' ? null : type,
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Farmer':
        return Icons.agriculture;
      case 'Vet':
        return Icons.medical_services;
      case 'Wholesaler':
        return Icons.warehouse;
      case 'Retailer':
        return Icons.storefront;
      default:
        return Icons.person;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'Farmer':
        return const Color(0xFF2F5D62);
      case 'Vet':
        return const Color(0xFF3D5A80);
      case 'Wholesaler':
        return const Color(0xFF6A4C93);
      case 'Retailer':
        return const Color(0xFFB56A00);
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _confirmDelete(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: offWhite,
        title: Text('Delete Client', style: TextStyle(color: primaryDeepGreen)),
        content: Text('Delete "${client.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return warmAmber;
                return primaryDeepGreen;
              }),
            ),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return Colors.red.shade900;
                return warmAmber;
              }),
            ),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId != null) {
      try {
        await Provider.of<ClientProvider>(context, listen: false)
            .deleteClient(facilityId, client.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete client: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: _buildAppBar(),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          final isSearching = _searchQuery.isNotEmpty;
          final clients = isSearching ? (_searchResults ?? []) : provider.items;
          final showLoadingSpinner = isSearching ? _isSearchLoading : !provider.hasLoaded;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _clientTypes.map((type) {
                      final selected = _selectedType == type;
                      final accent = type == 'All' ? primaryDeepGreen : _colorForType(type);
                      return ChoiceChip(
                        avatar: type == 'All'
                            ? null
                            : Icon(_iconForType(type), size: 16, color: selected ? Colors.white : accent),
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) => _onTypeSelected(type),
                        selectedColor: accent,
                        labelStyle: TextStyle(color: selected ? Colors.white : accent, fontWeight: FontWeight.w600),
                        side: BorderSide(color: accent.withValues(alpha: 0.4)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Searching by name (across all types)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              Expanded(
                child: !isSearching && provider.streamError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildErrorMessage(provider.streamError.toString()),
                        ),
                      )
                    : showLoadingSpinner
                    ? Center(child: CircularProgressIndicator(color: primaryDeepGreen))
                    : clients.isEmpty
                        ? Center(
                            child: Text(
                              isSearching ? 'No clients match "$_searchQuery"' : 'No clients found',
                            ),
                          )
                        : _buildClientsGrid(clients, isSearching, provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryDeepGreen,
        foregroundColor: offWhite,
        hoverColor: warmAmber,
        icon: const Icon(Icons.add),
        label: const Text('Add Client'),
        onPressed: () async {
          await showAddClientScreen(context);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      centerTitle: true,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: offWhite,
              style: TextStyle(color: offWhite),
              decoration: InputDecoration(
                hintText: 'Search clients by name...',
                hintStyle: TextStyle(color: offWhite.withValues(alpha: 0.7)),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: offWhite),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() => _isSearchExpanded = false);
                  },
                ),
              ),
              onChanged: _onSearchChanged,
            )
          : const Text('Clients'),
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

  Widget _buildClientsGrid(List<Client> clients, bool isSearching, ClientProvider provider) {
    // "Load more" only makes sense while browsing the paginated list -
    // search results are a single, complete query result on their own.
    final showLoadMore = !isSearching && provider.hasMore;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1024;
        final itemCount = clients.length + (showLoadMore ? 1 : 0);

        Widget itemBuilder(BuildContext context, int index) {
          if (index >= clients.length) {
            return _buildLoadMoreTile(provider);
          }
          return _buildClientCard(clients[index]);
        }

        if (isLargeScreen) {
          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }

  // Firestore's "missing index" errors always include a direct
  // console link to create exactly the index that's needed - extracted
  // here and shown as a real button, since the raw URL itself is
  // typically very long (encoded query parameters) and would look
  // messy and hard to read made tappable inline as plain text. Any
  // other kind of error (no URL present) just falls back to showing
  // the message as-is.
  Widget _buildErrorMessage(String errorText) {
    final urlMatch = RegExp(r'https?://\S+').firstMatch(errorText);
    final url = urlMatch?.group(0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
        const SizedBox(height: 8),
        Text(
          url != null
              ? 'This filter needs a one-time database index to be created first.'
              : 'Could not load clients: $errorText',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
        if (url != null) ...[
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the link - copy it from the error log instead.')),
                );
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Create Index'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return warmAmber;
                return primaryDeepGreen;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This takes a minute or two to finish building after you create it - then try this filter again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadMoreTile(ClientProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: provider.isLoading
            ? CircularProgressIndicator(color: primaryDeepGreen)
            : OutlinedButton(
                onPressed: () => provider.loadMorePagedClients(),
                style: OutlinedButton.styleFrom(foregroundColor: primaryDeepGreen),
                child: const Text('Load More'),
              ),
      ),
    );
  }

  Widget _buildClientCard(Client client) {
    final types = client.types.isNotEmpty ? client.types : ['Other'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: offWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade300, blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              client.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: types.map((type) {
                final accent = _colorForType(type);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(type), size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        type,
                        style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(client.phone, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            _infoRow('Address', client.address),
            if (client.farmerSubType != null)
              _infoRow('Farmer Type', client.farmerSubType!),
            if (client.crops.isNotEmpty)
              _infoRow('Crops', client.crops.join(', ')),
            if (client.animalSpecies.isNotEmpty)
              _infoRow('Animals', client.animalSpecies.join(', ')),
            if (client.vetPracticeType != null)
              _infoRow('Practice', client.vetPracticeType!),
            if (client.businessName != null)
              _infoRow('Business', client.businessName!),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (Provider.of<UserRoleProvider>(context).isAdmin)
                  TextButton.icon(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.hovered)) return Colors.red.shade900;
                        return Colors.red[400]!;
                      }),
                    ),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    onPressed: () => _confirmDelete(client),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await showAddClientScreen(context, client: client);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return primaryDeepGreen;
                    }),
                    foregroundColor: WidgetStateProperty.all(offWhite),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: primaryDeepGreen, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
