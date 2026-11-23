import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/theme_preference.dart';
import '../viewmodels/theme_viewmodel.dart';

/// Selector de tema: claro, oscuro o el del sistema.
///
/// La elección se guarda en la base, así que sigue puesta la próxima vez que
/// se abra la app en el teléfono del taller.
class ThemeMenuButton extends ConsumerWidget {
  const ThemeMenuButton({super.key});

  static IconData iconFor(ThemePreference preference) => switch (preference) {
        ThemePreference.claro => Icons.light_mode_outlined,
        ThemePreference.oscuro => Icons.dark_mode_outlined,
        ThemePreference.sistema => Icons.brightness_auto_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.sistema;

    return PopupMenuButton<ThemePreference>(
      tooltip: 'Tema',
      icon: Icon(iconFor(current)),
      initialValue: current,
      onSelected: (preference) =>
          ref.read(themeViewModelProvider.notifier).select(preference),
      itemBuilder: (_) => [
        for (final preference in ThemePreference.values)
          PopupMenuItem(
            value: preference,
            child: Row(
              children: [
                Icon(iconFor(preference), size: 20),
                const SizedBox(width: 12),
                Text(preference.label),
              ],
            ),
          ),
      ],
    );
  }
}
