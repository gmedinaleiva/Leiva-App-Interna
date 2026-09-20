class VehicleOption {
  const VehicleOption({
    required this.id,
    required this.label,
    required this.available,
    this.licensePlate,
    this.brand,
    this.model,
    this.passengerCapacity,
    this.unavailableReason,
  });

  factory VehicleOption.fromJson(Map<String, dynamic> json) => VehicleOption(
    id: json['id'] as int,
    label: json['label'] as String? ?? 'Vehículo',
    available: json['available'] as bool? ?? false,
    licensePlate: json['license_plate'] as String?,
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    passengerCapacity: json['passenger_capacity'] as int?,
    unavailableReason: json['unavailable_reason'] as String?,
  );

  final int id;
  final String label;
  final bool available;
  final String? licensePlate;
  final String? brand;
  final String? model;
  final int? passengerCapacity;
  final String? unavailableReason;
}

class ReservedVehicle {
  const ReservedVehicle({
    required this.id,
    required this.label,
    this.licensePlate,
  });

  factory ReservedVehicle.fromJson(Map<String, dynamic> json) =>
      ReservedVehicle(
        id: json['id'] as int,
        label: json['label'] as String? ?? 'Vehículo',
        licensePlate: json['license_plate'] as String?,
      );

  final int id;
  final String label;
  final String? licensePlate;
}

class VehicleReservation {
  const VehicleReservation({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.vehicle,
    this.purpose,
    this.destination,
    this.notes,
    this.originBranchId,
    this.expectedReturnBranchId,
    this.plannedDistanceKm,
    this.actualDistanceKm,
    this.occupantCount,
    this.estimatedLuggageKg,
    this.fuel,
    this.returnParking,
  });

  factory VehicleReservation.fromJson(Map<String, dynamic> json) =>
      VehicleReservation(
        id: json['id'] as int,
        status: json['status'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        vehicle: json['vehicle'] is Map<String, dynamic>
            ? ReservedVehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
            : null,
        purpose: json['purpose'] as String?,
        destination: json['destination'] as String?,
        notes: json['notes'] as String?,
        originBranchId: json['origin_branch_id'] as int?,
        expectedReturnBranchId: json['expected_return_branch_id'] as int?,
        plannedDistanceKm: (json['planned_distance_km'] as num?)?.toDouble(),
        actualDistanceKm: (json['actual_distance_km'] as num?)?.toDouble(),
        occupantCount: json['occupant_count'] as int?,
        estimatedLuggageKg: (json['estimated_luggage_kg'] as num?)?.toDouble(),
        fuel: json['fuel'] is Map<String, dynamic>
            ? Map<String, dynamic>.unmodifiable(
                json['fuel'] as Map<String, dynamic>,
              )
            : null,
        returnParking: json['return_parking'] is Map<String, dynamic>
            ? VehicleReturnParking.fromJson(
                json['return_parking'] as Map<String, dynamic>,
              )
            : null,
      );

  final int id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservedVehicle? vehicle;
  final String? purpose;
  final String? destination;
  final String? notes;
  final int? originBranchId;
  final int? expectedReturnBranchId;
  final double? plannedDistanceKm;
  final double? actualDistanceKm;
  final int? occupantCount;
  final double? estimatedLuggageKg;
  final Map<String, dynamic>? fuel;
  final VehicleReturnParking? returnParking;

  String? get nextAction => switch (status.toLowerCase()) {
    'aprobada' || 'approved' => 'start',
    'en_uso' || 'in_use' => 'finish',
    _ => null,
  };

  bool get canCancel => const {
    'pendiente',
    'pending',
    'aprobada',
    'approved',
  }.contains(status.toLowerCase());
}

class VehicleReservationDraft {
  const VehicleReservationDraft({
    required this.idempotencyKey,
    required this.vehicleId,
    required this.startsAt,
    required this.endsAt,
    this.purpose,
    this.destination,
    this.occupantCount,
    this.plannedDistanceKm,
    this.estimatedLuggageKg,
    this.notes,
    this.returnBayId,
    this.returnParkingMinutes = 60,
  });

  final String idempotencyKey;
  final int vehicleId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? purpose;
  final String? destination;
  final int? occupantCount;
  final double? plannedDistanceKm;
  final double? estimatedLuggageKg;
  final String? notes;
  final int? returnBayId;
  final int returnParkingMinutes;
}

class VehicleReturnParking {
  const VehicleReturnParking({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.bay,
    this.resolutionNotes,
  });

  factory VehicleReturnParking.fromJson(Map<String, dynamic> json) =>
      VehicleReturnParking(
        id: json['id'] as int,
        status: json['status'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        bay: json['bay'] is Map<String, dynamic>
            ? VehicleReturnBay.fromJson(json['bay'] as Map<String, dynamic>)
            : null,
        resolutionNotes: json['resolution_notes'] as String?,
      );

  final int id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final VehicleReturnBay? bay;
  final String? resolutionNotes;
}

class VehicleReturnBay {
  const VehicleReturnBay({
    required this.id,
    required this.branchId,
    required this.code,
    required this.name,
  });

