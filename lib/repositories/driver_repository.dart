import '../models/driver.dart';
import '../models/vehicle.dart';
import '../models/document.dart';
import '../models/earning.dart';
import '../core/constants/app_constants.dart';

abstract class DriverRepository {
  Future<bool> setStatus(String driverId, DriverStatus status);
  Future<bool> updateLocation(String driverId, double lat, double lng);
  Future<Earning> getEarnings(String driverId);
  Future<Vehicle> getVehicle(String driverId);
  Future<List<DriverDocument>> getDocuments(String driverId);
}

class DriverRepositoryImpl implements DriverRepository {
  @override
  Future<bool> setStatus(String driverId, DriverStatus status) async {
    return true;
  }

  @override
  Future<bool> updateLocation(String driverId, double lat, double lng) async {
    return true;
  }

  @override
  Future<Earning> getEarnings(String driverId) async {
    return Earning(
      hoy: 45250.0,
      semana: 186400.0,
      mes: 650000.0,
      viajesHoy: 14,
      viajesSemana: 78,
    );
  }

  @override
  Future<Vehicle> getVehicle(String driverId) async {
    return Vehicle(
      marca: 'Chevrolet',
      modelo: 'Corsa',
      color: 'Blanco',
      patente: 'ABC 123',
      numeroInterno: 'Móvil 042',
    );
  }

  @override
  Future<List<DriverDocument>> getDocuments(String driverId) async {
    return [
      DriverDocument(
        id: 'doc-1',
        titulo: 'Habilitación Municipal La Quiaca',
        estado: DocumentStatus.APPROVED,
        fechaVencimiento: DateTime(2026, 12, 15),
      ),
      DriverDocument(
        id: 'doc-2',
        titulo: 'Licencia de Conducir Cat. D1',
        estado: DocumentStatus.APPROVED,
        fechaVencimiento: DateTime(2027, 10, 10),
      ),
      DriverDocument(
        id: 'doc-3',
        titulo: 'Seguro del Automotor Poliza Taxi',
        estado: DocumentStatus.APPROVED,
        fechaVencimiento: DateTime(2026, 9, 1),
      ),
      DriverDocument(
        id: 'doc-4',
        titulo: 'Revision Técnica Obligatoria (VTV/RTO)',
        estado: DocumentStatus.APPROVED,
        fechaVencimiento: DateTime(2026, 8, 30),
      ),
    ];
  }
}
