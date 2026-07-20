import '../core/constants/app_constants.dart';

class DriverDocument {
  final String id;
  final String titulo;
  final DocumentStatus estado;
  final DateTime fechaVencimiento;

  DriverDocument({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.fechaVencimiento,
  });
}
