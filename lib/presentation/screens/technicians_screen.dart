import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/database/app_database.dart';
import '../../domain/order_status.dart';
import '../providers.dart';
import '../viewmodels/command_state.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/common.dart';
import 'orders_screen.dart';

/// Los técnicos del taller y cuánto trabajo tiene asignado cada uno.
class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workload = ref.watch(technicianWorkloadProvider);

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
      appBar: AppBar(title: const Text('Técnicos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTechnician(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Técnico'),
      ),
      body: workload.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.engineering_outlined,
                title: 'No hay técnicos registrados',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final technician = row.technician;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  technician.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (!technician.active)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text('Inactivo'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () =>
                                    _editTechnician(context, ref, technician),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                          if (technician.phone?.isNotEmpty ?? false)
                            Text(
                              technician.phone!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _Metric(
                                value: row.openOrders,
                                label: 'abiertas',
                              ),
                              _Metric(
                                value: row.inRepair,
                                label: 'en reparación',
                                color: context.workshop.enReparacion,
                              ),
                              _Metric(
                                value: row.ready,
                                label: 'listas',
                                color: context.workshop.lista,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                ref.read(ordersFilterProvider.notifier).state =
                                    OrdersFilter(
                                  statuses: OrderStatus.openStates,
                                  technicianId: technician.id,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const OrdersScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.list_alt, size: 18),
                              label: const Text('Ver sus órdenes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Future<void> _editTechnician(
    BuildContext context, WidgetRef ref, Technician? technician) async {
  final name = TextEditingController(text: technician?.name ?? '');
  final phone = TextEditingController(text: technician?.phone ?? '');
  var active = technician?.active ?? true;
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setLocalState) => AlertDialog(
        title: Text(technician == null ? 'Nuevo técnico' : 'Editar técnico'),
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
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (value) => setLocalState(() => active = value),
                title: const Text('Activo'),
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
    ),
  );

  if (confirmed != true) return;

  await ref.read(catalogViewModelProvider.notifier).saveTechnician(
        id: technician?.id,
        name: name.text,
        phone: phone.text,
        active: active,
      );
}
