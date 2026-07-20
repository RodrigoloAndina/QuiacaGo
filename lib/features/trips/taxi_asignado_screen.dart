import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';

class TaxiAsignadoScreen extends StatefulWidget {
  const TaxiAsignadoScreen({super.key});

  @override
  State<TaxiAsignadoScreen> createState() => _TaxiAsignadoScreenState();
}

class _TaxiAsignadoScreenState extends State<TaxiAsignadoScreen> {
  LatLng _conductorPos = const LatLng(-22.1055, -65.5985);
  final LatLng _pasajeroPos = const LatLng(-22.1024, -65.5998); // Av. Sarmiento 450
  List<LatLng> _rutaPuntos = [];
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _cargarRutaReal();
  }

  Future<void> _cargarRutaReal() async {
    // 1. Obtener ubicación GPS actual del dispositivo del conductor
    final posGps = await LocationService.getCurrentLocation();
    
    // 2. Consultar el motor de ruteo OSRM para trazar la línea exactamente por las calles
    final puntosCalculados = await RoutingService.getRoutePoints(posGps, _pasajeroPos);

    if (mounted) {
      setState(() {
        _conductorPos = posGps;
        _rutaPuntos = puntosCalculados;
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
    final Uri url = Uri.parse('https://wa.me/5493885401234?text=Hola%20María,%20soy%20el%20conductor%20de%20QuiacaGo.%20Estoy%20en%20camino%20a%20Av.%20Sarmiento%20450.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE NAVEGACIÓN OSRM POR CALLES
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (_conductorPos.latitude + _pasajeroPos.latitude) / 2,
                (_conductorPos.longitude + _pasajeroPos.longitude) / 2,
              ),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
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
                      child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 24),
                    ),
                  ),
                  Marker(
                    point: _pasajeroPos,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 26),
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
                    child: const Icon(Icons.turn_right, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingRoute ? 'Calculando ruta GPS...' : 'En 150m gira a la derecha',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '4 min',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '1.2 km',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF00327D),
                        child: Text(
                          'MG',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'María Gómez',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '4.9 (12 viajes)',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone, color: Color(0xFF00327D)),
                        onPressed: _hacerLlamada,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_outlined, color: Color(0xFF10B981)),
                        onPressed: _abrirWhatsApp,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFECFDF5)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Color(0xFF10B981), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PUNTO DE RECOGIDA (GPS ACTIVO)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                            ),
                            Text(
                              'Av. Sarmiento 450, La Quiaca',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                      onPressed: () => context.push('/confirmacion-llegada'),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                      label: const Text(
                        'HE LLEGADO / NOTIFICAR',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
