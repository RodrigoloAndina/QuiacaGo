import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class TaxiAsignadoScreen extends StatelessWidget {
  const TaxiAsignadoScreen({super.key});

  final LatLng conductorPos = const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  final LatLng pasajeroPos = const LatLng(-22.1024, -65.5998); // Av. Sarmiento 450

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
      appBar: AppBar(
        title: const Text('En camino al Pasajero'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: Stack(
        children: [
          // Mapa de Ruta Trazada al Pasajero
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (conductorPos.latitude + pasajeroPos.latitude) / 2,
                (conductorPos.longitude + pasajeroPos.longitude) / 2,
              ),
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              // Línea de Ruta Trazada en Azul
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      conductorPos,
                      const LatLng(-22.1040, -65.5990),
                      const LatLng(-22.1030, -65.5995),
                      pasajeroPos,
                    ],
                    strokeWidth: 5.0,
                    color: AppColors.primary,
                  ),
                ],
              ),
              // Marcador del Auto y del Pasajero
              MarkerLayer(
                markers: [
                  Marker(
                    point: conductorPos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                    ),
                  ),
                  Marker(
                    point: pasajeroPos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.statusAvailable,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Card Inferior con Datos del Pasajero
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
                  // Info Pasajero + Botones de Contacto
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
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
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '4.9 (12 viajes)',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botón Llamar
                      IconButton.filledTonal(
                        icon: const Icon(Icons.phone, color: AppColors.primary),
                        onPressed: _hacerLlamada,
                        tooltip: 'Llamar al Pasajero',
                      ),
                      const SizedBox(width: 6),
                      // Botón WhatsApp
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chat_outlined, color: AppColors.statusAvailable),
                        onPressed: _abrirWhatsApp,
                        tooltip: 'Enviar WhatsApp',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Dirección Origen & Distancia
                  Row(
                    children: const [
                      Icon(Icons.navigation, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PUNTO DE RECOGIDA (A 1.2 KM - 4 MIN)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                            ),
                            Text(
                              'Av. Sarmiento 450, La Quiaca',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón "Llegué al Punto de Encuentro"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/confirmacion-llegada'),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'HE LLEGADO AL PASAJERO',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusAvailable,
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
