import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'history_list.dart';

/// Historial completo de un equipo: cada vez que entró al taller, qué se le
/// hizo y qué piezas se le cambiaron.
class DeviceHistoryScreen extends ConsumerWidget {
  const DeviceHistoryScreen({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider(deviceId));
    final history = ref.watch(deviceHistoryProvider(deviceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial del equipo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          device.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (Device d) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.brand} ${d.model}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DetailRow('Tipo', d.kind),
                    DetailRow('Serie', d.serial),
                  ],
                ),
              ),
            ),
          ),
          const SectionTitle('Visitas al taller'),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
            data: (entries) => HistoryList(entries: entries),
          ),
        ],
      ),
    );
  }
}
