import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/workshop_repository.dart';
import '../../domain/order_status.dart';
import '../providers.dart';
import 'command_state.dart';

/// ViewModel de una orden concreta.
///
/// La vista no habla nunca con el repositorio: dispara comandos aquí y
/// observa [CommandState] para saber si debe bloquear botones o mostrar el
/// mensaje de una regla de negocio que no se cumplió.
class OrderViewModel extends FamilyNotifier<CommandState, int> {
  @override
  CommandState build(int orderId) => CommandState.idle;

  WorkshopRepository get _repo => ref.read(repositoryProvider);

  int get orderId => arg;

  /// Ejecuta una acción del repositorio traduciendo los errores de negocio
  /// a un mensaje que el técnico pueda entender.
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
      state = CommandState(error: 'No se pudo completar la operación: $e');
      return false;
    }
  }

  /// Limpia el mensaje ya mostrado para que no se repita en el próximo build.
  void consumeFeedback() => state = CommandState.idle;

  Future<bool> take(int technicianId) =>
      _run(() => _repo.takeOrder(orderId, technicianId), 'Tomaste la orden.');

  Future<bool> release() => _run(
        () => _repo.releaseOrder(orderId),
        'Orden liberada: otro técnico puede tomarla.',
      );

  Future<bool> changeStatus(OrderStatus target) => _run(
        () => _repo.changeStatus(orderId, target),
        'La orden pasó a ${target.label.toLowerCase()}.',
      );

  Future<bool> saveDiagnosis(String diagnosis) => _run(
        () => _repo.saveDiagnosis(orderId, diagnosis),
        'Diagnóstico guardado.',
      );

  Future<bool> addJob(String description, double laborCost) => _run(
        () => _repo.addJob(
          orderId: orderId,
          description: description,
          laborCost: laborCost,
        ),
        'Trabajo registrado.',
      );

  Future<bool> removeJob(int jobId) =>
      _run(() => _repo.removeJob(jobId), 'Trabajo eliminado.');

  Future<bool> addPart(int partId, int quantity) => _run(
        () => _repo.addPartToOrder(
          orderId: orderId,
          partId: partId,
          quantity: quantity,
        ),
        'Repuesto descontado del almacén.',
      );

  Future<bool> removePart(int lineId) => _run(
        () => _repo.removePartFromOrder(lineId),
        'Repuesto devuelto al almacén.',
      );
}

final orderViewModelProvider =
    NotifierProvider.family<OrderViewModel, CommandState, int>(
  OrderViewModel.new,
);
