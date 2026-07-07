import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/budget_plan.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../dashboard/home_shell.dart';
import 'budget_form_sheet.dart';

class BudgetsScreen extends StatelessWidget implements QuickActionHost {
  const BudgetsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  void onQuickAction(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BudgetFormSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Budgets',
            subtitle:
                'Set limits and monitor the spending pace against targets',
          ),
          const SizedBox(height: 16),
          if (controller.budgets.isEmpty)
            EmptyStateCard(
              title: 'No budgets yet',
              message:
                  'Create weekly or monthly caps to keep important categories in line.',
              icon: Icons.savings_rounded,
              action: FilledButton(
                onPressed: () => onQuickAction(context),
                child: const Text('Create budget'),
              ),
            )
          else
            ...controller.budgets.map(
              (budget) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BudgetCard(controller: controller, budget: budget),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.controller, required this.budget});

  final AppController controller;
  final BudgetPlan budget;

  @override
  Widget build(BuildContext context) {
    final spent = controller.spentForBudget(budget);
    final ratio = budget.limit == 0
        ? 0.0
        : (spent / budget.limit).clamp(0.0, 1.2);
    final category = budget.categoryId == null
        ? null
        : controller.findCategory(budget.categoryId!);
    final isOverLimit = ratio >= 1;
    final isNearLimit = ratio >= 0.8 && ratio < 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${category?.name ?? 'All expenses'} • ${budget.period.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => BudgetFormSheet(
                          controller: controller,
                          budget: budget,
                        ),
                      );
                    } else {
                      await controller.deleteBudget(budget.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio >= 1 ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent ${AppFormatters.currency(spent, symbol: controller.currencyCode)}',
                  ),
                ),
                Text(
                  'Limit ${AppFormatters.currency(budget.limit, symbol: controller.currencyCode)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (isOverLimit || isNearLimit) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (isOverLimit ? AppColors.danger : AppColors.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isOverLimit
                            ? AppColors.danger
                            : AppColors.warning)
                        .withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverLimit
                          ? Icons.error_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: isOverLimit
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOverLimit
                            ? 'Budget exceeded. Reduce spending or raise the limit.'
                            : 'Warning: this budget is almost fully used.',
                        style: TextStyle(
                          color: isOverLimit
                              ? AppColors.danger
                              : AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
