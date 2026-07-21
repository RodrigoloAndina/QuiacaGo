import 'package:intl/intl.dart';

class TariffService {
  /// Tarifa Plana Municipal Diurna (06:00 a 22:00): $2.500
  static const double tarifaDiurna = 2500.0;

  /// Tarifa Plana Municipal Nocturna (22:00 a 06:00) y Feriados: $3.000
  static const double tarifaNocturnaFeriado = 3000.0;

  /// Calcula el precio del viaje en base al horario y feriado
  static double calcularPrecio({DateTime? dateTime, bool esFeriado = false}) {
    final ahora = dateTime ?? DateTime.now();
    final hora = ahora.hour;

    if (esFeriado) {
      return tarifaNocturnaFeriado;
    }

    // Horario nocturno de 22:00 a 06:00
    if (hora >= 22 || hora < 6) {
      return tarifaNocturnaFeriado;
    }

    return tarifaDiurna;
  }

  /// Retorna la descripción oficial de la tarifa actual
  static String getDescripcionTarifa({DateTime? dateTime, bool esFeriado = false}) {
    final precio = calcularPrecio(dateTime: dateTime, esFeriado: esFeriado);
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    if (precio == tarifaNocturnaFeriado) {
      return 'Tarifa Nocturna / Feriados (${formatter.format(precio)})';
    }
    return 'Tarifa Diurna Municipal (${formatter.format(precio)})';
  }

  /// Formatea un monto numérico a formato moneda argentina ($ 2.500)
  static String formatearMonto(double monto) {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return formatter.format(monto);
  }
}
