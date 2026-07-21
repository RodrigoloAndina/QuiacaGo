import 'dart:async';
import 'dart:math';
import 'supabase_service.dart';

class TripModel {
  final String id;
  final String passengerName;
  final String passengerPhone;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final double fareAmount;
  final String pinCode;
  final String status;
  final String? driverId;
  final String? driverName;
  final String? vehicleInfo;

  TripModel({
    required this.id,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.fareAmount,
    required this.pinCode,
    required this.status,
    this.driverId,
    this.driverName,
    this.vehicleInfo,
  });

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: map['id']?.toString() ?? '',
      passengerName: map['passenger_name']?.toString() ?? '',
      passengerPhone: map['passenger_phone']?.toString() ?? '',
      pickupAddress: map['pickup_address']?.toString() ?? '',
      pickupLat: (map['pickup_lat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (map['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      destinationAddress: map['destination_address']?.toString() ?? '',
      destinationLat: (map['destination_lat'] as num?)?.toDouble() ?? 0.0,
      destinationLng: (map['destination_lng'] as num?)?.toDouble() ?? 0.0,
      fareAmount: (map['fare_amount'] as num?)?.toDouble() ?? 0.0,
      pinCode: map['pin_code']?.toString() ?? '',
      status: map['status']?.toString() ?? 'requested',
      driverId: map['driver_id']?.toString(),
      driverName: map['driver_name']?.toString(),
      vehicleInfo: map['vehicle_info']?.toString(),
    );
  }
}

class TripService {
  static final _supabase = SupabaseService().client;

  /// Genera un PIN aleatorio de 4 dígitos único por viaje
  static String _generarPinAleatorio() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Solicita un nuevo viaje — INSERT en Supabase tabla 'trips'
  static Future<TripModel?> solicitarViaje({
    required String passengerName,
    required String passengerPhone,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required double fareAmount,
  }) async {
    final pinCode = _generarPinAleatorio();

    try {
      final response = await _supabase.from('trips').insert({
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'pickup_address': pickupAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'destination_address': destinationAddress,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'fare_amount': fareAmount,
        'pin_code': pinCode,
        'status': 'requested',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      return TripModel.fromMap(response);
    } catch (e) {
      print('[TripService] Error solicitando viaje: $e');
      return null;
    }
  }

  /// Obtiene viajes pendientes con status 'requested' (para el conductor)
  static Future<List<TripModel>> obtenerViajesPendientes() async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .eq('status', 'requested')
          .order('created_at', ascending: true)
          .limit(5);

      if (data is List && data.isNotEmpty) {
        return data.map((item) => TripModel.fromMap(item)).toList();
      }
    } catch (e) {
      print('[TripService] Error obteniendo viajes pendientes: $e');
    }
    return [];
  }

  /// El conductor acepta el viaje
  static Future<bool> aceptarViaje({
    required String tripId,
    required String driverId,
    required String driverName,
    required String vehicleInfo,
  }) async {
    try {
      await _supabase.from('trips').update({
        'status': 'accepted',
        'driver_id': driverId,
        'driver_name': driverName,
        'vehicle_info': vehicleInfo,
      }).eq('id', tripId);
      return true;
    } catch (e) {
      print('[TripService] Error aceptando viaje: $e');
      return false;
    }
  }

  /// El conductor marca que llegó al punto de recogida
  static Future<bool> marcarLlegada(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'arrived',
      }).eq('id', tripId);
      return true;
    } catch (e) {
      print('[TripService] Error marcando llegada: $e');
      return false;
    }
  }

  /// Valida el PIN del pasajero e inicia el viaje
  static Future<bool> validarPinIniciarViaje(String tripId, String pinIngresado) async {
    try {
      final data = await _supabase
          .from('trips')
          .select('pin_code')
          .eq('id', tripId)
          .single();

      if (data['pin_code'] == pinIngresado) {
        await _supabase.from('trips').update({
          'status': 'in_progress',
        }).eq('id', tripId);
        return true;
      }
      return false;
    } catch (e) {
      print('[TripService] Error validando PIN: $e');
      return false;
    }
  }

  /// Finaliza el viaje
  static Future<bool> finalizarViaje(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'completed',
      }).eq('id', tripId);
      return true;
    } catch (e) {
      print('[TripService] Error finalizando viaje: $e');
      return false;
    }
  }

  /// Cancela el viaje con motivo
  static Future<bool> cancelarViaje(String tripId, String motivo) async {
    try {
      await _supabase.from('trips').update({
        'status': 'cancelled',
      }).eq('id', tripId);
      return true;
    } catch (e) {
      print('[TripService] Error cancelando viaje: $e');
      return false;
    }
  }

  /// Obtiene un viaje específico por ID
  static Future<TripModel?> obtenerViaje(String tripId) async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .eq('id', tripId)
          .maybeSingle();

      if (data != null) {
        return TripModel.fromMap(data);
      }
    } catch (e) {
      print('[TripService] Error obteniendo viaje: $e');
    }
    return null;
  }

  /// Stream de Supabase Realtime para escuchar cambios en un viaje específico
  static Stream<TripModel> escucharViaje(String tripId) {
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((list) {
          if (list.isNotEmpty) {
            return TripModel.fromMap(list.first);
          }
          throw Exception('Viaje no encontrado');
        });
  }

  /// Stream de Supabase Realtime para escuchar NUEVOS viajes con status 'requested'
  static Stream<List<TripModel>> escucharViajesPendientes() {
    return _supabase
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'requested')
        .map((list) => list.map((item) => TripModel.fromMap(item)).toList());
  }
}
