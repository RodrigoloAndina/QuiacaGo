import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/driver_document_service.dart';
import '../../services/driver_session_service.dart';
import '../../services/trip_service.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({super.key});

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  bool _loadingRatings = true;
  bool _loadingDocuments = true;
  List<Map<String, dynamic>> _ratings = const [];
  List<Map<String, dynamic>> _documents = const [];

  double get _average {
    if (_ratings.isEmpty) return 0;
    final total = _ratings.fold<int>(
        0, (sum, row) => sum + ((row['rating'] as num?)?.toInt() ?? 0));
    return total / _ratings.length;
  }

  @override
  void initState() {
    super.initState();
    _loadRatings();
    _loadDocuments();
  }

  Future<void> _loadRatings() async {
    final ratings = await TripService.obtenerCalificacionesConductor(
        DriverSessionService().id);
    if (!mounted) return;
    setState(() {
      _ratings = ratings;
      _loadingRatings = false;
    });
  }

  Future<void> _loadDocuments() async {
    final driverId = DriverSessionService().id;
    if (driverId.isEmpty) {
      if (mounted) setState(() => _loadingDocuments = false);
      return;
    }
    try {
      final documents = await DriverDocumentService().forDriver(driverId);
      if (mounted) setState(() => _documents = documents);
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([_loadRatings(), _loadDocuments()]);
  }

  @override
  Widget build(BuildContext context) {
    final session = DriverSessionService();
    final comments = _ratings
        .where((row) => (row['comment']?.toString().trim() ?? '').isNotEmpty)
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del Conductor')),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(session.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    session.phone.isNotEmpty
                        ? session.phone
                        : 'Conductor habilitado · La Quiaca',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _ratingBadge(),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionCard(
              title: 'Información personal',
              icon: Icons.badge_outlined,
              children: [
                _infoRow('Nombre completo', session.fullName),
                _infoRow('Teléfono',
                    session.phone.isNotEmpty ? session.phone : 'No registrado'),
                _infoRow('Licencia', 'Registrada en el legajo'),
              ],
            ),
            const SizedBox(height: 16),
            _documentsCard(context),
            const SizedBox(height: 16),
            _phoneCard(context),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Taxi asignado',
              icon: Icons.local_taxi_outlined,
              children: [
                _infoRow(
                    'Móvil',
                    session.taxiNumber.isNotEmpty
                        ? session.taxiNumber
                        : 'Registrado'),
                _infoRow('Patente',
                    session.plate.isNotEmpty ? session.plate : 'Registrada'),
                _infoRow('Vehículo', session.vehicleInfo),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Comentarios recientes',
              icon: Icons.reviews_outlined,
              children: [
                if (_loadingRatings)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Todavía no recibiste comentarios escritos.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...comments.map(_commentCard),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentsCard(BuildContext context) {
    const requiredTypes = {
      'dni_front',
      'dni_back',
      'license',
      'insurance',
      'vtv'
    };
    final uploadedTypes = _documents
        .map((document) => document['document_type']?.toString())
        .whereType<String>()
        .toSet();
    final missing = requiredTypes.difference(uploadedTypes).length;
    final today = DateTime.now();
    final expiring = _documents.where((document) {
      if (!{'license', 'insurance', 'vtv'}
          .contains(document['document_type'])) {
        return false;
      }
      final expiry =
          DateTime.tryParse(document['expires_at']?.toString() ?? '');
      if (expiry == null) return true;
      return expiry.difference(today).inDays <= 30;
    }).length;
    final pending = _documents
        .where((document) => document['status']?.toString() == 'pending')
        .length;

    String summary;
    Color summaryColor;
    if (_loadingDocuments) {
      summary = 'Consultando el legajo...';
      summaryColor = AppColors.textSecondary;
    } else if (missing > 0) {
      summary = 'Faltan $missing de los 5 documentos obligatorios.';
      summaryColor = AppColors.statusRejected;
    } else if (expiring > 0) {
      summary = '$expiring documento(s) vencidos o próximos a vencer.';
      summaryColor = AppColors.statusPending;
    } else if (pending > 0) {
      summary = '$pending documento(s) esperan revisión administrativa.';
      summaryColor = AppColors.statusPending;
    } else {
      summary = 'Los 5 documentos están cargados y vigentes.';
      summaryColor = AppColors.statusAvailable;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.folder_copy_outlined,
                  color: AppColors.primary, size: 21),
              SizedBox(width: 10),
              Text('Documentación del conductor',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
            const Divider(),
            Text(summary,
                style: TextStyle(
                    color: summaryColor, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Podés cargar los archivos faltantes o reemplazarlos antes de su vencimiento. Cada actualización vuelve a revisión.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadingDocuments
                    ? null
                    : () async {
                        await context.push('/documentacion');
                        await _loadDocuments();
                      },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('CARGAR O ACTUALIZAR DOCUMENTOS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.phone_android_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Verificá tu número de celular para recibir avisos de administración.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.3)),
            ),
            TextButton(
              onPressed: () async {
                await context.push('/verificar-telefono');
                if (mounted) setState(() {});
              },
              child: const Text('VERIFICAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingBadge() {
    if (_loadingRatings) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 5),
          Text(
            _ratings.isEmpty
                ? 'Sin calificaciones todavía'
                : '${_average.toStringAsFixed(1)} · ${_ratings.length} ${_ratings.length == 1 ? 'viaje' : 'viajes'}',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _commentCard(Map<String, dynamic> row) {
    final stars = (row['rating'] as num?)?.toInt() ?? 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < stars ? Icons.star : Icons.star_border,
                color: const Color(0xFFF59E0B),
                size: 17,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(row['comment']?.toString() ?? '',
              style:
                  const TextStyle(color: AppColors.textPrimary, height: 1.35)),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ]),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
