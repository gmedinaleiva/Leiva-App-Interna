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
      );

  final int id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservedVehicle? vehicle;
  final String? purpose;
  final String? destination;
  final String? notes;

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
    this.notes,
  });

  final String idempotencyKey;
  final int vehicleId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? purpose;
  final String? destination;
  final int? occupantCount;
  final String? notes;
}
