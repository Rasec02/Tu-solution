import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/workshop_repository.dart';
import '../providers.dart';
import 'command_state.dart';

/// ViewModel del almacén: alta y ajuste de repuestos, y reposiciones.
class InventoryViewModel extends Notifier<CommandState> {
  @override
  CommandState build() => CommandState.idle;

  WorkshopRepository get _repo => ref.read(repositoryProvider);

  void consumeFeedback() => state = CommandState.idle;

  Future<bool> _run(Future<void> Function() action, String okMessage) async {
    state = CommandState.working;
    try {
      await action();
      state = CommandState(message: okMessage);
      return true;
    } on WorkshopException catch (e) {
      state = CommandState(error: e.message);
      return false;
    } catch (e) {
      state = CommandState(error: 'No se pudo guardar: $e');
      return false;
    }
  }

  Future<bool> savePart({
    int? id,
    required String code,
    required String name,
    required double price,
    required int stock,
    required int minStock,
  }) =>
      _run(
        () => _repo.savePart(
          id: id,
          code: code,
          name: name,
          price: price,
          stock: stock,
          minStock: minStock,
        ),
        id == null ? 'Repuesto agregado al almacén.' : 'Repuesto actualizado.',
      );

  Future<bool> restock(int partId, int quantity) => _run(
        () => _repo.restock(partId, quantity),
        'Entrada registrada en el almacén.',
      );
}

final inventoryViewModelProvider =
    NotifierProvider<InventoryViewModel, CommandState>(InventoryViewModel.new);

/// ViewModel de clientes, equipos y técnicos.
class CatalogViewModel extends Notifier<CommandState> {
  @override
  CommandState build() => CommandState.idle;

  WorkshopRepository get _repo => ref.read(repositoryProvider);

  void consumeFeedback() => state = CommandState.idle;

  Future<bool> _run(Future<void> Function() action, String okMessage) async {
    state = CommandState.working;
    try {
      await action();
      state = CommandState(message: okMessage);
      return true;
    } on WorkshopException catch (e) {
      state = CommandState(error: e.message);
      return false;
    } catch (e) {
      state = CommandState(error: 'No se pudo guardar: $e');
      return false;
    }
  }

  Future<bool> saveClient({
    int? id,
    required String name,
    required String phone,
    String? notes,
  }) =>
      _run(
        () => _repo.saveClient(id: id, name: name, phone: phone, notes: notes),
        id == null ? 'Cliente registrado.' : 'Cliente actualizado.',
      );

  Future<bool> saveDevice({
    int? id,
    required int clientId,
    required String kind,
    required String brand,
    required String model,
    required String serial,
  }) =>
      _run(
        () => _repo.saveDevice(
          id: id,
          clientId: clientId,
          kind: kind,
          brand: brand,
          model: model,
          serial: serial,
        ),
        id == null ? 'Equipo registrado.' : 'Equipo actualizado.',
      );

  Future<bool> saveTechnician({
    int? id,
    required String name,
    String? phone,
    bool active = true,
  }) =>
      _run(
        () => _repo.saveTechnician(
          id: id,
          name: name,
          phone: phone,
          active: active,
        ),
        id == null ? 'Técnico registrado.' : 'Técnico actualizado.',
      );
}

final catalogViewModelProvider =
    NotifierProvider<CatalogViewModel, CommandState>(CatalogViewModel.new);
