import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/order_status.dart';
import '../../domain/views.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/theme_menu_button.dart';
import 'inventory_screen.dart';
import 'orders_screen.dart';
import 'technicians_screen.dart';

/// Tablero: el estado del taller de un vistazo.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final workload = ref.watch(technicianWorkloadProvider);
    final lowStock = ref.watch(lowStockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu Solution'),
        actions: [
          IconButton(
            tooltip: 'Técnicos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TechniciansScreen(),
              ),
            ),
            icon: const Icon(Icons.engineering_outlined),
          ),
          const ThemeMenuButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e),
            data: (data) => _StatsGrid(stats: data),
          ),
          const SectionTitle('Carga de los técnicos'),
          workload.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (rows) => rows.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Todavía no hay técnicos registrados.'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _WorkloadTile(row: rows[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          const SectionTitle('Repuestos por agotarse'),
          lowStock.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (parts) => parts.isEmpty
                ? Card(
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline,
                          color: context.workshop.exito),
                      title: const Text('El almacén está al día.'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < parts.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.warning_amber_rounded,
                                color: context.workshop.aviso),
                            title: Text(parts[i].name),
                            subtitle: Text(
                              'Quedan ${parts[i].stock} · mínimo '
                              '${parts[i].minStock}',
                            ),
                            trailing: LowStockBadge(stock: parts[i].stock),
                          ),
                        ],
                        const Divider(height: 1),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const InventoryScreen(startOnLowStock: true),
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Ir al almacén'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.stats});

  final WorkshopStats stats;

  void _openOrders(BuildContext context, WidgetRef ref,
      List<OrderStatus> statuses) {
    ref.read(ordersFilterProvider.notifier).state =
        OrdersFilter(statuses: statuses);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: [
        StatCard(
          label: 'Órdenes abiertas',
          value: '${stats.openOrders}',
          icon: Icons.build_outlined,
          onTap: () => _openOrders(context, ref, OrderStatus.openStates),
        ),
        StatCard(
          label: 'Sin técnico asignado',
          value: '${stats.untakenOpenOrders}',
          icon: Icons.person_off_outlined,
          color: context.workshop.aviso,
          onTap: () => _openOrders(context, ref, OrderStatus.openStates),
        ),
        StatCard(
          label: 'En reparación',
          value: '${stats.count(OrderStatus.enReparacion)}',
          icon: Icons.handyman_outlined,
          color: context.workshop.enReparacion,
          onTap: () =>
              _openOrders(context, ref, const [OrderStatus.enReparacion]),
        ),
        StatCard(
          label: 'Listas para entregar',
          value: '${stats.count(OrderStatus.lista)}',
          icon: Icons.task_alt,
          color: context.workshop.lista,
          onTap: () => _openOrders(context, ref, const [OrderStatus.lista]),
        ),
      ],
    );
  }
}

class _WorkloadTile extends StatelessWidget {
  const _WorkloadTile({required this.row});

  final TechnicianWorkload row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          row.technician.name.characters.first.toUpperCase(),
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(row.technician.name),
      subtitle: Text(
        '${row.inRepair} en reparación · ${row.ready} listas',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${row.openOrders}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('abiertas', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
