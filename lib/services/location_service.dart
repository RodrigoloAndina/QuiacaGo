import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';

class LocationService {
  /// Obtiene la posición GPS actual del celular o tablet del conductor
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getLastKnownOrCenter();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _getLastKnownOrCenter();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _getLastKnownOrCenter();
      }

      // Intentar obtener última posición conocida rápido
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        // También iniciar actualización de GPS preciso de fondo
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((pos) {}).catchError((_) {});
        return LatLng(lastPos.latitude, lastPos.longitude);
      }

      // Obtener posición precisa actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _getLastKnownOrCenter();
    }
  }

  static Future<LatLng> _getLastKnownOrCenter() async {
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        return LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  }

  /// Escucha cambios de posición GPS en tiempo real a medida que el vehículo se desplaza
  static Stream<LatLng> getRealtimeLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}
