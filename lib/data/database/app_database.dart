import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// El código generado (part) usa OrderStatus en la columna `status`, y un part
// file solo ve los imports de su librería padre.
import '../../domain/order_status.dart';
import 'daos/catalog_dao.dart';
import 'daos/inventory_dao.dart';
import 'daos/orders_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// Base de datos SQLite local del taller.
///
/// Toda la información vive en el teléfono: la app funciona sin conexión y
/// conserva los datos aunque se cierre.
@DriftDatabase(
  tables: [
    Clients,
    Devices,
    Technicians,
    RepairOrders,
    OrderJobs,
    SpareParts,
    OrderParts,
    StockMovements,
    AppSettings,
  ],
  daos: [CatalogDao, OrdersDao, InventoryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor usado por las pruebas (base en memoria).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 añadió los ajustes de la app (modo de tema). Se crea sin tocar
          // los datos del taller ya registrados en el teléfono.
          if (from < 2) {
            await m.createTable(appSettings);
          }
        },
        beforeOpen: (details) async {
          // Las claves foráneas no vienen activadas por defecto en SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Lee un ajuste suelto. Devuelve null si nunca se guardó.
  Future<String?> readSetting(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Observa un ajuste para que la UI reaccione sin recargar nada.
  Stream<String?> watchSetting(String key) =>
      (select(appSettings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> writeSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'tu_solution.sqlite'));

    // Evita problemas de locking con el directorio temporal en Android.
    final cache = await getTemporaryDirectory();
    sqlite3.tempDirectory = cache.path;

    return NativeDatabase.createInBackground(file);
  });
}
