import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../data/parking_repository.dart';
import '../domain/parking_models.dart';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({
    required this.gateway,
    required this.canCreate,
    this.focusRequestId,
    super.key,
  });
  final ParkingGateway gateway;
  final bool canCreate;
  final int? focusRequestId;

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  bool _loading = true;
  String? _error;
  List<ParkingRequest> _requests = const [];
  List<ParkingBranch> _branches = const [];
  bool _showHistory = false;

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
      final result = await Future.wait<dynamic>([
        widget.gateway.requests(),
        widget.gateway.branches(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = List<ParkingRequest>.of(result[0] as List<ParkingRequest>);
        if (widget.focusRequestId != null) {
          _requests.sort((a, b) {
            if (a.id == widget.focusRequestId) return -1;
            if (b.id == widget.focusRequestId) return 1;
            return 0;
          });
        }
        _branches = List<ParkingBranch>.of(result[1] as List<ParkingBranch>);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _parkingMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_branches.isEmpty) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateParkingRequestScreen(
          gateway: widget.gateway,
          branches: _branches,
          requests: _requests,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _cancel(ParkingRequest row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: Text(
          '¿Querés cancelar la solicitud para ${row.bay?.name ?? 'la dársena'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.gateway.cancel(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud cancelada.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_parkingMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Estacionamiento'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: widget.canCreate && _branches.isNotEmpty
        ? FloatingActionButton.extended(
            key: const Key('createParkingRequestButton'),
            onPressed: _create,
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Solicitar dársena'),
          )
        : null,
    body: RefreshIndicator(onRefresh: _load, child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ParkingMessage(message: _error!, onRetry: _load);
    }
    final active = _requests.where(_isActiveParkingRequest).toList();
    final history = _requests
        .where((row) => !_isActiveParkingRequest(row))
        .toList();
    final visible = _showHistory ? history : active;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: visible.isEmpty ? 4 : visible.length + 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _ParkingHero();
        }
        if (index == 1) {
          return FilledButton.icon(
            key: const Key('openParkingAvailabilityButton'),
            onPressed: widget.canCreate && _branches.isNotEmpty
                ? _create
                : null,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Consultar disponibilidad y plano'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );
        }
        if (index == 2) {
          return SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Activas (${active.length})'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.history_rounded),
                label: Text('Historial (${history.length})'),
              ),
            ],
            selected: {_showHistory},
            onSelectionChanged: (value) =>
                setState(() => _showHistory = value.first),
          );
        }
        if (visible.isEmpty) {
          return _ParkingEmpty(
            message: _showHistory
                ? 'Todavía no hay solicitudes finalizadas o canceladas.'
                : 'Todavía no tenés solicitudes de estacionamiento.',
          );
        }
        final row = visible[index - 3];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: row.id == widget.focusRequestId
                  ? const Color(0xFF059669)
                  : const Color(0xFFE3E8EF),
              width: row.id == widget.focusRequestId ? 2 : 1,
            ),
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
                        row.bay?.name ?? 'Dársena',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _ParkingStatus(row.status),
                  ],
                ),
                const SizedBox(height: 10),
                _ParkingLine(
                  Icons.directions_car_outlined,
                  [row.plate, row.vehicleType].whereType<String>().join(' · '),
                ),
                const SizedBox(height: 7),
                _ParkingLine(
                  Icons.schedule_rounded,
                  '${_parkingDateTime(row.startsAt)} — ${_parkingTime(row.endsAt)}',
                ),
                if (row.purpose?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  _ParkingLine(Icons.notes_outlined, row.purpose!),
                ],
                if (row.meetingRoomReservationId != null) ...[
                  const SizedBox(height: 7),
                  _ParkingLine(
                    Icons.meeting_room_outlined,
                    'Reserva de sala #${row.meetingRoomReservationId}',
                  ),
                ],
                if (row.geosatReservationId != null) ...[
                  const SizedBox(height: 7),
                  _ParkingLine(
                    Icons.route_outlined,
                    'Reserva de vehiculo #${row.geosatReservationId}',
                  ),
                ],
                if (row.resolutionNotes?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  _ParkingLine(Icons.fact_check_outlined, row.resolutionNotes!),
                ],
                if (row.canCancel) ...[
                  const Divider(height: 26),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _cancel(row),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar'),
                    ),
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

