import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../providers.dart';
import '../viewmodels/command_state.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../widgets/common.dart';

/// Almacén de repuestos: existencias, avisos de agotamiento y movimientos.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.startOnLowStock = false});

  /// Abre directamente la pestaña de "por agotarse" (desde el tablero).
  final bool startOnLowStock;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.startOnLowStock ? 1 : 0,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = ref.watch(partsProvider);
    final lowStock = ref.watch(lowStockProvider);

    ref.listen<CommandState>(inventoryViewModelProvider, (_, next) {
      if (next.error != null) {
        showMessage(context, next.error!, error: true);
        ref.read(inventoryViewModelProvider.notifier).consumeFeedback();
      } else if (next.message != null) {
        showMessage(context, next.message!);
        ref.read(inventoryViewModelProvider.notifier).consumeFeedback();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Almacén'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Todos'),
            Tab(
              text: 'Por agotarse'
                  '${(lowStock.valueOrNull?.isNotEmpty ?? false) ? ' (${lowStock.value!.length})' : ''}',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPart(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Repuesto'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PartsList(async: parts, emptyTitle: 'El almacén está vacío'),
          _PartsList(
            async: lowStock,
            emptyTitle: 'Nada por agotarse',
            emptyMessage: 'Todos los repuestos están por encima del mínimo.',
          ),
        ],
      ),
    );
  }
}

class _PartsList extends ConsumerWidget {
  const _PartsList({
    required this.async,
    required this.emptyTitle,
    this.emptyMessage,
  });

  final AsyncValue<List<SparePart>> async;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(e),
      data: (parts) => parts.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: emptyTitle,
              message: emptyMessage,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: parts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PartCard(part: parts[i]),
            ),
    );
  }
}

class _PartCard extends ConsumerWidget {
  const _PartCard({required this.part});

  final SparePart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final low = part.stock <= part.minStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    part.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (low) LowStockBadge(stock: part.stock),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${part.code} · ${money(part.price)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${part.stock}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: low ? context.workshop.aviso : null,
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  'en existencia (mín. ${part.minStock})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Movimientos',
                  onPressed: () => _showMovements(context, ref, part),
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () => _editPart(context, ref, part),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Reponer',
                  onPressed: () => _restock(context, ref, part),
                  icon: const Icon(Icons.add_box_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _restock(
    BuildContext context, WidgetRef ref, SparePart part) async {
  final controller = TextEditingController(text: '1');

  final quantity = await showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Reponer ${part.name}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Cantidad que entra'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext)
              .pop(int.tryParse(controller.text.trim())),
          child: const Text('Reponer'),
        ),
      ],
    ),
  );

  if (quantity == null) return;
  await ref.read(inventoryViewModelProvider.notifier).restock(part.id, quantity);
}

Future<void> _showMovements(
    BuildContext context, WidgetRef ref, SparePart part) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, controller) => Consumer(
        builder: (_, innerRef, _) {
          final movements = innerRef.watch(movementsProvider(part.id));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Movimientos de ${part.name}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: movements.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(e),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Sin movimientos',
                        )
                      : ListView.separated(
                          controller: controller,
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final movement = list[i];
                            final entry = movement.delta > 0;
                            return ListTile(
                              leading: Icon(
                                entry
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: entry
                                    ? sheetContext.workshop.exito
                                    : sheetContext.workshop.cancelada,
                              ),
                              title: Text(movement.reason),
                              subtitle: Text(longDate(movement.createdAt)),
                              trailing: Text(
                                '${entry ? '+' : ''}${movement.delta}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: entry
                                      ? sheetContext.workshop.exito
                                      : sheetContext.workshop.cancelada,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> _editPart(
    BuildContext context, WidgetRef ref, SparePart? part) async {
  final code = TextEditingController(text: part?.code ?? '');
  final name = TextEditingController(text: part?.name ?? '');
  final price = TextEditingController(text: part?.price.toString() ?? '0');
  final stock = TextEditingController(text: part?.stock.toString() ?? '0');
  final minStock = TextEditingController(text: part?.minStock.toString() ?? '2');
  final formKey = GlobalKey<FormState>();

  String? requiredField(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  String? positiveInt(String? v) {
    final value = int.tryParse((v ?? '').trim());
    if (value == null) return 'Número no válido';
    if (value < 0) return 'No puede ser negativo';
    return null;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(part == null ? 'Nuevo repuesto' : 'Editar repuesto'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Código'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio'),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (value == null) return 'Precio no válido';
                  if (value < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Existencias'),
                validator: positiveInt,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: minStock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mínimo',
                  helperText: 'Avisa cuando las existencias bajen hasta aquí.',
                ),
                validator: positiveInt,
              ),
            ],
          ),
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

  await ref.read(inventoryViewModelProvider.notifier).savePart(
        id: part?.id,
        code: code.text,
        name: name.text,
        price: double.parse(price.text.replaceAll(',', '.')),
        stock: int.parse(stock.text.trim()),
        minStock: int.parse(minStock.text.trim()),
      );
}
