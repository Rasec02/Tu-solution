import 'package:drift/drift.dart';

import '../app_database.dart';

part 'catalog_dao.g.dart';

/// Acceso a clientes, equipos y técnicos.
@DriftAccessor(tables: [Clients, Devices, Technicians])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  // ----- Clientes -----

  Stream<List<Client>> watchClients() =>
      (select(clients)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();

  Future<Client?> findClientByPhone(String phone) =>
      (select(clients)..where((c) => c.phone.equals(phone)))
          .getSingleOrNull();

  Future<Client> clientById(int id) =>
      (select(clients)..where((c) => c.id.equals(id))).getSingle();

  Future<int> insertClient(ClientsCompanion client) =>
      into(clients).insert(client);

  Future<void> updateClient(Client client) => update(clients).replace(client);

  Future<void> deleteClient(int id) =>
      (delete(clients)..where((c) => c.id.equals(id))).go();

  // ----- Equipos -----

  Stream<List<Device>> watchDevices() => (select(devices)
        ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
      .watch();

  Stream<List<Device>> watchDevicesOfClient(int clientId) =>
      (select(devices)
            ..where((d) => d.clientId.equals(clientId))
            ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
          .watch();

  Future<Device> deviceById(int id) =>
      (select(devices)..where((d) => d.id.equals(id))).getSingle();

  Future<Device?> findDeviceBySerial(String serial) =>
      (select(devices)..where((d) => d.serial.equals(serial)))
          .getSingleOrNull();

  Future<int> insertDevice(DevicesCompanion device) =>
      into(devices).insert(device);

  Future<void> updateDevice(Device device) => update(devices).replace(device);

  /// Equipos con el nombre de su dueño, para los selectores de la UI.
  Stream<List<(Device, Client)>> watchDevicesWithClient() {
    final query = select(devices).join([
      innerJoin(clients, clients.id.equalsExp(devices.clientId)),
    ])
      ..orderBy([OrderingTerm.desc(devices.createdAt)]);

    return query.watch().map((rows) => rows
        .map((row) => (row.readTable(devices), row.readTable(clients)))
        .toList());
  }

  // ----- Técnicos -----

  Stream<List<Technician>> watchTechnicians() => (select(technicians)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  Future<List<Technician>> allTechnicians() => select(technicians).get();

  Future<Technician> technicianById(int id) =>
      (select(technicians)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertTechnician(TechniciansCompanion technician) =>
      into(technicians).insert(technician);

  Future<void> updateTechnician(Technician technician) =>
      update(technicians).replace(technician);
}
