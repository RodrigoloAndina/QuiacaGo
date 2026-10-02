import 'package:flutter/services.dart';

import 'driver_session_service.dart';
import 'supabase_service.dart';

class DriverBackgroundService {
  static const _channel = MethodChannel('com.quiacago/driver_background');

  static Future<void> start() async {
    final client = SupabaseService().client;
    final session = client.auth.currentSession;
    final driver = DriverSessionService();
    if (session == null || driver.id.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'supabaseUrl': SupabaseService.supabaseUrl,
        'anonKey': SupabaseService.supabaseAnonKey,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'driverId': driver.id,
        'driverName': driver.fullName,
        'vehicleInfo': driver.vehicleInfo,
        'plate': driver.plate,
      });
    } on PlatformException {
      // La conexión visible continúa funcionando aunque el servicio nativo
      // no esté disponible en una plataforma distinta de Android.
    } on MissingPluginException {
      // Integración disponible únicamente en Android.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // No impide que el estado remoto sea marcado como desconectado.
    } on MissingPluginException {
      // Integración disponible únicamente en Android.
    }
  }

  static Future<bool> get isRunning async {
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> restoreSessionIfNeeded() async {
    try {
      final data = await _channel.invokeMapMethod<String, String>('getSession');
      final refreshToken = data?['refreshToken'];
      final nativeAccessToken = data?['accessToken'];
      final current = SupabaseService().client.auth.currentSession;
      if (refreshToken != null &&
          refreshToken.isNotEmpty &&
          nativeAccessToken != null &&
          nativeAccessToken != current?.accessToken) {
        await SupabaseService().client.auth.setSession(refreshToken);
      }
    } on PlatformException {
      // La sesión visible se conserva si el servicio no responde.
    } on MissingPluginException {
      // Integración disponible únicamente en Android.
    }
  }
}
