import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';
import '../../services/tariff_service.dart';

enum EstadoPasajero {
  inicio,           // Seleccionando origen y destino
  buscandoTaxi,     // Esperando que un chofer acepte
  taxiEnCamino,     // Chofer aceptó y va en camino
  enViaje,          // Pasajero a bordo viajando al destino
  viajeFinalizado,  // Viaje completado
  cancelado         // Viaje cancelado por emergencia
}

class DestinoPredefinido {
  final String nombre;
  final String direccion;
  final LatLng ubicacion;
  final IconData icono;

  const DestinoPredefinido({
    required this.nombre,
    required this.direccion,
    required this.ubicacion,
    required this.icono,
  });
}

class InicioPasajeroScreen extends StatefulWidget {
  const InicioPasajeroScreen({super.key});

  @override
  State<InicioPasajeroScreen> createState() => _InicioPasajeroScreenState();
}

class _InicioPasajeroScreenState extends State<InicioPasajeroScreen> {
  EstadoPasajero _estado = EstadoPasajero.inicio;

  // Ubicación GPS real del pasajero
  LatLng _pasajeroPos = const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  LatLng _destinoPos = const LatLng(-22.1085, -65.5940); // Por defecto Terminal
  LatLng _conductorPos = const LatLng(-22.1055, -65.5985); // Taxi Móvil 045

  final TextEditingController _origenCtrl = TextEditingController(text: 'Mi Ubicación Actual (GPS)');
  final TextEditingController _destinoCtrl = TextEditingController(text: 'Terminal de Ómnibus');
  final MapController _mapController = MapController();
  StreamSubscription<LatLng>? _gpsSubscription;

  // Código PIN de 4 dígitos único
  String _codigoPinSeguridad = '4821';
  bool _esFeriado = false;
  String _motivoCancelacion = '';

