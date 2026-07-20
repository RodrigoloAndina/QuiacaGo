import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  /// Obtiene la geometría exacta de las calles desde la API de OSRM (Open Source Routing Machine)
  static Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();
        }
      }
    } catch (_) {
      // Fallback si no hay conexión a la API OSRM
    }

    // Ruta por defecto adaptada a la cuadrícula de calles de La Quiaca
    return [
      start,
      LatLng(start.latitude, end.longitude),
      end,
    ];
  }
}
