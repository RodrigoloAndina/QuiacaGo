import '../models/trip.dart';
import '../core/constants/app_constants.dart';

abstract class TripRepository {
  Future<Trip> createTripRequest({
    required String origen,
    required String destino,
    required double tarifa,
    required String pasajeroNombre,
    required String pasajeroTelefono,
  });

  Future<bool> acceptTrip(String tripId, String driverId);
  Future<bool> validatePin(String tripId, String pinInput);
  Future<bool> updateTripStatus(String tripId, TripStatus status);
  Stream<Trip?> getActiveTripStream(String tripId);
  Future<List<Trip>> getDriverTripHistory(String driverId);
  Future<List<Trip>> getPassengerTripHistory(String passengerId);
}

class TripRepositoryImpl implements TripRepository {
  final Map<String, Trip> _mockDb = {};

  @override
  Future<Trip> createTripRequest({
    required String origen,
    required String destino,
    required double tarifa,
    required String pasajeroNombre,
    required String pasajeroTelefono,
  }) async {
    final trip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      origen: origen,
      destino: destino,
      tarifa: tarifa,
      estado: TripStatus.REQUESTED,
      fecha: DateTime.now(),
      codigoSeguridad: '4821', // PIN de 4 dígitos Stitch
      pasajeroNombre: pasajeroNombre,
      pasajeroTelefono: pasajeroTelefono,
      origenLat: AppConstants.laQuiacaLat,
      origenLng: AppConstants.laQuiacaLng,
      destinoLat: -22.1050,
      destinoLng: -65.6010,
    );

    _mockDb[trip.id] = trip;
    return trip;
  }

  @override
  Future<bool> acceptTrip(String tripId, String driverId) async {
    final trip = _mockDb[tripId];
    if (trip != null) {
      _mockDb[tripId] = trip.copyWith(estado: TripStatus.ACCEPTED);
      return true;
    }
    return true;
  }

  @override
  Future<bool> validatePin(String tripId, String pinInput) async {
    // Validar PIN de 4 dígitos contra el viaje
    final trip = _mockDb[tripId];
    if (trip != null) {
      return trip.codigoSeguridad == pinInput;
    }
    return pinInput == '4821' || pinInput == '1234' || pinInput == '8205';
  }

  @override
  Future<bool> updateTripStatus(String tripId, TripStatus status) async {
    final trip = _mockDb[tripId];
    if (trip != null) {
      _mockDb[tripId] = trip.copyWith(estado: status);
    }
    return true;
  }

  @override
  Stream<Trip?> getActiveTripStream(String tripId) async* {
    yield _mockDb[tripId];
  }

  @override
  Future<List<Trip>> getDriverTripHistory(String driverId) async {
    return [
      Trip(
        id: 'trip-101',
        origen: 'Plaza Central',
        destino: 'Terminal de Ómnibus',
        tarifa: 1200.0,
        estado: TripStatus.FINISHED,
        fecha: DateTime.now().subtract(const Duration(hours: 1)),
        codigoSeguridad: '4821',
        pasajeroNombre: 'Juan P.',
        pasajeroTelefono: '+54 388 555-0123',
      ),
      Trip(
        id: 'trip-102',
        origen: 'Av. Sarmiento 345',
        destino: 'Hospital Jorge Uro',
        tarifa: 1850.0,
        estado: TripStatus.FINISHED,
        fecha: DateTime.now().subtract(const Duration(hours: 3)),
        codigoSeguridad: '8205',
        pasajeroNombre: 'María Gómez',
        pasajeroTelefono: '+54 388 401234',
      ),
    ];
  }

  @override
  Future<List<Trip>> getPassengerTripHistory(String passengerId) async {
    return [
      Trip(
        id: 'trip-201',
        origen: 'Av. Sarmiento 345',
        destino: 'Terminal de Ómnibus',
        tarifa: 1850.0,
        estado: TripStatus.FINISHED,
        fecha: DateTime.now().subtract(const Duration(minutes: 40)),
        codigoSeguridad: '4821',
        pasajeroNombre: 'Carlos',
        pasajeroTelefono: '+54 388 401234',
      ),
      Trip(
        id: 'trip-202',
        origen: 'Plaza Central',
        destino: 'Hospital Jorge Uro',
        tarifa: 1400.0,
        estado: TripStatus.FINISHED,
        fecha: DateTime.now().subtract(const Duration(days: 1)),
        codigoSeguridad: '8205',
        pasajeroNombre: 'Roberto',
        pasajeroTelefono: '+54 388 777888',
      ),
    ];
  }
}
