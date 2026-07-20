import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DocumentacionConductorScreen extends StatelessWidget {
  const DocumentacionConductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> documentos = [
      {
        'titulo': 'Habilitación Municipal La Quiaca',
        'subtitulo': 'Exp: 2024-99812-MUNI',
        'vencimiento': 'Vence: 15/12/2026',
        'estado': 'APROBADO',
        'color': AppColors.statusAvailable,
      },
      {
        'titulo': 'Licencia de Conducir (Cat. D1)',
        'subtitulo': 'Municipalidad de La Quiaca',
        'vencimiento': 'Vence: 10/10/2027',
        'estado': 'APROBADO',
        'color': AppColors.statusAvailable,
      },
      {
        'titulo': 'Seguro del Automotor (Poliza Taxi)',
        'subtitulo': 'Sancor Seguros - Poliza 884120',
        'vencimiento': 'Vence: 01/09/2026',
        'estado': 'APROBADO',
        'color': AppColors.statusAvailable,
      },
      {
        'titulo': 'RTO / VTV Técnica Vehicular',
        'subtitulo': 'Revision Técnica Obligatoria Jujuy',
        'vencimiento': 'Vence: 30/08/2026',
        'estado': 'PENDIENTE',
        'color': AppColors.statusPending,
      },
      {
        'titulo': 'Certificado de Antecedentes Penales',
        'subtitulo': 'Policía de la Provincia de Jujuy',
        'vencimiento': 'Vence: 05/01/2026',
        'estado': 'VENCIDO',
        'color': AppColors.statusRejected,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Documentación Habilitada'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: documentos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final doc = documentos[index];
          final Color badgeColor = doc['color'] as Color;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.description, color: badgeColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['titulo'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc['subtitulo'],
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doc['vencimiento'],
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    doc['estado'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
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
}
