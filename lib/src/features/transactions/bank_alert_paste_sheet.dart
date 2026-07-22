import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/expense_category.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/sms_import_service.dart';

class BankAlertPasteSheet extends StatefulWidget {
  const BankAlertPasteSheet({required this.controller, super.key});

  final AppController controller;

  @override
  State<BankAlertPasteSheet> createState() => _BankAlertPasteSheetState();
}

class _BankAlertPasteSheetState extends State<BankAlertPasteSheet> {
  final SmsImportService _smsImportService = SmsImportService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _senderController = TextEditingController();

  SmsImportCandidate? _candidate;
  String? _parseError;
  bool _isDuplicate = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updatePreview);
    _senderController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _messageController.removeListener(_updatePreview);
    _senderController.removeListener(_updatePreview);
    _messageController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final candidate = _smsImportService.parsePastedMessage(
      _messageController.text,
      sender: _senderController.text,
    );

    if (_messageController.text.trim().isEmpty) {
      setState(() {
        _candidate = null;
        _parseError = null;
        _isDuplicate = false;
      });
      return;
    }

    if (candidate == null) {
      setState(() {
        _candidate = null;
        _parseError =
            'Could not recognize a bank debit or credit alert from this text.';
        _isDuplicate = false;
      });
      return;
    }

    final newCandidates = _smsImportService.filterNewCandidates(
      candidates: [candidate],
      existingEntries: widget.controller.entries,
    );

    setState(() {
      _candidate = candidate;
      _parseError = null;
      _isDuplicate = newCandidates.isEmpty;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
      return;
    }

    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  Future<void> _import() async {
    final candidate = _candidate;
    if (candidate == null || _isDuplicate || _isImporting) {
      return;
    }

    final entries = _smsImportService.buildEntriesFromCandidates(
      candidates: [candidate],
      categories: widget.controller.categories,
    );
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No matching bank category is available for import.'),
        ),
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      await widget.controller.addEntries(entries);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(entries.length);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste bank alert',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste the bank debit or credit SMS text here. The app will extract the amount, bank, and transaction type before saving it.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Paste from clipboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senderController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Bank or sender (optional)',
                hintText: 'Example: GTBank or PROVIDUS',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Bank alert text',
                hintText:
                    'Paste the full bank debit or credit SMS message here.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            if (_parseError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _parseError!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            if (candidate != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PreviewRow(label: 'Title', value: candidate.title),
                    _PreviewRow(
                      label: 'Type',
                      value: candidate.type == EntryType.expense
                          ? 'Debit / Expense'
                          : 'Credit / Income',
                    ),
                    _PreviewRow(
                      label: 'Amount',
                      value: AppFormatters.currency(
                        candidate.amount,
                        symbol: widget.controller.currencyCode,
                      ),
                    ),
                    _PreviewRow(
                      label: 'Bank',
                      value: candidate.institutionName,
                    ),
                    if (candidate.accountHint.isNotEmpty)
                      _PreviewRow(
                        label: 'Account',
                        value: candidate.accountHint,
                      ),
                    if (candidate.merchantOrSender.isNotEmpty)
                      _PreviewRow(
                        label: 'Narration',
                        value: candidate.merchantOrSender,
                      ),
                  ],
                ),
              ),
              if (_isDuplicate) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'This bank alert already appears to be in your records.',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: candidate == null || _isDuplicate || _isImporting
                    ? null
                    : _import,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_isImporting ? 'Importing...' : 'Import alert'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
