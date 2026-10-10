import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/web_download.dart';
import '../../models/client.dart';
import 'add_client_screen.dart';
import '../../services/cursor_paginated_list_controller.dart';
import '../../data/collections.dart';
import '../../config/money.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_date_format.dart';
import '../../config/app_links.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../theme/app_text.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {

  static const List<String> _clientTypes = ['All', 'Farmer', 'Vet', 'Wholesaler', 'Retailer'];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  // Periodically checks (never a live listener) whether new clients
  // have landed since the current browsing session's snapshot moment,
  // to drive the "N new clients available - Refresh" banner.
  Timer? _newRecordsCheckTimer;

  String _selectedType = 'All';
  String _statusFilter = 'All';
  Client? _selectedClient;
  final GlobalKey _clientCardKey = GlobalKey();
  bool _isSharing = false;
  final Map<String, Future<(int, double)>> _clientStatsFutureById = {};
  String? _facilityId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final facilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;

    if (facilityId != null && facilityId.isNotEmpty && facilityId != _facilityId) {
      _facilityId = facilityId;
      Provider.of<ClientProvider>(context, listen: false).listenToClients(facilityId);
      _openClientsListSession();
      _newRecordsCheckTimer ??= Timer.periodic(
        AppTimeouts.newRecordsPoll,
        (_) => Provider.of<ClientProvider>(context, listen: false).clientsListController.checkForNewRecords(),
      );
    }
  }

  /// Records the toolbar's current filters onto ClientProvider, then
  /// (re)opens the browsing session for them - a no-op if the
  /// signature hasn't actually changed and a session's already open.
  void _openClientsListSession({bool forceRefresh = false}) {
    final facilityId = _facilityId;
    if (facilityId == null) return;
    final provider = Provider.of<ClientProvider>(context, listen: false);
    final signature = provider.updateClientsListFilters(
      facilityId: facilityId,
      searchTerm: _searchQuery,
      typeFilter: _selectedType,
      statusFilter: _statusFilter,
    );
    provider.clientsListController.openSession(signature, forceRefresh: forceRefresh);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _newRecordsCheckTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppTimeouts.searchDebounce, _openClientsListSession);
  }

  void _onTypeSelected(String type) {
    setState(() => _selectedType = type);
    _openClientsListSession();
  }

  void _onStatusFilterChanged(String status) {
    setState(() => _statusFilter = status);
    _openClientsListSession();
  }

  Widget _buildMetricsRow(List<Client> allClients) {
    final now = DateTime.now();
    final newThisMonth = allClients
        .where((c) => c.createdAt != null && c.createdAt!.year == now.year && c.createdAt!.month == now.month)
        .length;

    final typeCounts = <String, int>{};
    for (final c in allClients) {
      final types = c.types.isNotEmpty ? c.types : ['Other'];
      for (final t in types) {
        typeCounts[t] = (typeCounts[t] ?? 0) + 1;
      }
    }
    String mostActiveType = '-';
    double mostActivePercent = 0;
    if (typeCounts.isNotEmpty && allClients.isNotEmpty) {
      final top = typeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      mostActiveType = top.key;
      mostActivePercent = (top.value / allClients.length) * 100;
    }

    Client? lastAdded;
    for (final c in allClients) {
      if (c.createdAt == null) continue;
      if (lastAdded == null || c.createdAt!.isAfter(lastAdded.createdAt!)) lastAdded = c;
    }

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _metricCard('Total Clients', '${allClients.length}', 'All time', Icons.people_outline, context.colors.primary)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: _metricCard('New This Month', '$newThisMonth', null, Icons.person_add_alt_outlined, context.colors.primary)),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _metricCard(
              'Most Active Type',
              mostActiveType,
              allClients.isEmpty ? null : '${mostActivePercent.toStringAsFixed(0)}% of clients',
              Icons.shopping_cart_outlined,
              context.colors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: _metricCard(
              'Last Added',
              lastAdded?.name ?? '-',
              lastAdded?.createdAt != null ? AppDateFormat.date.format(lastAdded!.createdAt!) : null,
              Icons.calendar_today_outlined,
              context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String? subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s6),
                decoration: BoxDecoration(color: color.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
                child: Icon(icon, size: AppIconSize.i16, color: color),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value, style: const TextStyle(fontSize: AppFontSize.f18, fontWeight: AppFontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: AppSpacing.s6),
                Flexible(
                  child: Text(subtitle, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarRow() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r10),
      borderSide: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
    );
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, address...',
              hintStyle: const TextStyle(fontSize: AppFontSize.f13),
              prefixIcon: const Icon(Icons.search, size: AppIconSize.i20),
              filled: true,
              fillColor: context.colors.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s12, horizontal: AppSpacing.s12),
              border: border,
              enabledBorder: border,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: AppIconSize.i18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
              style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
              items: _clientTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t == 'All' ? 'Type: All' : t)))
                  .toList(),
              onChanged: (val) {
                if (val != null) _onTypeSelected(val);
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              icon: Icon(Icons.arrow_drop_down, size: AppIconSize.i18, color: context.colors.primary),
              style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f13),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('Status: All')),
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
              onChanged: (val) {
                if (val != null) _onStatusFilterChanged(val);
              },
            ),
          ),
        ),
      ],
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
        return context.colors.primary;
      case 'Vet':
        return context.colors.chart1;
      case 'Wholesaler':
        return context.colors.chart2;
      case 'Retailer':
        return context.colors.chart3;
      default:
        return context.colors.textMuted;
    }
  }

  Future<void> _confirmDelete(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.background,
        title: Text('Delete Client', style: TextStyle(color: context.colors.primary)),
        content: Text('Delete "${client.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return context.colors.accent;
                return context.colors.primary;
              }),
            ),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return context.colors.dangerDeep;
                return context.colors.accent;
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
        if (_selectedClient?.id == client.id) setState(() => _selectedClient = null);
        // A hard delete (nothing goes to trash_clients), so no Undo: see
        // design-open-questions.md, "make client deletion soft?".
        AppFeedback.success('Client deleted');
      } catch (e, st) {
        AppFeedback.error("Couldn't delete the client", error: e, stackTrace: st);
      }
    }
  }

  Future<(int, double)> _getClientStatsFuture(Client client) {
    return _clientStatsFutureById.putIfAbsent(client.id, () async {
      final facilityId = _facilityId;
      if (facilityId == null) return (0, 0.0);
      try {
        final snap = await FirebaseFirestore.instance
            .collection(Collections.facilities)
            .doc(facilityId)
            .collection(Collections.payments)
            .where('clientId', isEqualTo: client.id)
            .get();
        double total = 0;
        for (final doc in snap.docs) {
          total += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        }
        return (snap.docs.length, total);
      } catch (e) {
        debugPrint('Could not load client stats: $e');
        return (0, 0.0);
      }
    });
  }

  Future<Uint8List?> _captureClientCardImage() async {
    final boundary =
        _clientCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareOrSaveClientCard(Client client) async {
    setState(() => _isSharing = true);
    Uint8List? bytes;
    try {
      bytes = await _captureClientCardImage();
      if (bytes == null) throw Exception('Could not capture the client card image.');

      final xfile = XFile.fromData(
        bytes,
        name: 'client_${client.id}.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles([xfile], text: client.name);
    } catch (e, st) {
      if (!mounted) return;
      // Desktop browsers' well-known unreliable support for
      // file-sharing through the Web Share API - not a benign
      // cancellation, and there's a reliable fallback that still gets
      // the file onto the user's device.
      if (kIsWeb && bytes != null) {
        downloadFileWeb(bytes, 'client_${client.id}.png');
        return;
      }
      AppFeedback.error("Couldn't share the client card", error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildDetailsPanel(Client client) {
    final types = client.types.isNotEmpty ? client.types : ['Other'];
    final accent = _colorForType(types.first);
    final latestNote = client.debtorNotes.isNotEmpty ? client.debtorNotes.last['text'] as String? : null;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a15)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Client Details', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                IconButton(
                  icon: const Icon(Icons.close, size: AppIconSize.i20),
                  onPressed: () => setState(() => _selectedClient = null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            RepaintBoundary(
              key: _clientCardKey,
              child: Container(
                color: context.colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withValues(alpha: AppAlpha.a10),
                  child: Text(
                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                    style: TextStyle(color: accent, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f16)),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: AppIconSize.i12, color: context.colors.textMuted),
                          const SizedBox(width: AppSpacing.s4),
                          Text(client.phone, style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.phone_outlined, size: AppIconSize.i18, color: accent),
                  tooltip: 'Call',
                  onPressed: () async {
                    final uri = AppLinks.tel(client.phone);
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      AppFeedback.info("Couldn't open the dialer");
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 32),
            _detailLabel('Address'),
            Text(client.address, style: const TextStyle(fontSize: AppFontSize.f14)),
            const SizedBox(height: AppSpacing.s16),
            _detailLabel('Client Type'),
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: types.map((type) {
                final typeAccent = _colorForType(type);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                  decoration: BoxDecoration(color: typeAccent.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(type), size: AppIconSize.i12, color: typeAccent),
                      const SizedBox(width: AppSpacing.s4),
                      Text(type, style: TextStyle(fontSize: AppFontSize.f11_5, color: typeAccent, fontWeight: AppFontWeight.semibold)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s16),
            _detailLabel('Joined On'),
            Text(
              client.createdAt != null ? AppDateFormat.date.format(client.createdAt!) : '-',
              style: const TextStyle(fontSize: AppFontSize.f14),
            ),
            const SizedBox(height: AppSpacing.s16),
            _detailLabel('Status'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                color: (client.status == 'Active' ? context.colors.success : context.colors.textHint).withValues(alpha: AppAlpha.a10),
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Text(
                client.status,
                style: TextStyle(
                  fontSize: AppFontSize.f11_5,
                  color: client.status == 'Active' ? context.colors.successStrong : context.colors.textMuted,
                  fontWeight: AppFontWeight.semibold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            FutureBuilder<(int, double)>(
              future: _getClientStatsFuture(client),
              builder: (context, snapshot) {
                final count = snapshot.data?.$1 ?? 0;
                final total = snapshot.data?.$2 ?? 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailLabel('Total Transactions'),
                    Text('$count', style: const TextStyle(fontSize: AppFontSize.f14)),
                    const SizedBox(height: AppSpacing.s16),
                    _detailLabel('Total Spent'),
                    Text(Money.symbolPlain(total), style: const TextStyle(fontSize: AppFontSize.f14)),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s16),
            _detailLabel('Notes'),
            Text(latestNote ?? 'No notes added', style: TextStyle(fontSize: AppFontSize.f13_5, color: latestNote == null ? context.colors.textHint : context.colors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : () => _shareOrSaveClientCard(client),
                icon: _isSharing
                    ? SizedBox(height: AppSpacing.s16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onPrimary))
                    : const Icon(Icons.share_outlined, size: AppIconSize.i18),
                label: const Text('Save / Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Text(label, style: TextStyle(fontSize: AppFontSize.f11_5, color: context.colors.textMuted, fontWeight: AppFontWeight.semibold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          final isSearching = _searchQuery.isNotEmpty;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, 0),
                child: _buildMetricsRow(provider.clients),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: _buildToolbarRow(),
              ),
              if (isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Searching by name (across all types)',
                      style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textHint, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              Expanded(
                child: ListenableBuilder(
                  listenable: provider.clientsListController,
                  builder: (context, _) {
                    final controller = provider.clientsListController;
                    final clients = controller.items;
                    return Column(
                      children: [
                        if (controller.newRecordsAvailable > 0)
                          Container(
                            width: double.infinity,
                            color: context.colors.primary.withValues(alpha: AppAlpha.a10),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                            child: Row(
                              children: [
                                Icon(Icons.fiber_new, size: AppIconSize.i18, color: context.colors.primary),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    '${controller.newRecordsAvailable} new client'
                                    '${controller.newRecordsAvailable == 1 ? '' : 's'} available',
                                    style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.primary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => controller.refreshSession(),
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: controller.error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.s24),
                                    child: _buildErrorMessage(controller.error.toString()),
                                  ),
                                )
                              : controller.isLoading && clients.isEmpty
                                  ? Center(child: CircularProgressIndicator(color: context.colors.primary))
                                  : clients.isEmpty
                                      ? Center(
                                          child: Text(
                                            isSearching ? 'No clients match "$_searchQuery"' : 'No clients found',
                                          ),
                                        )
                                      : _buildClientsTable(clients),
                        ),
                        _buildPaginationBar(controller),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
          ),
          if (_selectedClient != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _buildDetailsPanel(_selectedClient!),
            ),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: AppElevation.e1,
      centerTitle: true,
      toolbarHeight: 72,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Clients', style: TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f19, color: context.colors.textPrimary)),
          Text('Manage all your clients in one place', style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textSecondary)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s12),
          child: ElevatedButton.icon(
            onPressed: () async {
              await showAddClientScreen(context);
            },
            icon: const Icon(Icons.add, size: AppIconSize.i18),
            label: const Text('Add Client'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientsTable(List<Client> clients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
          child: Row(
            children: [
              _headerCell('Client', flex: 3),
              _headerCell('Type', flex: 2),
              _headerCell('Phone', flex: 2),
              _headerCell('Status', flex: 2),
              _headerCell('Joined On', flex: 2),
              _headerCell('', flex: 1),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) => _buildClientRow(clients[index]),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(label, style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textMuted)),
    );
  }

  Widget _buildClientRow(Client client) {
    final types = client.types.isNotEmpty ? client.types : ['Other'];
    final primaryType = types.first;
    final accent = _colorForType(primaryType);
    final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;
    final isSelected = _selectedClient?.id == client.id;

    return InkWell(
      onTap: () => setState(() => _selectedClient = client),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: isSelected ? context.colors.primary.withValues(alpha: AppAlpha.a05) : null,
        border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a10))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accent.withValues(alpha: AppAlpha.a10),
                  child: Text(
                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                    style: TextStyle(color: accent, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f13),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(client.name, style: const TextStyle(fontSize: AppFontSize.f13, fontWeight: AppFontWeight.semibold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s4,
              children: types.map((type) {
                final typeAccent = _colorForType(type);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(color: typeAccent.withValues(alpha: AppAlpha.a10), borderRadius: BorderRadius.circular(AppRadius.r8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(type), size: AppIconSize.i12, color: typeAccent),
                      const SizedBox(width: AppSpacing.s3),
                      Text(type, style: TextStyle(fontSize: AppFontSize.f10_5, color: typeAccent, fontWeight: AppFontWeight.semibold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(client.phone, style: const TextStyle(fontSize: AppFontSize.f13)),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                color: (client.status == 'Active' ? context.colors.success : context.colors.textHint).withValues(alpha: AppAlpha.a10),
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: client.status == 'Active' ? context.colors.successStrong : context.colors.textMuted),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    client.status,
                    style: TextStyle(
                      fontSize: AppFontSize.f11_5,
                      color: client.status == 'Active' ? context.colors.successStrong : context.colors.textMuted,
                      fontWeight: AppFontWeight.semibold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              client.createdAt != null ? AppDateFormat.date.format(client.createdAt!) : '-',
              style: const TextStyle(fontSize: AppFontSize.f13),
            ),
          ),
          Expanded(
            flex: 1,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: AppIconSize.i18, color: context.colors.textMuted),
              onSelected: (value) async {
                if (value == 'edit') {
                  await showAddClientScreen(context, client: client);
                } else if (value == 'delete') {
                  _confirmDelete(client);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (isAdmin)
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: context.colors.dangerSoft))),
              ],
            ),
          ),
        ],
      ),
      ),
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
        Icon(Icons.error_outline, color: context.colors.dangerAccent, size: AppIconSize.i32),
        const SizedBox(height: AppSpacing.s8),
        Text(
          url != null
              ? 'This filter needs a one-time database index to be created first.'
              : 'Could not load clients: $errorText',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: AppFontSize.f13),
        ),
        if (url != null) ...[
          const SizedBox(height: AppSpacing.s14),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched) {
                AppFeedback.warning("Couldn't open the link", detail: 'Copy it from the error log instead');
              }
            },
            icon: const Icon(Icons.open_in_new, size: AppIconSize.i18),
            label: const Text('Create Index'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return context.colors.accent;
                return context.colors.primary;
              }),
              foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'This takes a minute or two to finish building after you create it - then try this filter again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildPaginationBar(CursorPaginatedListController<Client> controller) {
    final pageSize = controller.pageSize;
    final itemCount = controller.items.length;
    final pageStart = itemCount == 0 ? 0 : (controller.currentPage - 1) * pageSize + 1;
    final pageEnd = (controller.currentPage - 1) * pageSize + itemCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            itemCount == 0 ? 'No clients' : 'Showing $pageStart to $pageEnd',
            style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
          ),
          Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: pageSize,
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n per page')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) controller.setPageSize(val);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.hasPreviousPage ? () => controller.goToPreviousPage() : null,
              ),
              Text('Page ${controller.currentPage}', style: const TextStyle(fontSize: AppFontSize.f13)),
              IconButton(
                icon: controller.isLoading
                    ? const SizedBox(width: AppSpacing.s16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onPressed: controller.hasNextPage && !controller.isLoading
                    ? () => controller.goToNextPage()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
