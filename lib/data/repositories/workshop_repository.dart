import 'dart:async';

import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/order_status.dart';
import '../../domain/views.dart';
import '../database/app_database.dart';
import '../database/daos/catalog_dao.dart';
import '../database/daos/inventory_dao.dart';
import '../database/daos/orders_dao.dart';

/// Error de negocio con un mensaje listo para mostrar al técnico.
class WorkshopException implements Exception {
  WorkshopException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Única puerta de entrada a los datos del taller.
///
/// Aquí viven las reglas del negocio: quién puede tomar una orden, cómo se
/// mueve de estado y cómo se descuentan los repuestos del almacén.
class WorkshopRepository {
  WorkshopRepository(this._db);

  final AppDatabase _db;

  CatalogDao get _catalog => _db.catalogDao;
  OrdersDao get _orders => _db.ordersDao;
  InventoryDao get _inventory => _db.inventoryDao;

  // ======================= Clientes y equipos =======================

  Stream<List<Client>> watchClients() => _catalog.watchClients();

  Stream<List<Device>> watchDevicesOfClient(int clientId) =>
      _catalog.watchDevicesOfClient(clientId);

  Stream<List<(Device, Client)>> watchDevicesWithClient() =>
      _catalog.watchDevicesWithClient();

  Future<Client> clientById(int id) => _catalog.clientById(id);

  Future<Device> deviceById(int id) => _catalog.deviceById(id);

