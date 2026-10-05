import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/driver_document_service.dart';
import '../../services/driver_document_rules.dart';
import '../../services/driver_session_service.dart';
import '../../services/trip_service.dart';
import '../../services/account_service.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({super.key});

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  bool _loadingRatings = true;
  bool _loadingDocuments = true;
  bool _savingProfile = false;
  bool _deletingAccount = false;
  String? _ratingsError;
  String? _documentsError;
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
    _loadProfile();
    _loadRatings();
    _loadDocuments();
  }

  Future<void> _loadRatings() async {
    if (mounted) {
      setState(() {
        _loadingRatings = true;
        _ratingsError = null;
      });
    }
    try {
      final ratings = await TripService.obtenerCalificacionesConductor(
          DriverSessionService().id);
      if (mounted) setState(() => _ratings = ratings);
    } catch (_) {
      if (mounted)
        setState(() => _ratingsError = 'No pudimos cargar las calificaciones.');
    } finally {
      if (mounted) setState(() => _loadingRatings = false);
    }
  }

  Future<void> _loadDocuments() async {
    final driverId = DriverSessionService().id;
    if (driverId.isEmpty) {
      if (mounted) setState(() => _loadingDocuments = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loadingDocuments = true;
        _documentsError = null;
      });
    }
    try {
      final documents = await DriverDocumentService().forDriver(driverId);
      if (mounted) setState(() => _documents = documents);
    } catch (_) {
      if (mounted) {
        setState(() => _documentsError = 'No pudimos consultar el legajo.');
      }
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([_loadProfile(), _loadRatings(), _loadDocuments()]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService().currentProfile();
      if (profile == null || profile['role'] != 'driver') return;
      DriverSessionService().setSession(
        id: profile['id'].toString(),
        fullName: profile['full_name']?.toString() ?? '',
        phone: profile['phone']?.toString() ?? '',
        vehicleInfo: profile['vehicle_info']?.toString() ?? '',
        plate: profile['plate']?.toString() ?? '',
        taxiNumber: profile['taxi_number']?.toString() ?? '',
        approvedUntil: profile['approved_until']?.toString(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // La sesión local permite seguir mostrando el perfil sin conexión.
    }
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _savingProfile ? null : _editProfile,
                icon: _savingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_outlined),
                label: const Text('EDITAR MIS DATOS Y EL TAXI'),
              ),
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
            const SizedBox(height: 16),
            Card(
              child: Column(children: [
                ListTile(
                  leading:
                      const Icon(Icons.support_agent, color: AppColors.primary),
                  title: const Text('Ayuda y emergencia'),
                  subtitle:
                      const Text('Soporte, incidentes y llamada de emergencia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/soporte'),
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !_deletingAccount,
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppColors.statusCancelled),
                  title: const Text('Eliminar mi cuenta',
                      style: TextStyle(color: AppColors.statusCancelled)),
                  subtitle:
                      const Text('Eliminación definitiva de datos personales'),
                  onTap: _deleteAccount,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta definitivamente'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'No podrás eliminarla si tenés un viaje activo. Tu perfil y documentación se borrarán y esta acción no puede deshacerse.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Escribí ELIMINAR'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusCancelled),
            onPressed: () => Navigator.pop(
                context, controller.text.trim().toUpperCase() == 'ELIMINAR'),
            child: const Text('ELIMINAR CUENTA'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await AccountService().deleteMyAccount(isDriver: true);
      DriverSessionService().clear();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error
              .toString()
              .replaceFirst('PostgrestException(message: ', '')),
        ));
      }
    }
  }

  Widget _documentsCard(BuildContext context) {
    final documentSummary = DriverDocumentRules.summarize(_documents);

    String summary;
    Color summaryColor;
    if (_loadingDocuments) {
      summary = 'Consultando el legajo...';
      summaryColor = AppColors.textSecondary;
    } else if (_documentsError != null) {
      summary = _documentsError!;
      summaryColor = AppColors.statusRejected;
    } else if (documentSummary.missing.isNotEmpty) {
      summary =
          'Faltan ${documentSummary.missing.length} de los 5 documentos obligatorios.';
      summaryColor = AppColors.statusRejected;
    } else if (documentSummary.expired.isNotEmpty) {
      summary =
          '${documentSummary.expired.length} documento(s) están vencidos o sin fecha válida.';
      summaryColor = AppColors.statusRejected;
    } else if (documentSummary.rejected.isNotEmpty) {
      summary =
          '${documentSummary.rejected.length} documento(s) deben reemplazarse.';
      summaryColor = AppColors.statusRejected;
    } else if (documentSummary.expiringSoon.isNotEmpty) {
      summary =
          '${documentSummary.expiringSoon.length} documento(s) vencen dentro de 30 días.';
      summaryColor = AppColors.statusPending;
    } else if (documentSummary.pending.isNotEmpty) {
      summary =
          '${documentSummary.pending.length} documento(s) esperan revisión administrativa.';
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
              child: Text(
                  'Verificá tu número de celular para recibir avisos de administración.',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.3)),
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
    if (_ratingsError != null) {
      return TextButton.icon(
        onPressed: _loadRatings,
        icon: const Icon(Icons.refresh),
        label: const Text('REINTENTAR CALIFICACIONES'),
      );
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

  Future<void> _editProfile() async {
    final session = DriverSessionService();
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: session.fullName);
    final phone = TextEditingController(text: session.phone);
    final vehicle = TextEditingController(text: session.vehicleInfo);
    final plate = TextEditingController(text: session.plate);
    final taxiNumber = TextEditingController(text: session.taxiNumber);

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Editar perfil del conductor',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Mantené estos datos actualizados. Un cambio del vehículo puede requerir una nueva revisión municipal.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Ingresá tu nombre completo.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  return digits.length < 8
                      ? 'Ingresá un teléfono válido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: vehicle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Vehículo',
                    hintText: 'Ej.: Fiat Cronos blanco 2022'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Describí el vehículo.'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: plate,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Patente'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Ingresá la patente.'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: taxiNumber,
                    decoration:
                        const InputDecoration(labelText: 'N.º de móvil'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Ingresá el móvil.'
                        : null,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('GUARDAR CAMBIOS'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (save != true || !mounted) {
      name.dispose();
      phone.dispose();
      vehicle.dispose();
      plate.dispose();
      taxiNumber.dispose();
      return;
    }
    final vehicleChanged = vehicle.text.trim() != session.vehicleInfo.trim() ||
        plate.text.trim().toUpperCase() != session.plate.trim().toUpperCase() ||
        taxiNumber.text.trim() != session.taxiNumber.trim();
    setState(() => _savingProfile = true);
    try {
      final profile = await AuthService().updateDriverProfile(
        fullName: name.text,
        phone: phone.text,
        vehicleInfo: vehicle.text,
        plate: plate.text,
        taxiNumber: taxiNumber.text,
      );
      session.setSession(
        id: profile['id'].toString(),
        fullName: profile['full_name']?.toString() ?? name.text,
        phone: profile['phone']?.toString() ?? phone.text,
        vehicleInfo: profile['vehicle_info']?.toString() ?? vehicle.text,
        plate: profile['plate']?.toString() ?? plate.text,
        taxiNumber: profile['taxi_number']?.toString() ?? taxiNumber.text,
        approvedUntil: profile['approved_until']?.toString(),
      );
      if (mounted) {
        setState(() {});
        if (vehicleChanged) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.fact_check_outlined,
                  color: AppColors.statusPending, size: 40),
              title: const Text('Datos guardados'),
              content: const Text(
                  'Como cambiaste información del taxi, el municipio debe revisar nuevamente tu perfil antes de que vuelvas a conectarte.'),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ENTENDIDO')),
              ],
            ),
          );
          if (mounted) context.go('/cuenta-pendiente');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Datos personales actualizados correctamente.'),
            backgroundColor: AppColors.statusAvailable,
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No pudimos guardar los cambios. Revisá la conexión e intentá nuevamente.'),
        ));
      }
    } finally {
      name.dispose();
      phone.dispose();
      vehicle.dispose();
      plate.dispose();
      taxiNumber.dispose();
      if (mounted) setState(() => _savingProfile = false);
    }
  }
}
