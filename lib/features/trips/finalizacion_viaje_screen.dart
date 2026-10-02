import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/current_trip_session.dart';
import '../../services/tariff_service.dart';
import '../../services/trip_service.dart';
import '../../services/offline_sync_service.dart';

class FinalizacionViajeScreen extends StatefulWidget {
  const FinalizacionViajeScreen({super.key});
  @override
  State<FinalizacionViajeScreen> createState() =>
      _FinalizacionViajeScreenState();
}

class _FinalizacionViajeScreenState extends State<FinalizacionViajeScreen> {
  final _code = TextEditingController();
  StreamSubscription<TripModel>? _subscription;
  bool _validating = false;
  bool _waitingPayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final trip = CurrentTripSession().currentTrip;
    if (trip != null) {
      _waitingPayment = trip.status == 'payment_pending';
      _subscription = TripService.escucharViaje(trip.id).listen((updated) {
        if (!mounted) return;
        CurrentTripSession().setTrip(updated);
        if (updated.status == 'completed') {
          // El chofer conserva el tracking activo. Al volver al inicio, la
          // pantalla detecta la sesión online y continúa recibiendo pedidos.
          CurrentTripSession().clear();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Viaje finalizado. Seguís conectado y disponible.')));
          context.go('/home');
        }
      });
    }
  }

  Future<void> _validate() async {
    final trip = CurrentTripSession().currentTrip;
    if (trip == null || _code.text.length != 4) {
      setState(() => _error = 'Ingresá los cuatro dígitos del pasajero.');
      return;
    }
    if (!await OfflineSyncService().checkNow()) {
      if (mounted) {
        setState(() => _error =
            'Sin conexión. El código no fue consumido; reintentá cuando vuelva internet.');
      }
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    final ok = await TripService.validarCodigoFinalizacion(trip.id, _code.text);
    if (!mounted) return;
    setState(() {
      _validating = false;
      _waitingPayment = ok;
    });
    if (ok) {
      CurrentTripSession().setTrip(trip.copyWithStatus('payment_pending'));
    }
    if (!ok)
      setState(() => _error = 'Código incorrecto, vencido o ya utilizado.');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = CurrentTripSession().currentTrip;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Finalizar viaje'),
          backgroundColor: AppColors.primary),
      body: Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    _waitingPayment
                        ? Icons.payments_outlined
                        : Icons.pin_outlined,
                    size: 64,
                    color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                    _waitingPayment
                        ? 'Esperando confirmación del pago'
                        : 'Código de finalización',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    _waitingPayment
                        ? 'Cobrá ${TariffService.formatearMonto(trip?.fareAmount ?? 0)} en efectivo. El pasajero debe confirmar el pago desde su app.'
                        : 'Pedile al pasajero el segundo código. Es diferente al código de inicio y funciona una sola vez.',
                    textAlign: TextAlign.center),
                if (!_waitingPayment) ...[
                  const SizedBox(height: 24),
                  TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                          labelText: 'Código de 4 dígitos',
                          border: OutlineInputBorder())),
                  if (_error != null)
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _validating ? null : _validate,
                        child: Text(
                            _validating ? 'VALIDANDO…' : 'VALIDAR Y COBRAR'),
                      )),
                ] else ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ]),
            ))),
      )),
    );
  }
}
