import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/expenses/domain/expense_models.dart';
import 'package:leiva_app_interna/features/parking/domain/parking_models.dart';
import 'package:leiva_app_interna/features/rooms/domain/room_models.dart';
import 'package:leiva_app_interna/features/vehicles/domain/vehicle_models.dart';

void main() {
  test('room detail keeps ownership, participants and visitor parking', () {
    final reservation = RoomReservation.fromJson({
      'id': 31,
      'status': 'confirmed',
      'title': 'Reunion operativa',
      'starts_at': '2026-09-20T12:00:00Z',
      'ends_at': '2026-09-20T13:00:00Z',
      'room': {
        'id': 4,
        'name': 'Sala Norte',
        'branch_id': 2,
        'branch_name': 'Central',
      },
      'organizer': {'id': 7, 'name': 'Organizador'},
      'responsible': {'id': 8, 'name': 'Responsable'},
      'participants': [
        {
          'id': 51,
          'kind': 'interno',
          'user_id': 12,
          'name': 'Participante interno',
        },
        {
          'id': 52,
          'kind': 'externo',
          'external_type': 'proveedor',
          'name': 'Visita externa',
          'organization': 'Proveedor SA',
          'email': 'visita@example.com',
        },
      ],
      'visitor_parking': [
        {
          'participant_name': 'Visita externa',
          'status': 'approved',
          'bay': {'id': 3, 'name': 'Darsena 3'},
        },
      ],
    });

    expect(reservation.room.branchId, 2);
    expect(reservation.organizerId, 7);
    expect(reservation.responsibleId, 8);
    expect(reservation.participants.first.userId, 12);
    expect(reservation.participants.last.externalType, 'proveedor');
    expect(reservation.visitorParking.single['status'], 'approved');
  });

  test('expense dashboard keeps trip relation and personal fines', () {
    final dashboard = ExpenseDashboard.fromJson({
      'capabilities': {'upload': true},
      'periods': <Map<String, dynamic>>[],
      'alerts': <Map<String, dynamic>>[],
      'records': [
        {
          'id': 9,
          'type': 'travel',
          'status': 'draft',
          'title': 'Combustible',
          'has_file': true,
          'reference': 'T-123',
          'geosat_reservation_id': 88,
        },
      ],
      'fines': [
        {
          'id': 6,
          'status': 'notified',
          'reason': 'Exceso de velocidad',
          'amount': 12000,
          'currency': 'ARS',
          'vehicle_label': 'AA123BB',
        },
      ],
    });

    expect(dashboard.records.single.reference, 'T-123');
    expect(dashboard.records.single.geosatReservationId, 88);
    expect(dashboard.fines.single.vehicleLabel, 'AA123BB');
    expect(dashboard.fines.single.amount, 12000);
  });

  test('parking history keeps cross-module links and resolution', () {
    final request = ParkingRequest.fromJson({
      'id': 14,
      'status': 'approved',
      'starts_at': '2026-09-20T12:00:00Z',
      'ends_at': '2026-09-20T13:00:00Z',
      'vehicle_type': 'auto',
      'meeting_room_reservation_id': 31,
      'geosat_reservation_id': 88,
      'resolution_notes': 'Asignada por Guardia',
      'bay': {'id': 3, 'branch_id': 2, 'name': 'Darsena 3', 'code': 'D3'},
    });

    expect(request.meetingRoomReservationId, 31);
    expect(request.geosatReservationId, 88);
    expect(request.resolutionNotes, 'Asignada por Guardia');
  });

  test('parses manager vehicle agenda without inferring trips', () {
    final item = VehicleAgendaItem.fromJson({
      'id': 7,
      'status': 'scheduled',
      'assignment_type': 'visita_cliente',
      'starts_at': '2026-09-21T12:00:00Z',
      'ends_at': '2026-09-21T14:00:00Z',
      'notes': 'Visita programada',
      'vehicle': {
        'id': 4,
        'label': 'AF 211 SZ',
        'license_plate': 'AF 211 SZ',
        'brand': 'Nissan',
        'model': 'Frontier',
      },
    });

    expect(item.status, 'scheduled');
    expect(item.vehicle.licensePlate, 'AF 211 SZ');
    expect(item.notes, 'Visita programada');
  });

  test('parses an authorized petty cash fund and open settlement', () {
    final fund = PettyCashFund.fromJson({
      'id': 5,
      'account_code': 'SIS-01',
      'name': 'Caja Sistemas',
      'currency': 'ARS',
      'settlement': {
        'id': 9,
        'period_start': '2026-09-01',
        'period_end': '2026-09-30',
      },
    });

    expect(fund.accountCode, 'SIS-01');
    expect(fund.settlementId, 9);
    expect(fund.periodEnd.day, 30);
  });
}
