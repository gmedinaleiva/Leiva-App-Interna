import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../../parking/data/parking_repository.dart';
import '../../parking/presentation/parking_screen.dart';
import '../data/rooms_repository.dart';
import '../domain/room_models.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    required this.gateway,
    required this.canCreate,
    this.parkingGateway,
    this.canCreateParking = false,
    super.key,
  });

  final RoomsGateway gateway;
  final bool canCreate;
  final ParkingGateway? parkingGateway;
  final bool canCreateParking;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  bool _loading = true;
  String? _error;
  List<RoomBranch> _branches = const [];
  List<RoomReservation> _reservations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final now = DateTime.now();
    try {
      final results = await Future.wait<dynamic>([
        widget.gateway.branches(),
        widget.gateway.reservations(
          from: now.subtract(const Duration(days: 30)),
          to: now.add(const Duration(days: 180)),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = List<RoomBranch>.of(results[0] as List<RoomBranch>);
        _reservations = List<RoomReservation>.of(
          results[1] as List<RoomReservation>,
        );
        _reservations.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _create() async {
    if (_branches.isEmpty) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateRoomReservationScreen(
          gateway: widget.gateway,
          branches: _branches,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _cancel(RoomReservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text('¿Querés cancelar “${reservation.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.cancel(reservation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  Future<void> _openDetail(RoomReservation reservation) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoomReservationDetailScreen(
          gateway: widget.gateway,
          reservationId: reservation.id,
          parkingGateway: widget.parkingGateway,
          canCreateParking: widget.canCreateParking,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas de salas'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: widget.canCreate && _branches.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('createRoomReservationButton'),
              onPressed: _create,
              backgroundColor: const Color(0xFFDC1F26),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva reserva'),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _MessageCard(
            icon: Icons.cloud_off_outlined,
            title: 'No pudimos cargar las reservas',
            message: _error!,
            action: TextButton(
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }
    if (_reservations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _MessageCard(
            icon: Icons.meeting_room_outlined,
            title: 'Todavía no tenés reservas',
            message: 'Creá una reserva para consultar salas disponibles.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: _reservations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reservation = _reservations[index];
        return _ReservationCard(
          reservation: reservation,
          onTap: () => _openDetail(reservation),
          onCancel: reservation.canCancel ? () => _cancel(reservation) : null,
        );
      },
    );
  }
}

class RoomReservationDetailScreen extends StatefulWidget {
  const RoomReservationDetailScreen({
    required this.gateway,
    required this.reservationId,
    this.parkingGateway,
    this.canCreateParking = false,
    super.key,
  });

  final RoomsGateway gateway;
  final int reservationId;
  final ParkingGateway? parkingGateway;
  final bool canCreateParking;

  @override
  State<RoomReservationDetailScreen> createState() =>
      _RoomReservationDetailScreenState();
}

class _RoomReservationDetailScreenState
    extends State<RoomReservationDetailScreen> {
  RoomReservation? _reservation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await widget.gateway.detail(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _reservation = row;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _visitorParking() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitorParkingScreen(
          gateway: widget.gateway,
          reservationId: widget.reservationId,
        ),
      ),
    );
    if (created == true) await _load();
  }

  void _openParking() {
    final gateway = widget.parkingGateway;
    if (gateway == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ParkingScreen(gateway: gateway, canCreate: widget.canCreateParking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de la sala'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: _error != null
        ? _MessageCard(
            icon: Icons.error_outline,
            title: 'No pudimos abrir la reserva',
            message: _error!,
          )
        : _reservation == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _reservation!.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _InfoLine(
                Icons.meeting_room_outlined,
                '${_reservation!.room.name} · ${_reservation!.room.branchName ?? 'Sucursal'}',
              ),
              const SizedBox(height: 8),
              _InfoLine(
                Icons.schedule_rounded,
                '${_formatDateTime(_reservation!.startsAt)} — ${_formatTime(_reservation!.endsAt)}',
              ),
              if (_reservation!.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(_reservation!.notes!),
              ],
              if (_reservation!.participants.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Participantes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                ..._reservation!.participants.map(
                  (person) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      person.isExternal
                          ? Icons.badge_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(person.name),
                    subtitle: person.organization == null
                        ? null
                        : Text(person.organization!),
                  ),
                ),
              ],
              if (_reservation!.visitorParking.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Dársenas de visitantes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                ..._reservation!.visitorParking.map(
                  (request) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_parking_outlined),
                    title: Text(
                      request['guest_name'] as String? ??
                          request['plate'] as String? ??
                          'Solicitud',
                    ),
                    subtitle: Text(request['status'] as String? ?? ''),
                  ),
                ),
              ],
              if (_reservation!.participants.any(
                (person) => person.isExternal,
              )) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _visitorParking,
                  icon: const Icon(Icons.local_parking_outlined),
                  label: const Text('Solicitar dársena para visitante'),
                ),
              ],
              if (widget.parkingGateway != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openParking,
                  icon: const Icon(Icons.directions_car_outlined),
                  label: const Text('Ver mis dársenas'),
                ),
              ],
            ],
          ),
  );
}

