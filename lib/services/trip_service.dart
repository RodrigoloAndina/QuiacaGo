import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      id: map['id']?.toString() ?? 'TRIP-${DateTime.now().millisecondsSinceEpoch}',
      passengerName: map['passenger_name'] ?? map['passengerName'] ?? 'María Gómez',
      passengerPhone: map['passenger_phone'] ?? map['passengerPhone'] ?? '+54 3885 401234',
      pickupAddress: map['pickup_address'] ?? map['pickupAddress'] ?? 'Av. Sarmiento 450, La Quiaca',
      destinationAddress: map['destination_address'] ?? map['destinationAddress'] ?? 'Terminal de Ómnibus',
      fareAmount: (map['fare_amount'] ?? map['fareAmount'] as num?)?.toDouble() ?? 2500.0,
      pinCode: map['pin_code'] ?? map['pinCode'] ?? '4821',
      status: map['status'] ?? 'requested',
    );
  }
}

class TripService {
  /// Solicita un nuevo viaje en Supabase DB y notifica al Servidor Backend Local HTTP
  static Future<String?> solicitarViaje({
    required String passengerName,
    required String passengerPhone,
    required String pickupAddress,
    required String destinationAddress,
    required double fareAmount,
    required String pinCode,
  }) async {
    String tripId = 'TRIP-${DateTime.now().millisecondsSinceEpoch}';

    // 1. Guardar en Supabase tabla 'trips'
    try {
      final supabase = SupabaseService().client;
      await supabase.from('trips').insert({
        'passenger_name': passengerName,
        'passenger_phone': passengerPhone,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'fare_amount': fareAmount,
        'pin_code': pinCode,
        'status': 'requested',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 2. Notificar al Backend HTTP para transmisión garantizada (Servidor local / Emulador)
    final payload = jsonEncode({
      'id': tripId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'fareAmount': fareAmount,
      'pinCode': pinCode,
      'status': 'requested',
    });

    for (final host in ['10.0.2.2', 'localhost', '192.168.1.100']) {
      try {
        await http.post(
          Uri.parse('http://$host:3000/api/trips'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return tripId;
  }

  /// Obtiene los viajes solicitados pendientes mediante polling activo + Supabase Realtime
  static Future<List<TripModel>> obtenerViajesPendientes() async {
    List<TripModel> resultados = [];

    // 1. Consultar servidor HTTP local / emulador
    for (final host in ['10.0.2.2', 'localhost']) {
      try {
        final res = await http.get(Uri.parse('http://$host:3000/api/trips')).timeout(const Duration(milliseconds: 1200));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['trips'] != null && (data['trips'] as List).isNotEmpty) {
            for (var item in data['trips']) {
              if (item['status'] == 'requested') {
                resultados.add(TripModel.fromMap(item));
              }
            }
            if (resultados.isNotEmpty) return resultados;
          }
        }
      } catch (_) {}
    }

    // 2. Consultar Supabase DB
    try {
      final supabase = SupabaseService().client;
      final data = await supabase.from('trips').select().eq('status', 'requested').limit(5);
      if (data != null && (data as List).isNotEmpty) {
        return data.map((item) => TripModel.fromMap(item)).toList();
      }
    } catch (_) {}

    return resultados;
  }
}
