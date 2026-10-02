import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../services/routing_service.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/current_trip_session.dart';
import '../../services/offline_sync_service.dart';

class NuevoPedidoModal extends StatefulWidget {
  final TripModel? trip;
  final String driverId;
  final String driverName;
  final String vehicleInfo;
  final LatLng? driverPosition;

  const NuevoPedidoModal({
    super.key,
    this.trip,
    this.driverId = '',
    this.driverName = '',
    this.vehicleInfo = '',
    this.driverPosition,
  });

  @override
  State<NuevoPedidoModal> createState() => _NuevoPedidoModalState();
}

class _NuevoPedidoModalState extends State<NuevoPedidoModal> {
  // Coincide con offer_expires_at del despachador. Al vencer, la solicitud se
  // libera y continúa automáticamente con el siguiente conductor disponible.
  int _secondsRemaining = 20;
  Timer? _timer;
  bool _accepting = false;
  String? _acceptError;
  List<LatLng> _routeToPickup = const [];
  List<LatLng> _tripRoute = const [];
  bool _loadingPreview = true;

  LatLng get _pickup => LatLng(
        widget.trip!.pickupLat,
        widget.trip!.pickupLng,
      );

  LatLng get _destination => LatLng(
        widget.trip!.destinationLat,
        widget.trip!.destinationLng,
      );

  @override
  void initState() {
    super.initState();

    // Si no hay viaje real, cerrar inmediatamente
    if (widget.trip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    _startTimer();
    _loadRoutePreview();
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  }

  Future<void> _loadRoutePreview() async {
    final driver = widget.driverPosition;
    final trip = widget.trip;
    if (trip == null ||
        driver == null ||
        trip.pickupLat == 0 ||
        trip.pickupLng == 0 ||
        trip.destinationLat == 0 ||
        trip.destinationLng == 0) {
      if (mounted) setState(() => _loadingPreview = false);
      return;
    }

    final routes = await Future.wait([
      RoutingService.getRoutePoints(driver, _pickup),
      RoutingService.getRoutePoints(_pickup, _destination),
    ]);
    if (!mounted) return;
    setState(() {
      _routeToPickup = routes[0];
      _tripRoute = routes[1];
      _loadingPreview = false;
    });
  }

  double _routeKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters / 1000;
  }

