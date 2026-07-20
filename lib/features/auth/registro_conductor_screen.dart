import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

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
  final _vehiculoCtrl = TextEditingController(text: 'Chevrolet Corsa');
  final _patenteCtrl = TextEditingController(text: 'ABC 123');
  final _movilCtrl = TextEditingController(text: '045');

  bool _dniCargado = true;
  bool _licenciaCargada = true;
  bool _seguroCargado = true;
  bool _vtvCargada = true;
  bool _isLoading = false;

  void _registrarse() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud enviada con éxito. Tu legajo está en revisión por la Administración Municipal.'),
            backgroundColor: AppColors.statusAvailable,
          ),
        );
        context.go('/cuenta-pendiente');
      }
    });
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
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono celular (+54 3885...)',
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
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
                          prefixIcon: const Icon(Icons.directions_car_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _patenteCtrl,
                        decoration: InputDecoration(
                          labelText: 'Patente',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _movilCtrl,
                  decoration: InputDecoration(
                    labelText: 'Número de Móvil asignado (Ej: 045)',
                    prefixIcon: const Icon(Icons.numbers, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 24),

                // ADJUNTAR DOCUMENTACIÓN (PAPELES)
                const Text(
                  'DOCUMENTACIÓN OBLIGATORIA (PAPELES)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                _buildDocItem('DNI Frente y Dorso (PDF / Foto)', _dniCargado, () => setState(() => _dniCargado = true)),
                _buildDocItem('Licencia Nacional D1', _licenciaCargada, () => setState(() => _licenciaCargada = true)),
                _buildDocItem('Póliza de Seguro de Taxi', _seguroCargado, () => setState(() => _seguroCargado = true)),
                _buildDocItem('VTV / RTO Vigente', _vtvCargada, () => setState(() => _vtvCargada = true)),

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
                      _isLoading ? 'ENVIANDO SOLICITUD...' : 'ENVIAR SOLICITUD A REVISIÓN',
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

  Widget _buildDocItem(String label, bool isLoaded, VoidCallback onTap) {
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
            color: isLoaded ? AppColors.statusAvailable : AppColors.primary,
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
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isLoaded ? 'Cargado' : 'Subir',
              style: TextStyle(fontSize: 12, color: isLoaded ? AppColors.statusAvailable : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
