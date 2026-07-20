import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class InicioConductorScreen extends StatefulWidget {
  const InicioConductorScreen({super.key});

  @override
  State<InicioConductorScreen> createState() => _InicioConductorScreenState();
}

class _InicioConductorScreenState extends State<InicioConductorScreen> {
  bool _isConnected = false;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Conductor',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.onSurface, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa Interactivo de La Quiaca
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_conductor',
              ),
              const MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng),
                    child: Icon(Icons.directions_car, color: AppColors.primary, size: 36),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Sheet Stitch Conductor
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
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estado del Conductor
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tu estado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? AppColors.statusAvailable.withOpacity(0.15)
                              : AppColors.badgeCancelledBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isConnected ? AppColors.statusAvailable : AppColors.statusCancelled,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isConnected ? 'Disponible' : 'No disponible',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isConnected ? AppColors.statusAvailable : AppColors.statusCancelled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón CONECTARSE
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isConnected = !_isConnected);
                        if (_isConnected) {
                          context.push('/nuevo-pedido');
                        }
                      },
                      icon: const Icon(Icons.power_settings_new, color: Colors.white),
                      label: Text(
                        _isConnected ? 'DESCONECTARSE' : 'CONECTARSE',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected ? AppColors.statusCancelled : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarjetas de Métricas (100% SIN EMOJIS, CON ICONOS MATERIAL)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.outline),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ganancias de hoy',
                                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '\$0.00',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
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
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: AppColors.outline),
                                  SizedBox(width: 4),
                                  Text(
                                    'Viajes',
                                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '0',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
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
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), activeIcon: Icon(Icons.attach_money), label: 'Ganancias'),
          BottomNavigationBarItem(icon: Icon(Icons.history), activeIcon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