  factory VehicleReturnBay.fromJson(Map<String, dynamic> json) =>
      VehicleReturnBay(
        id: json['id'] as int,
        branchId: json['branch_id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? 'Dársena',
      );

  final int id;
  final int branchId;
  final String code;
  final String name;
}

class VehicleReturnParkingDraft {
  const VehicleReturnParkingDraft({
    required this.idempotencyKey,
    required this.bayId,
    this.minutes = 60,
  });

  final String idempotencyKey;
  final int bayId;
  final int minutes;
}

class VehicleTripPoint {
  const VehicleTripPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.at,
  });

  factory VehicleTripPoint.fromJson(Map<String, dynamic> json) =>
      VehicleTripPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num?)?.toDouble() ?? 0,
        at: json['at'] == null
            ? null
            : DateTime.tryParse(json['at'] as String)?.toLocal(),
      );

  final double latitude;
  final double longitude;
  final double speed;
  final DateTime? at;
}

class VehicleTripEvent {
  const VehicleTripEvent({
    required this.kind,
    required this.label,
    this.detail,
    this.at,
    this.latitude,
    this.longitude,
    this.raw = const {},
  });

  factory VehicleTripEvent.fromJson(Map<String, dynamic> json) =>
      VehicleTripEvent(
        kind: json['kind'] as String? ?? 'event',
        label: json['label'] as String? ?? 'Evento',
        detail: json['detail'] as String?,
        at: json['at'] == null
            ? null
            : DateTime.tryParse(json['at'] as String)?.toLocal(),
        latitude: (json['lat'] as num? ?? json['latitude'] as num?)?.toDouble(),
        longitude: (json['lng'] as num? ?? json['longitude'] as num?)
            ?.toDouble(),
        raw: Map<String, dynamic>.unmodifiable(json),
      );

  final String kind;
  final String label;
  final String? detail;
  final DateTime? at;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> raw;

  bool get hasPosition => latitude != null && longitude != null;

  bool get isConfirmedFine => kind == 'fine';
  bool get isPreventive => const {
    'speed_sustained',
    'speed_brief',
    'speed_camera_estimate',
    'speed_camera',
  }.contains(kind);
}

class VehicleTripView {
  const VehicleTripView({
    required this.status,
    required this.summary,
    required this.points,
    required this.events,
    required this.live,
    required this.fuel,
  });

  factory VehicleTripView.fromJson(Map<String, dynamic> json) =>
      VehicleTripView(
        status: json['status'] as String? ?? '',
        summary: Map<String, dynamic>.unmodifiable(
          json['summary'] as Map<String, dynamic>? ?? const {},
        ),
        points: _vehicleMaps(json['points'])
            .where((item) => item['lat'] is num && item['lng'] is num)
            .map(VehicleTripPoint.fromJson)
            .toList(),
        events: _vehicleMaps(json['events'])
            .map(VehicleTripEvent.fromJson)
            .toList(),
        live: Map<String, dynamic>.unmodifiable(
          json['live'] as Map<String, dynamic>? ?? const {},
        ),
        fuel: Map<String, dynamic>.unmodifiable(
          json['fuel'] as Map<String, dynamic>? ?? const {},
        ),
      );

  final String status;
  final Map<String, dynamic> summary;
  final List<VehicleTripPoint> points;
  final List<VehicleTripEvent> events;
  final Map<String, dynamic> live;
  final Map<String, dynamic> fuel;
}

class VehicleNotice {
  const VehicleNotice({
    required this.id,
    required this.status,
    this.reason,
    this.amount,
    this.currency,
    this.location,
    this.infractionAt,
    this.reservationId,
    this.noticeNumber,
    this.authority,
    this.dueDate,
    this.vehicleLabel,
    this.employeeManagement = const {},
    this.hasEvidence = false,
    this.telemetryEvidence,
  });

  factory VehicleNotice.fromJson(Map<String, dynamic> json) => VehicleNotice(
    id: json['id'] as int,
    status: json['status'] as String,
    reason: json['reason'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    location: json['location'] as String?,
    infractionAt: json['infraction_at'] == null
        ? null
        : DateTime.tryParse(json['infraction_at'] as String)?.toLocal(),
    reservationId: json['reservation_id'] as int?,
    noticeNumber: json['notice_number'] as String?,
    authority: json['authority'] as String?,
    dueDate: json['due_date'] == null
        ? null
        : DateTime.tryParse(json['due_date'] as String),
    vehicleLabel: json['vehicle'] is Map<String, dynamic>
        ? (json['vehicle'] as Map<String, dynamic>)['label'] as String?
        : null,
    employeeManagement: Map<String, dynamic>.unmodifiable(
      json['employee_management'] as Map<String, dynamic>? ?? const {},
    ),
    hasEvidence: json['has_evidence'] as bool? ?? false,
    telemetryEvidence: json['telemetry_evidence'],
  );

  final int id;
  final String status;
  final String? reason;
  final double? amount;
  final String? currency;
  final String? location;
  final DateTime? infractionAt;
  final int? reservationId;
  final String? noticeNumber;
  final String? authority;
  final DateTime? dueDate;
  final String? vehicleLabel;
  final Map<String, dynamic> employeeManagement;
  final bool hasEvidence;
  final dynamic telemetryEvidence;
}

List<Map<String, dynamic>> _vehicleMaps(dynamic value) {
  if (value is! List) return const [];
  return value.cast<Map<String, dynamic>>();
}
