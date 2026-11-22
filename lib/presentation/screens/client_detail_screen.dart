import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'clients_screen.dart';
import 'device_history_screen.dart';
import 'history_list.dart';

/// Ficha del cliente: sus equipos y todo lo que el taller le ha reparado.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final client = clients.where((c) => c.id == clientId).firstOrNull;
    final devices = ref.watch(devicesOfClientProvider(clientId));
    final history = ref.watch(clientHistoryProvider(clientId));

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cliente')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'El cliente ya no existe',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => editClient(context, ref, client),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow('Teléfono', client.phone),
                  DetailRow('Cliente desde', shortDate(client.createdAt)),
                  if (client.notes?.isNotEmpty ?? false)
                    DetailRow('Notas', client.notes!),
                ],
              ),
            ),
          ),
          const SectionTitle('Equipos'),
          devices.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (list) => list.isEmpty
                ? const Card(
                    child: ListTile(
                      leading: Icon(Icons.devices_other_outlined),
                      title: Text('Sin equipos registrados.'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: Icon(_iconFor(list[i].kind)),
                            title: Text('${list[i].brand} ${list[i].model}'),
                            subtitle: Text(
                              '${list[i].kind} · serie ${list[i].serial}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DeviceHistoryScreen(deviceId: list[i].id),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SectionTitle('Historial de reparaciones'),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (entries) => HistoryList(entries: entries, showDevice: true),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String kind) => switch (kind.toLowerCase()) {
      'celular' => Icons.smartphone,
      'tablet' => Icons.tablet_android,
      'laptop' => Icons.laptop,
      _ => Icons.devices_other,
    };
