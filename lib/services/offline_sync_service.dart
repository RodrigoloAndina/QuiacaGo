import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'supabase_service.dart';
import 'runtime_policy.dart';

class OfflineSyncService with WidgetsBindingObserver {
  static final OfflineSyncService _instance = OfflineSyncService._();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._();

  final _statusController = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _isOnline = true;
  bool _checking = false;
  bool _syncing = false;
  bool _visible = true;
  DateTime? _lastCheck;
  Future<void> _writes = Future<void>.value();
  String? get _owner => SupabaseService().client.auth.currentUser?.id;

  bool get isOnline => _isOnline;
  Stream<bool> get statusStream => _statusController.stream;

  Future<void> start() async {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    await checkNow();
    _timer = Timer.periodic(AppRuntimePolicy.connectivityProbe, (_) {
      if (_visible) checkNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) { _lastCheck = null; unawaited(checkNow()); }
  }

  Future<bool> checkNow() async {
    if (_checking) return _isOnline;
    if (_lastCheck != null && DateTime.now().difference(_lastCheck!) < AppRuntimePolicy.connectivityCache) return _isOnline;
    _checking = true;
    var online = false;
    try {
      final session = SupabaseService().client.auth.currentSession;
      final response = await http.get(
        Uri.parse(
            '${SupabaseService.supabaseUrl}/rest/v1/fare_settings?select=id&limit=1'),
        headers: {
          'apikey': SupabaseService.supabaseAnonKey,
          'Authorization':
              'Bearer ${session?.accessToken ?? SupabaseService.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 4));
      online = response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      online = false;
    } finally {
      _checking = false;
      _lastCheck = DateTime.now();
    }
    if (online != _isOnline) {
      _isOnline = online;
      _statusController.add(online);
    }
    if (online) unawaited(syncPendingActions());
    return online;
  }

  Future<File> _file(String name, String owner) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/${owner}_$name');
  }

  Future<List<Map<String, dynamic>>> _readActions(String owner) async {
    if (kIsWeb) return [];
    try {
      final file = await _file('quiacago_pending_actions.json', owner);
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString()) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeActions(List<Map<String, dynamic>> actions, String owner) async {
    if (kIsWeb) return;
    final file = await _file('quiacago_pending_actions.json', owner);
    await file.writeAsString(jsonEncode(actions), flush: true);
  }

  Future<void> queueAction({
    required String type,
    required String tripId,
    String? reason,
  }) async {
    final owner = _owner;
    if (owner == null) throw StateError('Iniciá sesión para guardar una acción.');
    return _serialize(() async {
    final actions = await _readActions(owner);
    actions.removeWhere(
        (action) => action['type'] == type && action['trip_id'] == tripId);
    actions.add({
      'type': type,
      'trip_id': tripId,
      'reason': reason,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _writeActions(actions, owner);
    });
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> syncPendingActions() async {
    if (_syncing || !_isOnline) return;
    final owner = _owner;
    if (owner == null) return;
    _syncing = true;
    try {
      await _serialize(() async {
      final actions = await _readActions(owner);
      final remaining = <Map<String, dynamic>>[];
      for (final action in actions) {
        if (_owner != owner) { remaining.add(action); continue; }
        try {
          final tripId = action['trip_id']?.toString() ?? '';
          if (action['type'] == 'cancel_trip') {
            await SupabaseService().client.rpc('cancel_trip', params: {
              'p_trip_id': tripId,
              'p_reason_code': 'legacy_offline_request',
              'p_reason_detail': action['reason']?.toString(),
            });
          } else if (action['type'] == 'confirm_cash_payment') {
            final ok = await SupabaseService().client.rpc(
              'acknowledge_cash_payment',
              params: {'p_trip_id': tripId},
            );
            if (ok != true) {
              final trip = await SupabaseService()
                  .client
                  .from('trips')
                  .select('status')
                  .eq('id', tripId)
                  .maybeSingle();
              if (trip?['status'] != 'completed') {
                remaining.add(action);
              }
            }
          }
        } catch (_) {
          remaining.add(action);
        }
      }
      await _writeActions(remaining, owner);
      });
    } finally {
      _syncing = false;
    }
  }

  Future<void> cacheTrip(Map<String, dynamic> trip) async {
    final owner = _owner;
    if (owner == null || kIsWeb) return;
    await _serialize(() async {
      final file = await _file('quiacago_active_trip.json', owner);
      await file.writeAsString(jsonEncode(trip), flush: true);
    });
  }

  Future<Map<String, dynamic>?> readCachedTrip() async {
    try {
      final owner = _owner;
      if (owner == null || kIsWeb) return null;
      await _writes;
      final file = await _file('quiacago_active_trip.json', owner);
      if (!await file.exists()) return null;
      return Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedTrip() async {
    final owner = _owner;
    if (owner == null || kIsWeb) return;
    await _serialize(() async {
      final file = await _file('quiacago_active_trip.json', owner);
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> clearUserData() async {
    final owner = _owner;
    if (owner == null || kIsWeb) return;
    await _serialize(() async {
      for (final name in ['quiacago_active_trip.json', 'quiacago_pending_actions.json']) {
        final file = await _file(name, owner);
        if (await file.exists()) await file.delete();
      }
    });
  }
}

class ConnectionStatusOverlay extends StatelessWidget {
  final Widget child;
  const ConnectionStatusOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = OfflineSyncService();
    return StreamBuilder<bool>(
      stream: service.statusStream,
      initialData: service.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return Stack(
          children: [
            child,
            if (!online)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Material(
                    color: Color(0xFFB91C1C),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Sin conexión. El viaje sigue activo y sincronizaremos al volver internet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
