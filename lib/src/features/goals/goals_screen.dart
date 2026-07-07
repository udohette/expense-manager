import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/savings_goal.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../dashboard/home_shell.dart';
import 'goal_form_sheet.dart';

class GoalsScreen extends StatelessWidget implements QuickActionHost {
  const GoalsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  void onQuickAction(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GoalFormSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Savings goals',
              subtitle:
                  'Set funding targets and keep track of how close you are.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _GoalSummaryCard(
                    title: 'Saved so far',
                    amount: controller.goalsSavedTotal,
                    color: AppColors.success,
                    controller: controller,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoalSummaryCard(
                    title: 'Total targets',
                    amount: controller.goalsTargetTotal,
                    color: AppColors.primary,
                    controller: controller,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.goals.isEmpty)
              EmptyStateCard(
                title: 'No savings goals yet',
                message:
                    'Create a goal for rent, emergency funds, equipment, or any big purchase you want to plan ahead for.',
                icon: Icons.savings_rounded,
                action: FilledButton(
                  onPressed: () => onQuickAction(context),
                  child: const Text('Create goal'),
                ),
              )
            else
              ...controller.goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _GoalCard(controller: controller, goal: goal),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.controller,
  });

  final String title;
  final double amount;
  final Color color;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.flag_rounded, color: color),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              AppFormatters.currency(amount, symbol: controller.currencyCode),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.controller, required this.goal});

  final AppController controller;
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress;
    final remaining = goal.remainingAmount;
    final isCompleted = goal.isCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isCompleted
                            ? 'Goal completed'
                            : remaining <= 0
                            ? 'Fully funded'
                            : '${AppFormatters.currency(remaining, symbol: controller.currencyCode)} left',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'contribute':
                        await Future<void>.delayed(Duration.zero);
                        if (!context.mounted) {
                          return;
                        }
                        await _showContributionSheet(context);
                        break;
                      case 'edit':
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) =>
                              GoalFormSheet(controller: controller, goal: goal),
                        );
                        break;
                      case 'delete':
                        await controller.deleteGoal(goal.id);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'contribute',
                      child: Text('Add contribution'),
                    ),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (goal.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(goal.note, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved ${AppFormatters.currency(goal.currentAmount, symbol: controller.currencyCode)}',
                  ),
                ),
                Text(
                  'Target ${AppFormatters.currency(goal.targetAmount, symbol: controller.currencyCode)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (goal.targetDate != null) ...[
              const SizedBox(height: 10),
              Text(
                'Target date ${AppFormatters.compactDate(goal.targetDate!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showContributionSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContributionSheet(BuildContext context) async {
    var contributionText = '';
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add to ${goal.name}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Contribution amount',
                ),
                autofocus: true,
                onChanged: (value) => contributionText = value,
                onSubmitted: (value) {
                  Navigator.of(context).pop(double.tryParse(value.trim()));
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(double.tryParse(contributionText.trim()));
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    await controller.contributeToGoal(goal.id, amount);
  }
}
