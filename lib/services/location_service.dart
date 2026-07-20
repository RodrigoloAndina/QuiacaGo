import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_constants.dart';

class LocationService {
  /// Obtiene la posición GPS actual del celular del conductor
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 3));

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
    }
  }

  /// Escucha cambios de posición GPS en tiempo real
  static Stream<LatLng> getRealtimeLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}
