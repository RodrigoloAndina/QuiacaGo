import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class SplashPasajeroScreen extends StatefulWidget {
  const SplashPasajeroScreen({super.key});

  @override
  State<SplashPasajeroScreen> createState() => _SplashPasajeroScreenState();
}

class _SplashPasajeroScreenState extends State<SplashPasajeroScreen> {
  @override
  void initState() {
    super.initState();
    // Transición automática a la pantalla de Login de Pasajero en 2.5 segundos
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/login-pasajero');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo QuiacaGo Pasajero
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.hail_rounded, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 24),

              const Text(
                'QuiacaGo Pasajero',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Taxis Habilitados • La Quiaca, Jujuy',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF93C5FD),
                ),
              ),

              const SizedBox(height: 48),

              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF10B981),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
