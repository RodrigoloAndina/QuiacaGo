class Vehicle {
  final String marca;
  final String modelo;
  final String color;
  final String patente;
  final String numeroInterno;

  Vehicle({
    required this.marca,
    required this.modelo,
    required this.color,
    required this.patente,
    required this.numeroInterno,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      color: json['color'] as String? ?? '',
      patente: json['patente'] as String? ?? '',
      numeroInterno: json['numero_interno'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marca': marca,
      'modelo': modelo,
      'color': color,
      'patente': patente,
      'numero_interno': numeroInterno,
    };
  }
}
