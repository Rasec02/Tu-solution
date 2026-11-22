// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClientsTable get clients => attachedDatabase.clients;
  $DevicesTable get devices => attachedDatabase.devices;
  $TechniciansTable get technicians => attachedDatabase.technicians;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db.attachedDatabase, _db.clients);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db.attachedDatabase, _db.devices);
  $$TechniciansTableTableManager get technicians =>
      $$TechniciansTableTableManager(_db.attachedDatabase, _db.technicians);
}
