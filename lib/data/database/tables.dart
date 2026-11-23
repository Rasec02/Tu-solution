import 'package:drift/drift.dart';

import '../../domain/order_status.dart';

/// Dueño del equipo. Un mismo cliente puede traer varios equipos.
@DataClassName('Client')
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 120)();
  TextColumn get phone => text().withLength(min: 4, max: 40)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Equipo físico que entra al taller. Puede volver muchas veces.
@DataClassName('Device')
class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId =>
      integer().references(Clients, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text().withLength(min: 2, max: 40)(); // celular, tablet, laptop
  TextColumn get brand => text().withLength(min: 1, max: 60)();
  TextColumn get model => text().withLength(min: 1, max: 60)();
  TextColumn get serial => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {serial},
      ];
}

/// Los tres técnicos del taller (la app no lleva autenticación).
@DataClassName('Technician')
class Technicians extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 2, max: 120)();
  TextColumn get phone => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Cada visita del equipo al taller es una orden de reparación.
@DataClassName('RepairOrder')
class RepairOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId =>
      integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// Técnico responsable. Null = nadie la ha tomado todavía.
  IntColumn get technicianId =>
      integer().nullable().references(Technicians, #id)();

  TextColumn get reportedFault => text()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get status =>
      textEnum<OrderStatus>().withDefault(const Constant('recibida'))();
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get takenAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

/// Trabajo realizado sobre una orden, con su costo de mano de obra.
@DataClassName('OrderJob')
class OrderJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(RepairOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text().withLength(min: 2, max: 200)();
  RealColumn get laborCost => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Inventario del almacén de repuestos.
@DataClassName('SparePart')
class SpareParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 40)();
  TextColumn get name => text().withLength(min: 2, max: 120)();
  RealColumn get price => real().withDefault(const Constant(0))();
  IntColumn get stock => integer().withDefault(const Constant(0))();

  /// Umbral para avisar que el repuesto está por agotarse.
  IntColumn get minStock => integer().withDefault(const Constant(2))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {code},
      ];
}

/// Repuesto consumido por una orden. Guarda el precio del momento del uso.
@DataClassName('OrderPart')
class OrderParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(RepairOrders, #id, onDelete: KeyAction.cascade)();
  IntColumn get partId => integer().references(SpareParts, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Bitácora de movimientos del almacén, para que el stock siempre cuadre.
@DataClassName('StockMovement')
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get partId =>
      integer().references(SpareParts, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderId => integer().nullable().references(RepairOrders, #id)();

  /// Negativo = salida (consumo), positivo = entrada (reposición o devolución).
  IntColumn get delta => integer()();
  TextColumn get reason => text().withLength(min: 2, max: 120)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ajustes de la app guardados como pares clave/valor.
///
/// Es un par suelto, no merece tabla propia por cada opción: hoy solo guarda
/// el modo de tema que el técnico escogió en el teléfono del taller.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text().withLength(min: 1, max: 60)();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
