import '../core/constants/app_constants.dart';

class Trip {
  final String id;
  final String origen;
  final String destino;
  final double tarifa;
  final TripStatus estado;
  final DateTime fecha;
  final String codigoSeguridad;
  final String pasajeroNombre;
  final String pasajeroTelefono;
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;

  Trip({
    required this.id,
    required this.origen,
    required this.destino,
    required this.tarifa,
    required this.estado,
    required this.fecha,
    required this.codigoSeguridad,
    required this.pasajeroNombre,
    required this.pasajeroTelefono,
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      origen: json['origen'] as String,
      destino: json['destino'] as String,
      tarifa: (json['tarifa'] as num).toDouble(),
      estado: TripStatus.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => TripStatus.REQUESTED,
      ),
      fecha: DateTime.parse(json['fecha'] as String),
      codigoSeguridad: json['codigo_seguridad'] as String? ?? '1234',
      pasajeroNombre: json['pasajero_nombre'] as String? ?? 'Pasajero',
      pasajeroTelefono: json['pasajero_telefono'] as String? ?? '',
      origenLat: (json['origen_lat'] as num?)?.toDouble(),
      origenLng: (json['origen_lng'] as num?)?.toDouble(),
      destinoLat: (json['destino_lat'] as num?)?.toDouble(),
      destinoLng: (json['destino_lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origen': origen,
      'destino': destino,
      'tarifa': tarifa,
      'estado': estado.name,
      'fecha': fecha.toIso8601String(),
      'codigo_seguridad': codigoSeguridad,
      'pasajero_nombre': pasajeroNombre,
      'pasajero_telefono': pasajeroTelefono,
      'origen_lat': origenLat,
      'origen_lng': origenLng,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
    };
  }

  Trip copyWith({
    String? id,
    String? origen,
    String? destino,
    double? tarifa,
    TripStatus? estado,
    DateTime? fecha,
    String? codigoSeguridad,
    String? pasajeroNombre,
    String? pasajeroTelefono,
  }) {
    return Trip(
      id: id ?? this.id,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      tarifa: tarifa ?? this.tarifa,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      codigoSeguridad: codigoSeguridad ?? this.codigoSeguridad,
      pasajeroNombre: pasajeroNombre ?? this.pasajeroNombre,
      pasajeroTelefono: pasajeroTelefono ?? this.pasajeroTelefono,
      origenLat: origenLat,
      origenLng: origenLng,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
    );
  }
}
