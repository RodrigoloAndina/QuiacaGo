import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/account_service.dart';
import '../../services/auth_service.dart';

class CuentaPasajeroScreen extends StatefulWidget {
  const CuentaPasajeroScreen({super.key});

  @override
  State<CuentaPasajeroScreen> createState() => _CuentaPasajeroScreenState();
}

class _CuentaPasajeroScreenState extends State<CuentaPasajeroScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
            'Esta acción elimina definitivamente tu cuenta y tus datos personales. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONTINUAR')),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmación final'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Escribí ELIMINAR'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('VOLVER')),
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
    setState(() => _deleting = true);
    try {
      await AccountService().deleteMyAccount(isDriver: false);
      if (mounted) context.go('/login-pasajero');
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ListTile(
            leading: const Icon(Icons.support_agent, color: AppColors.primary),
            title: const Text('Ayuda y emergencia'),
            subtitle:
                const Text('Contactar a soporte o servicios de emergencia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/soporte-pasajero'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/login-pasajero');
            },
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusCancelled),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('ELIMINAR MI CUENTA'),
          ),
        ]),
      );
}
