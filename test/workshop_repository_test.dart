import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_solution/data/database/app_database.dart';
import 'package:tu_solution/data/repositories/workshop_repository.dart';
import 'package:tu_solution/domain/order_status.dart';
import 'package:tu_solution/domain/theme_preference.dart';

/// Pruebas de las reglas del taller sobre una base SQLite en memoria.
void main() {
  late AppDatabase db;
  late WorkshopRepository repo;
  late int technicianA;
  late int technicianB;
  late int deviceId;
  late int clientId;
  late int screenId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WorkshopRepository(db);

    technicianA = await repo.saveTechnician(name: 'Yoandry Pérez');
    technicianB = await repo.saveTechnician(name: 'Dayana Mora');

    clientId = await repo.saveClient(name: 'Marta Díaz', phone: '53123456');
    deviceId = await repo.saveDevice(
      clientId: clientId,
      kind: 'Celular',
      brand: 'Samsung',
      model: 'A52',
      serial: 'SN-0001',
    );
    screenId = await repo.savePart(
      code: 'PNT-A52',
      name: 'Pantalla Samsung A52',
      price: 85,
      stock: 3,
      minStock: 2,
    );
  });

  tearDown(() => db.close());

  test('una orden nueva nace recibida y sin tomar', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'No enciende',
    );

    final detail = await repo.watchOrderDetail(id).first;
    expect(detail, isNotNull);
    expect(detail!.order.status, OrderStatus.recibida);
    expect(detail.summary.isTaken, isFalse);
  });

  test('no se abren dos órdenes para el mismo equipo a la vez', () async {
    await repo.createOrder(deviceId: deviceId, reportedFault: 'No enciende');

    expect(
      () => repo.createOrder(deviceId: deviceId, reportedFault: 'Otra falla'),
      throwsA(isA<WorkshopException>()),
    );
  });

  test('un técnico no puede tomar la orden que ya tomó otro', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );

    await repo.takeOrder(id, technicianA);

    expect(
      () => repo.takeOrder(id, technicianB),
      throwsA(isA<WorkshopException>()),
    );

    // Si la libera, otro técnico sí puede tomarla.
    await repo.releaseOrder(id);
    await repo.takeOrder(id, technicianB);

    final detail = await repo.watchOrderDetail(id).first;
    expect(detail!.summary.technician!.id, technicianB);
  });

  test('el flujo de estados no admite saltos', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );

    // Recibida -> lista no es una transición válida.
    expect(
      () => repo.changeStatus(id, OrderStatus.lista),
      throwsA(isA<WorkshopException>()),
    );

    // Y nadie puede ponerla en reparación sin haberla tomado.
    expect(
      () => repo.changeStatus(id, OrderStatus.enReparacion),
      throwsA(isA<WorkshopException>()),
    );

    await repo.takeOrder(id, technicianA);
    await repo.changeStatus(id, OrderStatus.enReparacion);
    await repo.changeStatus(id, OrderStatus.lista);
    await repo.changeStatus(id, OrderStatus.entregada);

    final detail = await repo.watchOrderDetail(id).first;
    expect(detail!.order.status, OrderStatus.entregada);
    expect(detail.order.closedAt, isNotNull);
  });

  test('usar un repuesto descuenta el almacén y devolverlo lo repone',
      () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );
    await repo.takeOrder(id, technicianA);

    await repo.addPartToOrder(orderId: id, partId: screenId, quantity: 2);

    var parts = await repo.watchParts().first;
    expect(parts.single.stock, 1);

    final detail = await repo.watchOrderDetail(id).first;
    await repo.removePartFromOrder(detail!.parts.single.line.id);

    parts = await repo.watchParts().first;
    expect(parts.single.stock, 3);
  });

  test('no se puede usar más repuestos de los que hay', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );

    expect(
      () => repo.addPartToOrder(orderId: id, partId: screenId, quantity: 10),
      throwsA(isA<WorkshopException>()),
    );

    final parts = await repo.watchParts().first;
    expect(parts.single.stock, 3, reason: 'el stock no debe moverse');
  });

  test('el total de la orden es mano de obra más repuestos', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );
    await repo.takeOrder(id, technicianA);

    await repo.addJob(
      orderId: id,
      description: 'Cambio de pantalla',
      laborCost: 15,
    );
    await repo.addPartToOrder(orderId: id, partId: screenId, quantity: 1);

    final detail = await repo.watchOrderDetail(id).first;
    expect(detail!.laborTotal, 15);
    expect(detail.partsTotal, 85);
    expect(detail.total, 100);
  });

  test('avisa qué repuestos están por agotarse', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );
    await repo.takeOrder(id, technicianA);

    // Con 3 en stock y mínimo 2 todavía no hay aviso.
    expect(await repo.watchLowStock().first, isEmpty);

    await repo.addPartToOrder(orderId: id, partId: screenId, quantity: 1);

    final low = await repo.watchLowStock().first;
    expect(low.single.code, 'PNT-A52');
  });

  test('la carga de trabajo cuenta solo las órdenes abiertas', () async {
    final otherDevice = await repo.saveDevice(
      clientId: clientId,
      kind: 'Laptop',
      brand: 'HP',
      model: '240 G8',
      serial: 'SN-0002',
    );

    final first = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );
    final second = await repo.createOrder(
      deviceId: otherDevice,
      reportedFault: 'No carga',
    );

    await repo.takeOrder(first, technicianA);
    await repo.takeOrder(second, technicianA);
    await repo.changeStatus(second, OrderStatus.enReparacion);

    var load = await repo.watchTechnicianWorkload().first;
    var mine = load.firstWhere((w) => w.technician.id == technicianA);
    expect(mine.openOrders, 2);
    expect(mine.inRepair, 1);

    await repo.changeStatus(first, OrderStatus.cancelada);

    load = await repo.watchTechnicianWorkload().first;
    mine = load.firstWhere((w) => w.technician.id == technicianA);
    expect(mine.openOrders, 1);
  });

  test('el historial del equipo guarda trabajos y piezas', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );
    await repo.takeOrder(id, technicianA);
    await repo.addJob(
      orderId: id,
      description: 'Cambio de pantalla',
      laborCost: 15,
    );
    await repo.addPartToOrder(orderId: id, partId: screenId, quantity: 1);
    await repo.changeStatus(id, OrderStatus.enReparacion);
    await repo.changeStatus(id, OrderStatus.lista);
    await repo.changeStatus(id, OrderStatus.entregada);

    final history = await repo.history(deviceId: deviceId);
    expect(history, hasLength(1));
    expect(history.single.jobs, contains('Cambio de pantalla'));
    expect(history.single.parts.single, 'Pantalla Samsung A52 x1');
    expect(history.single.total, 100);

    // El mismo equipo puede volver al taller.
    final again = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'No carga',
    );
    expect(again, isNot(id));
    expect(await repo.history(clientId: clientId), hasLength(2));
  });

  test('no se repite el número de serie de un equipo', () async {
    expect(
      () => repo.saveDevice(
        clientId: clientId,
        kind: 'Celular',
        brand: 'Samsung',
        model: 'A52',
        serial: 'SN-0001',
      ),
      throwsA(isA<WorkshopException>()),
    );
  });

  test('reponer almacén suma existencias y deja rastro', () async {
    await repo.restock(screenId, 5);

    final parts = await repo.watchParts().first;
    expect(parts.single.stock, 8);

    final movements = await repo.watchMovements(screenId).first;
    expect(movements.first.delta, 5);
    expect(movements.first.reason, contains('Reposición'));
  });

  test('el tablero resume el estado del taller', () async {
    final id = await repo.createOrder(
      deviceId: deviceId,
      reportedFault: 'Pantalla rota',
    );

    var stats = await repo.watchStats().first;
    expect(stats.openOrders, 1);
    expect(stats.untakenOpenOrders, 1);

    await repo.takeOrder(id, technicianA);
    stats = await repo.watchStats().first;
    expect(stats.untakenOpenOrders, 0);
    expect(stats.count(OrderStatus.recibida), 1);
  });

  test('el modo de tema arranca en sistema y se guarda al cambiarlo', () async {
    expect(await repo.themePreference(), ThemePreference.sistema);

    await repo.setThemePreference(ThemePreference.oscuro);
    expect(await repo.themePreference(), ThemePreference.oscuro);

    // Se sobrescribe, no se acumula una fila por cada cambio.
    await repo.setThemePreference(ThemePreference.claro);
    expect(await repo.themePreference(), ThemePreference.claro);
    expect(await repo.watchThemePreference().first, ThemePreference.claro);
  });
}