  Widget _mapMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildRoutePreview() {
    final driver = widget.driverPosition;
    if (driver == null) {
      return const SizedBox.shrink();
    }

    final center = LatLng(
      (driver.latitude + _pickup.latitude + _destination.latitude) / 3,
      (driver.longitude + _pickup.longitude + _destination.longitude) / 3,
    );
    final approachKm = _routeKm(_routeToPickup);
    final tripKm = _routeKm(_tripRoute);
    const distance = Distance();
    final previewSpanKm = [
      distance.as(LengthUnit.Kilometer, driver, _pickup),
      distance.as(LengthUnit.Kilometer, _pickup, _destination),
      distance.as(LengthUnit.Kilometer, driver, _destination),
    ].reduce((a, b) => a > b ? a : b);
    final previewZoom = previewSpanKm < 1.5
        ? 14.5
        : previewSpanKm < 4
            ? 13.2
            : previewSpanKm < 10
                ? 11.5
                : 9.5;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: previewZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quiacago.conductor',
                    ),
                    const RichAttributionWidget(attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ]),
                    if (_routeToPickup.isNotEmpty || _tripRoute.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          if (_routeToPickup.isNotEmpty)
                            Polyline(
                              points: _routeToPickup,
                              strokeWidth: 5,
                              color: AppColors.primary,
                            ),
                          if (_tripRoute.isNotEmpty)
                            Polyline(
                              points: _tripRoute,
                              strokeWidth: 5,
                              color: const Color(0xFF10B981),
                            ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: driver,
                          width: 38,
                          height: 38,
                          child:
                              _mapMarker(Icons.local_taxi, AppColors.primary),
                        ),
                        Marker(
                          point: _pickup,
                          width: 38,
                          height: 38,
                          child: _mapMarker(
                              Icons.person_pin_circle, const Color(0xFF10B981)),
                        ),
                        Marker(
                          point: _destination,
                          width: 38,
                          height: 38,
                          child:
                              _mapMarker(Icons.flag, const Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loadingPreview)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _distanceChip(
                Icons.local_taxi,
                approachKm > 0
                    ? '${approachKm.toStringAsFixed(1)} km hasta recoger'
                    : 'Tu ubicación',
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _distanceChip(
                Icons.route,
                tripKm > 0
                    ? '${tripKm.toStringAsFixed(1)} km de viaje'
                    : 'Ruta del viaje',
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _distanceChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 1) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        // Al vencer, registrar el rechazo para que el despachador continúe con
        // el siguiente conductor y no vuelva a ofrecerlo inmediatamente aquí.
        final tripId = widget.trip?.id;
        if (tripId != null) await TripService.rechazarOferta(tripId);
        if (mounted) Navigator.pop(context, false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (trip == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixedDim.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hail, color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Text('SOLICITUD DE VIAJE',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 1.0)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Contador
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 7),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_secondsRemaining',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              height: 1)),
                      const SizedBox(height: 4),
                      const Text('SEGUNDOS',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.outline,
                              letterSpacing: 1.0)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Nombre Pasajero Real
                Text(
                    trip.passengerName.isEmpty
                        ? 'Pasajero de QuiacaGo'
                        : trip.passengerName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),

                // Monto Real
                Text(
                  trip.fareAmount > 0
                      ? TariffService.formatearMonto(trip.fareAmount)
                      : 'Tarifa no informada',
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                const Text('Tarifa Oficial Municipal',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),

                const SizedBox(height: 18),

                _buildRoutePreview(),

                if (widget.driverPosition != null) const SizedBox(height: 18),

                // Ruta Real
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.surfaceContainerHighest),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location,
                              color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('RECOGIDA',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.outline)),
                                Text(
                                    trip.pickupAddress.isEmpty
                                        ? 'Ubicación indicada en el mapa'
                                        : trip.pickupAddress,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('DESTINO',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.outline)),
                                Text(
                                    trip.destinationAddress.isEmpty
                                        ? 'Destino indicado en el mapa'
                                        : trip.destinationAddress,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (_acceptError != null) ...[
                  Text(
                    _acceptError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.statusCancelled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _accepting
                            ? null
                            : () async {
                                _timer?.cancel();
                                await TripService.rechazarOferta(trip.id);
                                if (context.mounted) {
                                  Navigator.pop(context, false);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(
                              color: AppColors.statusCancelled, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text('RECHAZAR',
                            style: TextStyle(
                                color: AppColors.statusCancelled,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _accepting
                            ? null
                            : () async {
                                if (!await OfflineSyncService().checkNow()) {
                                  if (mounted) {
                                    setState(() => _acceptError =
                                        'Sin conexión. No se aceptó el viaje.');
                                  }
                                  return;
                                }
                                _timer?.cancel();
                                setState(() {
                                  _accepting = true;
                                  _acceptError = null;
                                });
                                final acceptedTrip =
                                    await TripService.aceptarViaje(
                                  tripId: trip.id,
                                  driverId: widget.driverId,
                                  driverName: widget.driverName,
                                  vehicleInfo: widget.vehicleInfo,
                                );
                                if (!mounted) return;
                                if (acceptedTrip != null) {
                                  Navigator.pop(context, true);
                                  CurrentTripSession().setTrip(acceptedTrip);
                                  context.go('/taxi-asignado');
                                } else {
                                  setState(() {
                                    _accepting = false;
                                    _acceptError =
                                        TripService.lastAcceptError ??
                                            'No se pudo aceptar el viaje.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _accepting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ACEPTAR',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
