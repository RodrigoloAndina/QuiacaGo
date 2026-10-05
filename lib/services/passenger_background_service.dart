import 'package:flutter/services.dart';

import 'supabase_service.dart';

class PassengerBackgroundService {
  static const _channel = MethodChannel('com.quiacago/passenger_background');

  static Future<void> start(String tripId) async {
    final session = SupabaseService().client.auth.currentSession;
    final user = SupabaseService().client.auth.currentUser;
    if (session == null || user == null || tripId.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'supabaseUrl': SupabaseService.supabaseUrl,
        'anonKey': SupabaseService.supabaseAnonKey,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'passengerId': user.id,
        'tripId': tripId,
      });
    } on PlatformException {
      // En otras plataformas el seguimiento visible continúa con Realtime.
    } on MissingPluginException {
      // Servicio persistente disponible únicamente en Android.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // La app igualmente deja de escuchar el viaje al cerrarlo.
    } on MissingPluginException {
      // Servicio persistente disponible únicamente en Android.
    }
  }
}
