import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/supabase_service.dart';

class RegistroPasajeroScreen extends StatefulWidget {
  const RegistroPasajeroScreen({super.key});

  @override
  State<RegistroPasajeroScreen> createState() => _RegistroPasajeroScreenState();
}

class _RegistroPasajeroScreenState extends State<RegistroPasajeroScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _fechaNacCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;

  Future<void> _seleccionarFechaNacimiento() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaNacCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _registrarsePasajero() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final dni = _dniCtrl.text.trim();
      final fechaNac = _fechaNacCtrl.text.trim();
      final telefono = _telefonoCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      final supabase = SupabaseService().client;

      // Verificar si el DNI o teléfono ya existe
      final existente = await supabase
          .from('passengers')
          .select('id')
          .or('dni.eq.$dni,phone.eq.$telefono')
          .maybeSingle();

      if (existente != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya existe un pasajero con ese DNI o teléfono.'), backgroundColor: Color(0xFFEF4444)),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Guardar en Supabase tabla passengers
      await supabase.from('passengers').insert({
        'full_name': nombre,
        'dni': dni,
        'birth_date': fechaNac,
        'phone': telefono,
        'password': password,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bienvenido a QuiacaGo, $nombre. Ahora ingresá con tu DNI o teléfono.'),
            backgroundColor: AppColors.statusAvailable,
          ),
        );
        context.go('/login-pasajero');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          onPressed: () => context.go('/login-pasajero'),
        ),
        title: const Text(
          'Registro de Pasajero',
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
                  'Crea tu cuenta de Pasajero',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresa tus datos personales para solicitar taxis habilitados en La Quiaca.',
                  style: TextStyle(fontSize: 13, color: AppColors.outline),
                ),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _nombreCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre y Apellido completo',
                    hintText: 'Ej: María Gómez',
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _dniCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Documento Nacional de Identidad (DNI)',
                    hintText: 'Ej: 38450123',
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _fechaNacCtrl,
                  readOnly: true,
                  onTap: _seleccionarFechaNacimiento,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Nacimiento',
                    hintText: 'DD/MM/AAAA',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Selecciona tu fecha de nacimiento' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Número de Teléfono Celular',
                    hintText: '+54 3885 401234',
                    prefixIcon: const Icon(Icons.phone_android, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña de acceso',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _registrarsePasajero,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text(
                      _isLoading ? 'CREANDO CUENTA...' : 'CREAR MI CUENTA E INGRESAR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
