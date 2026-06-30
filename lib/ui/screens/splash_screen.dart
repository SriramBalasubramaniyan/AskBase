import 'package:flutter/material.dart';

import '../app_theme.dart';

class SplashScreen extends StatefulWidget {
  final String message;
  const SplashScreen({super.key, required this.message});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Opacity(
                opacity: _pulse.value,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accentDim, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.grain_rounded,
                    color: AppColors.accent,
                    size: 34,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text('AskBase', style: AppTextStyles.displayLarge),

            const SizedBox(height: 8),

            Text(
              widget.message,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}
