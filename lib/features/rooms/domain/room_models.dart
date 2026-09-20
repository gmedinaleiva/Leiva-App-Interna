class RoomBranch {
  const RoomBranch({required this.id, required this.code, required this.name});

  factory RoomBranch.fromJson(Map<String, dynamic> json) => RoomBranch(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String,
  );

  final int id;
  final String code;
  final String name;
}

class MeetingRoom {
  const MeetingRoom({
    required this.id,
    required this.branchId,
    required this.code,
    required this.name,
    required this.capacity,
    this.equipment,
  });

  factory MeetingRoom.fromJson(Map<String, dynamic> json) => MeetingRoom(
    id: json['id'] as int,
    branchId: json['branch_id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String,
    capacity: json['capacity'] as int? ?? 0,
    equipment: json['equipment'] as String?,
  );

  final int id;
  final int branchId;
  final String code;
  final String name;
  final int capacity;
  final String? equipment;
}

class RoomAvailability {
  const RoomAvailability({
    required this.roomId,
    required this.code,
    required this.name,
    required this.capacity,
    required this.available,
  });

  factory RoomAvailability.fromJson(Map<String, dynamic> json) =>
      RoomAvailability(
        roomId: json['room_id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String,
        capacity: json['capacity'] as int? ?? 0,
        available: json['available'] as bool? ?? false,
      );

  final int roomId;
  final String code;
  final String name;
  final int capacity;
  final bool available;
}

class ReservationRoom {
  const ReservationRoom({
    required this.id,
    required this.name,
    this.branchId,
    this.branchName,
  });

  factory ReservationRoom.fromJson(Map<String, dynamic> json) =>
      ReservationRoom(
        id: json['id'] as int,
        name: json['name'] as String,
        branchId: json['branch_id'] as int?,
        branchName: json['branch_name'] as String?,
      );

  final int id;
  final String name;
  final int? branchId;
  final String? branchName;
}

class RoomReservation {
  const RoomReservation({
    required this.id,
    required this.status,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.room,
    this.notes,
    this.participants = const [],
    this.visitorParking = const [],
    this.organizerId,
    this.responsibleId,
  });

  factory RoomReservation.fromJson(Map<String, dynamic> json) =>
      RoomReservation(
        id: json['id'] as int,
        status: json['status'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        room: ReservationRoom.fromJson(json['room'] as Map<String, dynamic>),
        participants: _roomMaps(json['participants'])
            .map(RoomParticipant.fromJson)
            .toList(),
        visitorParking: _roomMaps(json['visitor_parking']),
        organizerId: json['organizer'] is Map<String, dynamic>
            ? (json['organizer'] as Map<String, dynamic>)['id'] as int?
            : null,
        responsibleId: json['responsible'] is Map<String, dynamic>
            ? (json['responsible'] as Map<String, dynamic>)['id'] as int?
            : null,
      );

  final int id;
  final String status;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservationRoom room;
  final List<RoomParticipant> participants;
  final List<Map<String, dynamic>> visitorParking;
  final int? organizerId;
  final int? responsibleId;

  bool get canCancel => !const {
    'cancelled',
    'canceled',
    'completed',
  }.contains(status.toLowerCase());
}

class RoomParticipant {
  const RoomParticipant({
    required this.id,
    required this.kind,
    required this.name,
    this.organization,
    this.email,
    this.userId,
    this.externalType,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) =>
      RoomParticipant(
        id: json['id'] as int,
        kind: json['kind'] as String,
        name: json['name'] as String? ?? 'Participante',
        organization: json['organization'] as String?,
        email: json['email'] as String?,
        userId: json['user_id'] as int?,
        externalType: json['external_type'] as String?,
      );

  final int id;
  final String kind;
  final String name;
  final String? organization;
  final String? email;
  final int? userId;
  final String? externalType;

  bool get isExternal => kind == 'externo';
}

class VisitorParkingOption {
  const VisitorParkingOption({
    required this.id,
    required this.name,
    required this.hasActiveRequest,
    this.organization,
  });

  factory VisitorParkingOption.fromJson(Map<String, dynamic> json) =>
      VisitorParkingOption(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Visitante',
        organization: json['organization'] as String?,
        hasActiveRequest: json['has_active_request'] as bool? ?? false,
      );

  final int id;
  final String name;
  final String? organization;
  final bool hasActiveRequest;
}

class VisitorParkingBay {
  const VisitorParkingBay({
    required this.id,
    required this.name,
    required this.available,
    this.sector,
    this.unavailableReason,
  });

  factory VisitorParkingBay.fromJson(Map<String, dynamic> json) =>
      VisitorParkingBay(
        id: json['id'] as int,
        name: json['name'] as String,
        available: json['available'] as bool? ?? false,
        sector: json['sector'] as String?,
        unavailableReason: json['unavailable_reason'] as String?,
      );

  final int id;
  final String name;
  final bool available;
  final String? sector;
  final String? unavailableReason;
}

class VisitorParkingOptions {
  const VisitorParkingOptions({
    required this.visitors,
    required this.bays,
    required this.requests,
  });

  factory VisitorParkingOptions.fromJson(Map<String, dynamic> json) =>
      VisitorParkingOptions(
        visitors: _roomMaps(json['visitors'])
            .map(VisitorParkingOption.fromJson)
            .toList(),
        bays: _roomMaps(json['bays']).map(VisitorParkingBay.fromJson).toList(),
        requests: _roomMaps(json['requests']),
      );

  final List<VisitorParkingOption> visitors;
  final List<VisitorParkingBay> bays;
  final List<Map<String, dynamic>> requests;
}

class VisitorParkingDraft {
  const VisitorParkingDraft({
    required this.idempotencyKey,
    required this.participantId,
    required this.bayId,
    required this.vehicleType,
    this.plate,
    this.notes,
  });

  final String idempotencyKey;
  final int participantId;
  final int bayId;
  final String vehicleType;
  final String? plate;
  final String? notes;
}

class RoomReservationDraft {
  const RoomReservationDraft({
    required this.idempotencyKey,
    required this.roomId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.notes,
    this.internalParticipantIds = const [],
    this.externalParticipants = const [],
  });

  final String idempotencyKey;
  final int roomId;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<int> internalParticipantIds;
  final List<ExternalRoomParticipantDraft> externalParticipants;
}

class RoomParticipantOption {
  const RoomParticipantOption({
    required this.id,
    required this.name,
    required this.username,
    this.email,
  });

  factory RoomParticipantOption.fromJson(Map<String, dynamic> json) =>
      RoomParticipantOption(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String,
        email: json['email'] as String?,
      );

  final int id;
  final String name;
  final String username;
  final String? email;
}

class ExternalRoomParticipantDraft {
  const ExternalRoomParticipantDraft({
    required this.name,
    this.type = 'visita',
    this.organization,
    this.email,
  });

  final String type;
  final String name;
  final String? organization;
  final String? email;

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'organization': organization,
    'email': email,
  };
}

class RoomReservationUpdate {
  const RoomReservationUpdate({
    required this.roomId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.notes,
    this.internalParticipantIds = const [],
    this.externalParticipants = const [],
    this.rescheduleReason,
  });

  final int roomId;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<int> internalParticipantIds;
  final List<ExternalRoomParticipantDraft> externalParticipants;
  final String? rescheduleReason;
}

List<Map<String, dynamic>> _roomMaps(dynamic value) {
  if (value is! List) return const [];
  return value.cast<Map<String, dynamic>>();
}
