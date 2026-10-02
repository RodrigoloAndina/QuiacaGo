import 'dart:async';
import 'supabase_service.dart';
import 'offline_sync_service.dart';

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
  final String finishCode;
  final String status;
  final String? driverId;
  final String? driverName;
  final String? vehicleInfo;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;

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
    required this.finishCode,
    required this.status,
    this.driverId,
    this.driverName,
    this.vehicleInfo,
    this.acceptedAt,
    this.arrivedAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> map) {
    double number(String key, [List<String> aliases = const []]) {
      final value = <String>[key, ...aliases]
          .map((candidate) => map[candidate])
          .where((candidate) => candidate != null)
          .firstOrNull;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
          0.0;
    }

    String value(String key, [List<String> aliases = const []]) {
      for (final candidate in <String>[key, ...aliases]) {
        final parsed = map[candidate]?.toString().trim() ?? '';
        if (parsed.isNotEmpty) return parsed;
      }
      return '';
    }

    return TripModel(
      id: value('id'),
      passengerName:
          value('passenger_name', const ['pasajero_nombre', 'nombre_pasajero']),
      passengerPhone: value(
          'passenger_phone', const ['pasajero_telefono', 'telefono_pasajero']),
      pickupAddress: value('pickup_address', const ['origen']),
      pickupLat: number('pickup_lat', const ['origen_lat']),
      pickupLng: number('pickup_lng', const ['origen_lng']),
      destinationAddress: value('destination_address', const ['destino']),
      destinationLat: number('destination_lat', const ['destino_lat']),
      destinationLng: number('destination_lng', const ['destino_lng']),
      fareAmount: number('fare_amount', const ['tarifa', 'precio']),
      pinCode: value('pin_code', const ['codigo_seguridad']),
      finishCode: value('finish_code', const ['codigo_finalizacion']),
      status: value('status', const ['estado']).isEmpty
          ? 'requested'
          : value('status', const ['estado']).toLowerCase(),
      driverId: map['driver_id']?.toString(),
      driverName: map['driver_name']?.toString(),
      vehicleInfo: map['vehicle_info']?.toString(),
      acceptedAt: DateTime.tryParse(map['accepted_at']?.toString() ?? ''),
      arrivedAt: DateTime.tryParse(map['arrived_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
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
        'finish_code': finishCode,
        'status': status,
        'driver_id': driverId,
        'driver_name': driverName,
        'vehicle_info': vehicleInfo,
        'accepted_at': acceptedAt?.toIso8601String(),
        'arrived_at': arrivedAt?.toIso8601String(),
      };

  TripModel copyWithStatus(String newStatus) => TripModel(
        id: id,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        destinationAddress: destinationAddress,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        fareAmount: fareAmount,
        pinCode: pinCode,
        finishCode: finishCode,
        status: newStatus,
        driverId: driverId,
        driverName: driverName,
        vehicleInfo: vehicleInfo,
        acceptedAt: acceptedAt,
        arrivedAt: arrivedAt,
      );
}

class TripCancellationResult {
  final bool success;
  final String outcome;
  final String message;

  const TripCancellationResult({
    required this.success,
    required this.outcome,
    required this.message,
  });

  factory TripCancellationResult.fromMap(Map<String, dynamic> map) =>
      TripCancellationResult(
        success: map['success'] == true,
        outcome: map['outcome']?.toString() ?? 'cancelled',
        message: map['message']?.toString() ?? 'Operación completada.',
      );
}

class TripService {
  static String? lastAcceptError;
  static String? lastOfferError;
  static String? lastCancellationError;
  static bool lastActionQueued = false;
  static final _supabase = SupabaseService().client;

  /// Crea una solicitud con `driver_id` explícitamente nulo. La base heredada
  /// tenía como default una cadena vacía, que hacía invisible el viaje para el
  /// despachador. Los códigos continúan generándose mediante el trigger seguro.
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
    if (!await OfflineSyncService().checkNow()) {
      throw StateError('Sin conexión. El viaje no fue enviado.');
    }
    final passengerId = _supabase.auth.currentUser?.id;
    if (passengerId == null) {
      throw StateError(
          'Se requiere una sesión de pasajero para solicitar un viaje.');
    }
    if (pickupAddress.trim().isEmpty || destinationAddress.trim().isEmpty) {
      throw ArgumentError('La recogida y el destino son obligatorios.');
    }
    if (fareAmount <= 0) {
      throw ArgumentError('La tarifa debe ser mayor que cero.');
    }

    final response = await _supabase.rpc('create_trip', params: {
      'p_passenger_name': passengerName.trim().isNotEmpty
          ? passengerName.trim()
          : 'Pasajero La Quiaca',
      'p_passenger_phone': passengerPhone.trim(),
      'p_pickup_address': pickupAddress.trim(),
      'p_pickup_lat': pickupLat,
      'p_pickup_lng': pickupLng,
      'p_destination_address': destinationAddress.trim(),
      'p_destination_lat': destinationLat,
      'p_destination_lng': destinationLng,
      'p_fare_amount': fareAmount,
    });
    return _tripFromResponse(response, operation: 'crear el viaje');
  }

  /// Obtiene exclusivamente la oferta asignada por el despachador al conductor actual.
  static Future<List<TripModel>> obtenerViajesPendientes() async {
    lastOfferError = null;
    try {
      final data = await _supabase.rpc('get_driver_trip_offer');
      final trip = _tripFromResponse(data, operation: 'obtener la oferta');
      if (trip != null) return [trip];
    } catch (e) {
      print('[TripService] Error obteniendo oferta de viaje: $e');
      lastOfferError = e.toString();
    }
    return [];
  }

  /// El conductor acepta el viaje
  static Future<TripModel?> aceptarViaje({
    required String tripId,
    required String driverId,
    required String driverName,
    required String vehicleInfo,
  }) async {
    lastAcceptError = null;
    if (!await OfflineSyncService().checkNow()) {
      lastAcceptError =
          'Sin conexión. No se aceptó el viaje; esperá a recuperar internet.';
      return null;
    }
    try {
      final authenticatedDriver = _supabase.auth.currentUser?.id;
      if (authenticatedDriver == null) {
        lastAcceptError = 'La sesión del conductor venció. Volvé a ingresar.';
        return null;
      }
      if (authenticatedDriver != driverId) {
        lastAcceptError = 'La sesión no coincide con el conductor conectado.';
        return null;
      }
      final response = await _supabase.rpc('accept_trip', params: {
        'p_trip_id': tripId,
        'p_driver_name': driverName,
        'p_vehicle_info': vehicleInfo,
      });
      return _tripFromResponse(response, operation: 'aceptar el viaje');
    } catch (e) {
      print('[TripService] Error aceptando viaje: $e');
      lastAcceptError = _friendlyAcceptError(e);
      return null;
    }
  }

  static TripModel? _tripFromResponse(dynamic response,
      {required String operation}) {
    dynamic row = response;
    if (row is List) row = row.isEmpty ? null : row.first;
    if (row == null) return null;
    if (row is! Map) {
      throw FormatException('Respuesta inválida al $operation.');
    }
    final trip = TripModel.fromMap(Map<String, dynamic>.from(row));
    if (trip.id.isEmpty) {
      // PostgreSQL serializa `return null` de una función que devuelve una
      // fila compuesta como un objeto con todas sus columnas en null.
      if (row.values.every((value) => value == null)) return null;
      throw FormatException('La respuesta al $operation no contiene ID.');
    }
    return trip;
  }

  static Future<void> rechazarOferta(String tripId) async {
    try {
      await _supabase.rpc('decline_trip_offer', params: {'p_trip_id': tripId});
    } catch (e) {
      print('[TripService] Error rechazando oferta: $e');
    }
  }

  static String _friendlyAcceptError(Object error) {
    final message = error.toString();
    if (message.contains('Conductor no aprobado')) {
      return 'Tu cuenta de conductor todavía no está aprobada.';
    }
    if (message.contains('Habilitación vencida')) {
      return 'Tu habilitación municipal está vencida.';
    }
    if (message.contains('suspendida temporalmente')) {
      return 'Tu cuenta está suspendida temporalmente. Revisá el motivo en administración.';
    }
    if (message.contains('rol driver')) {
      return 'Esta cuenta no tiene asignado el rol de conductor.';
    }
    if (message.contains('La oferta venció')) {
      return 'El tiempo para aceptar esta solicitud venció.';
    }
    if (message.contains('ya no está asignada')) {
      return 'Esta solicitud ya no está asignada a tu móvil.';
    }
    if (message.contains('ya no está disponible')) {
      return 'La solicitud fue cancelada o ya no está disponible.';
    }
    if (message.contains('Could not choose the best candidate function') ||
        message.contains('PGRST203')) {
      return 'La función de aceptación está duplicada en Supabase. Ejecutá nuevamente complete_trip_flow.sql.';
    }
    return 'No se pudo aceptar el viaje. Verificá la conexión y reintentá.';
  }

  /// El conductor marca que llegó al punto de recogida
  static Future<bool> marcarLlegada(String tripId) async {
    if (!await OfflineSyncService().checkNow()) return false;
    try {
      return await _supabase
              .rpc('mark_arrived', params: {'p_trip_id': tripId}) ==
          true;
    } catch (e) {
      print('[TripService] Error marcando llegada: $e');
      return false;
    }
  }

  /// Valida el PIN del pasajero e inicia el viaje
  static Future<bool> validarPinIniciarViaje(
      String tripId, String pinIngresado) async {
    if (!await OfflineSyncService().checkNow()) return false;
    try {
      return await _supabase.rpc('verify_start_code', params: {
            'p_trip_id': tripId,
            'p_code': pinIngresado,
          }) ==
          true;
    } catch (e) {
      print('[TripService] Error validando PIN: $e');
      return false;
    }
  }

  static Future<bool> solicitarCodigoFinalizacion(String tripId) async {
    if (!await OfflineSyncService().checkNow()) return false;
    try {
      return await _supabase
              .rpc('request_finish_code', params: {'p_trip_id': tripId}) ==
          true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validarCodigoFinalizacion(
      String tripId, String code) async {
    if (!await OfflineSyncService().checkNow()) return false;
    try {
      return await _supabase.rpc('verify_finish_code', params: {
            'p_trip_id': tripId,
            'p_code': code,
          }) ==
          true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> confirmarPagoEfectivo(String tripId) async {
    lastActionQueued = false;
    if (!await OfflineSyncService().checkNow()) {
      await OfflineSyncService()
          .queueAction(type: 'confirm_cash_payment', tripId: tripId);
      lastActionQueued = true;
      return false;
    }
    try {
      return await _supabase
              .rpc('confirm_cash_payment', params: {'p_trip_id': tripId}) ==
          true;
    } catch (_) {
      await OfflineSyncService()
          .queueAction(type: 'confirm_cash_payment', tripId: tripId);
      lastActionQueued = true;
      return false;
    }
  }

  /// Finaliza el viaje
  static Future<bool> finalizarViaje(String tripId) async {
    try {
      await _supabase.from('trips').update({
        'status': 'completed',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', tripId);
      return true;
    } catch (e) {
      print('[TripService] Error finalizando viaje: $e');
      return false;
    }
  }

  /// Cancela o reasigna de forma atómica según el usuario y estado del viaje.
  static Future<TripCancellationResult?> cancelarViaje({
    required String tripId,
    required String reasonCode,
    String reasonDetail = '',
  }) async {
    lastCancellationError = null;
    if (!await OfflineSyncService().checkNow()) {
      lastCancellationError =
          'Necesitás conexión para confirmar la cancelación de forma segura.';
      return null;
    }
    try {
      final response = await _supabase.rpc('cancel_trip', params: {
        'p_trip_id': tripId,
        'p_reason_code': reasonCode,
        'p_reason_detail':
            reasonDetail.trim().isEmpty ? null : reasonDetail.trim(),
      });
      if (response is Map) {
        return TripCancellationResult.fromMap(
            Map<String, dynamic>.from(response));
      }
      lastCancellationError = 'El servidor no confirmó la cancelación.';
      return null;
    } catch (e) {
      print('[TripService] Error cancelando viaje: $e');
      final message = e.toString();
      lastCancellationError = message.contains('5 minutos')
          ? 'Todavía no transcurrieron los 5 minutos de espera.'
          : message.contains('ya comenzó')
              ? 'El viaje ya comenzó. Usá la opción de emergencia o soporte.'
              : message.contains('suspendida')
                  ? 'La cuenta está suspendida temporalmente.'
                  : 'No se pudo confirmar la cancelación. Reintentá.';
      return null;
    }
  }

  /// Obtiene un viaje específico por ID
  static Future<TripModel?> obtenerViaje(String tripId) async {
    try {
      final data =
          await _supabase.from('trips').select().eq('id', tripId).maybeSingle();

      if (data != null) {
        return TripModel.fromMap(data);
      }
    } catch (e) {
      print('[TripService] Error obteniendo viaje: $e');
    }
    return null;
  }

  /// Recupera el viaje activo después de cerrar o reiniciar la aplicación.
  static Future<TripModel?> obtenerViajeActivo() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .or('passenger_id.eq.$userId,driver_id.eq.$userId')
          .inFilter('status', [
            'requested',
            'accepted',
            'arrived',
            'in_progress',
            'awaiting_finish_code',
            'payment_pending'
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data == null ? null : TripModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> calificarViaje({
    required String tripId,
    required int rating,
    String comment = '',
  }) async {
    if (!await OfflineSyncService().checkNow()) return false;
    try {
      final result = await _supabase.rpc('rate_trip', params: {
        'p_trip_id': tripId,
        'p_rating': rating,
        'p_comment': comment.trim(),
      });
      return result != null;
    } catch (e) {
      print('[TripService] Error calificando viaje: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerCalificacionesConductor(
      String driverId) async {
    if (driverId.isEmpty || !await OfflineSyncService().checkNow()) return [];
    try {
      final rows = await _supabase
          .from('trip_ratings')
          .select('rating,comment,created_at')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map<Map<String, dynamic>>((row) => row).toList();
    } catch (e) {
      print('[TripService] Error obteniendo calificaciones: $e');
      return [];
    }
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
  static Future<List<TripModel>> obtenerHistorialConductor(
      String driverId) async {
    try {
      final data = await _supabase
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(50);

      if (data.isNotEmpty) {
        return data.map((item) => TripModel.fromMap(item)).toList();
      }
    } catch (e) {
      print('[TripService] Error obteniendo historial del conductor: $e');
    }
    return [];
  }

  /// Obtiene métricas reales de ganancias (Hoy, Semana, Total) para el conductor
  static Future<Map<String, dynamic>> obtenerMetricasConductor(
      String driverId) async {
    double gananciasHoy = 0.0;
    int viajesHoyCount = 0;
    double gananciasSemana = 0.0;
    double gananciasTotal = 0.0;
    int totalViajes = 0;

    try {
      final data = await _supabase
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed');

      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      for (var item in data) {
        final trip = TripModel.fromMap(item);
        final createdAt = item['created_at'] != null
            ? DateTime.tryParse(item['created_at'].toString())
            : null;
        final isCompleted = trip.status == 'completed';
        final isMyTrip = trip.driverId == driverId;

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
