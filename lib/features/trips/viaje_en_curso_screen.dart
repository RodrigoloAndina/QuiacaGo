import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';

import '../../services/current_trip_session.dart';
import '../../services/trip_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/tariff_service.dart';
import '../../core/constants/app_constants.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  LatLng _conductorPos = const LatLng(0, 0);
  LatLng _destinoPos = const LatLng(0, 0);
  List<LatLng> _rutaPuntos = [];
  bool _isLoadingRoute = true;
  bool _finishing = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarRutaRealOSRM();
  }

  Future<void> _cargarRutaRealOSRM() async {
    final trip = CurrentTripSession().currentTrip;
    final posGps = await LocationService.getCurrentLocation();

    LatLng destinoReal = posGps;
    if (trip != null &&
        trip.destinationLat != 0.0 &&
        trip.destinationLng != 0.0) {
      destinoReal = LatLng(trip.destinationLat, trip.destinationLng);
    } else {
      destinoReal = LatLng(posGps.latitude + 0.005, posGps.longitude + 0.005);
    }

    final puntos = await RoutingService.getRoutePoints(posGps, destinoReal);

    if (mounted) {
      setState(() {
        _conductorPos = posGps;
        _destinoPos = destinoReal;
        _rutaPuntos = puntos;
        _isLoadingRoute = false;
      });
      _enfocarRuta(posGps, destinoReal);
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
    final Uri url = Uri.https('wa.me', '/$phone', {
      'text':
          'Hola ${trip?.passengerName ?? 'pasajero'}, estamos llegando a ${trip?.destinationAddress ?? 'tu destino'}.',
    });
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _llegueAlDestino() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _finishing) return;
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sin conexión. El viaje sigue activo; reintentá al recuperar internet.'),
        ));
      }
      return;
    }
    setState(() => _finishing = true);
    final ok = await TripService.solicitarCodigoFinalizacion(trip.id);
    if (!mounted) return;
    setState(() => _finishing = false);
    if (ok) {
      CurrentTripSession().setTrip(trip.copyWithStatus('awaiting_finish_code'));
      context.go('/finalizacion-viaje');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo solicitar el código final.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE NAVEGACIÓN OSRM ALINEADO 100% SOBRE EL ASFALTO
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
                          child: Icon(Icons.navigation,
                              color: Colors.white, size: 24)),
                    ),
                  ),
                  Marker(
                    point: _destinoPos,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
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
                          child: Icon(Icons.location_on,
                              color: Colors.white, size: 26)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // BARRA SUPERIOR SLATE DARK
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
                    child: const Icon(Icons.turn_left,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingRoute
                              ? 'Calculando ruta por calles...'
                              : 'En 200m gira a la izquierda',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrentTripSession()
                                  .currentTrip
                                  ?.destinationAddress ??
                              'Destino indicado por el pasajero',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '6 min',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          '2.1 km',
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 128,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'support-trip-in-progress',
              tooltip: 'Ayuda y emergencia',
              onPressed: () => context.push('/soporte'),
              child: const Icon(Icons.support_agent_outlined),
            ),
          ),

          // PANEL INFERIOR DE FINALIZACIÓN
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DESTINO FINAL',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrentTripSession()
                                      .currentTrip
                                      ?.destinationAddress ??
                                  'Destino indicado por el pasajero',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          TariffService.formatearMonto(
                              CurrentTripSession().currentTrip?.fareAmount ??
                                  TariffService.calcularPrecio()),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00327D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          color: Color(0xFF00327D), size: 20),
                      const SizedBox(width: 8),
                      Text(
                          CurrentTripSession().currentTrip?.passengerName ??
                              'Pasajero',
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone,
                            color: Color(0xFF00327D), size: 20),
                        onPressed: _hacerLlamada,
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_outlined,
                            color: Color(0xFF10B981), size: 20),
                        onPressed: _abrirWhatsApp,
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _finishing ? null : _llegueAlDestino,
                      icon:
                          const Icon(Icons.flag, color: Colors.white, size: 22),
                      label: Text(
                        'LLEGUÉ AL DESTINO · COBRAR ${TariffService.formatearMonto(CurrentTripSession().currentTrip?.fareAmount ?? 0)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
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
