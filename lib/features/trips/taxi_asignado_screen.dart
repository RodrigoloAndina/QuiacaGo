import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class TaxiAsignadoScreen extends StatelessWidget {
  const TaxiAsignadoScreen({super.key});

  // Coordenadas reales siguiendo la cuadrícula de calles de La Quiaca
  final List<LatLng> rutaPorCalles = const [
    LatLng(-22.1055, -65.5985), // Inicio: Calle Belgrano y Av. España
    LatLng(-22.1055, -65.5960), // Esquina: Belgrano y Balcarce
    LatLng(-22.1024, -65.5960), // Esquina: Balcarce y 9 de Julio
    LatLng(-22.1024, -65.5998), // Destino: Av. Sarmiento 450 (Punto de Recogida)
  ];

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
    final LatLng conductorPos = rutaPorCalles.first;
    final LatLng pasajeroPos = rutaPorCalles.last;

    return Scaffold(
      body: Stack(
        children: [
          // MAPA MODO NAVEGACIÓN ESTILO UBER
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (conductorPos.latitude + pasajeroPos.latitude) / 2,
                (conductorPos.longitude + pasajeroPos.longitude) / 2,
              ),
              initialZoom: 16.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              // Línea de Ruta Curvada por Calles (Estilo Neón Uber #0052FF)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: rutaPorCalles,
                    strokeWidth: 6.5,
                    color: const Color(0xFF0052FF),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              // Marcadores de Vehículo y Pasajero
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
                      child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 24),
                    ),
                  ),
                  Marker(
                    point: pasajeroPos,
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

          // BARRA SUPERIOR DE NAVEGACIÓN ESTILO UBER / DIDI
          Positioned(
            top: 44,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Dark Slate Uber Style
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En 150m gira a la derecha',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
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

          // PANEL INFERIOR ESTILO UBER / DIDI CON BOTONES DE CONTACTO
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

                      // Botón Llamar
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone, color: Color(0xFF00327D)),
                        onPressed: _hacerLlamada,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 8),
                      // Botón WhatsApp
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
                              'PUNTO DE RECOGIDA',
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

                  // Botón Accionar Llegada
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
