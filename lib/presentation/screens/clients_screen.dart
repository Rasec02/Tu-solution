import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../providers.dart';
import '../viewmodels/command_state.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/common.dart';
import 'client_detail_screen.dart';

/// Listado de clientes del taller, con buscador por nombre o teléfono.
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);

    ref.listen<CommandState>(catalogViewModelProvider, (_, next) {
      if (next.error != null) {
        showMessage(context, next.error!, error: true);
        ref.read(catalogViewModelProvider.notifier).consumeFeedback();
      } else if (next.message != null) {
        showMessage(context, next.message!);
        ref.read(catalogViewModelProvider.notifier).consumeFeedback();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o teléfono',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editClient(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Cliente'),
      ),
      body: clients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (list) {
          final filtered = _query.isEmpty
              ? list
              : list
                  .where((c) =>
                      c.name.toLowerCase().contains(_query) ||
                      c.phone.toLowerCase().contains(_query))
                  .toList();

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: _query.isEmpty
                  ? 'Todavía no hay clientes'
                  : 'Sin resultados',
              message: _query.isEmpty
                  ? 'Se registran solos al recibir un equipo.'
                  : 'Prueba con otro nombre o teléfono.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final client = filtered[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(client.name.characters.first.toUpperCase()),
                ),
                title: Text(client.name),
                subtitle: Text(
                  '${client.phone} · desde ${shortDate(client.createdAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClientDetailScreen(clientId: client.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Alta o edición de un cliente. Compartido con la pantalla de detalle.
Future<void> editClient(
    BuildContext context, WidgetRef ref, Client? client) async {
  final name = TextEditingController(text: client?.name ?? '');
  final phone = TextEditingController(text: client?.phone ?? '');
  final notes = TextEditingController(text: client?.notes ?? '');
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(client == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(dialogContext).pop(true);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(catalogViewModelProvider.notifier).saveClient(
        id: client?.id,
        name: name.text,
        phone: phone.text,
        notes: notes.text,
      );
}
