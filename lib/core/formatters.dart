import 'package:intl/intl.dart';

import '../domain/order_status.dart';

/// Formatos compartidos por toda la app, en español.
final _money = NumberFormat.currency(locale: 'es', symbol: r'$', decimalDigits: 2);
final _date = DateFormat('dd/MM/yyyy', 'es');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'es');

String money(num value) => _money.format(value);

String shortDate(DateTime value) => _date.format(value);

String longDate(DateTime value) => _dateTime.format(value);

/// "hace 3 días", para que el técnico vea de un vistazo qué lleva esperando.
String relativeDays(DateTime value) {
  final days = DateTime.now().difference(value).inDays;
  return switch (days) {
    0 => 'hoy',
    1 => 'ayer',
    _ => 'hace $days días',
  };
}

/// Tipos de equipo que recibe el taller.
const deviceKinds = <String>['Celular', 'Tablet', 'Laptop', 'Otro'];

extension OrderStatusPlural on OrderStatus {
  String get pluralLabel => switch (this) {
        OrderStatus.recibida => 'Recibidas',
        OrderStatus.enReparacion => 'En reparación',
        OrderStatus.lista => 'Listas',
        OrderStatus.entregada => 'Entregadas',
        OrderStatus.cancelada => 'Canceladas',
      };
}
