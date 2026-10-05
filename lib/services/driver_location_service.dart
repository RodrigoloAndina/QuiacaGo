import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';
import 'runtime_policy.dart';

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
  static String? lastPublishError;
  static Future<int?> availableCount() async {
    try {
      final result = await _supabase.rpc('available_driver_count');
      return result is num ? result.toInt() : int.tryParse('$result');
    } catch (_) {
      return null;
    }
  }

  /// Publica o actualiza la ubicación GPS del conductor en Supabase (UPSERT)
  static Future<bool> publicarUbicacion({
    required String driverId,
    required double latitude,
    required double longitude,
    String driverName = '',
    String vehicleInfo = '',
    String plate = '',
  }) async {
    lastPublishError = null;
    try {
      final authenticatedId = _supabase.auth.currentUser?.id;
      if (authenticatedId == null || authenticatedId != driverId) {
        lastPublishError = 'La sesión del conductor no es válida.';
        return false;
      }
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
      return true;
    } catch (e) {
      lastPublishError = e.toString();
      print('[DriverLocationService] Error publicando ubicación: $e');
      return false;
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
  static Future<List<DriverLocationModel>>
      obtenerConductoresDisponibles() async {
    try {
      final activeSince =
          DateTime.now().toUtc().subtract(AppRuntimePolicy.locationFreshness);
      final data = await _supabase
          .from('driver_locations')
          .select()
          .eq('is_online', true)
          .gte('updated_at', activeSince.toIso8601String())
          .limit(50);

      if (data.isNotEmpty) {
        return data.map((item) => DriverLocationModel.fromMap(item)).toList();
      }
    } catch (e) {
      print('[DriverLocationService] Error obteniendo conductores: $e');
    }
    return [];
  }

  /// Obtiene la ubicación actual de un conductor específico (para seguimiento en tiempo real)
  static Future<DriverLocationModel?> obtenerUbicacionConductor(
      String driverId) async {
    try {
      final activeSince =
          DateTime.now().toUtc().subtract(AppRuntimePolicy.locationFreshness);
      final data = await _supabase
          .from('driver_locations')
          .select()
          .eq('driver_id', driverId)
          .eq('is_online', true)
          .gte('updated_at', activeSince.toIso8601String())
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
