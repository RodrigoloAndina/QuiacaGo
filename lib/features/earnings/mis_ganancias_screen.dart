import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MisGananciasScreen extends StatefulWidget {
  const MisGananciasScreen({super.key});

  @override
  State<MisGananciasScreen> createState() => _MisGananciasScreenState();
}

class _MisGananciasScreenState extends State<MisGananciasScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.local_taxi, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'QuiacaGo Conductor',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: AppColors.primary, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Tab Segmented Hoy / Semana / Mes
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTab(0, 'Hoy'),
                  _buildTab(1, 'Semana'),
                  _buildTab(2, 'Mes'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Header Ganancias
            const Text('Ganancias de hoy', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            const SizedBox(height: 4),
            const Text(
              '\$ 45.250',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '↗ +12% vs ayer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bar Chart Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar(0.45),
                        _buildBar(0.70),
                        _buildBar(1.0, isSelected: true),
                        _buildBar(0.10),
                        _buildBar(0.10),
                        _buildBar(0.10),
                        _buildBar(0.10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Text('L', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      Text('M', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      Text('X', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('J', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      Text('V', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      Text('S', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                      Text('D', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surfaceContainerHigh),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryFixedDim,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_taxi, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('Viajes realizados', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                        const SizedBox(height: 4),
                        const Text(
                          '14',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surfaceContainerHigh),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: AppColors.secondary, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('Calificación', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                        const SizedBox(height: 4),
                        const Text(
                          '4.9 / 5',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tiempo conectado
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time, color: AppColors.onSurface, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Tiempo conectado', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                          Text(
                            '5h 30m',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Text(
                    'Detalle',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(double heightFactor, {bool isSelected = false}) {
    return Container(
      width: 24,
      height: 100 * heightFactor,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : (heightFactor > 0.2 ? AppColors.primaryFixedDim : AppColors.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
