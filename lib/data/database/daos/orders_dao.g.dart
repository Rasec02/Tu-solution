// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_dao.dart';

// ignore_for_file: type=lint
mixin _$OrdersDaoMixin on DatabaseAccessor<AppDatabase> {
  $RepairOrdersTable get repairOrders => attachedDatabase.repairOrders;
  $OrderJobsTable get orderJobs => attachedDatabase.orderJobs;
  $OrderPartsTable get orderParts => attachedDatabase.orderParts;
  $DevicesTable get devices => attachedDatabase.devices;
  $ClientsTable get clients => attachedDatabase.clients;
  $TechniciansTable get technicians => attachedDatabase.technicians;
  $SparePartsTable get spareParts => attachedDatabase.spareParts;
  OrdersDaoManager get managers => OrdersDaoManager(this);
}

class OrdersDaoManager {
  final _$OrdersDaoMixin _db;
  OrdersDaoManager(this._db);
  $$RepairOrdersTableTableManager get repairOrders =>
      $$RepairOrdersTableTableManager(_db.attachedDatabase, _db.repairOrders);
  $$OrderJobsTableTableManager get orderJobs =>
      $$OrderJobsTableTableManager(_db.attachedDatabase, _db.orderJobs);
  $$OrderPartsTableTableManager get orderParts =>
      $$OrderPartsTableTableManager(_db.attachedDatabase, _db.orderParts);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db.attachedDatabase, _db.devices);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db.attachedDatabase, _db.clients);
  $$TechniciansTableTableManager get technicians =>
      $$TechniciansTableTableManager(_db.attachedDatabase, _db.technicians);
  $$SparePartsTableTableManager get spareParts =>
      $$SparePartsTableTableManager(_db.attachedDatabase, _db.spareParts);
}
