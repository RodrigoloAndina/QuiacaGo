import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';
import '../../services/trip_service.dart';
import '../../services/driver_session_service.dart';
import '../../services/current_trip_session.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/driver_background_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/driver_message_service.dart';
import '../trips/nuevo_pedido_modal.dart';

class InicioConductorScreen extends StatefulWidget {
  const InicioConductorScreen({super.key});

  @override
  State<InicioConductorScreen> createState() => _InicioConductorScreenState();
}

class _InicioConductorScreenState extends State<InicioConductorScreen>
    with WidgetsBindingObserver {
  bool _isConnected = false;
  int _currentIndex = 0;
  LatLng _conductorPos =
      const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  StreamSubscription<LatLng>? _locationSubscription;
  final MapController _mapController = MapController();
  bool _modalAbierto = false;
  bool _isConnecting = false;
  bool _checkingOffers = false;
  int _consecutiveOfferErrors = 0;
  final Set<String> _ignoredTripIds = {};
  final Set<String> _shownAdminMessageIds = {};
  Timer? _adminMessageTimer;

  // Identificación dinámica del conductor logueado desde DriverSessionService
  String get _driverId => DriverSessionService().id;
  String get _driverName => DriverSessionService().fullName;
  String get _vehicleInfo => DriverSessionService().vehicleInfo;

  double _gananciasHoy = 0.0;
  int _viajesHoy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isConnected = DriverTrackingService().isRunning;
    _iniciarCapturaGPSReal();
    _cargarMetricasInicio();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _cargarMensajesAdministracion());
    _adminMessageTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _cargarMensajesAdministracion());
    _restaurarViajeActivo();
    if (_isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _iniciarPollingOfertas();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isConnected) {
      _sincronizarSesionAlVolver();
    }
  }

  Future<void> _sincronizarSesionAlVolver() async {
    await DriverBackgroundService.restoreSessionIfNeeded();
    if (!mounted || !_isConnected) return;
    await DriverTrackingService().start();
    await _buscarOferta();
  }

  Future<void> _restaurarViajeActivo() async {
    final trip = await CurrentTripSession().restore();
    if (!mounted) return;
    if (trip == null) {
      await _restaurarConexionEnSegundoPlano();
      return;
    }
    if (!DriverTrackingService().isRunning) {
      final resumed = await DriverTrackingService().start();
      if (mounted && resumed) setState(() => _isConnected = true);
    }
    switch (trip.status) {
      case 'accepted':
        context.go('/taxi-asignado');
        break;
      case 'arrived':
        context.go('/codigo-seguridad');
        break;
      case 'in_progress':
        context.go('/viaje-en-curso');
        break;
      case 'awaiting_finish_code':
      case 'payment_pending':
        context.go('/finalizacion-viaje');
        break;
    }
  }

  Future<void> _restaurarConexionEnSegundoPlano() async {
    if (!await DriverBackgroundService.isRunning || !mounted) return;
    await DriverBackgroundService.restoreSessionIfNeeded();
    final resumed = await DriverTrackingService().start();
    if (!mounted || !resumed) return;
    setState(() => _isConnected = true);
    _iniciarPollingOfertas();
    await _buscarOferta();
  }

  Future<void> _cerrarSesion() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text(
                  'Se desconectará el taxi y dejarás de recibir solicitudes.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCELAR')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('CERRAR SESIÓN')),
              ],
            ));
    if (confirmed != true) return;
    _desconectarse();
    await DriverTrackingService().stop();
    await AuthService().logout();
    DriverSessionService().clear();
    CurrentTripSession().clear();
    if (mounted) context.go('/login');
  }

  Future<void> _cargarMetricasInicio() async {
    final res = await TripService.obtenerMetricasConductor(_driverId);
    if (mounted) {
      setState(() {
        _gananciasHoy = (res['gananciasHoy'] as num?)?.toDouble() ?? 0.0;
        _viajesHoy = (res['viajesHoy'] as num?)?.toInt() ?? 0;
      });
    }
  }

  Future<void> _cargarMensajesAdministracion() async {
    if (!mounted || _modalAbierto) return;
    try {
      final messages = await DriverMessageService().list(unreadOnly: true);
      final message = messages.firstWhere(
          (item) => !_shownAdminMessageIds.contains(item['id']?.toString()),
          orElse: () => <String, dynamic>{});
      final id = message['id']?.toString();
      if (id == null || id.isEmpty || !mounted) return;
      _shownAdminMessageIds.add(id);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title:
              Text(message['title']?.toString() ?? 'Mensaje de administración'),
          content: Text(message['body']?.toString() ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      await DriverMessageService().markRead(id);
    } catch (_) {
      // Los mensajes administrativos no deben impedir operar al conductor.
    }
  }

  Future<void> _iniciarCapturaGPSReal() async {
    final posIncial = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _conductorPos = posIncial);
      _mapController.move(posIncial, 16.0);
    }

    _locationSubscription =
        LocationService.getRealtimeLocationStream().listen((nuevaPos) {
      if (mounted) {
        setState(() => _conductorPos = nuevaPos);
        _mapController.move(nuevaPos, _mapController.camera.zoom);
      }
    });
  }

  Timer? _pollingTripsTimer;

  Future<bool> _conectarse() async {
    if (_isConnecting || _isConnected) return _isConnected;
    setState(() => _isConnecting = true);

    final authenticatedId = SupabaseService().client.auth.currentUser?.id;
    if (_driverId.isEmpty || authenticatedId != _driverId) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _mostrarErrorConexion(
            'La sesión del conductor venció. Cerrá sesión y volvé a ingresar.');
      }
      return false;
    }

    try {
      final operational = await AuthService().refreshDriverCompliance();
      if (!operational) {
        if (mounted) {
          setState(() => _isConnecting = false);
          _mostrarErrorConexion(
              'Tu cuenta o documentación requiere revisión. Abrí Perfil > Documentación para ver el detalle.');
        }
        return false;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _mostrarErrorConexion(
            'No pudimos validar tu habilitación con el servidor. Reintentá con conexión a internet.');
      }
      return false;
    }

    // El estado visible sólo cambia después de confirmar el alta online.
    final trackingStarted = await DriverTrackingService().start();
    if (!mounted) return false;
    if (!trackingStarted) {
      setState(() => _isConnecting = false);
      _mostrarErrorConexion(DriverTrackingService.lastStartError ??
          'No se pudo conectar el taxi con el servidor. ${DriverLocationService.lastPublishError ?? 'Verificá internet y GPS.'}');
      return false;
    }

    setState(() {
      _isConnecting = false;
      _isConnected = true;
      _ignoredTripIds.clear();
    });

    await _buscarOferta();
    if (TripService.lastOfferError != null) {
      _desconectarse();
      if (mounted) {
        _mostrarErrorConexion(
            'El taxi se publicó, pero el servicio de pedidos no respondió. Verificá la configuración de Supabase.');
      }
      return false;
    }
    _iniciarPollingOfertas();
    return true;
  }

  void _iniciarPollingOfertas() {
    _pollingTripsTimer?.cancel();
    // La RPC devuelve como máximo una oferta y únicamente al conductor
    // elegido por el despachador.
    _pollingTripsTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _buscarOferta();
    });
  }

  Future<void> _buscarOferta() async {
    if (!_isConnected || _modalAbierto || _checkingOffers) return;
    _checkingOffers = true;
    try {
      final viajes = await TripService.obtenerViajesPendientes();
      if (!mounted || !_isConnected || _modalAbierto) return;
      if (TripService.lastOfferError != null) {
        _consecutiveOfferErrors++;
        if (_consecutiveOfferErrors == 3) {
          _mostrarErrorConexion(
              'Se perdió la conexión con el servicio de pedidos. Seguimos reintentando automáticamente.');
        }
        return;
      }
      _consecutiveOfferErrors = 0;
      final visible = viajes.where((v) => !_ignoredTripIds.contains(v.id));
      if (visible.isNotEmpty) _mostrarModalNuevoPedido(visible.first);
    } finally {
      _checkingOffers = false;
    }
  }

  void _mostrarErrorConexion(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.statusCancelled,
      duration: const Duration(seconds: 8),
    ));
  }

  void _desconectarse() {
    setState(() {
      _isConnected = false;
      _isConnecting = false;
    });

    _pollingTripsTimer?.cancel();
    _pollingTripsTimer = null;

    DriverTrackingService().stop();
  }

  void _mostrarModalNuevoPedido(TripModel viaje) {
    if (_modalAbierto) return;
    setState(() => _modalAbierto = true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => NuevoPedidoModal(
        trip: viaje,
        driverId: _driverId,
        driverName: _driverName,
        vehicleInfo: _vehicleInfo,
        driverPosition: _conductorPos,
      ),
    ).then((accepted) {
      if (mounted)
        setState(() {
          _modalAbierto = false;
          if (accepted == false) _ignoredTripIds.add(viaje.id);
        });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _pollingTripsTimer?.cancel();
    _adminMessageTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Conductor',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (_isConnected)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusAvailable.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.statusAvailable,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('EN LÍNEA',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.statusAvailable)),
                ],
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, color: AppColors.primary),
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPA
          FlutterMap(
            mapController: _mapController,
            options:
                MapOptions(initialCenter: _conductorPos, initialZoom: 16.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.conductor',
              ),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _conductorPos,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Center(
                          child: Icon(Icons.directions_car,
                              color: Colors.white, size: 24)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // BOTTOM SHEET
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 90),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tu estado',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? AppColors.statusAvailable
                                  .withValues(alpha: 0.15)
                              : AppColors.badgeCancelledBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: _isConnected
                                        ? AppColors.statusAvailable
                                        : AppColors.statusCancelled,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              _isConnected ? 'Disponible' : 'No disponible',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isConnected
                                      ? AppColors.statusAvailable
                                      : AppColors.statusCancelled),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting
                          ? null
                          : () async {
                              bool changedSuccessfully = true;
                              if (_isConnected) {
                                _desconectarse();
                              } else {
                                changedSuccessfully = await _conectarse();
                              }
                              if (!mounted ||
                                  _isConnecting ||
                                  !changedSuccessfully) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_isConnected
                                      ? 'Disponible. Esperando solicitudes reales...'
                                      : 'Desconectado.'),
                                  backgroundColor: _isConnected
                                      ? AppColors.statusAvailable
                                      : AppColors.outline,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                      icon: const Icon(Icons.power_settings_new,
                          color: Colors.white),
                      label: Text(
                        _isConnecting
                            ? 'CONECTANDO...'
                            : (_isConnected ? 'DESCONECTARSE' : 'CONECTARSE'),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected
                            ? AppColors.statusCancelled
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 16, color: AppColors.outline),
                                SizedBox(width: 4),
                                Text('Ganancias hoy',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.outline)),
                              ]),
                              const SizedBox(height: 4),
                              Text('\$${_gananciasHoy.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.access_time,
                                    size: 16, color: AppColors.outline),
                                SizedBox(width: 4),
                                Text('Viajes',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.outline)),
                              ]),
                              const SizedBox(height: 4),
                              Text('$_viajesHoy',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: AppColors.outline,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.push('/ganancias');
              break;
            case 2:
              context.push('/historial');
              break;
            case 3:
              context.push('/perfil');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.attach_money), label: 'Ganancias'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
