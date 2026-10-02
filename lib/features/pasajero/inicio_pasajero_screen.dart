import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/auth_service.dart';
import '../../services/routing_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/current_trip_session.dart';
import '../trips/cancellation_dialog.dart';

enum EstadoPasajero {
  inicio,
  buscandoTaxi,
  taxiEnCamino,
  taxiLlego,
  enViaje,
  codigoFinalizacion,
  pagoPendiente,
  viajeFinalizado,
  cancelado
}

class InicioPasajeroScreen extends StatefulWidget {
  // Datos del pasajero logueado (se llenan desde el login)
  static String passengerName = 'Pasajero';
  static String passengerPhone = '';

  const InicioPasajeroScreen({super.key});

  @override
  State<InicioPasajeroScreen> createState() => _InicioPasajeroScreenState();
}

class _InicioPasajeroScreenState extends State<InicioPasajeroScreen> {
  EstadoPasajero _estado = EstadoPasajero.inicio;

  LatLng _pasajeroPos =
      const LatLng(AppConstants.laQuiacaLat, AppConstants.laQuiacaLng);
  LatLng _destinoPos = const LatLng(-22.1085, -65.5940);
  LatLng? _conductorPosRealtime;
  List<LatLng> _rutaViaje = [];

  final TextEditingController _origenCtrl =
      TextEditingController(text: 'Mi Ubicación Actual (GPS)');
  final TextEditingController _destinoCtrl =
      TextEditingController(text: 'Terminal de Ómnibus');
  final MapController _mapController = MapController();
  StreamSubscription<LatLng>? _gpsSubscription;
  StreamSubscription<TripModel>? _tripStreamSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _driverTrackingTimer;
  Timer? _driversRefreshTimer;

