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

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Track every naira in one place',
      message:
          'Capture expenses, income, payment methods, and notes so business and personal spending stay visible.',
      icon: Icons.receipt_long_rounded,
    ),
    _OnboardingItem(
      title: 'Set budgets before spending drifts',
      message:
          'Build monthly or weekly budgets, monitor progress, and spot categories that need tighter control.',
      icon: Icons.savings_rounded,
    ),
    _OnboardingItem(
      title: 'Make smarter decisions from trends',
      message:
          'See balance snapshots, category breakdowns, and recent activity without waiting for a cloud backend.',
      icon: Icons.query_stats_rounded,
    ),
  ];

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandedLogo(height: 42),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _pageIndex = value),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primary,
                                Color(0xFF6A84AD),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              item.icon,
                              size: 110,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.message,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: _pageIndex == index ? 32 : 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _pageIndex == index
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _pageIndex == _items.length - 1
                      ? _finish
                      : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    _pageIndex == _items.length - 1
                        ? 'Start tracking'
                        : 'Continue',
                  ),
                ),
              ),
              TextButton(onPressed: _finish, child: const Text('Skip for now')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}
