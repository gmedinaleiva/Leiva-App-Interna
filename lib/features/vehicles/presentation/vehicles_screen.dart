import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../../parking/data/parking_repository.dart';
import '../../parking/domain/parking_models.dart';
import '../data/vehicles_repository.dart';
import '../domain/vehicle_models.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    required this.gateway,
    required this.canCreate,
    this.parkingGateway,
    super.key,
  });
  final VehiclesGateway gateway;
  final bool canCreate;
  final ParkingGateway? parkingGateway;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _loading = true;
  String? _error;
  List<VehicleReservation> _reservations = const [];
  List<VehicleOption> _vehicles = const [];
  int _historyDays = 30;

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
      final now = DateTime.now();
      final result = await Future.wait<dynamic>([
        widget.gateway.reservations(),
        widget.gateway.available(
          from: now,
          to: now.add(const Duration(hours: 1)),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _reservations = List<VehicleReservation>.of(
          result[0] as List<VehicleReservation>,
        );
        _vehicles = List<VehicleOption>.of(result[1] as List<VehicleOption>);
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
        builder: (_) => CreateVehicleReservationScreen(
          gateway: widget.gateway,
          parkingGateway: widget.parkingGateway,
        ),
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
    final active = _reservations
        .where((row) => row.status.toLowerCase() == 'en_uso')
        .toList();
    final upcoming = _reservations
        .where(
          (row) => const {
            'pendiente',
            'pending',
            'aprobada',
            'approved',
          }.contains(row.status.toLowerCase()),
        )
        .toList();
    final history = _reservations
        .where((row) => !active.contains(row) && !upcoming.contains(row))
        .where(
          (row) => row.startsAt.isAfter(
            DateTime.now().subtract(Duration(days: _historyDays)),
          ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        const _MobilityHero(),
        const SizedBox(height: 14),
        _MobilityKpis(
          vehicleCount: _vehicles.length,
          activeCount: active.length + upcoming.length,
          historyCount: _reservations.length - active.length - upcoming.length,
          onVehicles: () => _showVehicles(_vehicles),
          onActive: () => _showReservations('Mis reservas activas', [
            ...active,
            ...upcoming,
          ]),
          onHistory: () => _showReservations(
            'Historial de reservas',
            _reservations
                .where(
                  (row) => !active.contains(row) && !upcoming.contains(row),
                )
                .toList(),
          ),
          onAgenda: () => _showAgendaUnavailable(false),
          onAgendaHistory: () => _showAgendaUnavailable(true),
        ),
        const SizedBox(height: 16),
        if (_reservations.isEmpty) const _SmallMobilityEmpty(),
        ..._section('En curso', active),
        ..._section('Próximos', upcoming),
        if (history.isNotEmpty || _reservations.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 10, 2, 8),
            child: Text(
              'Viajes recientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
                ButtonSegment(value: 90, label: Text('90 días')),
                ButtonSegment(value: 365, label: Text('1 año')),
              ],
              selected: {_historyDays},
              onSelectionChanged: (value) =>
                  setState(() => _historyDays = value.first),
            ),
          ),
          const SizedBox(height: 8),
          ..._section('', history),
        ],
      ],
    );
  }

  Future<void> _showVehicles(List<VehicleOption> rows) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _MobilitySheet(
          title: 'Vehículos habilitados',
          children: rows.isEmpty
              ? const [Text('No hay vehículos habilitados para este período.')]
              : rows
                    .map(
                      (row) => ListTile(
                        leading: const Icon(Icons.directions_car_outlined),
                        title: Text(
                          row.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            row.brand,
                            row.model,
                            row.available
                                ? 'Disponible'
                                : row.unavailableReason,
                          ].whereType<String>().join(' · '),
                        ),
                      ),
                    )
                    .toList(),
        ),
      );

  Future<void> _showReservations(
    String title,
    List<VehicleReservation> rows,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _MobilitySheet(
      title: title,
      children: rows.isEmpty
          ? const [Text('No hay datos para mostrar.')]
          : rows
                .map(
                  (row) => ListTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text(
                      row.vehicle?.label ?? 'Vehículo',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${row.destination ?? row.purpose ?? 'Sin destino'}\n${_dt(row.startsAt)} — ${_time(row.endsAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleTripScreen(
                            gateway: widget.gateway,
                            reservation: row,
                            parkingGateway: widget.parkingGateway,
                          ),
                        ),
                      );
                    },
                  ),
                )
                .toList(),
    ),
  );

  Future<void> _showAgendaUnavailable(bool history) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                history ? Icons.history_rounded : Icons.event_note_rounded,
                size: 44,
                color: const Color(0xFF9B3139),
              ),
              const SizedBox(height: 12),
              Text(
                history ? 'Historial de agenda' : 'Mi agenda activa',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'El portal todavía debe publicar la agenda gerencial en /api/app/v1. La app no mezcla este dato con el historial de viajes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  List<Widget> _section(String title, List<VehicleReservation> rows) {
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      ...rows.map(
        (row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE3E8EF)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VehicleTripScreen(
                    gateway: widget.gateway,
                    reservation: row,
                    parkingGateway: widget.parkingGateway,
                  ),
                ),
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
                                row.nextAction == 'start'
                                    ? 'Iniciar'
                                    : 'Finalizar',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _MobilityHero extends StatelessWidget {
  const _MobilityHero();
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
          'GEOSAT · AUTOGESTIÓN',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mi movilidad',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Reservá vehículos habilitados y consultá tu agenda, viajes, eventos y trayectorias.',
          style: TextStyle(color: Colors.white, height: 1.35),
        ),
      ],
    ),
  );
}

