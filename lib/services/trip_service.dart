import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class TripModel {
  final String id;
  final String passengerName;
  final String passengerPhone;
  final String pickupAddress;
  final String destinationAddress;
  final double fareAmount;
  final String pinCode;
  final String status;

  TripModel({
    required this.id,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fareAmount,
    required this.pinCode,
    required this.status,
  });

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: map['id']?.toString() ?? '',
      passengerName: map['passenger_name'] ?? 'Pasajero QuiacaGo',
      passengerPhone: map['passenger_phone'] ?? '+54 3885 401234',
      pickupAddress: map['pickup_address'] ?? 'Av. Sarmiento 450',
      destinationAddress: map['destination_address'] ?? 'Terminal de Ómnibus',
      fareAmount: (map['fare_amount'] as num?)?.toDouble() ?? 2500.0,
      pinCode: map['pin_code'] ?? '4821',
      status: map['status'] ?? 'requested',
    );
  }
}

class TripService {
  /// Solicita un nuevo viaje en la tabla Supabase 'trips'
  static Future<String?> solicitarViaje({
    required String passengerName,
    required String passengerPhone,
    required String pickupAddress,
    required String destinationAddress,
    required double fareAmount,
    required String pinCode,
  }) async {
    try {
      final supabase = SupabaseService().client;
      final res = await supabase.from('trips').insert({
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'fare_amount': fareAmount,
        'pin_code': pinCode,
        'status': 'requested',
        'created_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      if (res != null) {
        return res['id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Escucha en tiempo real viajes pendientes solicitados por pasajeros
  static Stream<List<TripModel>> escucharViajesPendientes() {
    try {
      final supabase = SupabaseService().client;
      return supabase
          .from('trips')
          .stream(primaryKey: ['id'])
          .eq('status', 'requested')
          .map((lista) => lista.map((item) => TripModel.fromMap(item)).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Acepta un viaje por parte del chofer
  static Future<bool> aceptarViaje(String tripId, String driverInfo) async {
    try {
      final supabase = SupabaseService().client;
      await supabase.from('trips').update({
        'status': 'accepted',
        'driver_info': driverInfo,
      }).eq('id', tripId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
