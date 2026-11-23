/// Modo de tema que el técnico escoge en el teléfono del taller.
///
/// Es un tipo del dominio y no el `ThemeMode` de Flutter para que la capa de
/// datos no dependa de la interfaz; la conversión ocurre en `presentation`.
enum ThemePreference {
  sistema,
  claro,
  oscuro;

  String get label => switch (this) {
        ThemePreference.sistema => 'Según el sistema',
        ThemePreference.claro => 'Claro',
        ThemePreference.oscuro => 'Oscuro',
      };

  /// Valor guardado en la base. Ante algo desconocido o ausente se sigue al
  /// sistema, que es el comportamiento menos sorprendente.
  static ThemePreference parse(String? raw) => switch (raw) {
        'claro' => ThemePreference.claro,
        'oscuro' => ThemePreference.oscuro,
        _ => ThemePreference.sistema,
      };
}
