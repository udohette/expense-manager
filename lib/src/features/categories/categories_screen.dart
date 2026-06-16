import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/expense_category.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories
        .where((item) => item.type == _type)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCategorySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Manage categories',
              subtitle: 'Create custom buckets for expense or income records',
            ),
            const SizedBox(height: 16),
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(value: EntryType.expense, label: Text('Expense')),
                ButtonSegment(value: EntryType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: categories.isEmpty
                  ? const EmptyStateCard(
                      title: 'No categories here',
                      message:
                          'Add one to tailor the tracker to your workflow.',
                      icon: Icons.category_rounded,
                    )
                  : ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: category.color.withValues(
                                alpha: 0.15,
                              ),
                              child: Icon(category.icon, color: category.color),
                            ),
                            title: Text(category.name),
                            subtitle: Text(
                              category.isDefault
                                  ? 'Default category'
                                  : 'Custom category',
                            ),
                            trailing: category.isDefault
                                ? const Icon(Icons.lock_outline_rounded)
                                : IconButton(
                                    onPressed: () async {
                                      await widget.controller.deleteCategory(
                                        category.id,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCategorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _CategoryFormSheet(controller: widget.controller, type: _type),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({required this.controller, required this.type});

  final AppController controller;
  final EntryType type;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final List<IconData> _icons = const [
    Icons.shopping_bag_rounded,
    Icons.attach_money_rounded,
    Icons.school_rounded,
    Icons.flight_takeoff_rounded,
    Icons.storefront_rounded,
    Icons.card_giftcard_rounded,
  ];
  final List<Color> _colors = const [
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    Color(0xFF8E44AD),
    Color(0xFF16A085),
  ];

  IconData _selectedIcon = Icons.shopping_bag_rounded;
  Color _selectedColor = AppColors.primary;

  @override
  void dispose() {
    _nameController.dispose();
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
              'Create ${widget.type.name} category',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 16),
            const Text('Pick an icon'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.map((icon) {
                final selected = icon == _selectedIcon;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Icon(icon),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Pick a color'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((color) {
                final selected = color == _selectedColor;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 3,
                        color: selected ? Colors.black : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save category'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    await widget.controller.addCategory(
      ExpenseCategory(
        id: '${widget.type.name}-${DateTime.now().microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        iconCodePoint: _selectedIcon.codePoint,
        colorValue: _selectedColor.toARGB32(),
        type: widget.type,
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
