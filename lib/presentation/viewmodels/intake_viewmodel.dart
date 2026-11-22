import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/workshop_repository.dart';
import '../providers.dart';
import 'command_state.dart';

/// Resultado de registrar la entrada de un equipo al taller.
class IntakeResult {
  const IntakeResult({required this.orderId, required this.deviceId});

  final int orderId;
  final int deviceId;
}

/// ViewModel de la recepción: crea (o reutiliza) cliente y equipo, y abre la
/// orden de reparación en un solo paso.
class IntakeViewModel extends Notifier<CommandState> {
  @override
  CommandState build() => CommandState.idle;

  WorkshopRepository get _repo => ref.read(repositoryProvider);

  void consumeFeedback() => state = CommandState.idle;

  /// [clientId] y [deviceId] llegan con valor cuando el técnico escogió un
  /// cliente o un equipo que ya estaban registrados.
  Future<IntakeResult?> submit({
    int? clientId,
    required String clientName,
    required String clientPhone,
    int? deviceId,
    required String kind,
    required String brand,
    required String model,
    required String serial,
    required String reportedFault,
    int? technicianId,
  }) async {
    state = CommandState.working;
    try {
      final resolvedClientId = clientId ??
          await _repo.saveClient(name: clientName, phone: clientPhone);

      final resolvedDeviceId = deviceId ??
          await _repo.saveDevice(
            clientId: resolvedClientId,
            kind: kind,
            brand: brand,
            model: model,
            serial: serial,
          );

      final orderId = await _repo.createOrder(
        deviceId: resolvedDeviceId,
        reportedFault: reportedFault,
        technicianId: technicianId,
      );

      state = const CommandState(message: 'Orden registrada.');
      return IntakeResult(orderId: orderId, deviceId: resolvedDeviceId);
    } on WorkshopException catch (e) {
      state = CommandState(error: e.message);
      return null;
    } catch (e) {
      state = CommandState(error: 'No se pudo registrar la entrada: $e');
      return null;
    }
  }
}

final intakeViewModelProvider =
    NotifierProvider<IntakeViewModel, CommandState>(IntakeViewModel.new);
