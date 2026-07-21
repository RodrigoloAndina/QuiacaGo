import 'package:intl/intl.dart';

class TariffService {
  /// Tarifa Plana Municipal Diurna (06:00 a 22:00 hs Argentina): $2.500
  static const double tarifaDiurna = 2500.0;

  /// Tarifa Plana Municipal Nocturna (22:00 a 06:00 hs Argentina) y Feriados: $3.000
  static const double tarifaNocturnaFeriado = 3000.0;

  /// Obtiene la hora actual ajustada a GMT-3 (Hora Oficial Argentina / Jujuy)
  static DateTime getHoraArgentina() {
    final utc = DateTime.now().toUtc();
    // Argentina está en GMT-3 (-3 horas sobre UTC)
    return utc.subtract(const Duration(hours: 3));
  }

  /// Calcula el precio del viaje automáticamente en base al horario oficial de Argentina
  static double calcularPrecio({DateTime? dateTime, bool esFeriado = false}) {
    final ahora = dateTime ?? getHoraArgentina();
    final hora = ahora.hour;

    if (esFeriado) {
      return tarifaNocturnaFeriado;
    }

    // Horario nocturno de 22:00 a 06:00 hs Argentina
    if (hora >= 22 || hora < 6) {
      return tarifaNocturnaFeriado;
    }

    return tarifaDiurna;
  }

  /// Retorna la descripción oficial de la tarifa actual basada en la hora de Argentina
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
