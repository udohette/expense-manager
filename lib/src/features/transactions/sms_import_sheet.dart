import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/expense_category.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/sms_import_service.dart';

class SmsImportSheet extends StatefulWidget {
  const SmsImportSheet({
    required this.controller,
    required this.session,
    super.key,
  });

  final AppController controller;
  final SmsImportSession session;

  @override
  State<SmsImportSheet> createState() => _SmsImportSheetState();
}

class _SmsImportSheetState extends State<SmsImportSheet> {
  late final Set<String> _selectedIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.session.candidates
        .map((candidate) => candidate.externalId)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.session.candidates;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import from SMS',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${candidates.length} new transaction${candidates.length == 1 ? '' : 's'} ready to import${widget.session.duplicateCount > 0 ? ' • ${widget.session.duplicateCount} duplicate${widget.session.duplicateCount == 1 ? '' : 's'} skipped' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  final selected = _selectedIds.contains(candidate.externalId);
                  return Card(
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedIds.add(candidate.externalId);
                                } else {
                                  _selectedIds.remove(candidate.externalId);
                                }
                              });
                            },
                      title: Text(candidate.title),
                      subtitle: Text(
                        '${candidate.institutionName.isNotEmpty ? candidate.institutionName : candidate.paymentMethod} • ${AppFormatters.compactDate(candidate.date)}\n${candidate.note}',
                      ),
                      secondary: Text(
                        '${candidate.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(candidate.amount, symbol: widget.controller.currencyCode)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: candidate.type == EntryType.expense
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving || _selectedIds.isEmpty ? null : _import,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isSaving
                      ? 'Importing...'
                      : 'Import ${_selectedIds.length} transaction${_selectedIds.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    setState(() => _isSaving = true);
    final selectedCandidates = widget.session.candidates
        .where((candidate) => _selectedIds.contains(candidate.externalId))
        .toList();

    final entries = selectedCandidates.map((candidate) {
      final categoryId =
          candidate.categoryId ??
          widget.controller.firstCategoryForType(candidate.type)?.id;
      if (categoryId == null) {
        throw StateError('No category configured for ${candidate.type.name}');
      }
      return candidate.toExpenseEntry(categoryId);
    }).toList();

    await widget.controller.addEntries(entries);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(entries.length);
  }
}
