import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';

import '../../services/current_trip_session.dart';
import '../../services/trip_service.dart';
import '../../core/constants/app_constants.dart';
import 'cancellation_dialog.dart';

class TaxiAsignadoScreen extends StatefulWidget {
  const TaxiAsignadoScreen({super.key});

  @override
  State<TaxiAsignadoScreen> createState() => _TaxiAsignadoScreenState();
}

class _TaxiAsignadoScreenState extends State<TaxiAsignadoScreen> {
  LatLng _conductorPos = const LatLng(0, 0);
  LatLng _pasajeroPos = const LatLng(0, 0);
  List<LatLng> _rutaPuntos = [];
  bool _isLoadingRoute = true;
  StreamSubscription<LatLng>? _locationSub;
  StreamSubscription<TripModel>? _tripSub;
  bool _markingArrival = false;
  bool _cancellingTrip = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarRutaReal();
    _iniciarSincronizacionGPS();
    _escucharViaje();
  }

  void _escucharViaje() {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null) return;
    _tripSub = TripService.escucharViaje(trip.id).listen((updated) {
      if (!mounted) return;
      if (updated.status == 'cancelled' || updated.status == 'requested') {
        if (_cancellingTrip) return;
        CurrentTripSession().clear();
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El pasajero canceló el viaje. Ya estás disponible.'),
        ));
      } else {
        CurrentTripSession().setTrip(updated);
      }
    });
  }

  void _iniciarSincronizacionGPS() {
    _locationSub =
        LocationService.getRealtimeLocationStream().listen((nuevaPos) {
      if (mounted) {
        setState(() {
          _conductorPos = nuevaPos;
        });
      }
    });
  }

  Future<void> _cargarRutaReal() async {
    final trip = CurrentTripSession().currentTrip;
    final posGps = await LocationService.getCurrentLocation();

    LatLng pasajeroPosReal = posGps;
    if (trip != null && trip.pickupLat != 0.0 && trip.pickupLng != 0.0) {
      pasajeroPosReal = LatLng(trip.pickupLat, trip.pickupLng);
    } else {
      pasajeroPosReal =
          LatLng(posGps.latitude + 0.003, posGps.longitude + 0.003);
    }

    final puntosCalculados =
        await RoutingService.getRoutePoints(posGps, pasajeroPosReal);

    if (mounted) {
      setState(() {
        _conductorPos = posGps;
        _pasajeroPos = pasajeroPosReal;
        _rutaPuntos = puntosCalculados;
        _isLoadingRoute = false;
      });
      _enfocarRuta(posGps, pasajeroPosReal);
    }
  }

  void _enfocarRuta(LatLng inicio, LatLng fin) {
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, inicio, fin);
    final zoom = meters < 1500
        ? 15.5
        : meters < 5000
            ? 13.5
            : meters < 20000
                ? 11.0
                : 8.0;
    final center = LatLng((inicio.latitude + fin.latitude) / 2,
        (inicio.longitude + fin.longitude) / 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(center, zoom);
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _tripSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _hacerLlamada() async {
    final phone = CurrentTripSession().currentTrip?.passengerPhone ?? '';
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _abrirWhatsApp() async {
    final trip = CurrentTripSession().currentTrip;
    final phone =
        (trip?.passengerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final message =
        'Hola ${trip?.passengerName ?? 'pasajero'}, soy tu conductor de QuiacaGo. Estoy en camino a ${trip?.pickupAddress ?? 'tu ubicación'}.';
    final Uri url = Uri.https('wa.me', '/$phone', {'text': message});
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _marcarLlegada() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _markingArrival) return;
    setState(() => _markingArrival = true);
    final ok = await TripService.marcarLlegada(trip.id);
    if (!mounted) return;
    setState(() => _markingArrival = false);
    if (ok) {
      CurrentTripSession().setTrip(trip.copyWithStatus('arrived'));
      context.go('/confirmacion-llegada');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No se pudo notificar la llegada. Revisá la conexión.')));
    }
  }

  Future<void> _cancelarYReasignar() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _cancellingTrip) return;
    final choice = await showTripCancellationDialog(context, isDriver: true);
    if (choice == null || !mounted) return;
    setState(() => _cancellingTrip = true);
    final result = await TripService.cancelarViaje(
      tripId: trip.id,
      reasonCode: choice.code,
      reasonDetail: choice.detail,
    );
    if (!mounted) return;
    setState(() => _cancellingTrip = false);
    if (result == null || !result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(TripService.lastCancellationError ??
            'No se pudo cancelar el viaje.'),
      ));
      return;
    }
    await _tripSub?.cancel();
    CurrentTripSession().clear();
    if (mounted) {
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE NAVEGACIÓN OSRM POR CALLES
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter:
                  LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
              // Línea de Ruta Neón OSRM alineada 100% sobre el asfalto de las calles
              if (_rutaPuntos.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _rutaPuntos,
                      strokeWidth: 6.5,
                      color: const Color(0xFF0052FF),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              // Marcadores de Ubicación GPS Real del Vehículo y Pasajero
              MarkerLayer(
                markers: [
                  Marker(
                    point: _conductorPos,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00327D),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                          child: Icon(Icons.directions_car_filled,
                              color: Colors.white, size: 24)),
                    ),
                  ),
                  Marker(
                    point: _pasajeroPos,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                          child: Icon(Icons.person_pin_circle,
                              color: Colors.white, size: 26)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // BARRA SUPERIOR UBER / DIDI CON ESTADO OSRM
          Positioned(
            top: 44,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.turn_right,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingRoute
                              ? 'Calculando ruta GPS...'
                              : 'En 150m gira a la derecha',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'por Calle Balcarce hacia 9 de Julio',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final distM = const Distance()
                          .as(LengthUnit.Meter, _conductorPos, _pasajeroPos);
                      final distStr = distM < 1000
                          ? '${distM.round()} m'
                          : '${(distM / 1000).toStringAsFixed(1)} km';
                      final minStr = '${(distM / 400).ceil().clamp(1, 60)} min';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              minStr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            Text(
                              distStr,
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 128,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'support-taxi-assigned',
              tooltip: 'Ayuda y emergencia',
              onPressed: () => context.push('/soporte'),
              child: const Icon(Icons.support_agent_outlined),
            ),
          ),

          // PANEL INFERIOR CON DATOS DEL PASAJERO
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF00327D),
                        child: Text(
                          (CurrentTripSession()
                                      .currentTrip
                                      ?.passengerName
                                      .isNotEmpty ==
                                  true)
                              ? CurrentTripSession()
                                  .currentTrip!
                                  .passengerName
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrentTripSession()
                                          .currentTrip
                                          ?.passengerName
                                          .isNotEmpty ==
                                      true
                                  ? CurrentTripSession()
                                      .currentTrip!
                                      .passengerName
                                  : 'Pasajero QuiacaGo',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  CurrentTripSession()
                                              .currentTrip
                                              ?.passengerPhone
                                              .isNotEmpty ==
                                          true
                                      ? CurrentTripSession()
                                          .currentTrip!
                                          .passengerPhone
                                      : 'Pasajero Registrado',
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone, color: Color(0xFF00327D)),
                        onPressed: _hacerLlamada,
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_outlined,
                            color: Color(0xFF10B981)),
                        onPressed: _abrirWhatsApp,
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFF10B981), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PUNTO DE RECOGIDA (GPS ACTIVO)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8)),
                            ),
                            Text(
                              CurrentTripSession()
                                          .currentTrip
                                          ?.pickupAddress
                                          .isNotEmpty ==
                                      true
                                  ? CurrentTripSession()
                                      .currentTrip!
                                      .pickupAddress
                                  : 'Ubicación GPS del Pasajero',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _markingArrival ? null : _marcarLlegada,
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 22),
                      label: const Text(
                        'HE LLEGADO / NOTIFICAR',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cancellingTrip ? null : _cancelarYReasignar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(_cancellingTrip
                        ? 'CANCELANDO...'
                        : 'NO PUEDO REALIZAR ESTE VIAJE'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFBA1A1A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
