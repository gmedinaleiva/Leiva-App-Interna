import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/vehicles_repository.dart';
import '../domain/vehicle_models.dart';

class VehicleVisitsScreen extends StatefulWidget {
  const VehicleVisitsScreen({
    required this.gateway,
    required this.reservation,
    super.key,
  });

  final VehiclesGateway gateway;
  final VehicleReservation reservation;

  @override
  State<VehicleVisitsScreen> createState() => _VehicleVisitsScreenState();
}

class _VehicleVisitsScreenState extends State<VehicleVisitsScreen> {
  VehicleVisitAgenda? _agenda;
  String? _error;
  bool _loading = true;
  int? _savingStopId;

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
      final agenda = await widget.gateway.visits(widget.reservation.id);
      if (!mounted) return;
      setState(() {
        _agenda = agenda;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(error);
        _loading = false;
      });
    }
  }

  Future<void> _report(VehicleVisitStop stop) async {
    final result = await showDialog<_VisitResultDraft>(
      context: context,
      builder: (_) => const _VisitResultDialog(),
    );
    if (result == null) return;
    setState(() => _savingStopId = stop.id);
    try {
      await widget.gateway.saveVisitResult(
        widget.reservation.id,
        stop.id,
        result: result.result,
        notes: result.notes,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultado de visita registrado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) setState(() => _savingStopId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Agenda de visitas'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.reservation.vehicle?.label ?? 'Vehiculo asignado',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.reservation.destination?.isNotEmpty == true)
                  Text(widget.reservation.destination!),
                const SizedBox(height: 14),
                if (_agenda!.stops.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay visitas asignadas para esta reserva.',
                      ),
                    ),
                  ),
                ..._agenda!.stops.map(_stopCard),
              ],
            ),
          ),
  );

  Widget _stopCard(VehicleVisitStop stop) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parada ${stop.order}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            stop.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (stop.address?.isNotEmpty == true) Text(stop.address!),
          if (stop.from != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_window(stop.from!, stop.to)),
            ),
          if (stop.identity.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_contact(stop.identity)),
          ],
          if (stop.hasMap) ...[
            const SizedBox(height: 12),
            SizedBox(height: 170, child: _map(stop)),
          ],
          const SizedBox(height: 10),
          Text('GPS: ${stop.gpsLabel ?? stop.gpsStatus ?? 'Sin evaluar'}'),
          Text('Resultado: ${stop.resultLabel ?? stop.result}'),
          if (stop.resultNotes?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Declaracion: ${stop.resultNotes}'),
            ),
          if (stop.notes?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Instrucciones: ${stop.notes}'),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingStopId == null ? () => _report(stop) : null,
            icon: _savingStopId == stop.id
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              stop.result == 'pending'
                  ? 'Registrar resultado'
                  : 'Rectificar resultado',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _map(VehicleVisitStop stop) {
    final point = LatLng(stop.latitude!, stop.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.leivahermanos.leiva_app_interna',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 42,
                height: 42,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitResultDraft {
  const _VisitResultDraft(this.result, this.notes);
  final String result;
  final String notes;
}

class _VisitResultDialog extends StatefulWidget {
  const _VisitResultDialog();
  @override
  State<_VisitResultDialog> createState() => _VisitResultDialogState();
}

class _VisitResultDialogState extends State<_VisitResultDialog> {
  String _result = 'completed';
  final _notes = TextEditingController();
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Resultado de visita'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _result,
          decoration: const InputDecoration(labelText: 'Resultado'),
          items: const [
            DropdownMenuItem(value: 'completed', child: Text('Realizada')),
            DropdownMenuItem(value: 'absent', child: Text('Ausente')),
            DropdownMenuItem(value: 'reschedule', child: Text('Reprogramar')),
            DropdownMenuItem(
              value: 'not_completed',
              child: Text('No realizada'),
            ),
          ],
          onChanged: (value) => setState(() => _result = value!),
        ),
        TextField(
          controller: _notes,
          maxLength: 2000,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Que ocurrio'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final notes = _notes.text.trim();
          if (notes.isEmpty) return;
          Navigator.pop(context, _VisitResultDraft(_result, notes));
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

String _window(DateTime from, DateTime? to) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date =
      '${two(from.day)}/${two(from.month)}/${from.year} ${two(from.hour)}:${two(from.minute)}';
  return to == null ? date : '$date - ${two(to.hour)}:${two(to.minute)}';
}

String _contact(Map<String, dynamic> identity) {
  final parts = [identity['contact'], identity['phone'], identity['email']]
      .whereType<Object>()
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList();
  return parts.isEmpty ? '' : 'Contacto: ${parts.join(' ? ')}';
}

String _errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
