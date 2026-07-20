import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  LatLng _conductorPos = const LatLng(-22.1024, -65.5998); // Av. Sarmiento 450
  final LatLng _destinoPos = const LatLng(-22.1085, -65.5940); // Terminal de Ómnibus
  List<LatLng> _rutaPuntos = [];
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _cargarRutaRealOSRM();
  }

  Future<void> _cargarRutaRealOSRM() async {
    // 1. Capturar la ubicación GPS en vivo del celular del conductor
    final posGps = await LocationService.getCurrentLocation();
    
    // 2. Traer la geometría vial OSRM alineada 100% al asfalto de las calles
    final puntos = await RoutingService.getRoutePoints(posGps, _destinoPos);

    if (mounted) {
      setState(() {
        _conductorPos = posGps;
        _rutaPuntos = puntos;
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _hacerLlamada() async {
    final Uri url = Uri.parse('tel:+5493885401234');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _abrirWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/5493885401234?text=Hola%20María,%20estamos%20en%20camino%20a%20la%20Terminal%20de%20Ómnibus.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE NAVEGACIÓN OSRM ALINEADO 100% SOBRE EL ASFALTO
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (_conductorPos.latitude + _destinoPos.latitude) / 2,
                (_conductorPos.longitude + _destinoPos.longitude) / 2,
              ),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
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
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00327D),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                    ),
                  ),
                  Marker(
                    point: _destinoPos,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 26),
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
                    color: Colors.black.withOpacity(0.25),
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
                    child: const Icon(Icons.turn_left, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingRoute ? 'Calculando ruta por calles...' : 'En 200m gira a la izquierda',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'por Calle 25 de Mayo hacia Av. España',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '6 min',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '2.1 km',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    color: Colors.black.withOpacity(0.12),
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESTINO FINAL',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Terminal de Ómnibus',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '\$ 1,250',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF00327D)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF00327D), size: 20),
                      const SizedBox(width: 8),
                      const Text('María Gómez', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                      const Spacer(),

                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone, color: Color(0xFF00327D), size: 20),
                        onPressed: _hacerLlamada,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_outlined, color: Color(0xFF10B981), size: 20),
                        onPressed: _abrirWhatsApp,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFECFDF5)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/finalizacion-viaje'),
                      icon: const Icon(Icons.flag, color: Colors.white, size: 22),
                      label: const Text(
                        'FINALIZAR VIAJE Y COBRAR \$1,250',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
