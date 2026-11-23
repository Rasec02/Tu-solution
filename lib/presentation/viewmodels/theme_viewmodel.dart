import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/theme_preference.dart';
import '../providers.dart';

/// Preferencia de tema guardada en la base.
///
/// Mientras se lee de SQLite el valor aún no se conoce, así que se arranca
/// siguiendo al sistema para no provocar un parpadeo de claro a oscuro.
final themePreferenceProvider = StreamProvider<ThemePreference>(
  (ref) => ref.watch(repositoryProvider).watchThemePreference(),
);

/// Lo que consume `MaterialApp`.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(themePreferenceProvider).valueOrNull ??
      ThemePreference.sistema;
  return switch (preference) {
    ThemePreference.claro => ThemeMode.light,
    ThemePreference.oscuro => ThemeMode.dark,
    ThemePreference.sistema => ThemeMode.system,
  };
});

/// ViewModel del selector de tema.
class ThemeViewModel extends Notifier<void> {
  @override
  void build() {}

  Future<void> select(ThemePreference preference) =>
      ref.read(repositoryProvider).setThemePreference(preference);
}

final themeViewModelProvider =
    NotifierProvider<ThemeViewModel, void>(ThemeViewModel.new);
