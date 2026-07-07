import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_entry.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../transactions/transaction_form_sheet.dart';
import 'home_shell.dart';

class OverviewScreen extends StatefulWidget implements QuickActionHost {
  const OverviewScreen({required this.controller, super.key});

  final AppController controller;

  @override
  void onQuickAction(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFormSheet(controller: controller),
    );
  }

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.controller.getLastSelectedMonth();
  }

  @override
  Widget build(BuildContext context) {
    final budgetAlerts = widget.controller.budgetAlertsForMonth(_selectedMonth);
    final monthlyCategory =
        widget.controller.getMonthByCategory(_selectedMonth).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final monthlyIncome = widget.controller.getMonthIncome(_selectedMonth);
    final monthlyExpense = widget.controller.getMonthExpense(_selectedMonth);

    final recentEntries = widget.controller.entries.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eintelix Expense Tracker',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Financial control at a glance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          _BalanceHero(
            controller: widget.controller,
            selectedMonth: _selectedMonth,
            monthlyIncome: monthlyIncome,
            monthlyExpense: monthlyExpense,
          ),
          if (budgetAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BudgetWarningCard(
              controller: widget.controller,
              alert: budgetAlerts.first,
            ),
          ],
          const SizedBox(height: 18),
          // Month selector dropdown
          Row(
            children: [
              const Text(
                'Month:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  color: Theme.of(context).cardColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: _selectedMonth,
                      items: List.generate(12, (i) {
                        final now = DateTime.now();
                        final monthDate = DateTime(
                          now.year,
                          now.month - (11 - i),
                          1,
                        );
                        return DropdownMenuItem<DateTime>(
                          value: monthDate,
                          child: Text(AppFormatters.monthYear(monthDate)),
                        );
                      }),
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _selectedMonth = v);
                          await widget.controller.setLastSelectedMonth(v);
                          // Clear any persisted transactions date-range when switching month
                          await widget.controller.setLastSelectedStartDate(
                            null,
                          );
                          await widget.controller.setLastSelectedEndDate(null);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniSummaryCard(
                  label: 'Month Income',
                  value: monthlyIncome,
                  color: AppColors.success,
                  controller: widget.controller,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniSummaryCard(
                  label: 'Month Expenses',
                  value: monthlyExpense,
                  color: AppColors.danger,
                  controller: widget.controller,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Category breakdown',
            subtitle: 'Category pressure points and spending distribution',
          ),
          const SizedBox(height: 12),
          if (monthlyCategory.isEmpty)
            const EmptyStateCard(
              title: 'No monthly expense data yet',
              message:
                  'Add expense entries to unlock charts and spending insights.',
              icon: Icons.pie_chart_rounded,
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 48,
                          sections: monthlyCategory.take(5).map((entry) {
                            final category = widget.controller.findCategory(
                              entry.key,
                            );
                            final total = monthlyCategory.fold<double>(
                              0,
                              (sum, item) => sum + item.value,
                            );
                            return PieChartSectionData(
                              value: entry.value,
                              color: category?.color ?? AppColors.primary,
                              title:
                                  '${((entry.value / total) * 100).round()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...monthlyCategory.take(5).map((entry) {
                      final category = widget.controller.findCategory(
                        entry.key,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: category?.color ?? AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(category?.name ?? 'Unknown category'),
                            ),
                            Text(
                              AppFormatters.currency(
                                entry.value,
                                symbol: widget.controller.currencyCode,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Recent activity',
            subtitle: 'Latest income and expense items',
          ),
          const SizedBox(height: 12),
          if (recentEntries.isEmpty)
            const EmptyStateCard(
              title: 'Nothing recorded yet',
              message: 'Create your first entry to populate the ledger.',
              icon: Icons.receipt_long_rounded,
            )
          else
            ...recentEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EntryTile(controller: widget.controller, entry: entry),
              ),
            ),
        ],
      ),
    );
  }

  // month dropdown handled inline in build
}

class _BalanceHero extends StatefulWidget {
  const _BalanceHero({
    required this.controller,
    required this.selectedMonth,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

  final AppController controller;
  final DateTime selectedMonth;
  final double monthlyIncome;
  final double monthlyExpense;

  @override
  State<_BalanceHero> createState() => _BalanceHeroState();
}

class _BalanceHeroState extends State<_BalanceHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void didUpdateWidget(covariant _BalanceHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulseState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseState();
  }

  void _syncPulseState() {
    final shouldPulse = widget.monthlyIncome - widget.monthlyExpense < 0;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = widget.monthlyIncome - widget.monthlyExpense;
    final balanceColor = netBalance < 0 ? AppColors.danger : Colors.white;
    final amountText = _formatBalanceAmount(
      value: netBalance,
      symbol: widget.controller.currencyCode,
      hidden: widget.controller.hideBalances,
    );
    final isNegative = netBalance < 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = isNegative ? _pulseController.value : 0.0;
        final glowColor = Color.lerp(
          AppColors.danger.withValues(alpha: 0.16),
          AppColors.danger.withValues(alpha: 0.42),
          pulseValue,
        )!;
        final startColor = isNegative
            ? Color.lerp(
                const Color(0xFF5A2230),
                const Color(0xFF7D2936),
                pulseValue,
              )!
            : AppColors.primaryDark;
        final midColor = isNegative
            ? Color.lerp(AppColors.danger, const Color(0xFFC94844), pulseValue)!
            : AppColors.primary;
        final endColor = isNegative
            ? Color.lerp(
                const Color(0xFFB64045),
                const Color(0xFFE16A61),
                pulseValue,
              )!
            : const Color(0xFF5578AE);

        return Card(
          elevation: isNegative ? 2 + (pulseValue * 8) : 1,
          shadowColor: glowColor,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: isNegative
                  ? Border.all(color: glowColor, width: 1.5)
                  : null,
              boxShadow: isNegative
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 20 + (pulseValue * 18),
                        spreadRadius: 1 + (pulseValue * 2),
                      ),
                    ]
                  : null,
              gradient: LinearGradient(
                colors: [startColor, midColor, endColor],
              ),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net balance',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  widget.controller.setHideBalances(!widget.controller.hideBalances);
                },
                icon: Icon(
                  widget.controller.hideBalances
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white,
                ),
                tooltip: widget.controller.hideBalances
                    ? 'Show balances'
                    : 'Hide balances',
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amountText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: widget.controller.hideBalances ? Colors.white : balanceColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isNegative) ...[
            const SizedBox(height: 10),
            Text(
              'Warning: you are spending beyond the available balance.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                icon: Icons.calendar_month_rounded,
                label: AppFormatters.monthYear(widget.selectedMonth),
              ),
              _HeroBadge(
                icon: Icons.wallet_rounded,
                label: '${widget.controller.entries.length} entries tracked',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetWarningCard extends StatelessWidget {
  const _BudgetWarningCard({required this.controller, required this.alert});

  final AppController controller;
  final BudgetUsageSnapshot alert;

  @override
  Widget build(BuildContext context) {
    final category = alert.budget.categoryId == null
        ? null
        : controller.findCategory(alert.budget.categoryId!);
    final isOverLimit = alert.isOverLimit;
    final tone = isOverLimit ? AppColors.danger : AppColors.warning;
    final title = isOverLimit
        ? '${alert.budget.name} is over budget'
        : '${alert.budget.name} is nearly used up';
    final message = isOverLimit
        ? 'Spent ${AppFormatters.currency(alert.spent, symbol: controller.currencyCode)} against ${AppFormatters.currency(alert.budget.limit, symbol: controller.currencyCode)}.'
        : 'Only ${AppFormatters.currency(alert.remaining, symbol: controller.currencyCode)} left before you hit the limit.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverLimit ? Icons.error_rounded : Icons.warning_amber_rounded,
              color: tone,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${category?.name ?? 'All expenses'} • ${alert.budget.period.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.controller,
  });

  final String label;
  final double value;
  final Color color;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final amountText = _formatBalanceAmount(
      value: value,
      symbol: controller.currencyCode,
      hidden: controller.hideBalances,
    );

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
              child: Icon(Icons.trending_up_rounded, color: color),
            ),
            const SizedBox(height: 14),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              amountText,
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

String _formatBalanceAmount({
  required double value,
  required String symbol,
  required bool hidden,
}) {
  if (!hidden) {
    return AppFormatters.currency(value, symbol: symbol);
  }

  return '$symbol ••••••';
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.controller, required this.entry});

  final AppController controller;
  final ExpenseEntry entry;

  @override
  Widget build(BuildContext context) {
    final category = controller.findCategory(entry.categoryId);
    final bankLinked = _isBankLinked(entry);
    final leadingColor = bankLinked
        ? const Color(0xFF2F5B9A)
        : category?.color ?? AppColors.primary;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: leadingColor.withValues(alpha: 0.14),
          child: Icon(
            bankLinked
                ? Icons.account_balance_rounded
                : category?.icon ?? Icons.category_rounded,
            color: leadingColor,
          ),
        ),
        title: Text(entry.title),
        subtitle: Text(
          bankLinked
              ? '${_resolvedBankName(entry)}  •  ${AppFormatters.compactDate(entry.date)}'
              : '${category?.name ?? 'Category'}  •  ${AppFormatters.compactDate(entry.date)}',
        ),
        trailing: Text(
          '${entry.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(entry.amount, symbol: controller.currencyCode)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: entry.type == EntryType.expense
                ? AppColors.danger
                : AppColors.success,
          ),
        ),
      ),
    );
  }

  bool _isBankLinked(ExpenseEntry entry) {
    return _resolvedBankName(entry).isNotEmpty;
  }

  String _resolvedBankName(ExpenseEntry entry) {
    if (entry.institutionName.trim().isNotEmpty) {
      return entry.institutionName.trim();
    }
    final paymentMethod = entry.paymentMethod.trim().toLowerCase();
    if (paymentMethod.contains('providus')) return 'Providus';
    if (paymentMethod.contains('wema')) return 'Wema Bank';
    if (paymentMethod.contains('gtbank') || paymentMethod.contains('gt bank')) {
      return 'GTBank';
    }
    if (paymentMethod.contains('access')) return 'Access Bank';
    if (paymentMethod.contains('union')) return 'Union Bank';
    if (paymentMethod.contains('stanbic')) return 'Stanbic IBTC';

    final rawText =
        '${entry.note} ${entry.rawMessage} ${entry.merchantOrSender}'
            .toLowerCase();
    if (rawText.contains('providus')) return 'Providus';
    if (rawText.contains('wema')) return 'Wema Bank';
    if (rawText.contains('gtbank') || rawText.contains('gt bank')) {
      return 'GTBank';
    }
    if (rawText.contains('access')) return 'Access Bank';
    if (rawText.contains('union')) return 'Union Bank';
    if (rawText.contains('stanbic')) return 'Stanbic IBTC';
    return '';
  }
}
