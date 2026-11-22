import '../data/database/app_database.dart';
import 'order_status.dart';

/// Orden con todo lo que la UI necesita para mostrarla en una lista.
class OrderSummary {
  const OrderSummary({
    required this.order,
    required this.device,
    required this.client,
    required this.technician,
    required this.laborTotal,
    required this.partsTotal,
  });

  final RepairOrder order;
  final Device device;
  final Client client;
  final Technician? technician;
  final double laborTotal;
  final double partsTotal;

  OrderStatus get status => order.status;
  double get total => laborTotal + partsTotal;
  bool get isTaken => technician != null;

  String get deviceLabel => '${device.brand} ${device.model}';
}

/// Detalle completo de una orden: cabecera + trabajos + repuestos.
class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.jobs,
    required this.parts,
  });

  final OrderSummary summary;
  final List<OrderJob> jobs;
  final List<OrderPartLine> parts;

  RepairOrder get order => summary.order;
  double get laborTotal =>
      jobs.fold<double>(0, (acc, j) => acc + j.laborCost);
  double get partsTotal =>
      parts.fold<double>(0, (acc, p) => acc + p.lineTotal);
  double get total => laborTotal + partsTotal;
}

/// Línea de repuesto usada en una orden, junto al repuesto del inventario.
class OrderPartLine {
  const OrderPartLine({required this.line, required this.part});

  final OrderPart line;
  final SparePart part;

  double get lineTotal => line.quantity * line.unitPrice;
}

/// Cuánto trabajo tiene asignado cada técnico.
class TechnicianWorkload {
  const TechnicianWorkload({
    required this.technician,
    required this.openOrders,
    required this.inRepair,
    required this.ready,
  });

  final Technician technician;
  final int openOrders;
  final int inRepair;
  final int ready;
}

/// Una entrada del historial de reparaciones de un equipo o de un cliente.
class HistoryEntry {
  const HistoryEntry({
    required this.order,
    required this.device,
    required this.technicianName,
    required this.jobs,
    required this.parts,
    required this.total,
  });

  final RepairOrder order;
  final Device device;
  final String? technicianName;
  final List<String> jobs;
  final List<String> parts;
  final double total;
}

/// Conteos para el tablero inicial.
class WorkshopStats {
  const WorkshopStats({
    required this.byStatus,
    required this.untakenOpenOrders,
    required this.lowStockCount,
  });

  final Map<OrderStatus, int> byStatus;
  final int untakenOpenOrders;
  final int lowStockCount;

  int get openOrders => OrderStatus.openStates
      .fold<int>(0, (acc, s) => acc + (byStatus[s] ?? 0));

  int count(OrderStatus status) => byStatus[status] ?? 0;
}
