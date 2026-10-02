import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/driver_session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Navegación automática a Login después de 2.5s
    Future.delayed(const Duration(milliseconds: 2500), _resolveSession);
  }

  Future<void> _resolveSession() async {
    Map<String, dynamic>? profile;
    try {
      profile = await AuthService().currentProfile();
    } catch (_) {
      if (AuthService().hasSession && await DriverSessionService().restore()) {
        if (mounted) context.go('/home');
        return;
      }
    }
    if (!mounted) return;
    if (profile?['role'] == 'driver') {
      if (AuthService.suspensionMessage(profile) != null) {
        await AuthService().logout();
        if (mounted) context.go('/login');
        return;
      }
      DriverSessionService().setSession(
        id: profile!['id'].toString(),
        fullName: profile['full_name']?.toString() ?? 'Conductor',
        phone: profile['phone']?.toString() ?? '',
        vehicleInfo: profile['vehicle_info']?.toString() ?? '',
        plate: profile['plate']?.toString() ?? '',
        taxiNumber: profile['taxi_number']?.toString() ?? '',
        approvedUntil: profile['approved_until']?.toString(),
      );
      final approvedUntil =
          DateTime.tryParse(profile['approved_until']?.toString() ?? '');
      final enabled = profile['is_approved'] == true &&
          (approvedUntil == null || approvedUntil.isAfter(DateTime.now()));
      context.go(enabled ? '/home' : '/cuenta-pendiente');
    } else if (AuthService().hasSession &&
        await DriverSessionService().restore()) {
      if (mounted) context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    size: 64,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 24),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Quiaca',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: 'Go',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'CONDUCTOR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    strokeWidth: 3,
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
