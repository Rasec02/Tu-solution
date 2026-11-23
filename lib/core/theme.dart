import 'package:flutter/material.dart';

/// Colores con significado propio del taller (estados de orden y avisos).
///
/// Viven en el tema, y no fijos en los widgets, porque los tonos oscuros que
/// se leen bien sobre fondo claro resultan ilegibles sobre fondo oscuro.
@immutable
class WorkshopColors extends ThemeExtension<WorkshopColors> {
  const WorkshopColors({
    required this.recibida,
    required this.enReparacion,
    required this.lista,
    required this.cancelada,
    required this.aviso,
    required this.exito,
  });

  final Color recibida;
  final Color enReparacion;
  final Color lista;
  final Color cancelada;

  /// Repuesto por agotarse.
  final Color aviso;

  /// Todo en orden.
  final Color exito;

  static const light = WorkshopColors(
    recibida: Color(0xFF8E6C00),
    enReparacion: Color(0xFF0B5FA5),
    lista: Color(0xFF1B7A3D),
    cancelada: Color(0xFFA32020),
    aviso: Color(0xFF8E6C00),
    exito: Color(0xFF1B7A3D),
  );

  /// Mismos significados, subidos de luminosidad para contrastar en oscuro.
  static const dark = WorkshopColors(
    recibida: Color(0xFFE8C063),
    enReparacion: Color(0xFF7FB8EE),
    lista: Color(0xFF6FCF97),
    cancelada: Color(0xFFEF9A9A),
    aviso: Color(0xFFE8C063),
    exito: Color(0xFF6FCF97),
  );

  @override
  WorkshopColors copyWith({
    Color? recibida,
    Color? enReparacion,
    Color? lista,
    Color? cancelada,
    Color? aviso,
    Color? exito,
  }) {
    return WorkshopColors(
      recibida: recibida ?? this.recibida,
      enReparacion: enReparacion ?? this.enReparacion,
      lista: lista ?? this.lista,
      cancelada: cancelada ?? this.cancelada,
      aviso: aviso ?? this.aviso,
      exito: exito ?? this.exito,
    );
  }

  @override
  WorkshopColors lerp(ThemeExtension<WorkshopColors>? other, double t) {
    if (other is! WorkshopColors) return this;
    return WorkshopColors(
      recibida: Color.lerp(recibida, other.recibida, t)!,
      enReparacion: Color.lerp(enReparacion, other.enReparacion, t)!,
      lista: Color.lerp(lista, other.lista, t)!,
      cancelada: Color.lerp(cancelada, other.cancelada, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      exito: Color.lerp(exito, other.exito, t)!,
    );
  }
}

/// Atajo para leer los colores del taller desde cualquier widget.
extension WorkshopColorsOf on BuildContext {
  WorkshopColors get workshop =>
      Theme.of(this).extension<WorkshopColors>() ?? WorkshopColors.light;
}

const _seed = Color(0xFF1565C0);

ThemeData buildLightTheme() => _build(Brightness.light, WorkshopColors.light);

ThemeData buildDarkTheme() => _build(Brightness.dark, WorkshopColors.dark);

/// Un solo constructor para los dos modos: así no se desincronizan.
ThemeData _build(Brightness brightness, WorkshopColors workshop) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [workshop],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
