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

    final mapData = {
      'passenger_name': passengerName.isNotEmpty ? passengerName : 'Pasajero La Quiaca',
      'passenger_phone': passengerPhone.isNotEmpty ? passengerPhone : '3885000000',
      'pickup_address': pickupAddress.isNotEmpty ? pickupAddress : 'Punto en La Quiaca',
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'destination_address': destinationAddress.isNotEmpty ? destinationAddress : 'Destino La Quiaca',
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'fare_amount': fareAmount,
      'pin_code': pinCode,
      'status': 'requested',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _supabase.from('trips').insert(mapData).select().single();
      return TripModel.fromMap(response);
    } catch (e) {
      print('[TripService] Error primario solicitando viaje: $e');
      try {
        await _supabase.from('trips').insert(mapData);
        return TripModel.fromMap(mapData);
      } catch (err2) {
        print('[TripService] Error secundario solicitando viaje: $err2');
      }
    }
    return null;
  }

  /// Obtiene viajes pendientes con status 'requested' (para el conductor)
  static Future<List<TripModel>> obtenerViajesPendientes() async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .or('status.eq.requested,status.eq.buscando,status.eq.pending')
          .order('created_at', ascending: false)
          .limit(10);

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

  /// Obtiene el historial de viajes asignados o completados por el conductor actual
  static Future<List<TripModel>> obtenerHistorialConductor(String driverId) async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .or('driver_id.eq.$driverId,status.eq.completed')
          .order('created_at', ascending: false)
          .limit(50);

      if (data is List && data.isNotEmpty) {
        return data.map((item) => TripModel.fromMap(item)).toList();
      }
    } catch (e) {
      print('[TripService] Error obteniendo historial del conductor: $e');
    }
    return [];
  }

  /// Obtiene métricas reales de ganancias (Hoy, Semana, Total) para el conductor
  static Future<Map<String, dynamic>> obtenerMetricasConductor(String driverId) async {
    double gananciasHoy = 0.0;
    int viajesHoyCount = 0;
    double gananciasSemana = 0.0;
    double gananciasTotal = 0.0;
    int totalViajes = 0;

    try {
      final data = await _supabase
          .from('trips')
          .select();

      if (data is List) {
        final now = DateTime.now();
        final todayStr = now.toIso8601String().split('T')[0];

        for (var item in data) {
          final trip = TripModel.fromMap(item);
          final createdAt = item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) : null;
          final isCompleted = trip.status == 'completed' || trip.status == 'in_progress';
          final isMyTrip = trip.driverId == driverId || trip.driverId == null;

          if (isCompleted && isMyTrip) {
            gananciasTotal += trip.fareAmount;
            totalViajes++;

            if (createdAt != null) {
              final tripDateStr = createdAt.toIso8601String().split('T')[0];
              if (tripDateStr == todayStr) {
                gananciasHoy += trip.fareAmount;
                viajesHoyCount++;
              }
              final diffDays = now.difference(createdAt).inDays;
              if (diffDays <= 7) {
                gananciasSemana += trip.fareAmount;
              }
            }
          }
        }
      }
    } catch (e) {
      print('[TripService] Error calculando métricas del conductor: $e');
    }

    return {
      'gananciasHoy': gananciasHoy,
      'viajesHoy': viajesHoyCount,
      'gananciasSemana': gananciasSemana,
      'gananciasTotal': gananciasTotal,
      'totalViajes': totalViajes,
    };
  }
}
