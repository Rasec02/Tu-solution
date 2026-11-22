import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../domain/views.dart';
import '../providers.dart';
import '../viewmodels/command_state.dart';
import '../viewmodels/order_viewmodel.dart';
import '../widgets/common.dart';
import 'device_history_screen.dart';

/// Detalle de una orden: quién la tiene, en qué estado va, qué se le hizo y
/// cuánto cuesta.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(orderDetailProvider(orderId));
    final vm = ref.watch(orderViewModelProvider(orderId));

    // Los mensajes de las reglas de negocio se muestran una sola vez.
    ref.listen<CommandState>(orderViewModelProvider(orderId), (_, next) {
      if (next.error != null) {
        showMessage(context, next.error!, error: true);
        ref.read(orderViewModelProvider(orderId).notifier).consumeFeedback();
      } else if (next.message != null) {
        showMessage(context, next.message!);
        ref.read(orderViewModelProvider(orderId).notifier).consumeFeedback();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Orden #$orderId'),
        actions: [
          detail.valueOrNull == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Historial del equipo',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeviceHistoryScreen(
                        deviceId: detail.value!.summary.device.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (data) {
          if (data == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'La orden ya no existe',
            );
          }
          return _OrderBody(detail: data, busy: vm.busy);
        },
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.detail, required this.busy});

  final OrderDetail detail;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = detail.summary;
    final order = detail.order;
    final closed = summary.status.isClosed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _HeaderCard(summary: summary),
        const SectionTitle('Responsable'),
        _ResponsibleCard(summary: summary, busy: busy),
        const SectionTitle('Estado'),
        _StatusCard(summary: summary, busy: busy),
        SectionTitle(
          'Diagnóstico',
          trailing: TextButton(
            onPressed: busy
                ? null
                : () => _editDiagnosis(context, ref, order.id, order.diagnosis),
            child: const Text('Editar'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              order.diagnosis?.isNotEmpty == true
                  ? order.diagnosis!
                  : 'Sin diagnóstico anotado todavía.',
              style: order.diagnosis?.isNotEmpty == true
                  ? null
                  : TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
        SectionTitle(
          'Trabajos realizados',
          trailing: closed
              ? null
              : TextButton.icon(
                  onPressed:
                      busy ? null : () => _addJob(context, ref, order.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
        ),
        _JobsCard(detail: detail, busy: busy, closed: closed),
        SectionTitle(
          'Repuestos utilizados',
          trailing: closed
              ? null
              : TextButton.icon(
                  onPressed:
                      busy ? null : () => _addPart(context, ref, order.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
        ),
        _PartsCard(detail: detail, busy: busy, closed: closed),
        const SectionTitle('Costo total'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TotalLine(label: 'Mano de obra', amount: detail.laborTotal),
                TotalLine(label: 'Repuestos', amount: detail.partsTotal),
                const Divider(height: 20),
                TotalLine(label: 'Total', amount: detail.total, bold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editDiagnosis(
    BuildContext context,
    WidgetRef ref,
    int orderId,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Diagnóstico'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Qué se encontró al revisar el equipo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(orderViewModelProvider(orderId).notifier)
        .saveDiagnosis(result);
  }

  Future<void> _addJob(
      BuildContext context, WidgetRef ref, int orderId) async {
    final description = TextEditingController();
    final cost = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trabajo realizado'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: description,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describa el trabajo'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Mano de obra'),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (value == null) return 'Importe no válido';
                  if (value < 0) return 'No puede ser negativo';
                  return null;
                },
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
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(orderViewModelProvider(orderId).notifier).addJob(
          description.text,
          double.parse(cost.text.replaceAll(',', '.')),
        );
  }

  Future<void> _addPart(
      BuildContext context, WidgetRef ref, int orderId) async {
    final parts = await ref.read(repositoryProvider).allParts();
    if (!context.mounted) return;

    final available = parts.where((p) => p.stock > 0).toList();
    if (available.isEmpty) {
      showMessage(context, 'No hay repuestos con existencias.', error: true);
      return;
    }

    final selection = await showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => _PartPickerDialog(parts: available),
    );
    if (selection == null) return;

    await ref
        .read(orderViewModelProvider(orderId).notifier)
        .addPart(selection.$1, selection.$2);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final device = summary.device;
    final order = summary.order;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${device.brand} ${device.model}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(summary.status),
              ],
            ),
            const SizedBox(height: 10),
            DetailRow('Tipo', device.kind),
            DetailRow('Serie', device.serial),
            DetailRow('Cliente', summary.client.name),
            DetailRow('Teléfono', summary.client.phone),
            DetailRow('Recibida', longDate(order.receivedAt)),
            if (order.closedAt != null)
              DetailRow('Cerrada', longDate(order.closedAt!)),
            const SizedBox(height: 10),
            Text(
              'Falla reportada',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 2),
            Text(order.reportedFault),
          ],
        ),
      ),
    );
  }
}

class _ResponsibleCard extends ConsumerWidget {
  const _ResponsibleCard({required this.summary, required this.busy});

  final OrderSummary summary;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final closed = summary.status.isClosed;
    final notifier =
        ref.read(orderViewModelProvider(summary.order.id).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  summary.isTaken
                      ? Icons.assignment_ind_outlined
                      : Icons.person_off_outlined,
                  color: summary.isTaken
                      ? scheme.primary
                      : const Color(0xFF8E6C00),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.isTaken
                        ? 'La tiene ${summary.technician!.name}'
                        : 'Nadie ha tomado esta orden',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (!closed) ...[
              const SizedBox(height: 12),
              if (summary.isTaken)
                OutlinedButton.icon(
                  onPressed: busy ? null : notifier.release,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Liberar orden'),
                )
              else
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => _pickTechnician(context, ref, notifier),
                  icon: const Icon(Icons.pan_tool_alt_outlined),
                  label: const Text('Tomar orden'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickTechnician(
    BuildContext context,
    WidgetRef ref,
    OrderViewModel notifier,
  ) async {
    final technicians = await ref.read(repositoryProvider).allTechnicians();
    if (!context.mounted) return;

    final active = technicians.where((t) => t.active).toList();
    if (active.isEmpty) {
      showMessage(context, 'No hay técnicos activos registrados.', error: true);
      return;
    }

    final chosen = await showModalBottomSheet<Technician>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('¿Quién toma la orden?'),
            ),
            for (final technician in active)
              ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: Text(technician.name),
                onTap: () => Navigator.of(sheetContext).pop(technician),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    // Recordamos quién está usando el teléfono para la próxima vez.
    ref.read(activeTechnicianProvider.notifier).state = chosen.id;
    await notifier.take(chosen.id);
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.summary, required this.busy});

  final OrderSummary summary;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = summary.status.nextStates;
    final notifier =
        ref.read(orderViewModelProvider(summary.order.id).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ahora está ${summary.status.label.toLowerCase()}.'),
            if (next.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Esta orden ya está cerrada.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in next)
                    FilledButton.tonal(
                      onPressed:
                          busy ? null : () => notifier.changeStatus(target),
                      child: Text('Marcar ${target.label.toLowerCase()}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobsCard extends ConsumerWidget {
  const _JobsCard({
    required this.detail,
    required this.busy,
    required this.closed,
  });

  final OrderDetail detail;
  final bool busy;
  final bool closed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.jobs.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.handyman_outlined),
          title: Text('Todavía no se ha anotado ningún trabajo.'),
        ),
      );
    }

    final notifier =
        ref.read(orderViewModelProvider(detail.order.id).notifier);

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < detail.jobs.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(detail.jobs[i].description),
              subtitle: Text(shortDate(detail.jobs[i].createdAt)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(detail.jobs[i].laborCost),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (!closed)
                    IconButton(
                      tooltip: 'Quitar',
                      onPressed: busy
                          ? null
                          : () => notifier.removeJob(detail.jobs[i].id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartsCard extends ConsumerWidget {
  const _PartsCard({
    required this.detail,
    required this.busy,
    required this.closed,
  });

  final OrderDetail detail;
  final bool busy;
  final bool closed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.parts.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.memory_outlined),
          title: Text('No se ha usado ningún repuesto.'),
        ),
      );
    }

    final notifier =
        ref.read(orderViewModelProvider(detail.order.id).notifier);

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < detail.parts.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(detail.parts[i].part.name),
              subtitle: Text(
                '${detail.parts[i].line.quantity} × '
                '${money(detail.parts[i].line.unitPrice)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(detail.parts[i].lineTotal),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (!closed)
                    IconButton(
                      tooltip: 'Devolver al almacén',
                      onPressed: busy
                          ? null
                          : () => notifier.removePart(detail.parts[i].line.id),
                      icon: const Icon(Icons.undo),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector de repuesto y cantidad, limitado por las existencias.
class _PartPickerDialog extends StatefulWidget {
  const _PartPickerDialog({required this.parts});

  final List<SparePart> parts;

  @override
  State<_PartPickerDialog> createState() => _PartPickerDialogState();
}

class _PartPickerDialogState extends State<_PartPickerDialog> {
  late SparePart _selected = widget.parts.first;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Usar repuesto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<SparePart>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Repuesto'),
            items: [
              for (final part in widget.parts)
                DropdownMenuItem(
                  value: part,
                  child: Text(
                    '${part.name} (${part.stock})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _selected = value!;
              _quantity = 1;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Cantidad'),
              const Spacer(),
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: _quantity < _selected.stock
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Subtotal ${money(_quantity * _selected.price)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_selected.id, _quantity)),
          child: const Text('Usar'),
        ),
      ],
    );
  }
}
