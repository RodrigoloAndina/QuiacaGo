import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const endpoint = String.fromEnvironment('ROUTING_URL',
      defaultValue: 'https://router.project-osrm.org');
  static final _cache = <String, List<LatLng>>{};
  /// Obtiene la geometría exacta de las calles desde la API de OSRM (Open Source Routing Machine)
  static Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    final key = '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)};${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final url = Uri.parse(
        '$endpoint/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates =
              data['routes'][0]['geometry']['coordinates'] as List;
          final result = coordinates.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();
          if (_cache.length >= 32) _cache.remove(_cache.keys.first);
          _cache[key] = result;
          return result;
        }
      }
    } catch (_) {
      // Fallback si no hay conexión a la API OSRM
    }

    return [];
  }
}