class _MobilityKpis extends StatelessWidget {
  const _MobilityKpis({
    required this.vehicleCount,
    required this.activeCount,
    required this.historyCount,
    required this.onVehicles,
    required this.onActive,
    required this.onHistory,
    required this.onAgenda,
    required this.onAgendaHistory,
  });
  final int vehicleCount;
  final int activeCount;
  final int historyCount;
  final VoidCallback onVehicles;
  final VoidCallback onActive;
  final VoidCallback onHistory;
  final VoidCallback onAgenda;
  final VoidCallback onAgendaHistory;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _MobilityKpi(
          label: 'Vehículos habilitados',
          value: vehicleCount,
          icon: Icons.directions_car_outlined,
          onTap: onVehicles,
        ),
        _MobilityKpi(
          label: 'Reservas activas',
          value: activeCount,
          icon: Icons.event_available_outlined,
          onTap: onActive,
        ),
        _MobilityKpi(
          label: 'Historial de reservas',
          value: historyCount,
          icon: Icons.history_rounded,
          onTap: onHistory,
        ),
        _MobilityKpi(
          label: 'Mi agenda activa',
          value: 0,
          icon: Icons.event_note_rounded,
          onTap: onAgenda,
        ),
        _MobilityKpi(
          label: 'Historial de agenda',
          value: 0,
          icon: Icons.calendar_month_outlined,
          onTap: onAgendaHistory,
        ),
      ],
    ),
  );
}

class _MobilityKpi extends StatelessWidget {
  const _MobilityKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: SizedBox(
      width: 148,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD8E1EA)),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF9B3139)),
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MobilitySheet extends StatelessWidget {
  const _MobilitySheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _SmallMobilityEmpty extends StatelessWidget {
  const _SmallMobilityEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3E8EF)),
    ),
    child: const Text(
      'Todavía no tenés reservas de vehículos.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF667085)),
    ),
  );
}

class VehicleTripScreen extends StatefulWidget {
  const VehicleTripScreen({
    required this.gateway,
    required this.reservation,
    this.parkingGateway,
    super.key,
  });

  final VehiclesGateway gateway;
  final VehicleReservation reservation;
  final ParkingGateway? parkingGateway;

  @override
  State<VehicleTripScreen> createState() => _VehicleTripScreenState();
}

