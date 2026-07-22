import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../dashboard/home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _motionController;
  int _pageIndex = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Capture bank debit and credit alerts in one clean flow',
      message:
          'Bring bank-alert details into the app, review debit and credit activity clearly, and keep every record organized from day one.',
      visual: _OnboardingVisualType.bankAlerts,
    ),
    _OnboardingItem(
      title: 'Set budgets before spending drifts',
      message:
          'Build weekly or monthly limits, watch categories move in real time, and catch overspending before it compounds.',
      visual: _OnboardingVisualType.budgetControl,
    ),
    _OnboardingItem(
      title: 'Make smarter decisions from live trends',
      message:
          'Track balances, category movement, and recent activity with a dashboard that keeps business and personal spending visible.',
      visual: _OnboardingVisualType.trendSignals,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.controller.setOnboardingComplete();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeShell(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 760;
            final horizontalPadding = constraints.maxWidth < 390 ? 20.0 : 24.0;
            final topSpacing = isCompact ? 16.0 : 24.0;
            final logoHeight = isCompact ? 104.0 : 132.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topSpacing,
                horizontalPadding,
                16,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BrandedLogo(height: logoHeight),
                  ),
                  SizedBox(height: isCompact ? 18 : 28),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (value) =>
                          setState(() => _pageIndex = value),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return LayoutBuilder(
                          builder: (context, pageConstraints) {
                            final heroHeight =
                                (pageConstraints.maxHeight *
                                        (isCompact ? 0.36 : 0.48))
                                    .clamp(180.0, 340.0);

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: pageConstraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OnboardingHeroCard(
                                      height: heroHeight,
                                      motion: _motionController,
                                      visual: item.visual,
                                    ),
                                    SizedBox(height: isCompact ? 22 : 30),
                                    Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            height: 1.06,
                                            fontSize: isCompact ? 26 : 30,
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      item.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            height: 1.55,
                                            fontSize: isCompact ? 15 : 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: isCompact ? 16 : 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        _items.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: _pageIndex == index ? 34 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: _pageIndex == index
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 18 : 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _pageIndex == _items.length - 1
                          ? _finish
                          : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(
                          vertical: isCompact ? 18 : 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        _pageIndex == _items.length - 1
                            ? 'Start tracking'
                            : 'Continue',
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingHeroCard extends StatelessWidget {
  const _OnboardingHeroCard({
    required this.height,
    required this.motion,
    required this.visual,
  });

  final double height;
  final Animation<double> motion;
  final _OnboardingVisualType visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF738BB3)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -20,
              top: -36,
              child: _GlowOrb(
                diameter: height * 0.46,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              right: -28,
              bottom: -44,
              child: _GlowOrb(
                diameter: height * 0.54,
                color: const Color(0xFF9DB4D8).withValues(alpha: 0.22),
              ),
            ),
            AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                switch (visual) {
                  case _OnboardingVisualType.bankAlerts:
                    return _BankAlertsVisual(
                      progress: motion.value,
                      height: height,
                    );
                  case _OnboardingVisualType.budgetControl:
                    return _BudgetControlVisual(
                      progress: motion.value,
                      height: height,
                    );
                  case _OnboardingVisualType.trendSignals:
                    return _TrendSignalsVisual(
                      progress: motion.value,
                      height: height,
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAlertsVisual extends StatelessWidget {
  const _BankAlertsVisual({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 420 || height < 250;
        final contentWidth = math.min(width - (isCompact ? 28 : 36), 360.0);

        return Padding(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            children: [
              Row(
                children: [
                  _SignalChip(
                    icon: Icons.sms_rounded,
                    label: isCompact ? 'Alert' : 'Bank alert',
                    tone: const Color(0xFFFFF6D8),
                    accent: const Color(0xFF8A6B00),
                    compact: isCompact,
                  ),
                  const Spacer(),
                  _SignalChip(
                    icon: Icons.filter_alt_rounded,
                    label: isCompact ? 'Review' : 'Debit/Credit review',
                    tone: const Color(0xFFDFF4FF),
                    accent: const Color(0xFF145A86),
                    compact: isCompact,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 12 : 18),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: isCompact ? 40 : 48,
                                height: isCompact ? 40 : 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.white,
                                  size: isCompact ? 20 : 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bank alert preview',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: isCompact ? 17 : 20,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Review debit and credit records before saving',
                                      maxLines: isCompact ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.90,
                                        ),
                                        fontSize: isCompact ? 12 : 13.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 14 : 20),
                          const _HeroTransactionRow(
                            label: 'Debit',
                            amount: '- N12,500',
                            color: AppColors.danger,
                            icon: Icons.arrow_upward_rounded,
                          ),
                          const SizedBox(height: 10),
                          const _HeroTransactionRow(
                            label: 'Credit',
                            amount: '+ N85,000',
                            color: AppColors.success,
                            icon: Icons.arrow_downward_rounded,
                          ),
                          SizedBox(height: isCompact ? 10 : 16),
                          const Row(
                            children: [
                              Expanded(
                                child: _HeroStatCard(
                                  label: 'Debit saved',
                                  amount: '14',
                                  color: AppColors.danger,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _HeroStatCard(
                                  label: 'Credit saved',
                                  amount: '6',
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BudgetControlVisual extends StatelessWidget {
  const _BudgetControlVisual({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 420 || height < 250;
        final contentWidth = math.min(width - (isCompact ? 28 : 36), 380.0);

        return Padding(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SignalChip(
                    icon: Icons.savings_rounded,
                    label: isCompact ? 'Budget' : 'Budget guard',
                    tone: const Color(0xFFE7F8EF),
                    accent: AppColors.success,
                    compact: isCompact,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly budget',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: isCompact ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: isCompact ? 8 : 10),
                          Text(
                            'N420,000',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 32 : 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: isCompact ? 14 : 20),
                          const _HeroBudgetRow(
                            label: 'Operations',
                            percentLabel: '57%',
                            fill: 0.57,
                            accent: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          const _HeroBudgetRow(
                            label: 'Transport',
                            percentLabel: '68%',
                            fill: 0.68,
                            accent: AppColors.warning,
                          ),
                          if (!isCompact) ...[
                            const SizedBox(height: 12),
                            const _HeroBudgetRow(
                              label: 'Utilities',
                              percentLabel: '35%',
                              fill: 0.35,
                              accent: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrendSignalsVisual extends StatelessWidget {
  const _TrendSignalsVisual({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pointA = 0.28 + (math.sin(progress * math.pi * 2) * 0.03);
    final pointB = 0.52 + (math.cos((progress + 0.15) * math.pi * 2) * 0.04);
    final pointC = 0.36 + (math.sin((progress + 0.25) * math.pi * 2) * 0.03);
    final pointD = 0.68 + (math.cos((progress + 0.35) * math.pi * 2) * 0.04);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 420 || height < 250;
        final isUltraCompact = width < 340 || height < 220;
        final chartHeight = isUltraCompact
            ? 70.0
            : isCompact
            ? 86.0
            : height * 0.32;
        final padding = isUltraCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
          child: Column(
            children: [
              Row(
                children: [
                  const _MiniMetricCard(
                    title: 'Balance',
                    value: 'N1.4M',
                    accent: AppColors.primary,
                  ),
                  const Spacer(),
                  _SignalChip(
                    icon: Icons.query_stats_rounded,
                    label: isUltraCompact ? 'Trends' : 'Live trends',
                    tone: const Color(0xFFE9F1FF),
                    accent: AppColors.primaryDark,
                    compact: isCompact,
                  ),
                ],
              ),
              SizedBox(height: isUltraCompact ? 10 : 16),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isUltraCompact ? 14 : 22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(
                        isUltraCompact ? 22 : 28,
                      ),
                    ),
                    child: SizedBox(
                      height: chartHeight,
                      child: CustomPaint(
                        painter: _TrendPainter(
                          points: [pointA, pointB, pointC, pointD],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.icon,
    required this.label,
    required this.tone,
    required this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: accent),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTransactionRow extends StatelessWidget {
  const _HeroTransactionRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Imported from pasted bank alert',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBudgetRow extends StatelessWidget {
  const _HeroBudgetRow({
    required this.label,
    required this.percentLabel,
    required this.fill,
    required this.accent,
  });

  final String label;
  final String percentLabel;
  final double fill;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                percentLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fill.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.success],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.20),
          AppColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);

    for (var i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final xStep = size.width / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = i * xStep;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()..color = AppColors.primaryDark,
      );
    }

    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.message,
    required this.visual,
  });

  final String title;
  final String message;
  final _OnboardingVisualType visual;
}

enum _OnboardingVisualType { bankAlerts, budgetControl, trendSignals }
