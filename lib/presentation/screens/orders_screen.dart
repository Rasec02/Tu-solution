import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../domain/order_status.dart';
import '../../domain/views.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

/// Lista de órdenes del taller, con filtros por estado y por técnico.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(ordersFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: _Filters(filter: filter),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewOrderScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Recibir equipo'),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No hay órdenes con ese filtro',
                message: 'Cambia el filtro o recibe un equipo nuevo.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OrderCard(summary: list[i]),
              ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.filter});

  final OrdersFilter filter;

  bool _isSelected(List<OrderStatus> statuses) =>
      filter.statuses.length == statuses.length &&
      filter.statuses.every(statuses.contains);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technicians = ref.watch(techniciansProvider).valueOrNull ?? const [];
    final notifier = ref.read(ordersFilterProvider.notifier);

    const groups = <(String, List<OrderStatus>)>[
      ('Abiertas', OrderStatus.openStates),
      ('Recibidas', [OrderStatus.recibida]),
      ('En reparación', [OrderStatus.enReparacion]),
      ('Listas', [OrderStatus.lista]),
      ('Entregadas', [OrderStatus.entregada]),
      ('Canceladas', [OrderStatus.cancelada]),
      ('Todas', OrderStatus.values),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (label, statuses) in groups)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _isSelected(statuses),
                    onSelected: (_) => notifier.state =
                        filter.copyWith(statuses: statuses),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: FilterChip(
                  label: const Text('Todos los técnicos'),
                  selected: filter.technicianId == null,
                  onSelected: (_) =>
                      notifier.state = filter.copyWith(clearTechnician: true),
                ),
              ),
              for (final technician in technicians)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: FilterChip(
                    label: Text(technician.name),
                    selected: filter.technicianId == technician.id,
                    onSelected: (selected) => notifier.state = selected
                        ? filter.copyWith(technicianId: technician.id)
                        : filter.copyWith(clearTechnician: true),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una orden en la lista. Deja claro quién la tiene tomada.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = summary.order;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${order.id}',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.deviceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(summary.status, dense: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.device.kind} · ${summary.client.name}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              Text(
                order.reportedFault,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    summary.isTaken
                        ? Icons.person_outline
                        : Icons.person_off_outlined,
                    size: 16,
                    color: summary.isTaken
                        ? scheme.primary
                        : context.workshop.aviso,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      summary.isTaken
                          ? summary.technician!.name
                          : 'Sin tomar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: summary.isTaken
                                ? scheme.primary
                                : context.workshop.aviso,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    relativeDays(order.receivedAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money(summary.total),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