class VisitorParkingScreen extends StatefulWidget {
  const VisitorParkingScreen({
    required this.gateway,
    required this.reservationId,
    super.key,
  });
  final RoomsGateway gateway;
  final int reservationId;

  @override
  State<VisitorParkingScreen> createState() => _VisitorParkingScreenState();
}

class _VisitorParkingScreenState extends State<VisitorParkingScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _plate = TextEditingController();
  final _notes = TextEditingController();
  String _vehicleType = 'auto';
  VisitorParkingOptions? _options;
  int? _participantId;
  int? _bayId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final options = await widget.gateway.visitorParkingOptions(
        widget.reservationId,
        vehicleType: _vehicleType,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _participantId = options.visitors
            .where((row) => !row.hasActiveRequest)
            .firstOrNull
            ?.id;
        _bayId = options.bays.where((row) => row.available).firstOrNull?.id;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _submit() async {
    if (_participantId == null || _bayId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createVisitorParking(
        widget.reservationId,
        VisitorParkingDraft(
          idempotencyKey: _idempotencyKey,
          participantId: _participantId!,
          bayId: _bayId!,
          vehicleType: _vehicleType,
          plate: _plate.text.trim().isEmpty
              ? null
              : _plate.text.trim().toUpperCase(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitors =
        _options?.visitors.where((row) => !row.hasActiveRequest).toList() ??
        const <VisitorParkingOption>[];
    final bays =
        _options?.bays.where((row) => row.available).toList() ??
        const <VisitorParkingBay>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dársena para visitante'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _options == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.link_rounded, color: Color(0xFF059669)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La dársena queda vinculada a la sala, al visitante y al horario de la reunión.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de vehículo',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(
                      value: 'camioneta',
                      child: Text('Camioneta'),
                    ),
                    DropdownMenuItem(
                      value: 'utilitario',
                      child: Text('Utilitario'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _vehicleType = value);
                    await _load();
                  },
                ),
                const SizedBox(height: 16),
                if (_options != null && visitors.isEmpty)
                  const _MessageCard(
                    icon: Icons.person_off_outlined,
                    title: 'No hay visitantes pendientes',
                    message: 'Todos los visitantes ya tienen una solicitud activa o la reserva no tiene participantes externos.',
                  ),
                if (_options != null && bays.isEmpty) ...[
                  const SizedBox(height: 12),
                  const _MessageCard(
                    icon: Icons.local_parking_outlined,
                    title: 'No hay dársenas disponibles',
                    message: 'Probá otro tipo de vehículo o consultá nuevamente más tarde.',
                  ),
                ],
                if (_options != null && (visitors.isEmpty || bays.isEmpty))
                  const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _participantId,
                  decoration: const InputDecoration(labelText: 'Visitante'),
                  items: visitors
                      .map(
                        (row) => DropdownMenuItem(
                          value: row.id,
                          child: Text(row.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _participantId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _bayId,
                  decoration: const InputDecoration(
                    labelText: 'Dársena disponible',
                  ),
                  items: bays
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
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _plate,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Patente (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Observación (opcional)',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving || _participantId == null || _bayId == null
                      ? null
                      : _submit,
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
    );
  }
}

class CreateRoomReservationScreen extends StatefulWidget {
  const CreateRoomReservationScreen({
    required this.gateway,
    required this.branches,
    super.key,
  });

  final RoomsGateway gateway;
  final List<RoomBranch> branches;

  @override
  State<CreateRoomReservationScreen> createState() =>
      _CreateRoomReservationScreenState();
}

class _CreateRoomReservationScreenState
    extends State<CreateRoomReservationScreen> {
  final _idempotencyKey = newIdempotencyKey();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late int _branchId;
  late DateTime _from;
  late DateTime _to;
  bool _checking = false;
  bool _saving = false;
  String? _error;
  List<RoomAvailability> _availability = const [];
  int? _roomId;

  @override
  void initState() {
    super.initState();
    _branchId = widget.branches.first.id;
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day, now.hour + 1);
    _to = _from.add(const Duration(hours: 1));
    _checkAvailability();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    setState(() {
      _checking = true;
      _error = null;
      _roomId = null;
    });
    try {
      final result = await widget.gateway.availability(
        branchId: _branchId,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _roomId = result.where((room) => room.available).firstOrNull?.roomId;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _pickDateTime({required bool start}) async {
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
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _from = selected;
        if (!_to.isAfter(_from)) _to = _from.add(const Duration(hours: 1));
      } else {
        _to = selected;
      }
    });
    await _checkAvailability();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _roomId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.create(
        RoomReservationDraft(
          idempotencyKey: _idempotencyKey,
          roomId: _roomId!,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          startsAt: _from,
          endsAt: _to,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableRooms = _availability
        .where((room) => room.available)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva reserva'),
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
                    (branch) => DropdownMenuItem(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) async {
                      if (value == null) return;
                      setState(() => _branchId = value);
                      await _checkAvailability();
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    label: 'Desde',
                    value: _from,
                    onTap: () => _pickDateTime(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeButton(
                    label: 'Hasta',
                    value: _to,
                    onTap: () => _pickDateTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_checking)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<int>(
                key: ValueKey('room-$_branchId-${_from.toIso8601String()}'),
                initialValue: _roomId,
                decoration: const InputDecoration(labelText: 'Sala disponible'),
                items: availableRooms
                    .map(
                      (room) => DropdownMenuItem(
                        value: room.roomId,
                        child: Text('${room.name} · ${room.capacity} personas'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _roomId = value),
                validator: (value) =>
                    value == null ? 'No hay una sala seleccionada' : null,
              ),
            if (!_checking && availableRooms.isEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'No hay salas disponibles en ese horario.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Motivo de la reserva',
              ),
              maxLength: 220,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresá el motivo'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 3,
              maxLength: 4000,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('saveRoomReservationButton'),
              onPressed: _saving || _checking ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Guardando...' : 'Confirmar reserva'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    this.onTap,
    this.onCancel,
  });

  final RoomReservation reservation;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cancelled = const {
      'cancelled',
      'canceled',
    }.contains(reservation.status.toLowerCase());
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE3E8EF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusChip(status: reservation.status),
                ],
              ),
              const SizedBox(height: 12),
              _InfoLine(
                Icons.meeting_room_outlined,
                '${reservation.room.name} · ${reservation.room.branchName ?? 'Sucursal'}',
              ),
              const SizedBox(height: 7),
              _InfoLine(
                Icons.schedule_rounded,
                '${_formatDateTime(reservation.startsAt)} — ${_formatTime(reservation.endsAt)}',
              ),
              if (onCancel != null && !cancelled) ...[
                const Divider(height: 26),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cancelled = const {
      'cancelled',
      'canceled',
    }.contains(status.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cancelled ? const Color(0xFFFEE4E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        cancelled ? 'Cancelada' : 'Activa',
        style: TextStyle(
          color: cancelled ? const Color(0xFFB42318) : const Color(0xFF067647),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
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

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
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
        Text(_formatDateTime(value), maxLines: 1),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3E8EF)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xFF7C3AED)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF667085)),
        ),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ],
    ),
  );
}

String _messageFor(Object error) {
  if (error is ApiFailure) {
    return switch (error.statusCode) {
      401 => 'La sesión venció. Volvé a iniciar sesión.',
      403 => 'Tu usuario no tiene permiso para esta operación.',
      404 => 'La reserva o sala ya no está disponible.',
      409 => error.message,
      422 => error.message,
      429 => 'Hay demasiadas solicitudes. Esperá un momento.',
      _ => error.message,
    };
  }
  if (error is DioException) return 'No pudimos comunicarnos con el portal.';
  if (error is FormatException) return 'El portal devolvió datos inesperados.';
  return 'No pudimos completar la operación.';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _formatDateTime(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year} ${_formatTime(value)}';
String _formatTime(DateTime value) =>
    '${_two(value.hour)}:${_two(value.minute)}';
