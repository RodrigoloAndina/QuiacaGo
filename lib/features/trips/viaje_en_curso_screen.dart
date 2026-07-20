import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  // Coordenadas reales trazadas por las esquinas y calles de La Quiaca hacia la Terminal
  final List<LatLng> rutaAlDestino = const [
    LatLng(-22.1024, -65.5998), // Origen: Av. Sarmiento 450
    LatLng(-22.1060, -65.5998), // Esquina: Av. Sarmiento y 25 de Mayo
    LatLng(-22.1060, -65.5940), // Esquina: 25 de Mayo y Av. España
    LatLng(-22.1085, -65.5940), // Destino Final: Terminal de Ómnibus
  ];

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
    final LatLng conductorPos = rutaAlDestino[1]; // Auto avanzando en la esquina de Av. Sarmiento
    final LatLng destinoPos = rutaAlDestino.last;

    return Scaffold(
      body: Stack(
        children: [
          // MAPA DE NAVEGACIÓN ESTILO UBER / DIDI
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (conductorPos.latitude + destinoPos.latitude) / 2,
                (conductorPos.longitude + destinoPos.longitude) / 2,
              ),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              // Ruta Neón Terracota/Azul Siguiendo la Cuadrícula Urbana
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: rutaAlDestino,
                    strokeWidth: 6.5,
                    color: const Color(0xFF0052FF),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              // Marcadores del Auto en Movimiento y del Destino Final
              MarkerLayer(
                markers: [
                  Marker(
                    point: conductorPos,
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
                    point: destinoPos,
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

          // BARRA SUPERIOR DE GIRO Y NAVEGACIÓN UBER STYLE (SLATE DARK)
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En 200m gira a la izquierda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
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

          // PANEL INFERIOR ESTILO UBER / DIDI CON COBRO Y FINALIZACIÓN
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

                      // Botones de contacto flotantes
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

                  // Botón Finalizar Viaje
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
