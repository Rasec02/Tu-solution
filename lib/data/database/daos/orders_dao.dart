import 'package:drift/drift.dart';

import '../../../domain/order_status.dart';
import '../app_database.dart';
import '../tables.dart';

part 'orders_dao.g.dart';

/// Acceso a órdenes de reparación, trabajos y repuestos consumidos.
@DriftAccessor(
  tables: [RepairOrders, OrderJobs, OrderParts, Devices, Clients, Technicians, SpareParts],
)
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);

  // ----- Consultas -----

  /// Órdenes con equipo, dueño, técnico y totales ya calculados.
  Stream<List<OrderRow>> watchOrders({
    List<OrderStatus>? statuses,
    int? technicianId,
    int? deviceId,
    int? clientId,
  }) {
    final query = select(repairOrders).join([
      innerJoin(devices, devices.id.equalsExp(repairOrders.deviceId)),
      innerJoin(clients, clients.id.equalsExp(devices.clientId)),
      leftOuterJoin(
        technicians,
        technicians.id.equalsExp(repairOrders.technicianId),
      ),
    ]);

    if (statuses != null && statuses.isNotEmpty) {
      query.where(repairOrders.status.isIn(statuses.map((s) => s.name)));
    }
    if (technicianId != null) {
      query.where(repairOrders.technicianId.equals(technicianId));
    }
    if (deviceId != null) {
      query.where(repairOrders.deviceId.equals(deviceId));
    }
    if (clientId != null) {
      query.where(devices.clientId.equals(clientId));
    }

    query.orderBy([OrderingTerm.desc(repairOrders.receivedAt)]);

    return query.watch().map((rows) => rows
        .map((row) => OrderRow(
              order: row.readTable(repairOrders),
              device: row.readTable(devices),
              client: row.readTable(clients),
              technician: row.readTableOrNull(technicians),
            ))
        .toList());
  }

  Stream<OrderRow?> watchOrder(int orderId) {
    final query = select(repairOrders).join([
      innerJoin(devices, devices.id.equalsExp(repairOrders.deviceId)),
      innerJoin(clients, clients.id.equalsExp(devices.clientId)),
      leftOuterJoin(
        technicians,
        technicians.id.equalsExp(repairOrders.technicianId),
      ),
    ])
      ..where(repairOrders.id.equals(orderId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return OrderRow(
        order: row.readTable(repairOrders),
        device: row.readTable(devices),
        client: row.readTable(clients),
        technician: row.readTableOrNull(technicians),
      );
    });
  }

  Future<RepairOrder?> orderById(int id) =>
      (select(repairOrders)..where((o) => o.id.equals(id))).getSingleOrNull();

  /// Orden abierta del equipo, si existe. Sirve para no abrir dos a la vez.
  Future<RepairOrder?> openOrderForDevice(int deviceId) =>
      (select(repairOrders)
            ..where((o) => o.deviceId.equals(deviceId))
            ..where((o) =>
                o.status.isIn(OrderStatus.openStates.map((s) => s.name))))
          .getSingleOrNull();

  Stream<List<OrderJob>> watchJobs(int orderId) => (select(orderJobs)
        ..where((j) => j.orderId.equals(orderId))
        ..orderBy([(j) => OrderingTerm.asc(j.createdAt)]))
      .watch();

  Future<List<OrderJob>> jobsOf(int orderId) =>
      (select(orderJobs)..where((j) => j.orderId.equals(orderId))).get();

  /// Repuestos consumidos por una orden, con el repuesto del inventario.
  Stream<List<(OrderPart, SparePart)>> watchParts(int orderId) {
    final query = select(orderParts).join([
      innerJoin(spareParts, spareParts.id.equalsExp(orderParts.partId)),
    ])
      ..where(orderParts.orderId.equals(orderId))
      ..orderBy([OrderingTerm.asc(orderParts.createdAt)]);

    return query.watch().map((rows) => rows
        .map((row) => (row.readTable(orderParts), row.readTable(spareParts)))
        .toList());
  }

  Future<List<(OrderPart, SparePart)>> partsOf(int orderId) {
    final query = select(orderParts).join([
      innerJoin(spareParts, spareParts.id.equalsExp(orderParts.partId)),
    ])
      ..where(orderParts.orderId.equals(orderId));

    return query.get().then((rows) => rows
        .map((row) => (row.readTable(orderParts), row.readTable(spareParts)))
        .toList());
  }

  /// Totales de mano de obra por orden (para las listas).
  Stream<Map<int, double>> watchLaborTotals() {
    final sum = orderJobs.laborCost.sum();
    final query = selectOnly(orderJobs)
      ..addColumns([orderJobs.orderId, sum])
      ..groupBy([orderJobs.orderId]);

    return query.watch().map((rows) => {
          for (final row in rows)
            row.read(orderJobs.orderId)!: row.read(sum) ?? 0,
        });
  }

  /// Totales de repuestos por orden (cantidad * precio del momento).
  Stream<Map<int, double>> watchPartsTotals() {
    final total = (orderParts.quantity.cast<double>() * orderParts.unitPrice)
        .sum();
    final query = selectOnly(orderParts)
      ..addColumns([orderParts.orderId, total])
      ..groupBy([orderParts.orderId]);

    return query.watch().map((rows) => {
          for (final row in rows)
            row.read(orderParts.orderId)!: row.read(total) ?? 0,
        });
  }

  /// Conteo de órdenes agrupado por estado.
  Stream<Map<OrderStatus, int>> watchCountsByStatus() {
    final count = repairOrders.id.count();
    final query = selectOnly(repairOrders)
      ..addColumns([repairOrders.status, count])
      ..groupBy([repairOrders.status]);

    return query.watch().map((rows) {
      final result = <OrderStatus, int>{};
      for (final row in rows) {
        final raw = row.readWithConverter(repairOrders.status);
        if (raw == null) continue;
        result[raw] = row.read(count) ?? 0;
      }
      return result;
    });
  }

  /// Órdenes abiertas que todavía no ha tomado ningún técnico.
  Stream<int> watchUntakenOpenOrders() {
    final count = repairOrders.id.count();
    final query = selectOnly(repairOrders)
      ..addColumns([count])
      ..where(repairOrders.technicianId.isNull() &
          repairOrders.status.isIn(OrderStatus.openStates.map((s) => s.name)));

    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Carga de trabajo por técnico: órdenes abiertas, en reparación y listas.
  Stream<List<TechnicianLoadRow>> watchTechnicianLoad() {
    final query = select(technicians).join([
      leftOuterJoin(
        repairOrders,
        repairOrders.technicianId.equalsExp(technicians.id) &
            repairOrders.status
                .isIn(OrderStatus.openStates.map((s) => s.name)),
      ),
    ])
      ..orderBy([OrderingTerm.asc(technicians.name)]);

    return query.watch().map((rows) {
      final byTechnician = <int, TechnicianLoadRow>{};
      for (final row in rows) {
        final technician = row.readTable(technicians);
        final order = row.readTableOrNull(repairOrders);
        final current = byTechnician.putIfAbsent(
          technician.id,
          () => TechnicianLoadRow(technician: technician),
        );
        if (order == null) continue;
        current.open++;
        if (order.status == OrderStatus.enReparacion) current.inRepair++;
        if (order.status == OrderStatus.lista) current.ready++;
      }
      return byTechnician.values.toList();
    });
  }

  // ----- Escrituras -----

  Future<int> insertOrder(RepairOrdersCompanion order) =>
      into(repairOrders).insert(order);

  Future<void> updateOrder(RepairOrdersCompanion order) =>
      update(repairOrders).replace(order);

  Future<int> writeOrder(int id, RepairOrdersCompanion changes) =>
      (update(repairOrders)..where((o) => o.id.equals(id))).write(changes);

  Future<int> insertJob(OrderJobsCompanion job) => into(orderJobs).insert(job);

  Future<int> deleteJob(int id) =>
      (delete(orderJobs)..where((j) => j.id.equals(id))).go();

  Future<int> insertPartLine(OrderPartsCompanion line) =>
      into(orderParts).insert(line);

  Future<OrderPart?> partLineById(int id) =>
      (select(orderParts)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<int> deletePartLine(int id) =>
      (delete(orderParts)..where((l) => l.id.equals(id))).go();
}

/// Fila cruda de una orden junto a sus relaciones.
class OrderRow {
  const OrderRow({
    required this.order,
    required this.device,
    required this.client,
    required this.technician,
  });

  final RepairOrder order;
  final Device device;
  final Client client;
  final Technician? technician;
}

/// Acumulador mutable de la carga de un técnico.
class TechnicianLoadRow {
  TechnicianLoadRow({required this.technician});

  final Technician technician;
  int open = 0;
  int inRepair = 0;
  int ready = 0;
}
