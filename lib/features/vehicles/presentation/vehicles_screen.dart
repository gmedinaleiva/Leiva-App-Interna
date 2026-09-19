import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../data/vehicles_repository.dart';
import '../domain/vehicle_models.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    required this.gateway,
    required this.canCreate,
    super.key,
  });
  final VehiclesGateway gateway;
  final bool canCreate;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _loading = true;
  String? _error;
  List<VehicleReservation> _reservations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.gateway.reservations();
      if (!mounted) return;
      setState(() {
        _reservations = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateVehicleReservationScreen(gateway: widget.gateway),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _runAction(VehicleReservation row, String action) async {
    final notes = TextEditingController();
    final label = switch (action) {
      'start' => 'Iniciar viaje',
      'finish' => 'Finalizar viaje',
      _ => 'Cancelar reserva',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: action == 'finish'
                ? 'Observación de devolución'
                : 'Observación (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (action == 'finish' && notes.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresá la observación de devolución.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      notes.dispose();
      return;
    }
    try {
      await widget.gateway.action(
        row.id,
        action,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      notes.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label realizado.')));
      await _load();
    } catch (error) {
      notes.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reservas de vehículos'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: widget.canCreate
        ? FloatingActionButton.extended(
            key: const Key('createVehicleReservationButton'),
            onPressed: _create,
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Solicitar vehículo'),
          )
        : null,
    body: RefreshIndicator(onRefresh: _load, child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _MessageList(message: _error!, onRetry: _load);
    if (_reservations.isEmpty) {
      return const _MessageList(
        message: 'Todavía no tenés reservas de vehículos.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: _reservations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = _reservations[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE3E8EF)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.vehicle?.label ?? 'Vehículo',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _Status(text: row.status),
                  ],
                ),
                const SizedBox(height: 10),
                _Line(
                  Icons.route_outlined,
                  [row.purpose, row.destination]
                          .whereType<String>()
                          .where((v) => v.isNotEmpty)
                          .join(' · ')
                          .isEmpty
                      ? 'Sin detalle de viaje'
                      : [row.purpose, row.destination]
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join(' · '),
                ),
                const SizedBox(height: 7),
                _Line(
                  Icons.schedule_rounded,
                  '${_dt(row.startsAt)} — ${_time(row.endsAt)}',
                ),
                if (row.nextAction != null || row.canCancel) ...[
                  const Divider(height: 26),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (row.canCancel)
                        TextButton.icon(
                          onPressed: () => _runAction(row, 'cancel'),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar'),
                        ),
                      if (row.nextAction != null)
                        FilledButton.icon(
                          onPressed: () => _runAction(row, row.nextAction!),
                          icon: Icon(
                            row.nextAction == 'start'
                                ? Icons.play_arrow_rounded
                                : Icons.flag_outlined,
                          ),
                          label: Text(
                            row.nextAction == 'start' ? 'Iniciar' : 'Finalizar',
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class CreateVehicleReservationScreen extends StatefulWidget {
  const CreateVehicleReservationScreen({required this.gateway, super.key});
  final VehiclesGateway gateway;

  @override
  State<CreateVehicleReservationScreen> createState() =>
      _CreateVehicleReservationScreenState();
}

class _CreateVehicleReservationScreenState
    extends State<CreateVehicleReservationScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _destination = TextEditingController();
  final _occupants = TextEditingController(text: '1');
  final _notes = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  List<VehicleOption> _vehicles = const [];
  int? _vehicleId;
  bool _checking = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day, now.hour + 1);
    _to = _from.add(const Duration(hours: 2));
    _check();
  }

  @override
  void dispose() {
    _purpose.dispose();
    _destination.dispose();
    _occupants.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _vehicleId = null;
    });
    try {
      final rows = await widget.gateway.available(from: _from, to: _to);
      if (!mounted) return;
      final available = rows.where((row) => row.available).toList();
      setState(() {
        _vehicles = rows;
        _vehicleId = available.firstOrNull?.id;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _checking = false;
      });
    }
  }

  Future<void> _pick(bool start) async {
    final current = start ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _from = value;
        if (!_to.isAfter(_from)) _to = _from.add(const Duration(hours: 2));
      } else {
        _to = value;
      }
    });
    await _check();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _vehicleId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.create(
        VehicleReservationDraft(
          idempotencyKey: _idempotencyKey,
          vehicleId: _vehicleId!,
          startsAt: _from,
          endsAt: _to,
          purpose: _nullable(_purpose.text),
          destination: _nullable(_destination.text),
          occupantCount: int.tryParse(_occupants.text),
          notes: _nullable(_notes.text),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _vehicles.where((row) => row.available).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar vehículo'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Desde',
                    value: _from,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Hasta',
                    value: _to,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_checking)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<int>(
                key: ValueKey('vehicle-${_from.toIso8601String()}'),
                initialValue: _vehicleId,
                decoration: const InputDecoration(
                  labelText: 'Vehículo disponible',
                ),
                items: available
                    .map(
                      (row) => DropdownMenuItem(
                        value: row.id,
                        child: Text(
                          '${row.label}${row.passengerCapacity == null ? '' : ' · ${row.passengerCapacity} personas'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _vehicleId = value),
                validator: (value) =>
                    value == null ? 'Seleccioná un vehículo' : null,
              ),
            if (!_checking && available.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'No hay vehículos habilitados y disponibles en ese horario.',
                  style: TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purpose,
              maxLength: 220,
              decoration: const InputDecoration(labelText: 'Motivo'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresá el motivo'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _destination,
              maxLength: 220,
              decoration: const InputDecoration(labelText: 'Destino'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresá el destino'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _occupants,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de ocupantes',
              ),
              validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                  ? 'Ingresá una cantidad válida'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || _checking ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_saving ? 'Enviando...' : 'Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      _statusLabel(text),
      style: const TextStyle(
        color: Color(0xFF175CD3),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF667085)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(color: Color(0xFF475467))),
      ),
    ],
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      alignment: Alignment.centerLeft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 3),
        Text(_dt(value), maxLines: 1),
      ],
    ),
  );
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E8EF)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 42,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    ],
  );
}

String _message(Object error) {
  if (error is ApiFailure) return error.message;
  if (error is DioException) return 'No pudimos comunicarnos con el portal.';
  return 'No pudimos completar la operación.';
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
String _two(int value) => value.toString().padLeft(2, '0');
String _dt(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year} ${_time(value)}';
String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';
String _statusLabel(String value) => switch (value.toLowerCase()) {
  'pendiente' || 'pending' => 'Pendiente',
  'aprobada' || 'approved' => 'Aprobada',
  'en_uso' || 'in_use' => 'En uso',
  'finalizada' || 'finished' => 'Finalizada',
  'cancelada' || 'cancelled' => 'Cancelada',
  'rechazada' || 'rejected' => 'Rechazada',
  _ => value,
};
