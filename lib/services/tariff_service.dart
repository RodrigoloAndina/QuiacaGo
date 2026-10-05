import 'package:intl/intl.dart';
import 'supabase_service.dart';

class TariffService {
  static const double tarifaDiurnaRespaldo = 2500.0;
  static const double tarifaNocturnaRespaldo = 2500.0;

  static double _tarifaDiurna = tarifaDiurnaRespaldo;
  static double _tarifaNocturna = tarifaNocturnaRespaldo;
  static int _horaInicioDiurna = 6;
  static int _horaInicioNocturna = 22;

  static double get tarifaDiurna => _tarifaDiurna;
  static double get tarifaNocturna => _tarifaNocturna;

  /// Actualiza la caché local desde Supabase. Si no hay conexión, conserva los
  /// últimos valores conocidos (o los valores de respaldo al primer inicio).
  static Future<bool> cargarTarifas() async {
    try {
      final data = await SupabaseService()
          .client
          .from('fare_settings')
          .select('day_amount,night_amount,day_starts_at,night_starts_at')
          .eq('id', 'current')
          .single();
      _tarifaDiurna = _toDouble(data['day_amount'], tarifaDiurnaRespaldo);
      _tarifaNocturna = _toDouble(data['night_amount'], tarifaNocturnaRespaldo);
      _horaInicioDiurna =
          _toHour(data['day_starts_at'], fallback: _horaInicioDiurna);
      _horaInicioNocturna =
          _toHour(data['night_starts_at'], fallback: _horaInicioNocturna);
      return true;
    } catch (_) {
      return false;
    }
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _toHour(dynamic value, {required int fallback}) {
    final text = value?.toString() ?? '';
    return int.tryParse(text.split(':').first) ?? fallback;
  }

  /// Obtiene la hora actual ajustada a GMT-3 (Hora Oficial Argentina / Jujuy)
  static DateTime getHoraArgentina() {
    final utc = DateTime.now().toUtc();
    // Argentina está en GMT-3 (-3 horas sobre UTC)
    return utc.subtract(const Duration(hours: 3));
  }

  /// Calcula el precio del viaje automáticamente en base al horario oficial de Argentina
  static double calcularPrecio({DateTime? dateTime, bool esFeriado = false}) {
    return _esHorarioDiurno(dateTime ?? getHoraArgentina())
        ? _tarifaDiurna
        : _tarifaNocturna;
  }

  static bool _esHorarioDiurno(DateTime dateTime) {
    final hora = dateTime.hour;
    final esHorarioDiurno = _horaInicioDiurna < _horaInicioNocturna
        ? hora >= _horaInicioDiurna && hora < _horaInicioNocturna
        : hora >= _horaInicioDiurna || hora < _horaInicioNocturna;
    return esHorarioDiurno;
  }

  /// Retorna la descripción oficial de la tarifa actual basada en la hora de Argentina
  static String getDescripcionTarifa(
      {DateTime? dateTime, bool esFeriado = false}) {
    final precio = calcularPrecio(dateTime: dateTime, esFeriado: esFeriado);
    final formatter =
        NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    final tipo = _esHorarioDiurno(dateTime ?? getHoraArgentina())
        ? 'Diurna'
        : 'Nocturna';
    return 'Tarifa $tipo (${formatter.format(precio)})';
  }

  /// Formatea un monto numérico a formato moneda argentina ($ 2.500)
  static String formatearMonto(double monto) {
    final formatter =
        NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return formatter.format(monto);
  }
}
