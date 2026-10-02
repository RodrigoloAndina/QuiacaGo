import 'package:flutter_test/flutter_test.dart';
import 'package:quiaca_go_conductor/services/tariff_service.dart';
import 'package:quiaca_go_conductor/services/trip_service.dart';
import 'package:quiaca_go_conductor/services/registration_validator.dart';
import 'package:quiaca_go_conductor/services/auth_service.dart';

void main() {
  group('TariffService', () {
    test('aplica tarifa diurna entre las 06 y las 22', () {
      expect(TariffService.calcularPrecio(dateTime: DateTime(2026, 8, 25, 12)),
          2500);
    });

    test('mantiene tarifa diurna durante la noche', () {
      expect(TariffService.calcularPrecio(dateTime: DateTime(2026, 8, 25, 22)),
          2500);
    });

    test('mantiene tarifa diurna en feriados', () {
      expect(
          TariffService.calcularPrecio(
              dateTime: DateTime(2026, 8, 25, 12), esFeriado: true),
          2500);
    });
  });

  group('TripModel', () {
    test('conserva todos los datos canónicos de una oferta', () {
      final trip = TripModel.fromMap({
        'id': 'trip-1',
        'passenger_name': 'Ana',
        'passenger_phone': '3884000000',
        'pickup_address': 'Plaza Central',
        'pickup_lat': -22.10,
        'pickup_lng': -65.60,
        'destination_address': 'Terminal',
        'destination_lat': -22.11,
        'destination_lng': -65.59,
        'fare_amount': 2500,
        'pin_code': '1234',
        'finish_code': '5678',
        'status': 'requested',
      });

      expect(trip.passengerName, 'Ana');
      expect(trip.pickupAddress, 'Plaza Central');
      expect(trip.destinationAddress, 'Terminal');
      expect(trip.fareAmount, 2500);
    });

    test('acepta columnas legadas y montos serializados como texto', () {
      final trip = TripModel.fromMap({
        'id': 'trip-2',
        'pasajero_nombre': 'Luis',
        'origen': 'Hospital',
        'destino': 'Terminal',
        'tarifa': '2500.00',
        'estado': 'REQUESTED',
      });

      expect(trip.passengerName, 'Luis');
      expect(trip.pickupAddress, 'Hospital');
      expect(trip.destinationAddress, 'Terminal');
      expect(trip.fareAmount, 2500);
      expect(trip.status, 'requested');
    });
  });

  group('Cancelaciones y suspensiones', () {
    test('interpreta la respuesta de cancelación del servidor', () {
      final result = TripCancellationResult.fromMap({
        'success': true,
        'outcome': 'reassigned',
        'message': 'Buscando otro conductor',
      });
      expect(result.success, isTrue);
      expect(result.outcome, 'reassigned');
    });

    test('detecta una suspensión vigente y omite una vencida', () {
      expect(
          AuthService.suspensionMessage({
            'account_suspended_until': '2100-01-10T00:00:00Z',
            'account_suspension_reason': 'Cancelaciones recurrentes',
          }),
          contains('Cancelaciones recurrentes'));
      expect(
          AuthService.suspensionMessage({
            'account_suspended_until': '2020-01-10T00:00:00Z',
          }),
          isNull);
    });
  });

  group('RegistrationValidator', () {
    test('acepta datos argentinos válidos', () {
      expect(RegistrationValidator.email('persona@correo.com'), isNull);
      expect(RegistrationValidator.phone('+54 9 3885 401234'), isNull);
      expect(RegistrationValidator.dni('38.450.123'), isNull);
      expect(RegistrationValidator.plate('AB 123 CD'), isNull);
      expect(RegistrationValidator.password('Taxi2026'), isNull);
    });

    test('rechaza datos incompletos y contraseñas diferentes', () {
      expect(RegistrationValidator.email('correo-invalido'), isNotNull);
      expect(RegistrationValidator.phone('1234'), isNotNull);
      expect(RegistrationValidator.dni('123'), isNotNull);
      expect(RegistrationValidator.plate('TAXI'), isNotNull);
      expect(RegistrationValidator.password('12345678'), isNotNull);
      expect(RegistrationValidator.passwordConfirmation('otra', 'Taxi2026'),
          isNotNull);
    });
  });
}
