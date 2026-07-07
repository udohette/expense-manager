import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../data/models/savings_goal.dart';
import '../../data/services/app_controller.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({required this.controller, this.goal, super.key});

  final AppController controller;
  final SavingsGoal? goal;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;
  late final TextEditingController _noteController;
  DateTime? _targetDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal != null
          ? AmountInputFormatter.formatValue(goal.targetAmount)
          : '',
    );
    _currentController = TextEditingController(
      text: goal != null
          ? AmountInputFormatter.formatValue(goal.currentAmount)
          : '',
    );
    _noteController = TextEditingController(text: goal?.note ?? '');
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.goal == null ? 'Create savings goal' : 'Edit savings goal',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(labelText: 'Saved so far'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('Target date'),
                subtitle: Text(
                  _targetDate == null
                      ? 'No target date selected'
                      : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (_targetDate != null)
                      TextButton(
                        onPressed: () => setState(() => _targetDate = null),
                        child: const Text('Clear'),
                      ),
                    TextButton(
                      onPressed: _pickTargetDate,
                      child: const Text('Set date'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSubmitting) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _isSubmitting
                          ? (widget.goal == null ? 'Saving...' : 'Updating...')
                          : (widget.goal == null ? 'Save goal' : 'Update goal'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTargetDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
    );
    if (selectedDate != null) {
      setState(() => _targetDate = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final targetAmount = double.tryParse(
      AmountInputFormatter.normalize(_targetController.text),
    );
    final currentAmount =
        double.tryParse(
          AmountInputFormatter.normalize(_currentController.text),
        ) ??
        0;
    if (_nameController.text.trim().isEmpty ||
        targetAmount == null ||
        targetAmount <= 0 ||
        currentAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the goal name and valid amounts.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final goal = SavingsGoal(
        id: widget.goal?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        createdAt: widget.goal?.createdAt ?? DateTime.now(),
        note: _noteController.text.trim(),
        targetDate: _targetDate,
      );

      if (widget.goal == null) {
        await widget.controller.addGoal(goal);
      } else {
        await widget.controller.updateGoal(goal);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
