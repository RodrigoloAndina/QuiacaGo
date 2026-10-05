import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'driver_location_service.dart';
import 'driver_background_service.dart';
import 'driver_session_service.dart';
import 'location_service.dart';
import 'screen_awake_service.dart';

class DriverTrackingService {
  static final DriverTrackingService _instance = DriverTrackingService._();
  factory DriverTrackingService() => _instance;
  DriverTrackingService._();

  StreamSubscription<LatLng>? _subscription;
  Timer? _timer;
  LatLng? _latest;
  bool get isRunning => _timer != null;
  static String? lastStartError;

  Future<bool> start() async {
    lastStartError = null;
    if (isRunning) {
      await DriverBackgroundService.start();
      await ScreenAwakeService.enable();
      return true;
    }
    final unavailableReason = await LocationService.trackingUnavailableReason();
    if (unavailableReason != null) {
      lastStartError = unavailableReason;
      return false;
    }
    _latest = await LocationService.getFreshLocation();
    if (_latest == null) {
      lastStartError = 'No se pudo obtener una ubicación GPS actual.';
      return false;
    }
    if (!await _publish()) return false;
    _subscription =
        LocationService.getRealtimeLocationStream().listen((p) => _latest = p);
    // Diez segundos mantiene al conductor dentro de la ventana activa de
    // veinte segundos sin duplicar escrituras innecesarias en Supabase.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _publish());
    await DriverBackgroundService.start();
    await ScreenAwakeService.enable();
    return true;
  }

  /// Fuerza un heartbeat antes de consultar pedidos. Así la disponibilidad no
  /// depende únicamente del Timer, que Android puede demorar temporalmente.
  Future<bool> publishNow() async {
    await ScreenAwakeService.enable();
    _latest ??= await LocationService.getFreshLocation();
    return _publish();
  }

  Future<bool> _publish() async {
    final p = _latest;
    final session = DriverSessionService();
    if (p == null || session.id.isEmpty) return false;
    return DriverLocationService.publicarUbicacion(
      driverId: session.id,
      latitude: p.latitude,
      longitude: p.longitude,
      driverName: session.fullName,
      vehicleInfo: session.vehicleInfo,
      plate: session.plate,
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    await DriverBackgroundService.stop();
    await ScreenAwakeService.disable();
    final id = DriverSessionService().id;
    if (id.isNotEmpty) await DriverLocationService.desconectar(id);
  }
}
