import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/budget_plan.dart';
import '../../data/models/expense_category.dart';
import '../../data/services/app_controller.dart';

class BudgetFormSheet extends StatefulWidget {
  const BudgetFormSheet({required this.controller, this.budget, super.key});

  final AppController controller;
  final BudgetPlan? budget;

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  ExpenseCategory? _category;
  late BudgetPeriod _period;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _nameController = TextEditingController(text: budget?.name ?? '');
    _limitController = TextEditingController(
      text: budget != null ? budget.limit.toString() : '',
    );
    _category = budget?.categoryId != null
        ? widget.controller.findCategory(budget!.categoryId!)
        : null;
    _period = budget?.period ?? BudgetPeriod.monthly;
    _startDate = budget?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories
        .where((item) => item.type == EntryType.expense)
        .toList();

    return Padding(
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
              widget.budget == null ? 'Create budget' : 'Edit budget',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Budget name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Budget limit'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory?>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Linked category'),
              items: [
                const DropdownMenuItem<ExpenseCategory?>(
                  value: null,
                  child: Text('All expenses'),
                ),
                ...categories.map(
                  (item) => DropdownMenuItem<ExpenseCategory?>(
                    value: item,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<BudgetPeriod>(
              segments: const [
                ButtonSegment(
                  value: BudgetPeriod.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment(
                  value: BudgetPeriod.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (selection) {
                setState(() => _period = selection.first);
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Period start date'),
                subtitle: Text(
                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2022),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _startDate,
                    );
                    if (selectedDate != null) {
                      setState(() => _startDate = selectedDate);
                    }
                  },
                  child: const Text('Change'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(
                  widget.budget == null ? 'Save budget' : 'Update budget',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final limit = double.tryParse(_limitController.text.trim());
    if (_nameController.text.trim().isEmpty || limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provide a valid name and spending limit.'),
        ),
      );
      return;
    }

    final budget = BudgetPlan(
      id: widget.budget?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      limit: limit,
      categoryId: _category?.id,
      startDate: _startDate,
      period: _period,
    );

    if (widget.budget == null) {
      await widget.controller.addBudget(budget);
    } else {
      await widget.controller.updateBudget(budget);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
