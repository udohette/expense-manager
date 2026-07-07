import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AuthStatusBanner extends StatelessWidget {
  const AuthStatusBanner({
    required this.icon,
    required this.message,
    required this.background,
    required this.foreground,
    super.key,
  });

  final IconData icon;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceAuthBackdrop extends StatelessWidget {
  const FinanceAuthBackdrop({
    required this.progress,
    required this.isSignUp,
    super.key,
  });

  final Animation<double> progress;
  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        return Stack(
          children: [
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(-0.92, -0.58),
              radius: 64,
              icon: Icons.pie_chart_rounded,
              color: const Color(0xFFD9E7FF),
              accent: AppColors.primary,
              phase: 0.1,
              depth: 18,
            ),
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(0.95, -0.76),
              radius: 56,
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFE6ECF8),
              accent: AppColors.primaryDark,
              phase: 0.32,
              depth: 14,
            ),
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(-0.72, 0.05),
              radius: 48,
              icon: Icons.stacked_line_chart_rounded,
              color: const Color(0xFFEAF3FF),
              accent: const Color(0xFF5779B0),
              phase: 0.56,
              depth: 20,
            ),
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(0.88, 0.28),
              radius: 58,
              icon: isSignUp
                  ? Icons.savings_rounded
                  : Icons.credit_card_rounded,
              color: const Color(0xFFF0F5FF),
              accent: const Color(0xFF6F88B5),
              phase: 0.78,
              depth: 16,
            ),
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(-0.18, 0.86),
              radius: 42,
              icon: Icons.payments_rounded,
              color: const Color(0xFFE4ECFA),
              accent: const Color(0xFF456392),
              phase: 0.22,
              depth: 12,
            ),
            _FloatingFinanceBubble(
              progress: t,
              alignment: const Alignment(0.72, 0.84),
              radius: 34,
              icon: Icons.attach_money_rounded,
              color: const Color(0xFFF5F8FD),
              accent: AppColors.primary,
              phase: 0.67,
              depth: 10,
            ),
          ],
        );
      },
    );
  }
}

class _FloatingFinanceBubble extends StatelessWidget {
  const _FloatingFinanceBubble({
    required this.progress,
    required this.alignment,
    required this.radius,
    required this.icon,
    required this.color,
    required this.accent,
    required this.phase,
    required this.depth,
  });

  final double progress;
  final Alignment alignment;
  final double radius;
  final IconData icon;
  final Color color;
  final Color accent;
  final double phase;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin((progress + phase) * math.pi * 2);
    final drift = math.cos((progress + phase) * math.pi * 2);
    final dx = drift * depth;
    final dy = wave * depth * 0.8;
    final rotation = wave * 0.16;
    final scale = 0.96 + ((drift + 1) * 0.04);

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateZ(rotation)
              ..rotateX(rotation * 0.6),
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.88),
                    Colors.white.withValues(alpha: 0.74),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: radius * 0.24,
                    left: radius * 0.38,
                    child: Container(
                      width: radius * 0.48,
                      height: radius * 0.22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                  Icon(
                    icon,
                    size: radius * 0.78,
                    color: accent.withValues(alpha: 0.82),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
