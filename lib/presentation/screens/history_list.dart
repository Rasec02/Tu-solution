import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../domain/views.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Historial de reparaciones: qué se le hizo al equipo y qué piezas llevó.
///
/// Es la respuesta a "cuando un equipo vuelve, nadie recuerda qué se le hizo
/// la vez anterior".
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.entries,
    this.showDevice = false,
  });

  final List<HistoryEntry> entries;
  final bool showDevice;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.history_toggle_off),
          title: Text('Sin reparaciones anteriores.'),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OrderDetailScreen(orderId: entry.order.id),
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
                            '#${entry.order.id}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: scheme.outline),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shortDate(entry.order.receivedAt),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          StatusChip(entry.order.status, dense: true),
                        ],
                      ),
                      if (showDevice) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${entry.device.brand} ${entry.device.model} · '
                          '${entry.device.kind}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.outline),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        entry.order.reportedFault,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (entry.jobs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _Bullets(
                          icon: Icons.handyman_outlined,
                          label: 'Trabajos',
                          items: entry.jobs,
                        ),
                      ],
                      if (entry.parts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _Bullets(
                          icon: Icons.memory_outlined,
                          label: 'Repuestos',
                          items: entry.parts,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 15, color: scheme.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.technicianName ?? 'Sin técnico',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ),
                          Text(
                            money(entry.total),
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
            ),
          ),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.icon,
    required this.label,
    required this.items,
  });

  final IconData icon;
  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: scheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: ${items.join(', ')}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
      ],
    );
  }
}
