import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/workshop_repository.dart';
import '../domain/order_status.dart';
import '../domain/views.dart';

/// Base de datos. Se inyecta en `main` con un override para abrirla una sola
/// vez al arrancar la app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(ref.watch(databaseProvider)),
);

// ----------------------------- Tablero -----------------------------

final statsProvider = StreamProvider<WorkshopStats>(
  (ref) => ref.watch(repositoryProvider).watchStats(),
);

// ----------------------------- Órdenes -----------------------------

/// Filtro activo en la lista de órdenes.
class OrdersFilter {
  const OrdersFilter({this.statuses = OrderStatus.openStates, this.technicianId});

  final List<OrderStatus> statuses;
  final int? technicianId;

  OrdersFilter copyWith({List<OrderStatus>? statuses, int? technicianId, bool clearTechnician = false}) {
    return OrdersFilter(
      statuses: statuses ?? this.statuses,
      technicianId: clearTechnician ? null : (technicianId ?? this.technicianId),
    );
  }
}

final ordersFilterProvider =
    StateProvider<OrdersFilter>((ref) => const OrdersFilter());

final ordersProvider = StreamProvider<List<OrderSummary>>((ref) {
  final filter = ref.watch(ordersFilterProvider);
  return ref.watch(repositoryProvider).watchOrders(
        statuses: filter.statuses,
        technicianId: filter.technicianId,
      );
});

final orderDetailProvider =
    StreamProvider.family<OrderDetail?, int>((ref, orderId) {
  return ref.watch(repositoryProvider).watchOrderDetail(orderId);
});

// ---------------------------- Catálogos ----------------------------

final clientsProvider = StreamProvider<List<Client>>(
  (ref) => ref.watch(repositoryProvider).watchClients(),
);

final devicesWithClientProvider = StreamProvider<List<(Device, Client)>>(
  (ref) => ref.watch(repositoryProvider).watchDevicesWithClient(),
);

final deviceProvider = FutureProvider.family<Device, int>(
  (ref, deviceId) => ref.watch(repositoryProvider).deviceById(deviceId),
);

final devicesOfClientProvider =
    StreamProvider.family<List<Device>, int>((ref, clientId) {
  return ref.watch(repositoryProvider).watchDevicesOfClient(clientId);
});

final techniciansProvider = StreamProvider<List<Technician>>(
  (ref) => ref.watch(repositoryProvider).watchTechnicians(),
);

final technicianWorkloadProvider = StreamProvider<List<TechnicianWorkload>>(
  (ref) => ref.watch(repositoryProvider).watchTechnicianWorkload(),
);

// ---------------------------- Inventario ---------------------------

final partsProvider = StreamProvider<List<SparePart>>(
  (ref) => ref.watch(repositoryProvider).watchParts(),
);

final lowStockProvider = StreamProvider<List<SparePart>>(
  (ref) => ref.watch(repositoryProvider).watchLowStock(),
);

final movementsProvider =
    StreamProvider.family<List<StockMovement>, int>((ref, partId) {
  return ref.watch(repositoryProvider).watchMovements(partId);
});

// ----------------------------- Historial ---------------------------

final deviceHistoryProvider =
    FutureProvider.family<List<HistoryEntry>, int>((ref, deviceId) {
  // Se reconstruye cuando cambia cualquier orden.
  ref.watch(ordersProvider);
  return ref.watch(repositoryProvider).history(deviceId: deviceId);
});

final clientHistoryProvider =
    FutureProvider.family<List<HistoryEntry>, int>((ref, clientId) {
  ref.watch(ordersProvider);
  return ref.watch(repositoryProvider).history(clientId: clientId);
});

/// Técnico seleccionado en el teléfono del taller.
///
/// La app no lleva autenticación: esto solo recuerda, por comodidad, quién
/// está usando el teléfono para precargarlo al tomar órdenes.
final activeTechnicianProvider = StateProvider<int?>((ref) => null);
