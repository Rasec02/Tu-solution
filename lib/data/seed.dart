import 'package:drift/drift.dart';

import 'database/app_database.dart';

/// Carga los datos mínimos con los que el taller empieza a trabajar:
/// los tres técnicos y el almacén de repuestos.
///
/// Solo corre la primera vez: si ya hay técnicos registrados no toca nada.
Future<void> seedIfEmpty(AppDatabase db) async {
  final technicians = await db.catalogDao.allTechnicians();
  if (technicians.isNotEmpty) return;

  await db.transaction(() async {
    for (final name in const ['Yoandry Pérez', 'Dayana Mora', 'Luis Alfonso']) {
      await db.catalogDao.insertTechnician(
        TechniciansCompanion.insert(name: name),
      );
    }

    const parts = [
      ('PNT-A52', 'Pantalla Samsung A52', 85.0, 4, 2),
      ('PNT-IP11', 'Pantalla iPhone 11', 120.0, 2, 2),
      ('BAT-A52', 'Batería Samsung A52', 25.0, 6, 3),
      ('BAT-IP11', 'Batería iPhone 11', 32.0, 1, 2),
      ('CON-TC', 'Conector de carga tipo C', 9.5, 12, 4),
      ('CON-LIGHT', 'Conector de carga Lightning', 11.0, 3, 4),
      ('CAM-A52', 'Módulo de cámara Samsung A52', 40.0, 2, 2),
      ('TEC-LAP', 'Teclado para laptop HP', 45.0, 2, 1),
    ];

    for (final (code, name, price, stock, minStock) in parts) {
      final id = await db.inventoryDao.insertPart(
        SparePartsCompanion.insert(
          code: code,
          name: name,
          price: Value(price),
          stock: Value(stock),
          minStock: Value(minStock),
        ),
      );
      await db.inventoryDao.logMovement(
        StockMovementsCompanion.insert(
          partId: id,
          delta: stock,
          reason: 'Carga inicial del almacén',
        ),
      );
    }
  });
}
