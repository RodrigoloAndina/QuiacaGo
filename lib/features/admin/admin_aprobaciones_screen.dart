import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AdminAprobacionesScreen extends StatefulWidget {
  const AdminAprobacionesScreen({super.key});

  @override
  State<AdminAprobacionesScreen> createState() => _AdminAprobacionesScreenState();
}

class _AdminAprobacionesScreenState extends State<AdminAprobacionesScreen> {
  final List<Map<String, dynamic>> _solicitudes = [
    {
      'id': 'driver-042',
      'nombre': 'Carlos Mamani',
      'telefono': '+54 3885 401234',
      'vehiculo': 'Chevrolet Corsa Blanco (Móvil 042)',
      'patente': 'ABC 123',
      'dni': '32.145.678',
      'habilitacion': 'Exp: 2024-99812-MUNI (Vence 15/12/2026)',
      'licencia': 'Cat. D1 Habilitada',
      'vtv': 'RTO Jujuy Aprobada',
      'seguro': 'Sancor Seguros Póliza 884120',
      'isApproved': false,
    },
    {
      'id': 'driver-043',
      'nombre': 'Roberto Flores',
      'telefono': '+54 3885 777888',
      'vehiculo': 'Renault Kangoo Gris (Móvil 043)',
      'patente': 'AF 342',
      'dni': '29.888.111',
      'habilitacion': 'Exp: 2024-99815-MUNI (Vence 10/10/2026)',
      'licencia': 'Cat. D1 Habilitada',
      'vtv': 'RTO Jujuy Aprobada',
      'seguro': 'La Segunda Seguros',
      'isApproved': false,
    },
  ];

  void _aprobarConductor(int index) {
    setState(() {
      _solicitudes[index]['isApproved'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.statusAvailable,
        content: Text('✅ Conductor ${_solicitudes[index]['nombre']} APROBADO e incorporado al sistema.'),
      ),
    );
  }

  void _rechazarConductor(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.statusCancelled,
        content: Text('❌ Solicitud de ${_solicitudes[index]['nombre']} devuelta para revisión de documentos.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Administración Municipal - QuiacaGo'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _solicitudes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final sol = _solicitudes[index];
          final isApproved = sol['isApproved'] as bool;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isApproved ? AppColors.statusAvailable : AppColors.outlineVariant,
                width: isApproved ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isApproved ? AppColors.statusAvailable : AppColors.primary,
                          child: Text(
                            sol['nombre'][0],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sol['nombre'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                            Text(
                              sol['telefono'],
                              style: const TextStyle(fontSize: 12, color: AppColors.outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? AppColors.statusAvailable.withOpacity(0.12) : AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isApproved ? 'HABILITADO' : 'PENDIENTE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? AppColors.statusAvailable : AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                _buildDocItem('🚘 Vehículo:', sol['vehiculo']),
                _buildDocItem('🏷️ Patente:', sol['patente']),
                _buildDocItem('🆔 DNI:', sol['dni']),
                _buildDocItem('🏛️ Habilitación:', sol['habilitacion']),
                _buildDocItem('🪪 Licencia:', sol['licencia']),
                _buildDocItem('🔍 VTV / RTO:', sol['vtv']),
                _buildDocItem('🛡️ Seguro:', sol['seguro']),

                const SizedBox(height: 20),

                if (!isApproved)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rechazarConductor(index),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.statusCancelled),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          child: const Text('RECHAZAR', style: TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _aprobarConductor(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusAvailable,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          child: const Text('APROBAR TAXISTA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.statusAvailable.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        '✓ Habilitación registrada en PostgreSQL Supabase',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.statusAvailable),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.outline, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }
}
