import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_entry.dart';
import '../../data/services/app_controller.dart';

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({required this.controller, this.entry, super.key});

  final AppController controller;
  final ExpenseEntry? entry;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _paymentMethodController;
  late EntryType _type;
  ExpenseCategory? _selectedCategory;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _amountController = TextEditingController(
      text: entry != null ? entry.amount.toString() : '',
    );
    _noteController = TextEditingController(text: entry?.note ?? '');
    _paymentMethodController = TextEditingController(
      text: entry?.paymentMethod ?? 'Transfer',
    );
    _type = entry?.type ?? EntryType.expense;
    _date = entry?.date ?? DateTime.now();
    _selectedCategory = entry != null
        ? widget.controller.findCategory(entry.categoryId)
        : widget.controller.categories.firstWhere(
            (item) => item.type == _type,
            orElse: () => widget.controller.categories.first,
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingCategories = widget.controller.categories
        .where((item) => item.type == _type)
        .toList();
    if (_selectedCategory == null && matchingCategories.isNotEmpty) {
      _selectedCategory = matchingCategories.first;
    }

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
              widget.entry == null ? 'Add transaction' : 'Edit transaction',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  _selectedCategory = widget.controller.categories.firstWhere(
                    (item) => item.type == _type,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: matchingCategories.contains(_selectedCategory)
                  ? _selectedCategory
                  : null,
              decoration: const InputDecoration(labelText: 'Category'),
              items: matchingCategories
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentMethodController,
              decoration: const InputDecoration(labelText: 'Payment method'),
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
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Transaction date'),
                subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                trailing: TextButton(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _date,
                    );
                    if (selectedDate != null) {
                      setState(() => _date = selectedDate);
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
                  widget.entry == null ? 'Save transaction' : 'Update',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (_titleController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the title, amount, and category.'),
        ),
      );
      return;
    }

    final entry = ExpenseEntry(
      id: widget.entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: amount,
      date: _date,
      categoryId: _selectedCategory!.id,
      type: _type,
      paymentMethod: _paymentMethodController.text.trim(),
      note: _noteController.text.trim(),
    );

    if (widget.entry == null) {
      await widget.controller.addEntry(entry);
    } else {
      await widget.controller.updateEntry(entry);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
