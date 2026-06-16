import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/debt_record.dart';
import '../../data/services/app_controller.dart';

class DebtFormSheet extends StatefulWidget {
  const DebtFormSheet({required this.controller, this.debt, super.key});

  final AppController controller;
  final DebtRecord? debt;

  @override
  State<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<DebtFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  late DebtType _type;
  late DebtStatus _status;
  late DebtPersonSource _source;
  DateTime? _dueDate;
  String? _contactId;
  bool _isPickingContact = false;
  List<Contact> _cachedContacts = const [];

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _nameController = TextEditingController(text: debt?.personName ?? '');
    _amountController = TextEditingController(
      text: debt != null ? debt.amount.toString() : '',
    );
    _phoneController = TextEditingController(text: debt?.phoneNumber ?? '');
    _noteController = TextEditingController(text: debt?.note ?? '');
    _type = debt?.type ?? DebtType.owedToMe;
    _status = debt?.status ?? DebtStatus.active;
    _source = debt?.personSource ?? DebtPersonSource.manual;
    _dueDate = debt?.dueDate;
    _contactId = debt?.contactId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
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
              widget.debt == null ? 'Add debt record' : 'Edit debt record',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(
                  value: DebtType.owedToMe,
                  label: Text('Owed to me'),
                ),
                ButtonSegment(value: DebtType.iOwe, label: Text('I owe')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<DebtPersonSource>(
              segments: const [
                ButtonSegment(
                  value: DebtPersonSource.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.edit_note_rounded),
                ),
                ButtonSegment(
                  value: DebtPersonSource.contacts,
                  label: Text('Contacts'),
                  icon: Icon(Icons.contacts_rounded),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (selection) async {
                final next = selection.first;
                setState(() => _source = next);
                if (next == DebtPersonSource.contacts) {
                  await _pickContact();
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              readOnly: _source == DebtPersonSource.contacts,
              decoration: InputDecoration(
                labelText: 'Person or business name',
                suffixIcon: _source == DebtPersonSource.contacts
                    ? IconButton(
                        onPressed: _isPickingContact ? null : _pickContact,
                        icon: _isPickingContact
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_search_rounded),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              readOnly: _source == DebtPersonSource.contacts,
              decoration: const InputDecoration(labelText: 'Phone number'),
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
            SegmentedButton<DebtStatus>(
              segments: const [
                ButtonSegment(value: DebtStatus.active, label: Text('Active')),
                ButtonSegment(
                  value: DebtStatus.settled,
                  label: Text('Settled'),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() => _status = selection.first);
              },
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
                leading: const Icon(Icons.event_rounded),
                title: const Text('Due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'No due date selected'
                      : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (_dueDate != null)
                      TextButton(
                        onPressed: () => setState(() => _dueDate = null),
                        child: const Text('Clear'),
                      ),
                    TextButton(
                      onPressed: _pickDueDate,
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
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(widget.debt == null ? 'Save debt' : 'Update debt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dueDate ?? DateTime.now(),
    );
    if (selectedDate != null) {
      setState(() => _dueDate = selectedDate);
    }
  }

  Future<void> _pickContact() async {
    setState(() => _isPickingContact = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contacts permission not granted. You can still enter the debtor manually.',
              ),
            ),
          );
          setState(() => _source = DebtPersonSource.manual);
        }
        return;
      }

      if (_cachedContacts.isEmpty) {
        _cachedContacts = await FlutterContacts.getContacts(
          withProperties: true,
          sorted: true,
        );
      }

      if (!mounted) {
        return;
      }

      final selected = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ContactPickerSheet(contacts: _cachedContacts),
      );

      if (selected == null) {
        return;
      }

      setState(() {
        _source = DebtPersonSource.contacts;
        _contactId = selected.id;
        _nameController.text = selected.displayName;
        _phoneController.text = selected.phones.isNotEmpty
            ? selected.phones.first.number
            : '';
      });
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contacts integration is not loaded in this app instance yet. Stop the app completely and run it again.',
            ),
          ),
        );
        setState(() => _source = DebtPersonSource.manual);
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingContact = false);
      }
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (_nameController.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide a valid name and amount.')),
      );
      return;
    }

    final debt = DebtRecord(
      id: widget.debt?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      personName: _nameController.text.trim(),
      amount: amount,
      type: _type,
      status: _status,
      personSource: _source,
      createdAt: widget.debt?.createdAt ?? DateTime.now(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      note: _noteController.text.trim(),
      contactId: _contactId,
      dueDate: _dueDate,
    );

    if (widget.debt == null) {
      await widget.controller.addDebt(debt);
    } else {
      await widget.controller.updateDebt(debt);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({required this.contacts});

  final List<Contact> contacts;

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredContacts = widget.contacts.where((contact) {
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : '';
      return query.isEmpty ||
          contact.displayName.toLowerCase().contains(query) ||
          phone.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a contact',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name or phone number',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filteredContacts.isEmpty
                    ? const Center(child: Text('No matching contacts found.'))
                    : ListView.separated(
                        itemCount: filteredContacts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          final phone = contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : 'No phone number';
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.of(context).pop(contact),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  contact.displayName.isEmpty
                                      ? '?'
                                      : contact.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(contact.displayName),
                              subtitle: Text(phone),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