class CreateParkingRequestScreen extends StatefulWidget {
  const CreateParkingRequestScreen({
    required this.gateway,
    required this.branches,
    this.requests = const [],
    super.key,
  });
  final ParkingGateway gateway;
  final List<ParkingBranch> branches;
  final List<ParkingRequest> requests;

  @override
  State<CreateParkingRequestScreen> createState() =>
      _CreateParkingRequestScreenState();
}

class _CreateParkingRequestScreenState
    extends State<CreateParkingRequestScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  late int _branchId;
  late DateTime _from;
  late DateTime _to;
  String _vehicleType = 'auto';
  List<ParkingBay> _bays = const [];
  int? _bayId;
  bool _checking = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branchId = widget.branches.first.id;
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day, now.hour + 1);
    _to = _from.add(const Duration(hours: 2));
    _check();
  }

  @override
  void dispose() {
    _plate.dispose();
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _bayId = null;
    });
    try {
      final rows = await widget.gateway.bays(
        branchId: _branchId,
        from: _from,
        to: _to,
        vehicleType: _vehicleType,
      );
      if (!mounted) return;
      final available = rows.where((row) => row.available).toList();
      setState(() {
        _bays = rows;
        _bayId = available.firstOrNull?.id;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _parkingMessage(error);
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
      lastDate: DateTime.now().add(const Duration(days: 180)),
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
    if (!_formKey.currentState!.validate() || _bayId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.create(
        ParkingRequestDraft(
          idempotencyKey: _idempotencyKey,
          bayId: _bayId!,
          startsAt: _from,
          endsAt: _to,
          vehicleType: _vehicleType,
          plate: _parkingNullable(_plate.text.toUpperCase()),
          purpose: _parkingNullable(_purpose.text),
          notes: _parkingNullable(_notes.text),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _parkingMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _bays.where((row) => row.available).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar dársena'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _branchId,
              decoration: const InputDecoration(labelText: 'Sucursal'),
              items: widget.branches
                  .map(
                    (row) =>
                        DropdownMenuItem(value: row.id, child: Text(row.name)),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _branchId = value);
                await _check();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(labelText: 'Tipo de vehículo'),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: 'camioneta', child: Text('Camioneta')),
                DropdownMenuItem(
                  value: 'utilitario',
                  child: Text('Utilitario'),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _vehicleType = value);
                await _check();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ParkingDateButton(
                    label: 'Desde',
                    value: _from,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ParkingDateButton(
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
                key: ValueKey(
                  'bay-$_branchId-${_from.toIso8601String()}-$_vehicleType',
                ),
                initialValue: _bayId,
                decoration: const InputDecoration(
                  labelText: 'Dársena disponible',
                ),
                items: available
                    .map(
                      (row) => DropdownMenuItem(
                        value: row.id,
                        child: Text(
                          '${row.name}${row.sector == null ? '' : ' · ${row.sector}'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _bayId = value),
                validator: (value) =>
                    value == null ? 'Seleccioná una dársena' : null,
              ),
            if (!_checking && available.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'No hay dársenas disponibles en ese horario.',
                  style: TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            if (!_checking && _bays.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Plano de dársenas',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver plano en pantalla completa',
                    onPressed: _openFullPlan,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ParkingLegend(requests: widget.requests),
              const SizedBox(height: 12),
              _ParkingPlan(
                bays: _bays,
                requests: widget.requests,
                from: _from,
                to: _to,
                selectedBayId: _bayId,
                onSelect: (bay) {
                  if (bay.available) setState(() => _bayId = bay.id);
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _plate,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Patente'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresá la patente'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purpose,
              maxLength: 220,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              maxLength: 4000,
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

  Future<void> _openFullPlan() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ParkingFullPlanScreen(
          bays: _bays,
          requests: widget.requests,
          from: _from,
          to: _to,
          selectedBayId: _bayId,
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _bayId = selected);
  }
}

class _ParkingBayTile extends StatelessWidget {
  const _ParkingBayTile(
    this.bay, {
    required this.state,
    required this.selected,
    required this.onTap,
  });
  final ParkingBay bay;
  final _ParkingVisualState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = state.color;
    return Semantics(
      button: bay.available,
      selected: selected,
      label: '${bay.name}, ${state.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 92,
          height: 150,
          padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: selected ? 3 : 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                bay.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(color, BlendMode.modulate),
                  child: Image.asset(
                    'assets/parking/vehicle-topdown-neutral.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'Auto visto desde arriba',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ParkingVisualState {
  available('Disponible', Color(0xFF15803D)),
  pending('Pendiente', Color(0xFFD18A00)),
  reserved('Reservada', Color(0xFFDC2626)),
  institutional('Institucional', Color(0xFF64748B)),
  incompatible('No compatible', Color(0xFF64748B));

  const _ParkingVisualState(this.label, this.color);
  final String label;
  final Color color;
}

_ParkingVisualState _visualState(
  ParkingBay bay,
  List<ParkingRequest> requests,
  DateTime from,
  DateTime to,
) {
  final own = requests.where(
    (row) =>
        row.bay?.id == bay.id &&
        row.startsAt.isBefore(to) &&
        row.endsAt.isAfter(from) &&
        _isActiveParkingRequest(row),
  );
  if (own.any(
    (row) => {'pendiente', 'pending'}.contains(row.status.toLowerCase()),
  )) {
    return _ParkingVisualState.pending;
  }
  if (own.isNotEmpty ||
      bay.unavailableReason == 'reserved' ||
      bay.unavailableReason == 'blocked') {
    return _ParkingVisualState.reserved;
  }
  if (bay.unavailableReason == 'institutional') {
    return _ParkingVisualState.institutional;
  }
  if (bay.unavailableReason == 'vehicle_type') {
    return _ParkingVisualState.incompatible;
  }
  return _ParkingVisualState.available;
}

bool _isActiveParkingRequest(ParkingRequest row) => const {
  'pendiente',
  'pending',
  'aprobada',
  'approved',
  'en_uso',
  'in_use',
}.contains(row.status.toLowerCase());

class _ParkingPlan extends StatelessWidget {
  const _ParkingPlan({
    required this.bays,
    required this.requests,
    required this.from,
    required this.to,
    required this.selectedBayId,
    required this.onSelect,
  });

  final List<ParkingBay> bays;
  final List<ParkingRequest> requests;
  final DateTime from;
  final DateTime to;
  final int? selectedBayId;
  final ValueChanged<ParkingBay> onSelect;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ParkingBay>>{};
    for (final bay in bays) {
      grouped
          .putIfAbsent(
            bay.sector?.trim().isNotEmpty == true ? bay.sector! : 'Sector',
            () => [],
          )
          .add(bay);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9FB4C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE4EDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'SUCURSAL · ÁREAS DE ACCESO Y EDIFICIO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF496B87),
              ),
            ),
          ),
          ...grouped.entries.indexed.expand((entry) {
            final index = entry.$1;
            final group = entry.$2;
            return [
              if (index > 0) const _ParkingLane(),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF365D7C),
                        ),
                      ),
                    ),
                    Text(
                      '${group.value.length} POSICIONES',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: group.value.map((bay) {
                  final state = _visualState(bay, requests, from, to);
                  return _ParkingBayTile(
                    bay,
                    state: state,
                    selected: bay.id == selectedBayId,
                    onTap: () {
                      if (bay.available) {
                        onSelect(bay);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${bay.name}: ${state.label}.'),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

class _ParkingLane extends StatelessWidget {
  const _ParkingLane();
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    margin: const EdgeInsets.only(top: 16),
    decoration: const BoxDecoration(
      color: Color(0xFF8B969E),
      border: Border.symmetric(
        horizontal: BorderSide(color: Color(0xFF66717A), width: 2),
      ),
    ),
    alignment: Alignment.center,
    child: const Text(
      '→   CIRCULACIÓN VEHICULAR   →',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _ParkingLegend extends StatelessWidget {
  const _ParkingLegend({required this.requests});
  final List<ParkingRequest> requests;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    children: _ParkingVisualState.values
        .where((state) => state != _ParkingVisualState.incompatible)
        .map(
          (state) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: state.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                state.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        )
        .toList(),
  );
}

class _ParkingFullPlanScreen extends StatefulWidget {
  const _ParkingFullPlanScreen({
    required this.bays,
    required this.requests,
    required this.from,
    required this.to,
    required this.selectedBayId,
  });
  final List<ParkingBay> bays;
  final List<ParkingRequest> requests;
  final DateTime from;
  final DateTime to;
  final int? selectedBayId;

  @override
  State<_ParkingFullPlanScreen> createState() => _ParkingFullPlanScreenState();
}

class _ParkingFullPlanScreenState extends State<_ParkingFullPlanScreen> {
  int? _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.selectedBayId;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Plano de dársenas'),
      actions: [
        TextButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('USAR'),
        ),
      ],
    ),
    body: SafeArea(
      child: InteractiveViewer(
        minScale: 0.7,
        maxScale: 3.5,
        boundaryMargin: const EdgeInsets.all(100),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 620,
            child: Column(
              children: [
                _ParkingLegend(requests: widget.requests),
                const SizedBox(height: 12),
                _ParkingPlan(
                  bays: widget.bays,
                  requests: widget.requests,
                  from: widget.from,
                  to: widget.to,
                  selectedBayId: _selected,
                  onSelect: (bay) => setState(() => _selected = bay.id),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ParkingHero extends StatelessWidget {
  const _ParkingHero();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8E2630), Color(0xFFC65F54)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTACIONAMIENTO · AUTOGESTIÓN',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mis solicitudes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Elegí una dársena verde y enviá la solicitud. Recepción o Guardia la autoriza antes del uso.',
          style: TextStyle(color: Colors.white, height: 1.35),
        ),
      ],
    ),
  );
}

class _ParkingEmpty extends StatelessWidget {
  const _ParkingEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3E8EF)),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF667085)),
    ),
  );
}

class _ParkingStatus extends StatelessWidget {
  const _ParkingStatus(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF3),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: Color(0xFF027A48),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ParkingLine extends StatelessWidget {
  const _ParkingLine(this.icon, this.text);
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

class _ParkingDateButton extends StatelessWidget {
  const _ParkingDateButton({
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
        Text(_parkingDateTime(value), maxLines: 1),
      ],
    ),
  );
}

class _ParkingMessage extends StatelessWidget {
  const _ParkingMessage({required this.message, this.onRetry});
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
              Icons.local_parking_outlined,
              size: 42,
              color: Color(0xFF059669),
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

String _parkingMessage(Object error) {
  if (error is ApiFailure) return error.message;
  if (error is DioException) return 'No pudimos comunicarnos con el portal.';
  return 'No pudimos completar la operación.';
}

String? _parkingNullable(String value) =>
    value.trim().isEmpty ? null : value.trim();
String _parkingTwo(int value) => value.toString().padLeft(2, '0');
String _parkingDateTime(DateTime value) =>
    '${_parkingTwo(value.day)}/${_parkingTwo(value.month)}/${value.year} ${_parkingTime(value)}';
String _parkingTime(DateTime value) =>
    '${_parkingTwo(value.hour)}:${_parkingTwo(value.minute)}';
