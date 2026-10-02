import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';

class LocationService {
  static Future<String?> trackingUnavailableReason() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Activá la ubicación del teléfono para conectarte.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Debes permitir el acceso a la ubicación para conectarte.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Habilitá la ubicación para QuiacaGo desde Ajustes del teléfono.';
    }
    return null;
  }

  /// Obtiene la posición GPS real y precisa del sensor del dispositivo
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await _getLastKnownOrCenter();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await _getLastKnownOrCenter();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await _getLastKnownOrCenter();
      }

      // 1. Priorizar SIEMPRE la captura fresca del hardware GPS (Timeout 4s)
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        return LatLng(position.latitude, position.longitude);
      } catch (_) {
        // En caso de delay en la antena GPS, continuar al fallback
      }

      // 2. Fallback a última conocida o centro de La Quiaca
      return await _getLastKnownOrCenter();
    } catch (_) {
      return await _getLastKnownOrCenter();
    }
  }

  static Future<LatLng> _getLastKnownOrCenter() async {
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        // Verificar que la posición almacenada esté en un rango coherente de La Quiaca/Jujuy
        final distLat = (pos.latitude - AppConstants.laQuiacaLat).abs();
        if (distLat < 0.5) {
          // Dentro del radio urbano / regional de La Quiaca (~55 km)
          return LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}
    return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  }

  /// Escucha cambios de posición GPS en tiempo real a medida que el vehículo se desplaza
  static Stream<LatLng> getRealtimeLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}
