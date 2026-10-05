import 'package:flutter/material.dart';
import '../../services/legal_service.dart';
import 'legal_screen.dart';
import '../../services/current_trip_session.dart';

/// Applied after trip restoration so consent never obscures an active journey.
class LegalGate extends StatefulWidget {
  const LegalGate({super.key, required this.child});
  final Widget child;
  @override
  State<LegalGate> createState() => _LegalGateState();
}

class _LegalGateState extends State<LegalGate> {
  bool? _required;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _failed = false);
    try {
      final trip = await CurrentTripSession().restore();
      if (trip != null && !['completed', 'cancelled'].contains(trip.status)) {
        if (mounted) setState(() => _required = false);
        return;
      }
      final required = await LegalService().needsAcceptance();
      if (mounted) setState(() => _required = required);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_required == false) return widget.child;
    if (_required == true)
      return LegalScreen(
          requireAcceptance: true,
          onAccepted: () => setState(() => _required = false));
    return Scaffold(
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: _failed
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Conectate para verificar las condiciones vigentes antes de solicitar u ofrecer viajes.'),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _check, child: const Text('REINTENTAR'))
                      ])
                    : const CircularProgressIndicator())));
  }
}
