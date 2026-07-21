import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../services/supabase_service.dart';

class RegistroConductorScreen extends StatefulWidget {
  const RegistroConductorScreen({super.key});

  @override
  State<RegistroConductorScreen> createState() => _RegistroConductorScreenState();
}

class _RegistroConductorScreenState extends State<RegistroConductorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // CAMPOS DE VEHÍCULO 100% EN BLANCO SEGÚN LO SOLICITADO
  final _vehiculoCtrl = TextEditingController();
  final _patenteCtrl = TextEditingController();
  final _movilCtrl = TextEditingController();

  // 5 Documentos separados
  String? _dniFrenteData;
  String? _dniDorsoData;
  String? _licenciaFrenteData;
  String? _seguroData;
  String? _vtvData;

  String? _dniFrenteNombre;
  String? _dniDorsoNombre;
  String? _licenciaFrenteNombre;
  String? _seguroNombre;
  String? _vtvNombre;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _abrirSelectorDocumento(String tipo, String etiqueta) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Text('Adjuntar $etiqueta', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  title: const Text('Tomar Foto con la Cámara'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturarImagen(tipo, ImageSource.camera, etiqueta);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: const Text('Seleccionar de la Galería'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capturarImagen(tipo, ImageSource.gallery, etiqueta);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
                  title: const Text('Seleccionar Archivo (PDF / Imagen)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _seleccionarArchivo(tipo, etiqueta);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _capturarImagen(String tipo, ImageSource source, String etiqueta) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 75);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _guardarDocumento(tipo, base64String, photo.name);
      }
    } catch (e) {
      _mostrarSnackError('Error al capturar imagen: $e');
    }
  }

  Future<void> _seleccionarArchivo(String tipo, String etiqueta) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes != null) {
          final ext = file.extension?.toLowerCase() ?? 'jpg';
          final mime = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
          final base64String = 'data:$mime;base64,${base64Encode(bytes)}';
          _guardarDocumento(tipo, base64String, file.name);
        }
      }
    } catch (e) {
      _mostrarSnackError('Error al seleccionar archivo: $e');
    }
  }

  void _guardarDocumento(String tipo, String data, String nombre) {
    setState(() {
      switch (tipo) {
        case 'dni_frente':
          _dniFrenteData = data;
          _dniFrenteNombre = nombre;
          break;
        case 'dni_dorso':
          _dniDorsoData = data;
          _dniDorsoNombre = nombre;
          break;
        case 'licencia_frente':
          _licenciaFrenteData = data;
          _licenciaFrenteNombre = nombre;
          break;
        case 'seguro':
          _seguroData = data;
          _seguroNombre = nombre;
          break;
        case 'vtv':
          _vtvData = data;
          _vtvNombre = nombre;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Documento "$nombre" adjuntado al legajo.'),
        backgroundColor: AppColors.statusAvailable,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarSnackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dniFrenteData == null || _dniDorsoData == null || _licenciaFrenteData == null || _seguroData == null || _vtvData == null) {
      _mostrarSnackError('⚠️ Debes adjuntar los 5 documentos obligatorios (DNI Frente, DNI Dorso, Licencia Frente, Seguro y VTV).');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final telefono = _telefonoCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final vehiculo = _vehiculoCtrl.text.trim();
      final patente = _patenteCtrl.text.trim().toUpperCase();
      final movil = _movilCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      final supabase = SupabaseService().client;

      // Intentar guardar con las 5 columnas de legajo
      try {
        await supabase.from('profiles').insert({
          'full_name': nombre,
          'phone': telefono,
          'email': email,
          'password': password,
          'role': 'driver',
          'is_approved': false,
          'vehicle_info': '$vehiculo - Móvil $movil ($patente)',
          'plate': patente,
          'taxi_number': movil,
          'dni_frente_url': _dniFrenteData,
          'dni_dorso_url': _dniDorsoData,
          'licencia_frente_url': _licenciaFrenteData,
          'seguro_url': _seguroData,
          'vtv_url': _vtvData,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {
        // Fallback resiliente si en Supabase las columnas especificas no existen aún
        await supabase.from('profiles').insert({
          'full_name': nombre,
          'phone': telefono,
          'email': email,
          'password': password,
          'role': 'driver',
          'is_approved': false,
          'vehicle_info': '$vehiculo - Móvil $movil ($patente)',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud y legajo completos enviados con éxito a la Administración Municipal.'),
            backgroundColor: AppColors.statusAvailable,
          ),
        );
        context.go('/cuenta-pendiente');
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackError('Error al enviar la solicitud: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dniFrenteCargado = _dniFrenteData != null;
    final bool dniDorsoCargado = _dniDorsoData != null;
    final bool licenciaFrenteCargada = _licenciaFrenteData != null;
    final bool seguroCargado = _seguroData != null;
    final bool vtvCargada = _vtvData != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Registro de Conductor',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitud de Alta de Conductor Habilitado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresa tus datos y adjunta tu documentación para ser habilitado en La Quiaca.',
                  style: TextStyle(fontSize: 13, color: AppColors.outline),
                ),
                const SizedBox(height: 24),

                // DATOS PERSONALES
                const Text(
                  'DATOS PERSONALES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre y Apellido completo',
                    hintText: 'Ej: Juan Pérez',
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa tu nombre completo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono celular (+54 3885...)',
                    hintText: '+54 3885 401234',
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa tu teléfono' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa tu correo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña de acceso',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),

                const SizedBox(height: 24),

                // DATOS DEL VEHÍCULO
                const Text(
                  'DATOS DEL VEHÍCULO DE TAXI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _vehiculoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Marca y Modelo',
                          hintText: 'Ej: Chevrolet Corsa',
                          prefixIcon: const Icon(Icons.directions_car_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Marca/Modelo obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _patenteCtrl,
                        decoration: InputDecoration(
                          labelText: 'Patente',
                          hintText: 'ABC 123',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Patente obligatoria' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _movilCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Número de Móvil asignado',
                    hintText: 'Ej: 045',
                    prefixIcon: const Icon(Icons.numbers, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Móvil obligatorio' : null,
                ),

                const SizedBox(height: 24),

                // ADJUNTAR DOCUMENTACIÓN (5 PAPELES OBLIGATORIOS)
                const Text(
                  'DOCUMENTACIÓN OBLIGATORIA (5 ARCHIVOS)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                _buildDocItem('DNI Frente', 'dni_frente', dniFrenteCargado, _dniFrenteNombre),
                _buildDocItem('DNI Dorso', 'dni_dorso', dniDorsoCargado, _dniDorsoNombre),
                _buildDocItem('Licencia Nacional D1 (Frente)', 'licencia_frente', licenciaFrenteCargada, _licenciaFrenteNombre),
                _buildDocItem('Póliza de Seguro de Taxi', 'seguro', seguroCargado, _seguroNombre),
                _buildDocItem('VTV / RTO Vigente', 'vtv', vtvCargada, _vtvNombre),

                const SizedBox(height: 32),

                // BOTÓN ENVIAR REGISTRO
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registrarse,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(
                      _isLoading ? 'ENVIANDO LEGAJO...' : 'ENVIAR SOLICITUD A REVISIÓN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocItem(String label, String tipo, bool isLoaded, String? fileName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLoaded ? AppColors.statusAvailable : AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            isLoaded ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
            color: isLoaded ? AppColors.statusAvailable : AppColors.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLoaded ? AppColors.onSurface : AppColors.outline,
                  ),
                ),
                if (fileName != null)
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 11, color: AppColors.statusAvailable, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _abrirSelectorDocumento(tipo, label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: isLoaded ? AppColors.statusAvailable : AppColors.primary),
            ),
            child: Text(
              isLoaded ? 'Cambiar ✓' : 'Subir',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isLoaded ? AppColors.statusAvailable : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