class _VehicleTripScreenState extends State<VehicleTripScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  VehicleTripView? _trip;
  List<VehicleNotice> _notices = const [];
  late VehicleReservation _reservation;
  String? _error;
  bool _loading = true;

  bool get _isLive => _reservation.status.toLowerCase() == 'en_uso';

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startPolling();
    } else {
      _timer?.cancel();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    if (_isLive) {
      _timer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _load(silent: true),
      );
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reservation = await widget.gateway.reservation(
        widget.reservation.id,
      );
      final live = reservation.status.toLowerCase() == 'en_uso';
      final result = await Future.wait<dynamic>([
        widget.gateway.trip(widget.reservation.id, live: live),
        widget.gateway.notices(reservationId: widget.reservation.id),
      ]);
      if (!mounted) return;
      setState(() {
        _reservation = reservation;
        _trip = result[0] as VehicleTripView;
        _notices = result[1] as List<VehicleNotice>;
        _loading = false;
        _error = null;
      });
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _extend() async {
    var selected = _reservation.endsAt.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selected),
    );
    if (time == null) return;
    selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await widget.gateway.extend(widget.reservation.id, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Extensión registrada.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _requestReturnParking() async {
    final parkingGateway = widget.parkingGateway;
    if (parkingGateway == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VehicleReturnParkingScreen(
          gateway: widget.gateway,
          parkingGateway: parkingGateway,
          reservation: _reservation,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openNotice(VehicleNotice notice) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VehicleNoticeDetailScreen(
          gateway: widget.gateway,
          noticeId: notice.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_reservation.vehicle?.label ?? 'Detalle del viaje'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _MessageList(message: _error!, onRetry: _load)
        : _tripBody(),
  );

  Widget _tripBody() {
    final trip = _trip!;
    final live = trip.live['position'] as Map<String, dynamic>?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isLive)
          FilledButton.icon(
            onPressed: _extend,
            icon: const Icon(Icons.more_time_rounded),
            label: const Text('Extender viaje'),
          ),
        if (_isLive) const SizedBox(height: 14),
        _TripPanel(
          title: 'Datos del viaje',
          child: Column(
            children: [
              _DetailRow(
                label: 'Estado',
                value: _statusLabel(_reservation.status),
              ),
              _DetailRow(
                label: 'Destino',
                value: _reservation.destination ?? 'No informado',
              ),
              _DetailRow(
                label: 'Distancia planificada',
                value: _reservation.plannedDistanceKm == null
                    ? 'No informada'
                    : '${_number(_reservation.plannedDistanceKm!)} km',
              ),
              _DetailRow(
                label: 'Ocupantes',
                value:
                    _reservation.occupantCount?.toString() ?? 'No informados',
              ),
              _DetailRow(
                label: 'Equipaje estimado',
                value: _reservation.estimatedLuggageKg == null
                    ? 'No informado'
                    : '${_number(_reservation.estimatedLuggageKg!)} kg',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ReturnParkingPanel(
          parking: _reservation.returnParking,
          canRequest:
              widget.parkingGateway != null &&
              _reservation.returnParking == null &&
              !const {
                'cancelada',
                'cancelled',
                'finalizada',
                'finished',
              }.contains(_reservation.status.toLowerCase()),
          onRequest: _requestReturnParking,
        ),
        if (live != null)
          _TripPanel(
            title: 'Última señal',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${live['event'] ?? 'Posición'} · ${live['speed'] ?? 0} km/h',
                ),
                const SizedBox(height: 4),
                Text('${live['lat'] ?? '—'}, ${live['lng'] ?? '—'}'),
              ],
            ),
          ),
        if (trip.points.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TripPanel(
            title: 'Recorrido',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: _TrajectoryMap(
                  points: trip.points,
                  events: trip.events,
                  live: _isLive,
                ),
              ),
            ),
          ),
        ],
        if (trip.summary.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TripPanel(
            title: 'Resumen',
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              children: trip.summary.entries
                  .where((entry) => entry.value is num || entry.value is String)
                  .take(8)
                  .map(
                    (entry) => Text('${_humanize(entry.key)}: ${entry.value}'),
                  )
                  .toList(),
            ),
          ),
        ],
        if (trip.fuel.isNotEmpty) ...[
          const SizedBox(height: 14),
          _FuelPanel(fuel: trip.fuel),
        ],
        if (_notices.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TripPanel(
            title: 'Multas y avisos confirmados',
            child: Column(
              children: _notices
                  .map(
                    (notice) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(notice.reason ?? 'Aviso'),
                      subtitle: Text(notice.location ?? notice.status),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openNotice(notice),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (trip.events.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TripPanel(
            title: 'Eventos del viaje',
            child: Column(
              children: trip.events
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        event.isConfirmedFine
                            ? Icons.gavel_outlined
                            : Icons.info_outline_rounded,
                      ),
                      title: Text(event.label),
                      subtitle: Text(
                        [
                          if (event.isPreventive && !event.isConfirmedFine)
                            'Estimación preventiva; no es una multa.',
                          if (event.detail != null) event.detail!,
                        ].join('\n'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _TripPanel extends StatelessWidget {
  const _TripPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3E8EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF667085))),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ReturnParkingPanel extends StatelessWidget {
  const _ReturnParkingPanel({
    required this.parking,
    required this.canRequest,
    required this.onRequest,
  });

  final VehicleReturnParking? parking;
  final bool canRequest;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => _TripPanel(
    title: 'Dársena de regreso',
    child: parking == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Este viaje todavía no tiene una dársena de regreso.'),
              if (canRequest) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRequest,
                  icon: const Icon(Icons.local_parking_rounded),
                  label: const Text('Solicitar dársena'),
                ),
              ],
            ],
          )
        : Column(
            children: [
              _DetailRow(label: 'Estado', value: _statusLabel(parking!.status)),
              _DetailRow(
                label: 'Dársena',
                value: [parking!.bay?.code, parking!.bay?.name]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ),
              _DetailRow(
                label: 'Horario',
                value: '${_dt(parking!.startsAt)} — ${_time(parking!.endsAt)}',
              ),
              if (parking!.resolutionNotes?.isNotEmpty == true)
                _DetailRow(
                  label: 'Resolución',
                  value: parking!.resolutionNotes!,
                ),
            ],
          ),
  );
}

class _FuelPanel extends StatelessWidget {
  const _FuelPanel({required this.fuel});
  final Map<String, dynamic> fuel;

  @override
  Widget build(BuildContext context) {
    final enabled = fuel['enabled'] as bool? ?? false;
    final rows = <(String, dynamic, String)>[
      ('Nivel inicial', fuel['start_level_pct'], '%'),
      ('Nivel final', fuel['end_level_pct'], '%'),
      ('Consumo medido', fuel['consumed_liters'], ' L'),
      ('Carga estimada', fuel['loaded_liters'], ' L'),
      ('Proyección del viaje', fuel['projected_liters'], ' L'),
      ('Distancia observada', fuel['actual_distance_km'], ' km'),
      ('Consumo cada 100 km', fuel['actual_consumption_l_per_100km'], ' L'),
    ].where((row) => row.$2 != null && '${row.$2}'.isNotEmpty).toList();
    final events = fuel['events'] is List ? fuel['events'] as List : const [];
    return _TripPanel(
      title: 'Combustible',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled
                ? 'Origen: telemetría GeoSat Extras. Las cargas se muestran como estimaciones hasta su conciliación.'
                : 'Esta unidad no tiene medición de combustible habilitada.',
            style: const TextStyle(color: Color(0xFF475467)),
          ),
          if (enabled && rows.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Todavía no hay mediciones disponibles para este viaje.',
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...rows.map(
              (row) => _DetailRow(label: row.$1, value: '${row.$2}${row.$3}'),
            ),
          ],
          if (events.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              '${events.length} carga${events.length == 1 ? '' : 's'} estimada${events.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class VehicleNoticeDetailScreen extends StatefulWidget {
  const VehicleNoticeDetailScreen({
    required this.gateway,
    required this.noticeId,
    super.key,
  });

  final VehiclesGateway gateway;
  final int noticeId;

  @override
  State<VehicleNoticeDetailScreen> createState() =>
      _VehicleNoticeDetailScreenState();
}

class _VehicleNoticeDetailScreenState extends State<VehicleNoticeDetailScreen> {
  VehicleNotice? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final notice = await widget.gateway.notice(widget.noticeId);
      if (!mounted) return;
      setState(() => _notice = notice);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de multa o aviso'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: _error != null
        ? _MessageList(message: _error!, onRetry: _load)
        : _notice == null
        ? const Center(child: CircularProgressIndicator())
        : _body(_notice!),
  );

  Widget _body(VehicleNotice notice) {
    final management = _readableEntries(notice.employeeManagement);
    final evidence = _readableEntries(notice.telemetryEvidence);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TripPanel(
          title: notice.reason ?? 'Multa o aviso',
          child: Column(
            children: [
              _DetailRow(label: 'Estado', value: _statusLabel(notice.status)),
              if (notice.noticeNumber != null)
                _DetailRow(label: 'Número', value: notice.noticeNumber!),
              if (notice.vehicleLabel != null)
                _DetailRow(label: 'Vehículo', value: notice.vehicleLabel!),
              if (notice.authority != null)
                _DetailRow(label: 'Autoridad', value: notice.authority!),
              if (notice.location != null)
                _DetailRow(label: 'Lugar', value: notice.location!),
              if (notice.infractionAt != null)
                _DetailRow(label: 'Fecha', value: _dt(notice.infractionAt!)),
              if (notice.amount != null)
                _DetailRow(
                  label: 'Importe',
                  value:
                      '${notice.currency ?? 'ARS'} ${_number(notice.amount!)}',
                ),
              if (notice.dueDate != null)
                _DetailRow(label: 'Vencimiento', value: _date(notice.dueDate!)),
            ],
          ),
        ),
        if (management.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TripPanel(
            title: 'Definición del portal',
            child: Column(
              children: management
                  .map((row) => _DetailRow(label: row.$1, value: row.$2))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _TripPanel(
          title: 'Evidencia GeoSat',
          child: evidence.isEmpty
              ? const Text('No hay evidencia disponible para este aviso.')
              : Column(
                  children: evidence
                      .map((row) => _DetailRow(label: row.$1, value: row.$2))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        const Text(
          'La app muestra la definición registrada en el portal. Las decisiones administrativas se realizan fuera de la app.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
      ],
    );
  }
}

class _TrajectoryMap extends StatefulWidget {
  const _TrajectoryMap({
    required this.points,
    required this.events,
    required this.live,
    this.fullscreen = false,
  });
  final List<VehicleTripPoint> points;
  final List<VehicleTripEvent> events;
  final bool live;
  final bool fullscreen;

  @override
  State<_TrajectoryMap> createState() => _TrajectoryMapState();
}

class _TrajectoryMapState extends State<_TrajectoryMap> {
  final MapController _controller = MapController();

  List<LatLng> get _coordinates => widget.points
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList(growable: false);

  void _fitRoute() {
    final coordinates = _coordinates;
    if (coordinates.length < 2) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: coordinates,
        padding: const EdgeInsets.all(44),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _openFullscreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullTrajectoryScreen(
          points: widget.points,
          events: widget.events,
          live: widget.live,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = _coordinates;
    final first = coordinates.first;
    final last = coordinates.last;
    final eventMarkers = widget.events
        .where((event) => event.hasPosition)
        .map(
          (event) => Marker(
            point: LatLng(event.latitude!, event.longitude!),
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () => _showEvent(context, event),
              child: _MapMarker(
                icon: _eventIcon(event.kind),
                color: _eventColor(event.kind),
              ),
            ),
          ),
        );
    final directionMarkers = <Marker>[];
    if (coordinates.length > 2) {
      final step = math.max(1, coordinates.length ~/ 10);
      for (var index = step; index < coordinates.length; index += step) {
        final previous = coordinates[index - 1];
        final current = coordinates[index];
        directionMarkers.add(
          Marker(
            point: current,
            width: 24,
            height: 24,
            child: Transform.rotate(
              angle: _bearingRadians(previous, current),
              child: const Icon(
                Icons.navigation_rounded,
                size: 20,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        );
      }
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: first,
            initialZoom: 15,
            initialCameraFit: coordinates.length > 1
                ? CameraFit.coordinates(
                    coordinates: coordinates,
                    padding: const EdgeInsets.all(34),
                    maxZoom: 17,
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.leivahermanos.leiva_app_interna',
              maxNativeZoom: 19,
            ),
            if (coordinates.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: coordinates,
                    color: const Color(0xFF2563EB),
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: first,
                  width: 38,
                  height: 38,
                  child: const _MapMarker(
                    icon: Icons.trip_origin_rounded,
                    color: Color(0xFF059669),
                  ),
                ),
                if (coordinates.length > 1)
                  Marker(
                    point: last,
                    width: 42,
                    height: 42,
                    child: _MapMarker(
                      icon: widget.live
                          ? Icons.directions_car_rounded
                          : Icons.location_on_rounded,
                      color: widget.live
                          ? const Color(0xFFE11D25)
                          : const Color(0xFF7C3AED),
                    ),
                  ),
                ...eventMarkers,
                ...directionMarkers,
              ],
            ),
            const RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              _MapControlButton(
                tooltip: 'Encuadrar recorrido',
                icon: Icons.center_focus_strong_rounded,
                onTap: _fitRoute,
              ),
              if (!widget.fullscreen) ...[
                const SizedBox(height: 8),
                _MapControlButton(
                  tooltip: 'Pantalla completa',
                  icon: Icons.fullscreen_rounded,
                  onTap: _openFullscreen,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Wrap(
                spacing: 12,
                children: [
                  _MapLegendDot(color: Color(0xFF059669), text: 'Inicio'),
                  _MapLegendDot(
                    color: Color(0xFF7C3AED),
                    text: 'Última posición',
                  ),
                  _MapLegendDot(color: Color(0xFFDC2626), text: 'Evento'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullTrajectoryScreen extends StatelessWidget {
  const _FullTrajectoryScreen({
    required this.points,
    required this.events,
    required this.live,
  });
  final List<VehicleTripPoint> points;
  final List<VehicleTripEvent> events;
  final bool live;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trayectoria completa')),
    body: SafeArea(
      child: _TrajectoryMap(
        points: points,
        events: events,
        live: live,
        fullscreen: true,
      ),
    ),
  );
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    borderRadius: BorderRadius.circular(10),
    child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
  );
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

double _bearingRadians(LatLng from, LatLng to) {
  final lat1 = from.latitudeInRad;
  final lat2 = to.latitudeInRad;
  final delta = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(delta) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(delta);
  return math.atan2(y, x);
}

IconData _eventIcon(String kind) => switch (kind) {
  'stop' || 'detention' => Icons.pause_circle_filled_rounded,
  'speed_camera' || 'speed_camera_estimate' => Icons.radar_rounded,
  'fine' => Icons.gavel_rounded,
  _ => Icons.warning_rounded,
};

Color _eventColor(String kind) => switch (kind) {
  'stop' || 'detention' => const Color(0xFFD18A00),
  'speed_camera' || 'speed_camera_estimate' => const Color(0xFF7C3AED),
  _ => const Color(0xFFDC2626),
};

void _showEvent(BuildContext context, VehicleTripEvent event) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if (event.at != null) ...[
              const SizedBox(height: 6),
              Text(
                _dt(event.at!),
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
            if (event.detail?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(event.detail!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

String _humanize(String value) => value.replaceAll('_', ' ');

class VehicleReturnParkingScreen extends StatefulWidget {
  const VehicleReturnParkingScreen({
    required this.gateway,
    required this.parkingGateway,
    required this.reservation,
    super.key,
  });

  final VehiclesGateway gateway;
  final ParkingGateway parkingGateway;
  final VehicleReservation reservation;

  @override
  State<VehicleReturnParkingScreen> createState() =>
      _VehicleReturnParkingScreenState();
}

class _VehicleReturnParkingScreenState
    extends State<VehicleReturnParkingScreen> {
  final _idempotencyKey = newIdempotencyKey();
  List<ParkingBranch> _branches = const [];
  List<ParkingBay> _bays = const [];
  int? _branchId;
  int? _bayId;
  int _minutes = 60;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await widget.parkingGateway.branches();
      if (!mounted) return;
      final expected =
          widget.reservation.expectedReturnBranchId ??
          widget.reservation.originBranchId;
      final selected = branches.any((branch) => branch.id == expected)
          ? expected
          : branches.firstOrNull?.id;
      setState(() {
        _branches = branches;
        _branchId = selected;
      });
      await _loadBays();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadBays() async {
    final branchId = _branchId;
    if (branchId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _bayId = null;
    });
    try {
      final bays = await widget.parkingGateway.bays(
        branchId: branchId,
        from: widget.reservation.endsAt,
        to: widget.reservation.endsAt.add(Duration(minutes: _minutes)),
        vehicleType: 'auto',
      );
      if (!mounted) return;
      final available = bays.where((bay) => bay.available).toList();
      setState(() {
        _bays = bays;
        _bayId = available.firstOrNull?.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _submit() async {
    final bayId = _bayId;
    if (bayId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createReturnParking(
        widget.reservation.id,
        VehicleReturnParkingDraft(
          idempotencyKey: _idempotencyKey,
          bayId: bayId,
          minutes: _minutes,
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
    final available = _bays.where((bay) => bay.available).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dársena de regreso'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Regreso previsto: ${_dt(widget.reservation.endsAt)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _branchId,
            decoration: const InputDecoration(labelText: 'Sucursal de regreso'),
            items: _branches
                .map(
                  (branch) => DropdownMenuItem(
                    value: branch.id,
                    child: Text(branch.name),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    setState(() => _branchId = value);
                    _loadBays();
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _minutes,
            decoration: const InputDecoration(labelText: 'Tiempo reservado'),
            items: const [30, 60, 90, 120]
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes minutos'),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _minutes = value);
                    _loadBays();
                  },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<int>(
              key: ValueKey('return-bay-$_branchId-$_minutes'),
              initialValue: _bayId,
              decoration: const InputDecoration(
                labelText: 'Dársena disponible',
              ),
              items: available
                  .map(
                    (bay) => DropdownMenuItem(
                      value: bay.id,
                      child: Text('${bay.code} · ${bay.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _bayId = value),
            ),
          if (!_loading && available.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No hay dársenas compatibles disponibles para ese regreso.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving || _loading || _bayId == null ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_parking_rounded),
            label: Text(_saving ? 'Enviando...' : 'Solicitar dársena'),
          ),
        ],
      ),
    );
  }
}

class CreateVehicleReservationScreen extends StatefulWidget {
  const CreateVehicleReservationScreen({
    required this.gateway,
    this.parkingGateway,
    super.key,
  });
  final VehiclesGateway gateway;
  final ParkingGateway? parkingGateway;

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
  final _distance = TextEditingController();
  final _luggage = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  List<VehicleOption> _vehicles = const [];
  int? _vehicleId;
  List<ParkingBranch> _parkingBranches = const [];
  List<ParkingBay> _returnBays = const [];
  bool _requestReturnParking = false;
  int? _returnBranchId;
  int? _returnBayId;
  int _returnMinutes = 60;
  bool _parkingLoading = false;
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
    _loadParkingBranches();
  }

  @override
  void dispose() {
    _purpose.dispose();
    _destination.dispose();
    _occupants.dispose();
    _distance.dispose();
    _luggage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadParkingBranches() async {
    final gateway = widget.parkingGateway;
    if (gateway == null) return;
    try {
      final branches = await gateway.branches();
      if (!mounted) return;
      setState(() {
        _parkingBranches = branches;
        _returnBranchId = branches.firstOrNull?.id;
      });
    } catch (_) {
      // La reserva de vehículo sigue disponible sin la opción de dársena.
    }
  }

  Future<void> _loadReturnBays() async {
    final gateway = widget.parkingGateway;
    final branchId = _returnBranchId;
    if (gateway == null || branchId == null || !_requestReturnParking) return;
    setState(() {
      _parkingLoading = true;
      _returnBayId = null;
    });
    try {
      final bays = await gateway.bays(
        branchId: branchId,
        from: _to,
        to: _to.add(Duration(minutes: _returnMinutes)),
        vehicleType: 'auto',
      );
      if (!mounted) return;
      final available = bays.where((bay) => bay.available).toList();
      setState(() {
        _returnBays = bays;
        _returnBayId = available.firstOrNull?.id;
        _parkingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _parkingLoading = false;
        _error = _message(error);
      });
    }
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
    if (_requestReturnParking) await _loadReturnBays();
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
          plannedDistanceKm: _decimal(_distance.text),
          estimatedLuggageKg: _decimal(_luggage.text),
          notes: _nullable(_notes.text),
          returnBayId: _requestReturnParking ? _returnBayId : null,
          returnParkingMinutes: _returnMinutes,
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Distancia planificada (km)',
                    ),
                    validator: _optionalNonNegative,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _luggage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Equipaje estimado (kg)',
                    ),
                    validator: _optionalNonNegative,
                  ),
                ),
              ],
            ),
            if (widget.parkingGateway != null &&
                _parkingBranches.isNotEmpty) ...[
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reservar dársena de regreso'),
                subtitle: const Text(
                  'La solicitud quedará pendiente para el horario de regreso.',
                ),
                value: _requestReturnParking,
                onChanged: (value) {
                  setState(() => _requestReturnParking = value);
                  if (value) _loadReturnBays();
                },
              ),
              if (_requestReturnParking) ...[
                DropdownButtonFormField<int>(
                  initialValue: _returnBranchId,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal de regreso',
                  ),
                  items: _parkingBranches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _returnBranchId = value);
                    _loadReturnBays();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _returnMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Tiempo reservado',
                  ),
                  items: const [30, 60, 90, 120]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minutos'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _returnMinutes = value);
                    _loadReturnBays();
                  },
                ),
                const SizedBox(height: 12),
                if (_parkingLoading)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'create-return-bay-$_returnBranchId-$_returnMinutes-${_to.toIso8601String()}',
                    ),
                    initialValue: _returnBayId,
                    decoration: const InputDecoration(
                      labelText: 'Dársena disponible',
                    ),
                    items: _returnBays
                        .where((bay) => bay.available)
                        .map(
                          (bay) => DropdownMenuItem(
                            value: bay.id,
                            child: Text('${bay.code} · ${bay.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _returnBayId = value),
                    validator: (value) => _requestReturnParking && value == null
                        ? 'Seleccioná una dársena disponible'
                        : null,
                  ),
              ],
            ],
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
double? _decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String? _optionalNonNegative(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = _decimal(text);
  if (parsed == null || parsed < 0) return 'Ingresá un valor válido';
  return null;
}

String _number(num value) {
  final rounded = value.toStringAsFixed(2);
  if (rounded.endsWith('.00')) return rounded.substring(0, rounded.length - 3);
  if (rounded.endsWith('0')) return rounded.substring(0, rounded.length - 1);
  return rounded;
}

String _date(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year}';

List<(String, String)> _readableEntries(dynamic value, [String prefix = '']) {
  final rows = <(String, String)>[];
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value == null || entry.value == '' || entry.value == false) {
        continue;
      }
      final label = prefix.isEmpty
          ? _humanize('${entry.key}')
          : '$prefix · ${_humanize('${entry.key}')}';
      if (entry.value is Map || entry.value is List) {
        rows.addAll(_readableEntries(entry.value, label));
      } else {
        rows.add((label, '${entry.value}'));
      }
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index++) {
      rows.addAll(
        _readableEntries(value[index], '$prefix ${index + 1}'.trim()),
      );
    }
  } else if (value != null) {
    rows.add((prefix.isEmpty ? 'Detalle' : prefix, '$value'));
  }
  return rows;
}

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
  'requiere_revision' => 'Requiere revisión',
  _ => value,
};