  TripModel? _viajeActual;
  bool _isPanelMinimized = false;
  bool _selectingPickup = false;
  bool _pickupConfirmed = false;
  bool _destinationConfirmed = false;
  bool _creatingTrip = false;
  bool _confirmingPayment = false;
  bool _cancellingTrip = false;
  bool _submittingRating = false;
  bool _ratingSubmitted = false;
  int _rating = 5;
  final TextEditingController _ratingCommentCtrl = TextEditingController();
  List<DriverLocationModel> _conductoresDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarTarifasVigentes();
    _iniciarGPSReal();
    _cargarConductoresDisponibles();
    _restaurarViajeActivo();
    _connectivitySub = OfflineSyncService().statusStream.listen((online) {
      if (online) _sincronizarAlReconectar();
    });
    _driversRefreshTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _cargarConductoresDisponibles());
  }

  Future<void> _cargarTarifasVigentes() async {
    await TariffService.cargarTarifas();
    if (mounted) setState(() {});
  }

  Future<void> _restaurarViajeActivo() async {
    final profile = await AuthService().currentProfile();
    if (profile != null) {
      InicioPasajeroScreen.passengerName =
          profile['full_name']?.toString() ?? 'Pasajero';
      InicioPasajeroScreen.passengerPhone = profile['phone']?.toString() ?? '';
    }
    final trip = await CurrentTripSession().restore();
    if (!mounted) return;
    if (trip == null) return;
    setState(() {
      _viajeActual = trip;
      _estado = switch (trip.status) {
        'accepted' => EstadoPasajero.taxiEnCamino,
        'arrived' => EstadoPasajero.taxiLlego,
        'in_progress' => EstadoPasajero.enViaje,
        'awaiting_finish_code' => EstadoPasajero.codigoFinalizacion,
        'payment_pending' => EstadoPasajero.pagoPendiente,
        _ => EstadoPasajero.buscandoTaxi,
      };
    });
    _escucharEstadoViaje(trip.id);
    _cargarRutaSimplificada(trip);
    if (trip.driverId != null) _iniciarSeguimientoConductor(trip.driverId!);
  }

  Future<void> _sincronizarAlReconectar() async {
    await OfflineSyncService().syncPendingActions();
    final tripId = _viajeActual?.id;
    if (tripId == null) {
      await _restaurarViajeActivo();
      return;
    }
    final updated = await TripService.obtenerViaje(tripId);
    if (!mounted || updated == null) return;
    _aplicarEstadoViaje(updated);
  }

  Future<void> _iniciarGPSReal() async {
    final posGps = await LocationService.getCurrentLocation();
    if (mounted) {
      const destinoDefecto = LatLng(-22.1085, -65.5940);
      final distLat = (posGps.latitude - destinoDefecto.latitude).abs();

      setState(() {
        _pasajeroPos = posGps;
        if (distLat > 0.5) {
          _destinoPos =
              LatLng(posGps.latitude + 0.005, posGps.longitude + 0.005);
          _destinoCtrl.text = 'Destino Cercano';
        }
      });
      _mapController.move(posGps, 16.2);
    }
    _gpsSubscription =
        LocationService.getRealtimeLocationStream().listen((pos) {
      if (mounted && _estado == EstadoPasajero.inicio)
        setState(() => _pasajeroPos = pos);
    });
  }

  Future<void> _cargarConductoresDisponibles() async {
    final conductores =
        await DriverLocationService.obtenerConductoresDisponibles();
    if (mounted) setState(() => _conductoresDisponibles = conductores);
  }

  Future<void> _cargarRutaSimplificada(TripModel trip) async {
    if (trip.pickupLat == 0 ||
        trip.pickupLng == 0 ||
        trip.destinationLat == 0 ||
        trip.destinationLng == 0) {
      return;
    }
    final pickup = LatLng(trip.pickupLat, trip.pickupLng);
    final destination = LatLng(trip.destinationLat, trip.destinationLng);
    final points = await RoutingService.getRoutePoints(pickup, destination);
    if (!mounted || _viajeActual?.id != trip.id) return;
    setState(() => _rutaViaje = points);

    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, pickup, destination);
    final zoom = meters < 1500
        ? 14.5
        : meters < 5000
            ? 13.0
            : meters < 20000
                ? 10.5
                : 8.0;
    final center = LatLng(
      (pickup.latitude + destination.latitude) / 2,
      (pickup.longitude + destination.longitude) / 2,
    );
    _mapController.move(center, zoom);
  }

  void _tocarPuntoEnMapa(LatLng punto) {
    if (_estado != EstadoPasajero.inicio) return;
    setState(() {
      if (_selectingPickup) {
        _pasajeroPos = punto;
        _origenCtrl.text = 'Punto de recogida marcado en el mapa';
        _pickupConfirmed = false;
      } else {
        _destinoPos = punto;
        _destinoCtrl.text = 'Destino marcado en el mapa';
        _destinationConfirmed = false;
      }
      _isPanelMinimized = true;
    });
  }

  void _seleccionarEnMapa({required bool recogida}) {
    setState(() {
      _selectingPickup = recogida;
      _isPanelMinimized = true;
    });
    _mapController.move(recogida ? _pasajeroPos : _destinoPos, 16.2);
  }

  void _confirmarPuntoDelMapa() {
    if (_selectingPickup) {
      setState(() {
        _pickupConfirmed = true;
        _selectingPickup = false;
        _origenCtrl.text =
            'Recogida (${_pasajeroPos.latitude.toStringAsFixed(5)}, ${_pasajeroPos.longitude.toStringAsFixed(5)})';
      });
      _mapController.move(_destinoPos, 16.2);
      return;
    }
    setState(() {
      _destinationConfirmed = true;
      _destinoCtrl.text =
          'Destino (${_destinoPos.latitude.toStringAsFixed(5)}, ${_destinoPos.longitude.toStringAsFixed(5)})';
      _isPanelMinimized = false;
    });
  }

  Future<void> _confirmarSolicitud() async {
    if (_creatingTrip) return;
    if (!_pickupConfirmed) {
      _seleccionarEnMapa(recogida: true);
      return;
    }
    if (!_destinationConfirmed) {
      _seleccionarEnMapa(recogida: false);
      return;
    }
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Sin conexión. El viaje no fue enviado; reintentá cuando vuelva internet.'),
        ));
      }
      return;
    }
    await TariffService.cargarTarifas();
    final precio = TariffService.calcularPrecio();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar viaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Te recogemos en:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_origenCtrl.text),
            const SizedBox(height: 12),
            const Text('Te llevamos a:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_destinoCtrl.text),
            const SizedBox(height: 16),
            Text('Total: ${TariffService.formatearMonto(precio)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('EDITAR')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONFIRMAR Y PEDIR')),
        ],
      ),
    );
    if (confirmed == true) await _solicitarTaxi();
  }

  Future<void> _solicitarTaxi() async {
    if (_creatingTrip) return;
    if (!_pickupConfirmed || !_destinationConfirmed) {
      await _confirmarSolicitud();
      return;
    }
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión. No se creó ninguna solicitud.')));
      }
      return;
    }
    _creatingTrip = true;
    // Refrescar GPS real fresco antes de generar la solicitud
    if (_origenCtrl.text.startsWith('Mi Ubicación')) {
      _pasajeroPos = await LocationService.getCurrentLocation();
    }

    final precio = TariffService.calcularPrecio();
    setState(() {
      _estado = EstadoPasajero.buscandoTaxi;
      _isPanelMinimized = false;
    });

    print(
        '[Pasajero] Solicitando viaje - Nombre: ${InicioPasajeroScreen.passengerName}, Tel: ${InicioPasajeroScreen.passengerPhone}');
    print(
        '[Pasajero] Origen: ${_origenCtrl.text} (${_pasajeroPos.latitude}, ${_pasajeroPos.longitude})');
    print(
        '[Pasajero] Destino: ${_destinoCtrl.text} (${_destinoPos.latitude}, ${_destinoPos.longitude})');
    print('[Pasajero] Precio: $precio');

    TripModel? trip;
    Object? requestError;
    try {
      trip = await TripService.solicitarViaje(
        passengerName: InicioPasajeroScreen.passengerName,
        passengerPhone: InicioPasajeroScreen.passengerPhone,
        pickupAddress: _origenCtrl.text,
        pickupLat: _pasajeroPos.latitude,
        pickupLng: _pasajeroPos.longitude,
        destinationAddress: _destinoCtrl.text,
        destinationLat: _destinoPos.latitude,
        destinationLng: _destinoPos.longitude,
        fareAmount: precio,
      );
    } catch (error) {
      requestError = error;
    }

    if (trip != null && mounted) {
      print(
          '[Pasajero] Viaje creado exitosamente con ID: ${trip.id}, status: ${trip.status}');
      setState(() => _viajeActual = trip);
      CurrentTripSession().setTrip(trip);
      _escucharEstadoViaje(trip.id);
      _cargarRutaSimplificada(trip);
    } else if (mounted) {
      print('[Pasajero] ERROR: No se pudo crear el viaje en Supabase');
      setState(() => _estado = EstadoPasajero.inicio);
      final detail = requestError?.toString() ?? 'Respuesta vacía de Supabase';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo crear el viaje: $detail'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
      ));
    }
    _creatingTrip = false;
  }

  void _escucharEstadoViaje(String tripId) {
    _tripStreamSub?.cancel();
    _tripStreamSub =
        TripService.escucharViaje(tripId).listen((tripActualizado) {
      if (!mounted) return;
      _aplicarEstadoViaje(tripActualizado);
    });
  }

  void _aplicarEstadoViaje(TripModel tripActualizado) {
    if (!mounted) return;
    final hadAssignedDriver = _viajeActual?.driverId?.isNotEmpty == true;
    setState(() => _viajeActual = tripActualizado);
    CurrentTripSession().setTrip(tripActualizado);
    switch (tripActualizado.status) {
      case 'requested':
        _detenerSeguimientoConductor();
        setState(() => _estado = EstadoPasajero.buscandoTaxi);
        if (hadAssignedDriver) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'El conductor canceló. Estamos buscando otro taxi automáticamente.'),
          ));
        }
        break;
      case 'accepted':
        setState(() => _estado = EstadoPasajero.taxiEnCamino);
        _iniciarSeguimientoConductor(tripActualizado.driverId ?? '');
        break;
      case 'arrived':
        setState(() => _estado = EstadoPasajero.taxiLlego);
        break;
      case 'in_progress':
        setState(() => _estado = EstadoPasajero.enViaje);
        break;
      case 'awaiting_finish_code':
        setState(() => _estado = EstadoPasajero.codigoFinalizacion);
        break;
      case 'payment_pending':
        setState(() => _estado = EstadoPasajero.pagoPendiente);
        break;
      case 'completed':
        _detenerSeguimientoConductor();
        setState(() => _estado = EstadoPasajero.viajeFinalizado);
        CurrentTripSession().clear();
        break;
      case 'cancelled':
        _detenerSeguimientoConductor();
        setState(() => _estado = EstadoPasajero.cancelado);
        CurrentTripSession().clear();
        break;
    }
  }

  void _iniciarSeguimientoConductor(String driverId) {
    if (driverId.isEmpty) return;
    _driverTrackingTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      final loc =
          await DriverLocationService.obtenerUbicacionConductor(driverId);
      if (mounted && loc != null) {
        setState(() => _conductorPosRealtime = loc.posicion);
      }
    });
  }

  void _detenerSeguimientoConductor() {
    _driverTrackingTimer?.cancel();
    _driverTrackingTimer = null;
  }

  Future<void> _confirmarPago() async {
    final trip = _viajeActual;
    if (trip == null || _confirmingPayment) return;
    setState(() => _confirmingPayment = true);
    final ok = await TripService.confirmarPagoEfectivo(trip.id);
    if (!mounted) return;
    setState(() => _confirmingPayment = false);
    if (ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(TripService.lastActionQueued
          ? 'Sin conexión. La confirmación quedó pendiente y se enviará automáticamente.'
          : 'No se pudo confirmar el pago. Intentá nuevamente.'),
    ));
  }

  Future<void> _cerrarSesion() async {
    if (!{
      EstadoPasajero.inicio,
      EstadoPasajero.viajeFinalizado,
      EstadoPasajero.cancelado
    }.contains(_estado)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No podés cerrar sesión mientras hay un viaje activo.'),
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text('¿Querés salir de QuiacaGo Pasajero?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCELAR')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('CERRAR SESIÓN')),
              ],
            ));
    if (confirmed != true) return;
    await AuthService().logout();
    InicioPasajeroScreen.passengerName = 'Pasajero';
    InicioPasajeroScreen.passengerPhone = '';
    if (mounted) context.go('/login-pasajero');
  }

  Future<void> _cancelarViaje() async {
    if (_cancellingTrip) return;
    final trip = _viajeActual;
    if (trip == null) return;
    final choice = await showTripCancellationDialog(
      context,
      isDriver: false,
    );
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
            'No se pudo confirmar la cancelación.'),
      ));
      return;
    }
    _detenerSeguimientoConductor();
    _tripStreamSub?.cancel();
    CurrentTripSession().clear();
    setState(() {
      _estado = EstadoPasajero.cancelado;
    });
  }

  Widget _buildCancelButton() => OutlinedButton.icon(
        onPressed: _cancellingTrip ? null : _cancelarViaje,
        icon: _cancellingTrip
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cancel_outlined),
        label: Text(_cancellingTrip ? 'CANCELANDO...' : 'CANCELAR VIAJE'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.statusCancelled,
          side: const BorderSide(color: AppColors.statusCancelled),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Future<void> _enviarCalificacion() async {
    final trip = _viajeActual;
    if (trip == null || _submittingRating || _ratingSubmitted) return;
    setState(() => _submittingRating = true);
    final ok = await TripService.calificarViaje(
      tripId: trip.id,
      rating: _rating,
      comment: _ratingCommentCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _submittingRating = false;
      _ratingSubmitted = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Gracias. Tu calificación fue guardada.'
          : 'No se pudo guardar. Revisá la conexión e intentá nuevamente.'),
    ));
  }

  void _volverAlInicio() {
    setState(() {
      _estado = EstadoPasajero.inicio;
      _viajeActual = null;
      _conductorPosRealtime = null;
      _rutaViaje = [];
      _pickupConfirmed = false;
      _destinationConfirmed = false;
      _rating = 5;
      _ratingSubmitted = false;
      _ratingCommentCtrl.clear();
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _tripStreamSub?.cancel();
    _connectivitySub?.cancel();
    _driverTrackingTimer?.cancel();
    _driversRefreshTimer?.cancel();
    _mapController.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _ratingCommentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final precio = TariffService.calcularPrecio();
    final descTarifa = TariffService.getDescripcionTarifa();

    // Construir marcadores dinámicos
    final List<Marker> markers = [];

    // Marcador GPS del pasajero
    markers.add(Marker(
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
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: const Center(
            child:
                Icon(Icons.person_pin_circle, color: Colors.white, size: 26)),
      ),
    ));

    // Marcadores de CONDUCTORES DISPONIBLES REALES (de Supabase)
    if (_estado == EstadoPasajero.inicio) {
      for (final c in _conductoresDisponibles) {
        markers.add(Marker(
          point: c.posicion,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]),
            child: const Center(
                child: Icon(Icons.local_taxi, color: Colors.white, size: 22)),
          ),
        ));
      }
    }

    // Marcador del conductor asignado en seguimiento en tiempo real
    if (_conductorPosRealtime != null &&
        (_estado == EstadoPasajero.taxiEnCamino ||
            _estado == EstadoPasajero.taxiLlego ||
            _estado == EstadoPasajero.enViaje)) {
      markers.add(Marker(
        point: _conductorPosRealtime!,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]),
          child: const Center(
              child: Icon(Icons.directions_car, color: Colors.white, size: 26)),
        ),
      ));
    }

    // Destino elegido, visible también durante el seguimiento del viaje.
    if (!_isPanelMinimized &&
        (_estado == EstadoPasajero.inicio || _rutaViaje.isNotEmpty)) {
      markers.add(Marker(
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
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ]),
          child: const Center(
              child: Icon(Icons.location_on, color: Colors.white, size: 26)),
        ),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pasajeroPos,
              initialZoom: 16.0,
              onTap: (_, point) => _tocarPuntoEnMapa(point),
              onPositionChanged: (pos, gesture) {
                if (_isPanelMinimized && gesture && pos.center != null) {
                  setState(() {
                    if (_selectingPickup) {
                      _pasajeroPos = pos.center!;
                      _pickupConfirmed = false;
                      _origenCtrl.text = 'Punto de recogida seleccionado';
                    } else {
                      _destinoPos = pos.center!;
                      _destinationConfirmed = false;
                      _destinoCtrl.text = 'Destino seleccionado';
                    }
                  });
                }
              },
            ),
            children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.quiacago.pasajero'),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
              if (_rutaViaje.isNotEmpty &&
                  _estado != EstadoPasajero.inicio &&
                  _estado != EstadoPasajero.cancelado)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _rutaViaje,
                      strokeWidth: 4,
                      color: AppColors.primary.withOpacity(0.7),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Pin central en modo Uber
          if (_isPanelMinimized && _estado == EstadoPasajero.inicio)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: const Center(
                            child: Icon(Icons.square,
                                color: Colors.white, size: 12))),
                    Container(width: 3, height: 22, color: Colors.black),
                  ],
                ),
              ),
            ),

          // La pantalla principal es la raíz de la app: no debe ofrecer un
          // "volver" sin destino. La flecha sólo cierra el selector del mapa.
          if (_isPanelMinimized && _estado == EstadoPasajero.inicio)
            Positioned(
              top: 44,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]),
                child: IconButton(
                  tooltip: 'Volver a configurar el viaje',
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => setState(() => _isPanelMinimized = false),
                ),
              ),
            ),

          // Botón GPS
          if (_isPanelMinimized)
            Positioned(
              right: 16,
              bottom: 230,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]),
                child: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.black),
                    onPressed: () async {
                      if (_selectingPickup) {
                        final current =
                            await LocationService.getCurrentLocation();
                        if (!mounted) return;
                        setState(() {
                          _pasajeroPos = current;
                          _origenCtrl.text = 'Mi ubicación actual (GPS)';
                          _pickupConfirmed = false;
                        });
                        _mapController.move(current, 16.2);
                      } else {
                        _mapController.move(_destinoPos, 16.2);
                      }
                    }),
              ),
            ),

          Positioned(
            top: 44,
            left:
                _isPanelMinimized && _estado == EstadoPasajero.inicio ? 76 : 16,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout, color: Colors.red),
              ),
            ),
          ),

          // Cantidad de taxis disponibles
          if (_estado == EstadoPasajero.inicio &&
              _conductoresDisponibles.isNotEmpty)
            Positioned(
              top: 44,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_taxi,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                        '${_conductoresDisponibles.length} disponible${_conductoresDisponibles.length > 1 ? "s" : ""}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),

          // Panel inferior
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildPanel(precio, descTarifa)),
        ],
      ),
    );
  }

  Widget _buildPanel(double precio, String descTarifa) {
    switch (_estado) {
      case EstadoPasajero.inicio:
        if (_isPanelMinimized) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6))
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Text(
                    _selectingPickup
                        ? 'Marca dónde te recogemos'
                        : 'Marca tu destino',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 4),
                const Text('Arrastra el mapa para mover el marcador',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: Colors.black, shape: BoxShape.rectangle)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              _selectingPickup
                                  ? _origenCtrl.text
                                  : _destinoCtrl.text,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirmarPuntoDelMapa,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(
                        _selectingPickup
                            ? 'CONFIRMAR RECOGIDA Y ELEGIR DESTINO'
                            : 'CONFIRMAR DESTINO',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
        // Panel completo
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Configurá tu viaje',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  IconButton(
                      icon: const Icon(Icons.pin_drop_outlined,
                          color: AppColors.primary),
                      tooltip: 'Marcar en mapa',
                      onPressed: () => _seleccionarEnMapa(recogida: false)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                !_pickupConfirmed
                    ? 'Paso 1 de 3: elegí dónde te recogemos'
                    : !_destinationConfirmed
                        ? 'Paso 2 de 3: elegí a dónde vas'
                        : 'Paso 3 de 3: revisá y confirmá el viaje',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _origenCtrl,
                  readOnly: true,
                  onTap: () => _seleccionarEnMapa(recogida: true),
                  decoration: InputDecoration(
                      labelText: _pickupConfirmed
                          ? 'Recogida confirmada'
                          : '1. Elegir punto de recogida',
                      suffixIcon: _pickupConfirmed
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF10B981))
                          : const Icon(Icons.chevron_right),
                      prefixIcon: const Icon(Icons.my_location,
                          color: Color(0xFF10B981)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 10),
              TextField(
                  controller: _destinoCtrl,
                  readOnly: true,
                  onTap: () => _seleccionarEnMapa(recogida: false),
                  decoration: InputDecoration(
                      labelText: _destinationConfirmed
                          ? 'Destino confirmado'
                          : '2. Elegir destino',
                      suffixIcon: _destinationConfirmed
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF10B981))
                          : const Icon(Icons.chevron_right),
                      prefixIcon: const Icon(Icons.location_on,
                          color: Color(0xFFEF4444)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TARIFA DIURNA',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.outline)),
                        Text(descTarifa,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                      ]),
                  Text(TariffService.formatearMonto(precio),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _creatingTrip ? null : _confirmarSolicitud,
                  icon: _creatingTrip
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_taxi,
                          color: Colors.white, size: 22),
                  label: Text(
                      _creatingTrip
                          ? 'ENVIANDO SOLICITUD...'
                          : !_pickupConfirmed
                              ? 'ELEGIR DÓNDE ME RECOGEN'
                              : !_destinationConfirmed
                                  ? 'ELEGIR MI DESTINO'
                                  : 'REVISAR Y CONFIRMAR (${TariffService.formatearMonto(precio)})',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                ),
              ),
            ],
          ),
        );

      case EstadoPasajero.buscandoTaxi:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 3.5)),
              const SizedBox(height: 16),
              const Text('Buscando taxi habilitado...',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                  'Solicitud enviada (${TariffService.formatearMonto(precio)})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              _buildCancelButton(),
            ],
          ),
        );

      case EstadoPasajero.taxiEnCamino:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white, size: 28)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('TU TAXI ESTÁ EN CAMINO',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusAvailable)),
                      Text(_viajeActual?.vehicleInfo ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      Text('Conductor: ${_viajeActual?.driverName ?? ""}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ])),
              ]),
              const SizedBox(height: 16),
              const Text(
                  'Seguí la ubicación del taxi en el mapa en tiempo real',
                  style: TextStyle(fontSize: 12, color: AppColors.outline)),
              const SizedBox(height: 14),
              _buildCancelButton(),
            ],
          ),
        );

      case EstadoPasajero.taxiLlego:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.statusAvailable, size: 40),
              const SizedBox(height: 10),
              const Text('TU TAXI LLEGÓ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(_viajeActual?.vehicleInfo ?? '',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.codeBoxBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryFixedDim)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CÓDIGO PIN',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.outline)),
                          Text('Decile este código al taxista',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ]),
                    Text(_viajeActual?.pinCode ?? '----',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 6)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildCancelButton(),
            ],
          ),
        );

      case EstadoPasajero.enViaje:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('EN VIAJE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.statusAvailable)),
                  Text(_destinoCtrl.text,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ]),
                Text(
                    TariffService.formatearMonto(
                        _viajeActual?.fareAmount ?? precio),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ]),
            ],
          ),
        );

      case EstadoPasajero.codigoFinalizacion:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.flag_circle, color: AppColors.primary, size: 46),
            const SizedBox(height: 10),
            const Text('LLEGASTE A DESTINO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
                'Decile este segundo código al conductor para cerrar el viaje.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                    color: AppColors.codeBoxBackground,
                    borderRadius: BorderRadius.circular(16)),
                child: Text(_viajeActual?.finishCode ?? '----',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 8))),
            const SizedBox(height: 8),
            const Text('Código de un solo uso',
                style: TextStyle(fontSize: 11, color: AppColors.outline)),
          ]),
        );

      case EstadoPasajero.pagoPendiente:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.payments_outlined,
                color: AppColors.statusAvailable, size: 48),
            const Text('PAGO EN EFECTIVO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                TariffService.formatearMonto(
                    _viajeActual?.fareAmount ?? precio),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            const Text(
                'Entregá el importe al conductor y confirmá únicamente después del pago.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmingPayment ? null : _confirmarPago,
                  icon: _confirmingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_confirmingPayment
                      ? 'CONFIRMANDO...'
                      : 'CONFIRMAR PAGO Y FINALIZAR'),
                )),
          ]),
        );

      case EstadoPasajero.viajeFinalizado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.statusAvailable, size: 48),
              const SizedBox(height: 10),
              const Text('Viaje Finalizado',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(
                  'Monto: ${TariffService.formatearMonto(_viajeActual?.fareAmount ?? precio)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              if (!_ratingSubmitted) ...[
                const Divider(),
                const Text('¿Cómo estuvo tu viaje?',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Tu opinión ayuda a mejorar el servicio.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value estrellas',
                      onPressed: _submittingRating
                          ? null
                          : () => setState(() => _rating = value),
                      icon: Icon(
                        value <= _rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFF59E0B),
                        size: 34,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: _ratingCommentCtrl,
                  enabled: !_submittingRating,
                  maxLength: 500,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comentario opcional',
                    hintText: 'Contanos qué salió bien o qué podemos mejorar',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _submittingRating ? null : _enviarCalificacion,
                  icon: _submittingRating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined),
                  label: Text(_submittingRating
                      ? 'ENVIANDO...'
                      : 'ENVIAR CALIFICACIÓN'),
                ),
                TextButton(
                  onPressed: _submittingRating ? null : _volverAlInicio,
                  child: const Text('OMITIR POR AHORA'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: AppColors.statusAvailable),
                      SizedBox(width: 8),
                      Text('Calificación enviada',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _volverAlInicio,
                  child: const Text('PEDIR OTRO VIAJE'),
                ),
              ],
            ],
          ),
        );

      case EstadoPasajero.cancelado:
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined,
                  color: AppColors.statusCancelled, size: 44),
              const SizedBox(height: 10),
              const Text('Viaje Cancelado',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusCancelled)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {
                  _estado = EstadoPasajero.inicio;
                  _viajeActual = null;
                  _conductorPosRealtime = null;
                  _rutaViaje = [];
                  _pickupConfirmed = false;
                  _destinationConfirmed = false;
                }),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('VOLVER AL INICIO',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
    }
  }
}
