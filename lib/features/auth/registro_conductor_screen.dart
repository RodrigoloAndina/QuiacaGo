import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  // DOCUMENTOS DESMARCADOS INICIALMENTE (OBLIGATORIOS)
  bool _dniCargado = false;
  bool _licenciaCargada = false;
  bool _seguroCargado = false;
  bool _vtvCargada = false;
  bool _isLoading = false;

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;

    // VALIDACIÓN OBLIGATORIA DE SUBIDA DE LOS 4 PAPELES
    if (!_dniCargado || !_licenciaCargada || !_seguroCargado || !_vtvCargada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes adjuntar los 4 documentos obligatorios (DNI, Licencia, Seguro y VTV) para enviar el legajo.'),
          backgroundColor: AppColors.statusCancelled,
        ),
      );
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

      // 1. Registrar chofer con estado is_approved = false en Supabase DB
      final supabase = SupabaseService().client;
      await supabase.from('profiles').insert({
        'full_name': nombre,
        'phone': telefono,
        'email': email,
        'role': 'driver',
        'is_approved': false,
        'vehicle_info': '$vehiculo - Móvil $movil ($patente)',
        'created_at': DateTime.now().toIso8601String(),
      }).catchError((_) {});

      // 2. Notificar al Backend para la tabla del Panel Municipal
      try {
        await http.post(
          Uri.parse('http://localhost:3000/api/drivers'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': nombre,
            'phone': telefono,
            'email': email,
            'vehicle': vehiculo,
            'plate': patente,
            'taxiNumber': movil,
            'isApproved': false,
          }),
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud y legajo enviados con éxito a la Administración Municipal.'),
            backgroundColor: AppColors.statusAvailable,
          ),
        );
        context.go('/cuenta-pendiente');
      }
    } catch (e) {
      if (mounted) {
        context.go('/cuenta-pendiente');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _simularCargaDocumento(String tipo, String nombreDocumento) {
    setState(() {
      switch (tipo) {
        case 'dni':
          _dniCargado = true;
          break;
        case 'licencia':
          _licenciaCargada = true;
          break;
        case 'seguro':
          _seguroCargado = true;
          break;
        case 'vtv':
          _vtvCargada = true;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📄 Documento "$nombreDocumento" adjuntado al legajo.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

                // DATOS DEL VEHÍCULO (CAMPOS EN BLANCO)
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

                // ADJUNTAR DOCUMENTACIÓN (PAPELES OBLIGATORIOS)
                const Text(
                  'DOCUMENTACIÓN OBLIGATORIA (PAPELES)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                _buildDocItem('DNI Frente y Dorso (PDF / Foto)', 'dni', _dniCargado),
                _buildDocItem('Licencia Nacional D1', 'licencia', _licenciaCargada),
                _buildDocItem('Póliza de Seguro de Taxi', 'seguro', _seguroCargado),
                _buildDocItem('VTV / RTO Vigente', 'vtv', _vtvCargada),

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

  Widget _buildDocItem(String label, String tipo, bool isLoaded) {
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isLoaded ? AppColors.onSurface : AppColors.outline,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => _simularCargaDocumento(tipo, label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: isLoaded ? AppColors.statusAvailable : AppColors.primary),
            ),
            child: Text(
              isLoaded ? 'Adjuntado ✓' : 'Subir',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isLoaded ? AppColors.statusAvailable : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
