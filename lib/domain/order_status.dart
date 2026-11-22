/// Estados por los que pasa una orden de reparación.
///
/// El flujo normal es: recibida -> enReparacion -> lista -> entregada.
/// Desde cualquier estado no terminal la orden puede quedar cancelada.
enum OrderStatus {
  recibida,
  enReparacion,
  lista,
  entregada,
  cancelada;

  String get label => switch (this) {
        OrderStatus.recibida => 'Recibida',
        OrderStatus.enReparacion => 'En reparación',
        OrderStatus.lista => 'Lista',
        OrderStatus.entregada => 'Entregada',
        OrderStatus.cancelada => 'Cancelada',
      };

  /// Una orden abierta es la que todavía ocupa al taller.
  bool get isOpen => this == OrderStatus.recibida ||
      this == OrderStatus.enReparacion ||
      this == OrderStatus.lista;

  bool get isClosed => !isOpen;

  /// Estados a los que se puede mover la orden desde el estado actual.
  List<OrderStatus> get nextStates => switch (this) {
        OrderStatus.recibida => const [
            OrderStatus.enReparacion,
            OrderStatus.cancelada,
          ],
        OrderStatus.enReparacion => const [
            OrderStatus.lista,
            OrderStatus.cancelada,
          ],
        OrderStatus.lista => const [
            OrderStatus.entregada,
            OrderStatus.enReparacion,
          ],
        OrderStatus.entregada => const [],
        OrderStatus.cancelada => const [],
      };

  static const openStates = [
    OrderStatus.recibida,
    OrderStatus.enReparacion,
    OrderStatus.lista,
  ];
}
