import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../providers.dart';
import '../viewmodels/command_state.dart';
import '../viewmodels/intake_viewmodel.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Recepción de un equipo: cliente, equipo y falla reportada en una pantalla.
///
/// El cliente y el equipo pueden ser nuevos o ya estar registrados, porque un
/// mismo equipo vuelve muchas veces y un dueño puede traer varios.
class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _fault = TextEditingController();

  Client? _existingClient;
  Device? _existingDevice;
  String _kind = deviceKinds.first;
  int? _technicianId;
  bool _assignToMe = true;

  @override
  void initState() {
    super.initState();
    _technicianId = ref.read(activeTechnicianProvider);
  }

  @override
  void dispose() {
    _clientName.dispose();
    _clientPhone.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _fault.dispose();
    super.dispose();
  }

  void _selectClient(Client? client) {
    setState(() {
      _existingClient = client;
      _existingDevice = null;
      if (client != null) {
        _clientName.text = client.name;
        _clientPhone.text = client.phone;
      } else {
        _clientName.clear();
        _clientPhone.clear();
      }
    });
  }

  void _selectDevice(Device? device) {
    setState(() {
      _existingDevice = device;
      if (device != null) {
        _kind = deviceKinds.contains(device.kind) ? device.kind : deviceKinds.last;
        _brand.text = device.brand;
        _model.text = device.model;
        _serial.text = device.serial;
      } else {
        _brand.clear();
        _model.clear();
        _serial.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(intakeViewModelProvider.notifier).submit(
          clientId: _existingClient?.id,
          clientName: _clientName.text,
          clientPhone: _clientPhone.text,
          deviceId: _existingDevice?.id,
          kind: _kind,
          brand: _brand.text,
          model: _model.text,
          serial: _serial.text,
          reportedFault: _fault.text,
          technicianId: _assignToMe ? _technicianId : null,
        );

    if (result == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: result.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(intakeViewModelProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final technicians =
        ref.watch(techniciansProvider).valueOrNull ?? const <Technician>[];

    ref.listen<CommandState>(intakeViewModelProvider, (_, next) {
      if (next.error != null) {
        showMessage(context, next.error!, error: true);
        ref.read(intakeViewModelProvider.notifier).consumeFeedback();
      }
    });

    final devicesOfClient = _existingClient == null
        ? const <Device>[]
        : ref.watch(devicesOfClientProvider(_existingClient!.id)).valueOrNull ??
            const <Device>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Recibir equipo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const SectionTitle('Dueño del equipo'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<Client?>(
                      initialValue: _existingClient,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        helperText: 'Escoge uno registrado o deja «Nuevo».',
                      ),
                      items: [
                        const DropdownMenuItem<Client?>(
                          child: Text('Nuevo cliente'),
                        ),
                        for (final client in clients)
                          DropdownMenuItem<Client?>(
                            value: client,
                            child: Text(
                              '${client.name} · ${client.phone}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _selectClient,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientName,
                      readOnly: _existingClient != null,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El nombre es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientPhone,
                      readOnly: _existingClient != null,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El teléfono es obligatorio'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Equipo'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_existingClient != null) ...[
                      DropdownButtonFormField<Device?>(
                        initialValue: _existingDevice,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Equipo ya registrado',
                          helperText: 'Si vuelve un equipo, escógelo aquí.',
                        ),
                        items: [
                          const DropdownMenuItem<Device?>(
                            child: Text('Equipo nuevo'),
                          ),
                          for (final device in devicesOfClient)
                            DropdownMenuItem<Device?>(
                              value: device,
                              child: Text(
                                '${device.brand} ${device.model} · '
                                '${device.serial}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _selectDevice,
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final kind in deviceKinds)
                          DropdownMenuItem(value: kind, child: Text(kind)),
                      ],
                      onChanged: _existingDevice != null
                          ? null
                          : (value) => setState(() => _kind = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _brand,
                      readOnly: _existingDevice != null,
                      decoration: const InputDecoration(labelText: 'Marca'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'La marca es obligatoria'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _model,
                      readOnly: _existingDevice != null,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El modelo es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _serial,
                      readOnly: _existingDevice != null,
                      decoration: const InputDecoration(
                        labelText: 'Número de serie',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El número de serie es obligatorio'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Falla reportada'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _fault,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Qué dice el cliente que le pasa al equipo',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Anote la falla que reporta el cliente'
                      : null,
                ),
              ),
            ),
            const SectionTitle('Responsable'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _assignToMe,
                    onChanged: (value) => setState(() => _assignToMe = value),
                    title: const Text('Tomar la orden ahora'),
                    subtitle: const Text(
                      'Así los demás técnicos ven que ya tiene responsable.',
                    ),
                  ),
                  if (_assignToMe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DropdownButtonFormField<int>(
                        initialValue: _technicianId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Técnico'),
                        items: [
                          for (final technician
                              in technicians.where((t) => t.active))
                            DropdownMenuItem(
                              value: technician.id,
                              child: Text(technician.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _technicianId = value),
                        validator: (v) =>
                            v == null ? 'Escoja el técnico responsable' : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: state.busy ? null : _submit,
              icon: state.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Registrar orden'),
            ),
          ],
        ),
      ),
    );
  }
}
