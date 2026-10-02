import 'package:flutter/services.dart';

/// Mantiene la pantalla encendida mientras el conductor está disponible.
/// Android libera automáticamente la bandera si la aplicación se cierra.
class ScreenAwakeService {
  static const MethodChannel _channel =
      MethodChannel('com.quiacago/screen_awake');

  static Future<void> enable() => _setEnabled(true);

  static Future<void> disable() => _setEnabled(false);

  static Future<void> _setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', enabled);
    } on PlatformException {
      // La disponibilidad del conductor no debe fallar si el sistema operativo
      // no permite modificar temporalmente el estado de la pantalla.
    } on MissingPluginException {
      // Permite ejecutar pruebas y plataformas no Android sin esta integración.
    }
  }
}
