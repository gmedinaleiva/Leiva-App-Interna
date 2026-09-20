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
    required this.currentUserId,
    this.parkingGateway,
    this.canCreateParking = false,
    super.key,
  });

  final RoomsGateway gateway;
  final bool canCreate;
  final int currentUserId;
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
  bool _showHistory = false;

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
        content: Text(
          'Sala: ${reservation.room.name}\n'
          'Sucursal: ${reservation.room.branchName ?? 'Sin informar'}\n'
          'Horario: ${_formatDateTime(reservation.startsAt)} — ${_formatTime(reservation.endsAt)}\n\n'
          'También se actualizarán las invitaciones y las dársenas vinculadas según las reglas del portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar reserva'),
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
          currentUserId: widget.currentUserId,
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
        title: const Text('Salas'),
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
    final now = DateTime.now();
    final active = _reservations.where((row) {
      final status = row.status.toLowerCase();
      return row.endsAt.isAfter(now) &&
          !{
            'cancelled',
            'canceled',
            'completed',
            'finalizada',
          }.contains(status);
    }).toList();
    final history = _reservations
        .where((row) => !active.contains(row))
        .toList()
        .reversed
        .toList();
    final visible = _showHistory ? history : active;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: visible.isEmpty ? 4 : visible.length + 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _RoomsHero(activeCount: active.length);
        if (index == 1) {
          return OutlinedButton.icon(
            onPressed: widget.canCreate && _branches.isNotEmpty
                ? _create
                : null,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Consultar disponibilidad y reservar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          );
        }
        if (index == 2) {
          return SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.event_available_outlined),
                label: Text('Próximas (${active.length})'),
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
          return _MessageCard(
            icon: _showHistory
                ? Icons.history_rounded
                : Icons.meeting_room_outlined,
            title: _showHistory
                ? 'Sin historial reciente'
                : 'Todavía no tenés reservas',
            message: _showHistory
                ? 'Las reservas finalizadas y canceladas aparecerán acá.'
                : 'Consultá disponibilidad para crear una nueva reserva.',
          );
        }
        final reservation = visible[index - 3];
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
    required this.currentUserId,
    this.parkingGateway,
    this.canCreateParking = false,
    super.key,
  });

  final RoomsGateway gateway;
  final int reservationId;
  final int currentUserId;
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

  bool get _canEdit {
    final row = _reservation;
    return row != null &&
        (row.organizerId == widget.currentUserId ||
            row.responsibleId == widget.currentUserId) &&
        row.canCancel;
  }

  bool get _canWithdraw {
    final row = _reservation;
    if (row == null || !row.canCancel || _canEdit) return false;
    return row.participants.any(
      (participant) =>
          !participant.isExternal && participant.userId == widget.currentUserId,
    );
  }

  Future<void> _edit() async {
    final row = _reservation;
    if (row == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EditRoomReservationScreen(
          gateway: widget.gateway,
          reservation: row,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _reprogram() async {
    final row = _reservation;
    if (row == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReprogramRoomReservationScreen(
          gateway: widget.gateway,
          reservation: row,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirarme de la reunión'),
        content: const Text(
          'Dejarás de figurar como participante. La reserva continuará para el resto de los asistentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirarme'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.withdraw(widget.reservationId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
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
                      request['participant_name'] as String? ??
                          request['plate'] as String? ??
                          'Solicitud',
                    ),
                    subtitle: Text(
                      [
                            request['status'] as String?,
                            if (request['bay'] is Map<String, dynamic>)
                              (request['bay'] as Map<String, dynamic>)['name']
                                  as String?,
                            request['resolution_notes'] as String?,
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                    ),
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
              if (_canEdit) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reprogram,
                  icon: const Icon(Icons.update_rounded),
                  label: const Text('Reprogramar'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar reunión'),
                ),
              ],
              if (_canWithdraw) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _withdraw,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Retirarme de la reunión'),
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

class ReprogramRoomReservationScreen extends StatefulWidget {
  const ReprogramRoomReservationScreen({
    required this.gateway,
    required this.reservation,
    super.key,
  });
  final RoomsGateway gateway;
  final RoomReservation reservation;

  @override
  State<ReprogramRoomReservationScreen> createState() =>
      _ReprogramRoomReservationScreenState();
}

class _ReprogramRoomReservationScreenState
    extends State<ReprogramRoomReservationScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _from = widget.reservation.startsAt;
    _to = widget.reservation.endsAt;
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
        final duration = _to.difference(_from);
        _from = value;
        _to = value.add(
          duration.isNegative || duration == Duration.zero
              ? const Duration(hours: 1)
              : duration,
        );
      } else {
        _to = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_to.isAfter(_from)) {
      setState(
        () =>
            _error = 'El horario de finalización debe ser posterior al inicio.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final reservation = widget.reservation;
      await widget.gateway.update(
        reservation.id,
        RoomReservationUpdate(
          roomId: reservation.room.id,
          title: reservation.title,
          notes: reservation.notes,
          startsAt: _from,
          endsAt: _to,
          internalParticipantIds: reservation.participants
              .where((person) => !person.isExternal && person.userId != null)
              .map((person) => person.userId!)
              .toList(),
          externalParticipants: reservation.participants
              .where((person) => person.isExternal)
              .map(
                (person) => ExternalRoomParticipantDraft(
                  type: person.externalType ?? 'visita',
                  name: person.name,
                  organization: person.organization,
                  email: person.email,
                ),
              )
              .toList(),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reprogramar reserva')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDEE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.reservation.room.name} · ${widget.reservation.room.branchName ?? 'Sucursal'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 18),
        _DateTimeButton(
          label: 'Desde (Argentina)',
          value: _from,
          onTap: () => _pick(true),
        ),
        const SizedBox(height: 12),
        _DateTimeButton(
          label: 'Hasta (Argentina)',
          value: _to,
          onTap: () => _pick(false),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.update_rounded),
          label: Text(_saving ? 'Reprogramando...' : 'Confirmar nuevo horario'),
        ),
      ],
    ),
  );
}

class EditRoomReservationScreen extends StatefulWidget {
  const EditRoomReservationScreen({
    required this.gateway,
    required this.reservation,
    super.key,
  });

  final RoomsGateway gateway;
  final RoomReservation reservation;

  @override
  State<EditRoomReservationScreen> createState() =>
      _EditRoomReservationScreenState();
}

class _EditRoomReservationScreenState extends State<EditRoomReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _from;
  late DateTime _to;
  List<RoomBranch> _branches = const [];
  List<MeetingRoom> _rooms = const [];
  int? _branchId;
  int? _roomId;
  late final List<RoomParticipantOption> _internalParticipants;
  late final List<ExternalRoomParticipantDraft> _externalParticipants;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _title = TextEditingController(text: reservation.title);
    _notes = TextEditingController(text: reservation.notes);
    _from = reservation.startsAt;
    _to = reservation.endsAt;
    _branchId = reservation.room.branchId;
    _roomId = reservation.room.id;
    _internalParticipants = reservation.participants
        .where(
          (participant) =>
              !participant.isExternal && participant.userId != null,
        )
        .map(
          (participant) => RoomParticipantOption(
            id: participant.userId!,
            name: participant.name,
            username: participant.email ?? participant.name,
            email: participant.email,
          ),
        )
        .toList();
    _externalParticipants = reservation.participants
        .where((participant) => participant.isExternal)
        .map(
          (participant) => ExternalRoomParticipantDraft(
            name: participant.name,
            type: participant.externalType ?? 'visita',
            organization: participant.organization,
            email: participant.email,
          ),
        )
        .toList();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final branches = await widget.gateway.branches();
      final selectedBranch = branches.any((item) => item.id == _branchId)
          ? _branchId
          : branches.firstOrNull?.id;
      final rooms = selectedBranch == null
          ? const <MeetingRoom>[]
          : await widget.gateway.rooms(selectedBranch);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchId = selectedBranch;
        _rooms = rooms;
        if (!rooms.any((room) => room.id == _roomId)) {
          _roomId = rooms.firstOrNull?.id;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
        _loading = false;
      });
    }
  }

  Future<void> _changeBranch(int branchId) async {
    setState(() {
      _branchId = branchId;
      _roomId = null;
      _loading = true;
    });
    try {
      final rooms = await widget.gateway.rooms(branchId);
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _roomId = rooms.firstOrNull?.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
        _loading = false;
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
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _roomId == null) return;
    if (!_to.isAfter(_from)) {
      setState(
        () => _error = 'La fecha final debe ser posterior a la inicial.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.update(
        widget.reservation.id,
        RoomReservationUpdate(
          roomId: _roomId!,
          title: _title.text.trim(),
          notes: _nullableRoom(_notes.text),
          startsAt: _from,
          endsAt: _to,
          internalParticipantIds: _internalParticipants
              .map((participant) => participant.id)
              .toList(),
          externalParticipants: List.unmodifiable(_externalParticipants),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Editar reunión'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _branchId,
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                  items: _branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) _changeBranch(value);
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _roomId,
                  decoration: const InputDecoration(labelText: 'Sala'),
                  items: _rooms
                      .map(
                        (room) => DropdownMenuItem(
                          value: room.id,
                          child: Text(
                            '${room.name} · ${room.capacity} personas',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _roomId = value),
                  validator: (value) =>
                      value == null ? 'Seleccioná una sala' : null,
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
                TextFormField(
                  controller: _title,
                  maxLength: 220,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresá el motivo'
                      : null,
                ),
                RoomParticipantsEditor(
                  gateway: widget.gateway,
                  internalParticipants: _internalParticipants,
                  externalParticipants: _externalParticipants,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
  );
}

class RoomParticipantsEditor extends StatefulWidget {
  const RoomParticipantsEditor({
    required this.gateway,
    required this.internalParticipants,
    required this.externalParticipants,
    required this.onChanged,
    super.key,
  });

  final RoomsGateway gateway;
  final List<RoomParticipantOption> internalParticipants;
  final List<ExternalRoomParticipantDraft> externalParticipants;
  final VoidCallback onChanged;

  @override
  State<RoomParticipantsEditor> createState() => _RoomParticipantsEditorState();
}

class _RoomParticipantsEditorState extends State<RoomParticipantsEditor> {
  final _search = TextEditingController();
  List<RoomParticipantOption> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Ingresá al menos dos caracteres.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.gateway.participants(query);
      if (!mounted) return;
      setState(() {
        _results = results
            .where(
              (result) => !widget.internalParticipants.any(
                (selected) => selected.id == result.id,
              ),
            )
            .toList();
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _addExternal() async {
    final participant = await _externalParticipantDialog(context);
    if (participant == null) return;
    widget.externalParticipants.add(participant);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Participantes',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      if (widget.internalParticipants.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: widget.internalParticipants
              .map(
                (participant) => InputChip(
                  label: Text(participant.name),
                  avatar: const Icon(Icons.person_outline, size: 18),
                  onDeleted: () {
                    widget.internalParticipants.removeWhere(
                      (item) => item.id == participant.id,
                    );
                    widget.onChanged();
                  },
                ),
              )
              .toList(),
        ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: const InputDecoration(
                labelText: 'Buscar empleado',
                hintText: 'Nombre, usuario o correo',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Buscar',
            onPressed: _searching ? null : _runSearch,
            icon: _searching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
          ),
        ],
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
        ),
      ..._results.map(
        (participant) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(participant.name),
          subtitle: Text(participant.email ?? participant.username),
          trailing: IconButton(
            tooltip: 'Agregar',
            onPressed: () {
              widget.internalParticipants.add(participant);
              setState(() {
                _results = _results
                    .where((item) => item.id != participant.id)
                    .toList();
              });
              widget.onChanged();
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
      ),
      const SizedBox(height: 8),
      ...widget.externalParticipants.asMap().entries.map(
        (entry) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(entry.value.name),
          subtitle: Text(
            [entry.value.type, entry.value.organization]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
          ),
          trailing: IconButton(
            tooltip: 'Quitar visitante',
            onPressed: () {
              widget.externalParticipants.removeAt(entry.key);
              widget.onChanged();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _addExternal,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Agregar visitante externo'),
      ),
    ],
  );
}

Future<ExternalRoomParticipantDraft?> _externalParticipantDialog(
  BuildContext context,
) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final organization = TextEditingController();
  final email = TextEditingController();
  var type = 'visita';
  final result = await showDialog<ExternalRoomParticipantDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Visitante externo'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items:
                      const {
                            'visita': 'Visita',
                            'proveedor': 'Proveedor',
                            'cliente': 'Cliente',
                            'entrevista': 'Entrevista',
                            'otro': 'Otro',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  maxLength: 180,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresá el nombre'
                      : null,
                ),
                TextFormField(
                  controller: organization,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Organización (opcional)',
                  ),
                ),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Correo (opcional)',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)
                        ? null
                        : 'Ingresá un correo válido';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                ExternalRoomParticipantDraft(
                  type: type,
                  name: name.text.trim(),
                  organization: _nullableRoom(organization.text),
                  email: _nullableRoom(email.text),
                ),
              );
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  organization.dispose();
  email.dispose();
  return result;
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
  final List<RoomParticipantOption> _internalParticipants = [];
  final List<ExternalRoomParticipantDraft> _externalParticipants = [];
  bool _coordinateParking = false;

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
      final created = await widget.gateway.create(
        RoomReservationDraft(
          idempotencyKey: _idempotencyKey,
          roomId: _roomId!,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          startsAt: _from,
          endsAt: _to,
          internalParticipantIds: _internalParticipants
              .map((participant) => participant.id)
              .toList(),
          externalParticipants: List.unmodifiable(_externalParticipants),
        ),
      );
      if (!mounted) return;
      if (_coordinateParking && _externalParticipants.isNotEmpty) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => VisitorParkingScreen(
              gateway: widget.gateway,
              reservationId: created.id,
            ),
          ),
        );
        if (!mounted) return;
      }
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
            RoomParticipantsEditor(
              gateway: widget.gateway,
              internalParticipants: _internalParticipants,
              externalParticipants: _externalParticipants,
              onChanged: () => setState(() {}),
            ),
            if (_externalParticipants.isNotEmpty) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _coordinateParking,
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _coordinateParking = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Elegir dársena para las personas externas'),
                subtitle: const Text(
                  'La solicitud quedará pendiente de autorización de Recepción o Guardia.',
                ),
              ),
            ],
            const SizedBox(height: 16),
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

class _RoomsHero extends StatelessWidget {
  const _RoomsHero({required this.activeCount});
  final int activeCount;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8E2630), Color(0xFFC65F54)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERACIÓN INTERNA · AGENDA EDILICIA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Reservas de salas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Consultá disponibilidad y gestioná tus reuniones activas.',
                style: TextStyle(color: Colors.white, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white38),
          ),
          child: Column(
            children: [
              Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'próximas',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
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

String? _nullableRoom(String value) =>
    value.trim().isEmpty ? null : value.trim();
String _two(int value) => value.toString().padLeft(2, '0');
String _formatDateTime(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year} ${_formatTime(value)}';
String _formatTime(DateTime value) =>
    '${_two(value.hour)}:${_two(value.minute)}';
