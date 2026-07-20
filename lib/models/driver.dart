import '../core/constants/app_constants.dart';

class Driver {
  final String id;
  final String nombre;
  final String telefono;
  final DriverStatus estado;
  final double calificacion;
  final String? fotoUrl;

  Driver({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.estado = DriverStatus.OFFLINE,
    this.calificacion = 5.0,
    this.fotoUrl,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String,
      estado: DriverStatus.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => DriverStatus.OFFLINE,
      ),
      calificacion: (json['calificacion'] as num?)?.toDouble() ?? 5.0,
      fotoUrl: json['foto_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'estado': estado.name,
      'calificacion': calificacion,
      'foto_url': fotoUrl,
    };
  }

  Driver copyWith({
    String? id,
    String? nombre,
    String? telefono,
    DriverStatus? estado,
    double? calificacion,
    String? fotoUrl,
  }) {
    return Driver(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      calificacion: calificacion ?? this.calificacion,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}
