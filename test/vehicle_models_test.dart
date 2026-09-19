import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/vehicles/domain/vehicle_models.dart';

void main() {
  test('interpreta la reserva completa y su dársena de regreso', () {
    final reservation = VehicleReservation.fromJson({
      'id': 41,
      'status': 'pendiente',
      'starts_at': '2026-09-20T12:00:00Z',
      'ends_at': '2026-09-20T14:00:00Z',
      'origin_branch_id': 3,
      'expected_return_branch_id': 3,
      'planned_distance_km': 84.5,
      'actual_distance_km': null,
      'occupant_count': 3,
      'estimated_luggage_kg': 22.0,
      'fuel': {'start_level_pct': 76.0},
      'vehicle': {'id': 7, 'label': 'AG 874 EZ', 'license_plate': 'AG 874 EZ'},
      'return_parking': {
        'id': 91,
        'status': 'requiere_revision',
        'starts_at': '2026-09-20T14:00:00Z',
        'ends_at': '2026-09-20T15:00:00Z',
        'bay': {'id': 12, 'branch_id': 3, 'code': 'ECHA-P1-A04', 'name': 'A04'},
        'resolution_notes': 'Requiere reasignación.',
      },
    });

    expect(reservation.plannedDistanceKm, 84.5);
    expect(reservation.occupantCount, 3);
    expect(reservation.estimatedLuggageKg, 22);
    expect(reservation.returnParking?.status, 'requiere_revision');
    expect(reservation.returnParking?.bay?.code, 'ECHA-P1-A04');
    expect(
      reservation.returnParking?.resolutionNotes,
      'Requiere reasignación.',
    );
  });

  test('interpreta definición y evidencia de una multa propia', () {
    final notice = VehicleNotice.fromJson({
      'id': 17,
      'reservation_id': 41,
      'status': 'confirmed',
      'notice_number': 'A-123',
      'reason': 'Exceso de velocidad',
      'authority': 'Autoridad vial',
      'infraction_at': '2026-09-20T13:00:00Z',
      'due_date': '2026-10-20',
      'amount': 25000.0,
      'currency': 'ARS',
      'location': 'Ruta 9',
      'vehicle': {'id': 7, 'label': 'AG 874 EZ'},
      'employee_management': {'decision': 'informada'},
      'has_evidence': true,
      'telemetry_evidence': {'speed_kmh': 96, 'source': 'geosat'},
    });

    expect(notice.reservationId, 41);
    expect(notice.vehicleLabel, 'AG 874 EZ');
    expect(notice.employeeManagement['decision'], 'informada');
    expect(notice.hasEvidence, isTrue);
    expect((notice.telemetryEvidence as Map<String, dynamic>)['speed_kmh'], 96);
  });
}
