import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';

class DriverLocationModel {
  final String driverId;
  final String driverName;
  final String vehicleInfo;
  final String plate;
  final double latitude;
  final double longitude;
  final bool isOnline;

  DriverLocationModel({
    required this.driverId,
    required this.driverName,
    required this.vehicleInfo,
    required this.plate,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
  });

  LatLng get posicion => LatLng(latitude, longitude);

  factory DriverLocationModel.fromMap(Map<String, dynamic> map) {
    return DriverLocationModel(
      driverId: map['driver_id']?.toString() ?? '',
      driverName: map['driver_name']?.toString() ?? '',
      vehicleInfo: map['vehicle_info']?.toString() ?? '',
      plate: map['plate']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      isOnline: map['is_online'] == true,
    );
  }
}

class DriverLocationService {
  static final _supabase = SupabaseService().client;

  /// Publica o actualiza la ubicación GPS del conductor en Supabase (UPSERT)
  static Future<void> publicarUbicacion({
    required String driverId,
    required double latitude,
    required double longitude,
    String driverName = '',
    String vehicleInfo = '',
    String plate = '',
  }) async {
    try {
      await _supabase.from('driver_locations').upsert({
        'driver_id': driverId,
        'driver_name': driverName,
        'vehicle_info': vehicleInfo,
        'plate': plate,
        'latitude': latitude,
        'longitude': longitude,
        'is_online': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'driver_id');
    } catch (e) {
      // Log silencioso para no bloquear la app
      print('[DriverLocationService] Error publicando ubicación: $e');
    }
  }

  /// Marca al conductor como desconectado
  static Future<void> desconectar(String driverId) async {
    try {
      await _supabase.from('driver_locations').update({
        'is_online': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('driver_id', driverId);
    } catch (e) {
      print('[DriverLocationService] Error desconectando: $e');
    }
  }

  /// Obtiene la lista de conductores disponibles (is_online = true) para mostrar en el mapa del pasajero
  static Future<List<DriverLocationModel>> obtenerConductoresDisponibles() async {
    try {
      final data = await _supabase
          .from('driver_locations')
          .select()
          .eq('is_online', true);

      if (data is List && data.isNotEmpty) {
        return data.map((item) => DriverLocationModel.fromMap(item)).toList();
      }
    } catch (e) {
      print('[DriverLocationService] Error obteniendo conductores: $e');
    }
    return [];
  }

  /// Obtiene la ubicación actual de un conductor específico (para seguimiento en tiempo real)
  static Future<DriverLocationModel?> obtenerUbicacionConductor(String driverId) async {
    try {
      final data = await _supabase
          .from('driver_locations')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();

      if (data != null) {
        return DriverLocationModel.fromMap(data);
      }
    } catch (e) {
      print('[DriverLocationService] Error obteniendo ubicación conductor: $e');
    }
    return null;
  }
}
