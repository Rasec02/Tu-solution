import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

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
  ],
  daos: [CatalogDao, OrdersDao, InventoryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor usado por las pruebas (base en memoria).
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Las claves foráneas no vienen activadas por defecto en SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
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
