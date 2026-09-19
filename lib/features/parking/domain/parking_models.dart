class ParkingBranch {
  const ParkingBranch({required this.id, required this.name});

  factory ParkingBranch.fromJson(Map<String, dynamic> json) =>
      ParkingBranch(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class ParkingBay {
  const ParkingBay({
    required this.id,
    required this.branchId,
    required this.code,
    required this.name,
    required this.available,
    this.sector,
    this.unavailableReason,
  });

  factory ParkingBay.fromJson(Map<String, dynamic> json) => ParkingBay(
    id: json['id'] as int,
    branchId: json['branch_id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String,
    available: json['available'] as bool? ?? false,
    sector: json['sector'] as String?,
    unavailableReason: json['unavailable_reason'] as String?,
  );

  factory ParkingBay.fromRequestJson(Map<String, dynamic> json) => ParkingBay(
    id: json['id'] as int,
    branchId: json['branch_id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String,
    available: true,
    sector: json['sector'] as String?,
  );

  final int id;
  final int branchId;
  final String code;
  final String name;
  final bool available;
  final String? sector;
  final String? unavailableReason;
}

class ParkingRequest {
  const ParkingRequest({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.vehicleType,
    this.bay,
    this.plate,
    this.purpose,
    this.resolutionNotes,
    this.meetingRoomReservationId,
    this.geosatReservationId,
  });

  factory ParkingRequest.fromJson(Map<String, dynamic> json) => ParkingRequest(
    id: json['id'] as int,
    status: json['status'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    vehicleType: json['vehicle_type'] as String? ?? 'auto',
    bay: json['bay'] is Map<String, dynamic>
        ? ParkingBay.fromRequestJson(json['bay'] as Map<String, dynamic>)
        : null,
    plate: json['plate'] as String?,
    purpose: json['purpose'] as String?,
    resolutionNotes: json['resolution_notes'] as String?,
    meetingRoomReservationId: json['meeting_room_reservation_id'] as int?,
    geosatReservationId: json['geosat_reservation_id'] as int?,
  );

  final int id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String vehicleType;
  final ParkingBay? bay;
  final String? plate;
  final String? purpose;
  final String? resolutionNotes;
  final int? meetingRoomReservationId;
  final int? geosatReservationId;

  bool get canCancel => const {
    'pendiente',
    'pending',
    'aprobada',
    'approved',
  }.contains(status.toLowerCase());
}

class ParkingRequestDraft {
  const ParkingRequestDraft({
    required this.idempotencyKey,
    required this.bayId,
    required this.startsAt,
    required this.endsAt,
    required this.vehicleType,
    this.plate,
    this.purpose,
    this.notes,
  });

  final String idempotencyKey;
  final int bayId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String vehicleType;
  final String? plate;
  final String? purpose;
  final String? notes;
}
