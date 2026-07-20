import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  final LatLng origenPos = const LatLng(-22.1024, -65.5998); // Av. Sarmiento 450
  final LatLng destinoPos = const LatLng(-22.1085, -65.5940); // Terminal de Ómnibus

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
      appBar: AppBar(
        title: const Text('Viaje en Curso'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _hacerLlamada,
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.white),
            onPressed: _abrirWhatsApp,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa de Navegación con Ruta Trazada al Destino Final
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (origenPos.latitude + destinoPos.latitude) / 2,
                (origenPos.longitude + destinoPos.longitude) / 2,
              ),
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              // Línea de Ruta Trazada al Destino (Color Terracota Andino)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      origenPos,
                      const LatLng(-22.1040, -65.5980),
                      const LatLng(-22.1060, -65.5960),
                      destinoPos,
                    ],
                    strokeWidth: 6.0,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              // Marcadores del Auto en Movimiento y del Destino Final
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(-22.1040, -65.5980),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 26),
                    ),
                  ),
                  Marker(
                    point: destinoPos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.statusCancelled,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Indicación Superior de Giro / Navegación
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                children: const [
                  Icon(Icons.turn_right, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En 200m gira a la derecha',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'por Av. España hacia Terminal de Ómnibus',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet de Navegación y Finalización de Viaje
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info Destino + Precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESTINO FINAL',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                          ),
                          Text(
                            'Terminal de Ómnibus',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.codeBoxBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '\$ 1,250',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Row(
                    children: [
                      Icon(Icons.person, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Pasajero: María Gómez', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Spacer(),
                      Text('Efectivo', style: TextStyle(color: AppColors.statusAvailable, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón Finalizar Viaje
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/finalizacion-viaje'),
                      icon: const Icon(Icons.flag, color: Colors.white),
                      label: const Text(
                        'FINALIZAR VIAJE Y COBRAR \$1,250',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCancelled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