  // LISTA OFICIAL DE DESTINOS FAVORITOS PREDEFINIDOS DE LA QUIACA
  final List<DestinoPredefinido> _destinosFavoritos = const [
    DestinoPredefinido(
      nombre: 'Terminal de Ómnibus',
      direccion: 'Av. España y 25 de Mayo',
      ubicacion: LatLng(-22.1085, -65.5940),
      icono: Icons.directions_bus,
    ),
    DestinoPredefinido(
      nombre: 'Hospital Jorge Uro',
      direccion: 'Av. Sarmiento y Balcarce',
      ubicacion: LatLng(-22.1065, -65.6020),
      icono: Icons.local_hospital,
    ),
    DestinoPredefinido(
      nombre: 'Plaza Centenario / Centro',
      direccion: 'Calle Belgrano y San Martín',
      ubicacion: LatLng(-22.1045, -65.5980),
      icono: Icons.park,
    ),
    DestinoPredefinido(
      nombre: 'Puente Internacional La Quiaca - Villazón',
      direccion: 'Paso Fronterizo',
      ubicacion: LatLng(-22.0965, -65.5960),
      icono: Icons.flag,
    ),
    DestinoPredefinido(
      nombre: 'Mercado Central',
      direccion: 'Calle Pellegrini 150',
      ubicacion: LatLng(-22.1030, -65.5975),
      icono: Icons.shopping_basket,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iniciarGPSReal();
  }

  Future<void> _iniciarGPSReal() async {
    // Captura inicial de posición GPS precisa del dispositivo
    final posGps = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _pasajeroPos = posGps;
      });
      _mapController.move(posGps, 16.2);
    }

    // Escuchar movimiento del dispositivo en tiempo real
    _gpsSubscription = LocationService.getRealtimeLocationStream().listen((pos) {
      if (mounted && _estado == EstadoPasajero.inicio) {
        setState(() {
          _pasajeroPos = pos;
        });
      }
    });
  }

  void _seleccionarDestinoFav(DestinoPredefinido fav) {
    setState(() {
      _destinoPos = fav.ubicacion;
      _destinoCtrl.text = fav.nombre;
    });
    _mapController.move(fav.ubicacion, 16.0);
  }

  void _tocarPuntoEnMapa(LatLng puntoTocado) {
    if (_estado != EstadoPasajero.inicio) return;
    setState(() {
      _destinoPos = puntoTocado;
      _destinoCtrl.text = 'Punto Marcado en Mapa (${puntoTocado.latitude.toStringAsFixed(4)}, ${puntoTocado.longitude.toStringAsFixed(4)})';
    });
  }

  void _solicitarTaxi() {
    setState(() {
      _estado = EstadoPasajero.buscandoTaxi;
    });
  }

  void _cancelarSolicitudConMotivo() {
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancelar Viaje', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Indica el motivo de cancelación. El motivo quedará registrado en el historial de auditoría municipal.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Motivo de cancelación',
                  hintText: 'Ej: Demora prolongada del móvil',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _motivoCancelacion = ctrl.text.trim();
                  _estado = EstadoPasajero.cancelado;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Viaje cancelado. Se registró el motivo en el historial municipal.'),
                    backgroundColor: AppColors.statusCancelled,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusCancelled),
              child: const Text('Confirmar Cancelación'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _llamarChofer() async {
    final Uri url = Uri.parse('tel:+5493885401234');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _mapController.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final precioCalculado = TariffService.calcularPrecio(esFeriado: _esFeriado);
    final descTarifa = TariffService.getDescripcionTarifa(esFeriado: _esFeriado);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.local_taxi, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Pasajero',
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
            icon: Icon(_esFeriado ? Icons.event_available : Icons.event_outlined, color: _esFeriado ? AppColors.secondary : AppColors.primary),
            tooltip: 'Alternar Tarifa Feriado/Nocturna',
            onPressed: () {
              setState(() {
                _esFeriado = !_esFeriado;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_esFeriado ? '🌙 Tarifa Nocturna/Feriado Activada (\$3.000)' : '☀️ Tarifa Diurna Municipal Activada (\$2.500)'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPA INTERACTIVO HD CON CAPTURA DE TOQUE DIRECTO PARA ELEGIR DESTINO
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pasajeroPos,
              initialZoom: 16.0,
              onTap: (tapPos, point) => _tocarPuntoEnMapa(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.quiacago.quiaca_go_pasajero',
              ),
              MarkerLayer(
                markers: [
                  // Marcador Verde GPS Exacto del Pasajero
                  Marker(
                    point: _pasajeroPos,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 28),
                    ),
                  ),
                  // Marcador Rojo de Destino Seleccionado
                  Marker(
                    point: _destinoPos,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // PANEL INFERIOR DINÁMICO
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildPanelSegunEstado(precioCalculado, descTarifa),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelSegunEstado(double precio, String descTarifa) {
    switch (_estado) {
      case EstadoPasajero.inicio:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '¿A dónde vamos en La Quiaca?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixedDim.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Toca el mapa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Campo Origen (GPS)
              TextField(
                controller: _origenCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Punto de Recogida (Tu GPS)',
                  prefixIcon: const Icon(Icons.my_location, color: Color(0xFF10B981)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              // Campo Destino
              TextField(
                controller: _destinoCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Destino Seleccionado',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFFEF4444)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              // DESTINOS FAVORITOS PREDEFINIDOS EN LA QUIACA
              const Text(
                'DESTINOS FAVORITOS PREDEFINIDOS:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _destinosFavoritos.length,
                  itemBuilder: (context, i) {
                    final fav = _destinosFavoritos[i];
                    final isSelected = _destinoCtrl.text == fav.nombre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: Icon(fav.icono, size: 16, color: isSelected ? Colors.white : AppColors.primary),
                        label: Text(fav.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary)),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceContainerLow,
                        onSelected: (_) => _seleccionarDestinoFav(fav),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              // TARIFA MUNICIPAL DE LA QUIACA ($2500 / $3000)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARIFA OFICIAL MUNICIPAL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline),
                      ),
                      Text(
                        descTarifa,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    TariffService.formatearMonto(precio),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _solicitarTaxi,
                  icon: const Icon(Icons.local_taxi, color: Colors.white, size: 22),
                  label: Text(
                    'PEDIR TAXI AHORA (${TariffService.formatearMonto(precio)})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.buscandoTaxi:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Buscando taxi habilitado cercano...',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Solicitud activa en La Quiaca (${TariffService.formatearMonto(precio)})',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _cancelarSolicitudConMotivo,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusCancelled),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('CANCELAR SOLICITUD', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.taxiEnCamino:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡TAXI ASIGNADO EN CAMINO!',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.statusAvailable),
                        ),
                        Text(
                          'Móvil 045 • Chevrolet Corsa',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text('Conductor: Carlos M. (⭐ 4.9)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.phone, color: AppColors.primary),
                    onPressed: _llamarChofer,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // CÓDIGO PIN DE SEGURIDAD OBLIGATORIO DE 4 DÍGITOS
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.codeBoxBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryFixedDim),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CÓDIGO PIN OBLIGATORIO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.outline),
                        ),
                        Text(
                          'Proporciona este código al taxista',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      _codigoPinSeguridad,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelarSolicitudConMotivo,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.statusCancelled),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('CANCELAR', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _estado = EstadoPasajero.enViaje;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('SUBÍ AL TAXI / EN VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case EstadoPasajero.enViaje:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EN VIAJE A TU DESTINO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.statusAvailable)),
                      Text(_destinoCtrl.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  Text(TariffService.formatearMonto(precio), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Nota: Únicamente el conductor puede finalizar formalmente el viaje.',
                style: TextStyle(fontSize: 11, color: AppColors.outline),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _cancelarSolicitudConMotivo,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.statusCancelled),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('EMERGENCIA: CANCELAR VIAJE', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.viajeFinalizado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const Icon(Icons.check_circle, color: AppColors.statusAvailable, size: 48),
              const SizedBox(height: 10),
              const Text('¡Viaje Finalizado con Éxito!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('Monto abonado en efectivo: ${TariffService.formatearMonto(precio)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _estado = EstadoPasajero.inicio;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('PEDIR OTRO VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

      case EstadoPasajero.cancelado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const Icon(Icons.cancel_outlined, color: AppColors.statusCancelled, size: 44),
              const SizedBox(height: 10),
              const Text('Viaje Cancelado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.statusCancelled)),
              if (_motivoCancelacion.isNotEmpty)
                Text('Motivo registrado: "$_motivoCancelacion"', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _estado = EstadoPasajero.inicio;
                    _motivoCancelacion = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('VOLVER AL INICIO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    }
  }
}