  Future<int> saveClient({
    int? id,
    required String name,
    required String phone,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    if (trimmedName.isEmpty) {
      throw WorkshopException('El nombre del cliente no puede estar vacío.');
    }
    if (trimmedPhone.isEmpty) {
      throw WorkshopException('El teléfono del cliente no puede estar vacío.');
    }

    if (id == null) {
      return _catalog.insertClient(
        ClientsCompanion.insert(
          name: trimmedName,
          phone: trimmedPhone,
          notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
        ),
      );
    }

    final existing = await _catalog.clientById(id);
    await _catalog.updateClient(
      existing.copyWith(
        name: trimmedName,
        phone: trimmedPhone,
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
      ),
    );
    return id;
  }

  Future<int> saveDevice({
    int? id,
    required int clientId,
    required String kind,
    required String brand,
    required String model,
    required String serial,
  }) async {
    final trimmedSerial = serial.trim();
    if (trimmedSerial.isEmpty) {
      throw WorkshopException('El número de serie es obligatorio.');
    }

    final duplicate = await _catalog.findDeviceBySerial(trimmedSerial);
    if (duplicate != null && duplicate.id != id) {
      throw WorkshopException(
        'Ya existe un equipo registrado con el número de serie $trimmedSerial.',
      );
    }

    if (id == null) {
      return _catalog.insertDevice(
        DevicesCompanion.insert(
          clientId: clientId,
          kind: kind.trim(),
          brand: brand.trim(),
          model: model.trim(),
          serial: trimmedSerial,
        ),
      );
    }

    final existing = await _catalog.deviceById(id);
    await _catalog.updateDevice(
      existing.copyWith(
        clientId: clientId,
        kind: kind.trim(),
        brand: brand.trim(),
        model: model.trim(),
        serial: trimmedSerial,
      ),
    );
    return id;
  }

  // ============================ Técnicos ============================

  Stream<List<Technician>> watchTechnicians() => _catalog.watchTechnicians();

  Future<List<Technician>> allTechnicians() => _catalog.allTechnicians();

  Future<int> saveTechnician({
    int? id,
    required String name,
    String? phone,
    bool active = true,
  }) async {
    if (name.trim().isEmpty) {
      throw WorkshopException('El nombre del técnico no puede estar vacío.');
    }
    if (id == null) {
      return _catalog.insertTechnician(
        TechniciansCompanion.insert(
          name: name.trim(),
          phone: Value(phone?.trim().isEmpty ?? true ? null : phone!.trim()),
          active: Value(active),
        ),
      );
    }
    final existing = await _catalog.technicianById(id);
    await _catalog.updateTechnician(
      existing.copyWith(
        name: name.trim(),
        phone: Value(phone?.trim().isEmpty ?? true ? null : phone!.trim()),
        active: active,
      ),
    );
    return id;
  }

  Stream<List<TechnicianWorkload>> watchTechnicianWorkload() =>
      _orders.watchTechnicianLoad().map((rows) => rows
          .map((row) => TechnicianWorkload(
                technician: row.technician,
                openOrders: row.open,
                inRepair: row.inRepair,
                ready: row.ready,
              ))
          .toList());

  // ============================= Órdenes ============================

  /// Órdenes con sus totales. Los totales se combinan en memoria para no
  /// repetir agregados por cada fila.
  Stream<List<OrderSummary>> watchOrders({
    List<OrderStatus>? statuses,
    int? technicianId,
    int? deviceId,
    int? clientId,
  }) {
    return Rx.combineLatest3<List<OrderRow>, Map<int, double>,
        Map<int, double>, List<OrderSummary>>(
      _orders.watchOrders(
        statuses: statuses,
        technicianId: technicianId,
        deviceId: deviceId,
        clientId: clientId,
      ),
      _orders.watchLaborTotals(),
      _orders.watchPartsTotals(),
      (rows, labor, parts) => rows
          .map((row) => OrderSummary(
                order: row.order,
                device: row.device,
                client: row.client,
                technician: row.technician,
                laborTotal: labor[row.order.id] ?? 0,
                partsTotal: parts[row.order.id] ?? 0,
              ))
          .toList(),
    );
  }

  Stream<OrderDetail?> watchOrderDetail(int orderId) {
    return Rx.combineLatest3<OrderRow?, List<OrderJob>,
        List<(OrderPart, SparePart)>, OrderDetail?>(
      _orders.watchOrder(orderId),
      _orders.watchJobs(orderId),
      _orders.watchParts(orderId),
      (row, jobs, parts) {
        if (row == null) return null;
        final lines = parts
            .map((p) => OrderPartLine(line: p.$1, part: p.$2))
            .toList();
        return OrderDetail(
          summary: OrderSummary(
            order: row.order,
            device: row.device,
            client: row.client,
            technician: row.technician,
            laborTotal: jobs.fold<double>(0, (a, j) => a + j.laborCost),
            partsTotal: lines.fold<double>(0, (a, l) => a + l.lineTotal),
          ),
          jobs: jobs,
          parts: lines,
        );
      },
    );
  }

  /// Registra la entrada de un equipo al taller.
  ///
  /// Si el equipo ya tiene una orden abierta no se crea otra: eso evita que
  /// dos técnicos trabajen por separado sobre el mismo equipo.
  Future<int> createOrder({
    required int deviceId,
    required String reportedFault,
    int? technicianId,
  }) async {
    if (reportedFault.trim().isEmpty) {
      throw WorkshopException('Debe anotar la falla que reporta el cliente.');
    }

    final open = await _orders.openOrderForDevice(deviceId);
    if (open != null) {
      throw WorkshopException(
        'Ese equipo ya tiene la orden #${open.id} abierta '
        '(${open.status.label}). Ciérrela antes de abrir otra.',
      );
    }

    return _orders.insertOrder(
      RepairOrdersCompanion.insert(
        deviceId: deviceId,
        reportedFault: reportedFault.trim(),
        technicianId: Value(technicianId),
        takenAt: Value(technicianId == null ? null : DateTime.now()),
      ),
    );
  }

  /// Un técnico toma la orden y queda como responsable visible para todos.
  Future<void> takeOrder(int orderId, int technicianId) async {
    final order = await _requireOrder(orderId);
    if (order.status.isClosed) {
      throw WorkshopException(
        'La orden #$orderId está ${order.status.label.toLowerCase()} y ya no '
        'se puede tomar.',
      );
    }
    if (order.technicianId != null && order.technicianId != technicianId) {
      final holder = await _catalog.technicianById(order.technicianId!);
      throw WorkshopException(
        'La orden #$orderId ya la tomó ${holder.name}. Debe liberarla primero.',
      );
    }

    await _orders.writeOrder(
      orderId,
      RepairOrdersCompanion(
        technicianId: Value(technicianId),
        takenAt: Value(order.takenAt ?? DateTime.now()),
      ),
    );
  }

  /// Libera la orden para que otro técnico pueda tomarla.
  Future<void> releaseOrder(int orderId) async {
    final order = await _requireOrder(orderId);
    if (order.technicianId == null) {
      throw WorkshopException('La orden #$orderId no está tomada.');
    }
    if (order.status.isClosed) {
      throw WorkshopException(
        'La orden #$orderId ya está ${order.status.label.toLowerCase()}.',
      );
    }
    await _orders.writeOrder(
      orderId,
      const RepairOrdersCompanion(
        technicianId: Value(null),
        takenAt: Value(null),
      ),
    );
  }

  /// Mueve la orden por el flujo de estados, validando la transición.
  Future<void> changeStatus(int orderId, OrderStatus target) async {
    final order = await _requireOrder(orderId);
    final current = order.status;

    if (current == target) return;
    if (!current.nextStates.contains(target)) {
      throw WorkshopException(
        'No se puede pasar de ${current.label.toLowerCase()} a '
        '${target.label.toLowerCase()}.',
      );
    }
    if (target == OrderStatus.enReparacion && order.technicianId == null) {
      throw WorkshopException(
        'Un técnico debe tomar la orden antes de ponerla en reparación.',
      );
    }

    await _orders.writeOrder(
      orderId,
      RepairOrdersCompanion(
        status: Value(target),
        closedAt: Value(target.isClosed ? DateTime.now() : null),
      ),
    );
  }

  Future<void> saveDiagnosis(int orderId, String diagnosis) async {
    await _requireOrder(orderId);
    await _orders.writeOrder(
      orderId,
      RepairOrdersCompanion(
        diagnosis: Value(diagnosis.trim().isEmpty ? null : diagnosis.trim()),
      ),
    );
  }

  // ---------------------- Trabajos (mano de obra) -------------------

  Future<void> addJob({
    required int orderId,
    required String description,
    required double laborCost,
  }) async {
    final order = await _requireOrder(orderId);
    if (order.status.isClosed) {
      throw WorkshopException(
        'La orden #$orderId está cerrada: no admite más trabajos.',
      );
    }
    if (description.trim().isEmpty) {
      throw WorkshopException('Describa el trabajo realizado.');
    }
    if (laborCost < 0) {
      throw WorkshopException('El costo de mano de obra no puede ser negativo.');
    }

    await _orders.insertJob(
      OrderJobsCompanion.insert(
        orderId: orderId,
        description: description.trim(),
        laborCost: Value(laborCost),
      ),
    );
  }

  Future<void> removeJob(int jobId) => _orders.deleteJob(jobId);

  // ------------------------ Repuestos usados ------------------------

  /// Consume un repuesto en una orden y descuenta el almacén.
  ///
  /// Todo ocurre en una transacción: o se registra la línea y baja el stock,
  /// o no pasa nada. Así el inventario siempre cuadra con lo anotado.
  Future<void> addPartToOrder({
    required int orderId,
    required int partId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw WorkshopException('La cantidad debe ser mayor que cero.');
    }

    await _db.transaction(() async {
      final order = await _requireOrder(orderId);
      if (order.status.isClosed) {
        throw WorkshopException(
          'La orden #$orderId está cerrada: no admite más repuestos.',
        );
      }

      final part = await _inventory.partById(partId);
      if (part.stock < quantity) {
        throw WorkshopException(
          'Solo quedan ${part.stock} de "${part.name}" en el almacén.',
        );
      }

      await _orders.insertPartLine(
        OrderPartsCompanion.insert(
          orderId: orderId,
          partId: partId,
          quantity: quantity,
          unitPrice: part.price,
        ),
      );
      await _inventory.addStock(partId, -quantity);
      await _inventory.logMovement(
        StockMovementsCompanion.insert(
          partId: partId,
          orderId: Value(orderId),
          delta: -quantity,
          reason: 'Usado en orden #$orderId',
        ),
      );
    });
  }

  /// Quita una línea de repuesto y devuelve las piezas al almacén.
  Future<void> removePartFromOrder(int lineId) async {
    await _db.transaction(() async {
      final line = await _orders.partLineById(lineId);
      if (line == null) {
        throw WorkshopException('Esa línea de repuesto ya no existe.');
      }
      await _orders.deletePartLine(lineId);
      await _inventory.addStock(line.partId, line.quantity);
      await _inventory.logMovement(
        StockMovementsCompanion.insert(
          partId: line.partId,
          orderId: Value(line.orderId),
          delta: line.quantity,
          reason: 'Devuelto de la orden #${line.orderId}',
        ),
      );
    });
  }

  // ============================ Inventario ==========================

  Stream<List<SparePart>> watchParts() => _inventory.watchParts();

  Stream<List<SparePart>> watchLowStock() => _inventory.watchLowStock();

  Stream<List<StockMovement>> watchMovements(int partId) =>
      _inventory.watchMovements(partId);

  Future<List<SparePart>> allParts() => _inventory.allParts();

  Future<int> savePart({
    int? id,
    required String code,
    required String name,
    required double price,
    required int stock,
    required int minStock,
  }) async {
    if (code.trim().isEmpty) {
      throw WorkshopException('El código del repuesto es obligatorio.');
    }
    if (name.trim().isEmpty) {
      throw WorkshopException('El nombre del repuesto es obligatorio.');
    }
    if (price < 0 || stock < 0 || minStock < 0) {
      throw WorkshopException('Precio, existencias y mínimo no pueden ser '
          'negativos.');
    }

    if (id == null) {
      final newId = await _inventory.insertPart(
        SparePartsCompanion.insert(
          code: code.trim(),
          name: name.trim(),
          price: Value(price),
          stock: Value(stock),
          minStock: Value(minStock),
        ),
      );
      if (stock > 0) {
        await _inventory.logMovement(
          StockMovementsCompanion.insert(
            partId: newId,
            delta: stock,
            reason: 'Alta del repuesto en el almacén',
          ),
        );
      }
      return newId;
    }

    final existing = await _inventory.partById(id);
    await _inventory.updatePart(
      existing.copyWith(
        code: code.trim(),
        name: name.trim(),
        price: price,
        minStock: minStock,
      ),
    );
    final diff = stock - existing.stock;
    if (diff != 0) {
      await _inventory.addStock(id, diff);
      await _inventory.logMovement(
        StockMovementsCompanion.insert(
          partId: id,
          delta: diff,
          reason: 'Ajuste manual de existencias',
        ),
      );
    }
    return id;
  }

  /// Entrada de mercancía al almacén.
  Future<void> restock(int partId, int quantity) async {
    if (quantity <= 0) {
      throw WorkshopException('La cantidad a reponer debe ser mayor que cero.');
    }
    await _db.transaction(() async {
      await _inventory.addStock(partId, quantity);
      await _inventory.logMovement(
        StockMovementsCompanion.insert(
          partId: partId,
          delta: quantity,
          reason: 'Reposición de almacén',
        ),
      );
    });
  }

  // ============================= Tablero ============================

  Stream<WorkshopStats> watchStats() {
    return Rx.combineLatest3<Map<OrderStatus, int>, int, int, WorkshopStats>(
      _orders.watchCountsByStatus(),
      _orders.watchUntakenOpenOrders(),
      _inventory.watchLowStockCount(),
      (byStatus, untaken, lowStock) => WorkshopStats(
        byStatus: byStatus,
        untakenOpenOrders: untaken,
        lowStockCount: lowStock,
      ),
    );
  }

  // ============================ Historial ===========================

  /// Historial de reparaciones de un equipo (o de todos los de un cliente).
  Future<List<HistoryEntry>> history({int? deviceId, int? clientId}) async {
    final rows = await _orders
        .watchOrders(deviceId: deviceId, clientId: clientId)
        .first;

    final entries = <HistoryEntry>[];
    for (final row in rows) {
      final jobs = await _orders.jobsOf(row.order.id);
      final parts = await _orders.partsOf(row.order.id);
      final labor = jobs.fold<double>(0, (a, j) => a + j.laborCost);
      final partsTotal = parts.fold<double>(
        0,
        (a, p) => a + p.$1.quantity * p.$1.unitPrice,
      );
      entries.add(
        HistoryEntry(
          order: row.order,
          device: row.device,
          technicianName: row.technician?.name,
          jobs: jobs.map((j) => j.description).toList(),
          parts: parts
              .map((p) => '${p.$2.name} x${p.$1.quantity}')
              .toList(),
          total: labor + partsTotal,
        ),
      );
    }
    return entries;
  }

  Future<RepairOrder> _requireOrder(int orderId) async {
    final order = await _orders.orderById(orderId);
    if (order == null) {
      throw WorkshopException('La orden #$orderId no existe.');
    }
    return order;
  }
}
