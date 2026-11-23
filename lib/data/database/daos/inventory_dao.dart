import 'package:drift/drift.dart';

import '../app_database.dart';

part 'inventory_dao.g.dart';

/// Acceso al almacén de repuestos y a su bitácora de movimientos.
@DriftAccessor(tables: [SpareParts, StockMovements])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Stream<List<SparePart>> watchParts() => (select(spareParts)
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .watch();

  /// Repuestos por agotarse: existencias en o por debajo del mínimo.
  Stream<List<SparePart>> watchLowStock() => (select(spareParts)
        ..where((p) => p.stock.isSmallerOrEqual(p.minStock))
        ..orderBy([(p) => OrderingTerm.asc(p.stock)]))
      .watch();

  Stream<int> watchLowStockCount() {
    final count = spareParts.id.count();
    final query = selectOnly(spareParts)
      ..addColumns([count])
      ..where(spareParts.stock.isSmallerOrEqual(spareParts.minStock));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<SparePart> partById(int id) =>
      (select(spareParts)..where((p) => p.id.equals(id))).getSingle();

  Future<List<SparePart>> allParts() => select(spareParts).get();

  Future<int> insertPart(SparePartsCompanion part) =>
      into(spareParts).insert(part);

  Future<void> updatePart(SparePart part) => update(spareParts).replace(part);

  Future<int> deletePart(int id) =>
      (delete(spareParts)..where((p) => p.id.equals(id))).go();

  Future<int> addStock(int partId, int delta) =>
      customUpdate(
        'UPDATE spare_parts SET stock = stock + ? WHERE id = ?',
        variables: [Variable.withInt(delta), Variable.withInt(partId)],
        updates: {spareParts},
      );

  Future<int> logMovement(StockMovementsCompanion movement) =>
      into(stockMovements).insert(movement);

  Stream<List<StockMovement>> watchMovements(int partId) =>
      (select(stockMovements)
            ..where((m) => m.partId.equals(partId))
            // Dos movimientos del mismo repuesto pueden caer en el mismo
            // instante (alta y consumo seguidos): el id desempata para que la
            // bitácora siempre muestre el más reciente primero.
            ..orderBy([
              (m) => OrderingTerm.desc(m.createdAt),
              (m) => OrderingTerm.desc(m.id),
            ])
            ..limit(50))
          .watch();
}
