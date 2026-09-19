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
    this.branchName,
  });

  factory ReservationRoom.fromJson(Map<String, dynamic> json) =>
      ReservationRoom(
        id: json['id'] as int,
        name: json['name'] as String,
        branchName: json['branch_name'] as String?,
      );

  final int id;
  final String name;
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
      );

  final int id;
  final String status;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservationRoom room;

  bool get canCancel => !const {
    'cancelled',
    'canceled',
    'completed',
  }.contains(status.toLowerCase());
}

class RoomReservationDraft {
  const RoomReservationDraft({
    required this.idempotencyKey,
    required this.roomId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.notes,
  });

  final String idempotencyKey;
  final int roomId;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
}
