import 'package:flutter/material.dart';

class CancellationChoice {
  final String code;
  final String label;
  final String detail;

  const CancellationChoice({
    required this.code,
    required this.label,
    required this.detail,
  });
}

class _Reason {
  final String code;
  final String label;

  const _Reason(this.code, this.label);
}

Future<CancellationChoice?> showTripCancellationDialog(
  BuildContext context, {
  required bool isDriver,
  bool allowPassengerNoShow = false,
}) {
  final reasons = isDriver
      ? <_Reason>[
          if (allowPassengerNoShow)
            const _Reason('passenger_no_show', 'El pasajero no se presentó'),
          const _Reason('mechanical_issue', 'Problema mecánico'),
          const _Reason('personal_emergency', 'Emergencia personal'),
          const _Reason('cannot_reach_pickup', 'No puedo llegar al punto'),
          const _Reason('unsafe_area', 'Zona inaccesible o insegura'),
          const _Reason('passenger_requested', 'El pasajero pidió cancelar'),
          const _Reason('other', 'Otro motivo'),
        ]
      : const <_Reason>[
          _Reason('changed_plans', 'Cambié de planes'),
          _Reason('driver_delayed', 'El conductor está demorando demasiado'),
          _Reason(
              'driver_not_approaching', 'El conductor no se está acercando'),
          _Reason('vehicle_mismatch', 'No reconozco al conductor o vehículo'),
          _Reason('safety_issue', 'Problema de seguridad'),
          _Reason('other', 'Otro motivo'),
        ];
  return showModalBottomSheet<CancellationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      var selected = reasons.first.code;
      final detailController = TextEditingController();
      return StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cancelar viaje',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  isDriver
                      ? 'El pasajero seguirá buscando otro taxi. Indicá por qué no podés continuar.'
                      : 'El conductor será notificado inmediatamente. Indicá el motivo.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                ...reasons.map((reason) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: reason.code,
                      groupValue: selected,
                      title: Text(reason.label),
                      onChanged: (value) =>
                          setModalState(() => selected = value!),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: detailController,
                  maxLength: 250,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comentario opcional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('VOLVER'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBA1A1A),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        final reason =
                            reasons.firstWhere((item) => item.code == selected);
                        Navigator.pop(
                          sheetContext,
                          CancellationChoice(
                            code: reason.code,
                            label: reason.label,
                            detail: detailController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('CONFIRMAR'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      });
    },
  );
}
