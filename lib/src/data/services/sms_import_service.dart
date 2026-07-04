import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/expense_category.dart';
import '../models/expense_entry.dart';

enum SmsImportStatus { ready, unsupported, permissionDenied, failed }

class SmsImportSession {
  const SmsImportSession({
    required this.status,
    this.candidates = const <SmsImportCandidate>[],
    this.duplicateCount = 0,
    this.errorMessage,
  });

  final SmsImportStatus status;
  final List<SmsImportCandidate> candidates;
  final int duplicateCount;
  final String? errorMessage;
}

class SmsImportCandidate {
  const SmsImportCandidate({
    required this.externalId,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.paymentMethod,
    required this.note,
    required this.rawMessage,
    required this.merchantOrSender,
    required this.accountHint,
    required this.institutionName,
    this.categoryId,
  });

  final String externalId;
  final String title;
  final double amount;
  final DateTime date;
  final EntryType type;
  final String paymentMethod;
  final String note;
  final String rawMessage;
  final String merchantOrSender;
  final String accountHint;
  final String institutionName;
  final String? categoryId;

  ExpenseEntry toExpenseEntry(String resolvedCategoryId) {
    return ExpenseEntry(
      id: '${date.microsecondsSinceEpoch}-${externalId.hashCode.abs()}',
      title: title,
      amount: amount,
      date: date,
      categoryId: resolvedCategoryId,
      type: type,
      paymentMethod: paymentMethod,
      note: note,
      source: TransactionSource.sms,
      externalId: externalId,
      merchantOrSender: merchantOrSender,
      accountHint: accountHint,
      institutionName: institutionName,
      rawMessage: rawMessage,
      importedAt: DateTime.now(),
    );
  }
}

class SmsImportService {
  static const MethodChannel _channel = MethodChannel(
    'com.eintelix.expensetracker/sms_import',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.eintelix.expensetracker/sms_import_events',
  );

  Future<bool> hasSmsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final granted = await _channel.invokeMethod<bool>('hasSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<SmsImportSession> prepareImport({
    required List<ExpenseEntry> existingEntries,
    required List<ExpenseCategory> categories,
    int limit = 200,
    Duration lookback = const Duration(days: 30),
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SmsImportSession(status: SmsImportStatus.unsupported);
    }

    try {
      final rawItems = await _channel
          .invokeListMethod<dynamic>('getSmsMessages', <String, dynamic>{
            'sinceEpochMs': DateTime.now()
                .subtract(lookback)
                .millisecondsSinceEpoch,
            'limit': limit,
          });

      final seenExternalIds = <String>{};
      final candidates = <SmsImportCandidate>[];
      var duplicateCount = 0;

      for (final item in rawItems ?? const <dynamic>[]) {
        if (item is! Map) {
          continue;
        }
        final candidate = _parseCandidate(
          Map<String, dynamic>.from(item.cast<dynamic, dynamic>()),
          categories,
        );
        if (candidate == null) {
          continue;
        }
        final isDuplicate =
            !seenExternalIds.add(candidate.externalId) ||
            existingEntries.any(
              (entry) =>
                  entry.externalId.isNotEmpty &&
                  entry.externalId == candidate.externalId,
            );
        if (isDuplicate) {
          duplicateCount += 1;
          continue;
        }
        candidates.add(candidate);
      }

      candidates.sort((a, b) => b.date.compareTo(a.date));
      return SmsImportSession(
        status: SmsImportStatus.ready,
        candidates: candidates,
        duplicateCount: duplicateCount,
      );
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') {
        return const SmsImportSession(status: SmsImportStatus.permissionDenied);
      }
      if (error.code == 'unsupported_platform') {
        return const SmsImportSession(status: SmsImportStatus.unsupported);
      }
      return SmsImportSession(
        status: SmsImportStatus.failed,
        errorMessage: error.message,
      );
    } catch (error) {
      return SmsImportSession(
        status: SmsImportStatus.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Stream<SmsImportCandidate> watchIncomingSms() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<SmsImportCandidate>.empty();
    }

    return _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is! Map) {
            throw const FormatException('Unexpected SMS event payload');
          }
          final candidate = parseRawMessage(
            Map<String, dynamic>.from(event.cast<dynamic, dynamic>()),
          );
          if (candidate == null) {
            throw const FormatException('Ignored non-bank SMS event');
          }
          return candidate;
        })
        .handleError((_) {});
  }

  List<ExpenseEntry> buildEntriesFromCandidates({
    required List<SmsImportCandidate> candidates,
    required List<ExpenseCategory> categories,
  }) {
    return candidates
        .map((candidate) {
          String? categoryId = candidate.categoryId;
          if (categoryId == null) {
            try {
              categoryId = categories
                  .firstWhere((item) => item.type == candidate.type)
                  .id;
            } catch (_) {
              categoryId = null;
            }
          }
          if (categoryId == null) {
            return null;
          }
          return candidate.toExpenseEntry(categoryId);
        })
        .whereType<ExpenseEntry>()
        .toList();
  }

  List<SmsImportCandidate> filterNewCandidates({
    required Iterable<SmsImportCandidate> candidates,
    required List<ExpenseEntry> existingEntries,
  }) {
    final existingIds = existingEntries
        .where((entry) => entry.externalId.isNotEmpty)
        .map((entry) => entry.externalId)
        .toSet();
    final seenIds = <String>{};
    return candidates.where((candidate) {
      if (!seenIds.add(candidate.externalId)) {
        return false;
      }
      if (existingIds.contains(candidate.externalId)) {
        return false;
      }
      return !_matchesSemanticDuplicate(candidate, existingEntries);
    }).toList();
  }

  SmsImportCandidate? parseRawMessage(Map<String, dynamic> rawItem) {
    return _parseCandidate(rawItem, const <ExpenseCategory>[]);
  }

  SmsImportCandidate? _parseCandidate(
    Map<String, dynamic> rawItem,
    List<ExpenseCategory> _,
  ) {
    final body = (rawItem['body'] as String? ?? '').trim();
    if (body.isEmpty) {
      return null;
    }

    final normalized = body.toLowerCase();
    final type = _detectType(normalized);
    if (type == null) {
      return null;
    }

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) {
      return null;
    }

    final sender = (rawItem['address'] as String? ?? '').trim();
    final bankName = _extractInstitutionName(sender, body);
    if (bankName.isEmpty) {
      return null;
    }
    final timestamp = rawItem['date'] is int
        ? rawItem['date'] as int
        : int.tryParse('${rawItem['date']}') ?? 0;
    final date = timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();
    final accountHint = _extractAccountHint(body);
    final description = _extractDescription(body, type);
    final title = _buildTitle(description, bankName, type);
    final externalId =
        '${bankName.toLowerCase()}|${sender.toLowerCase()}|${date.millisecondsSinceEpoch}|${amount.toStringAsFixed(2)}|${accountHint.toLowerCase()}|${title.toLowerCase()}';
    final note = [
      if (bankName.isNotEmpty) 'Bank: $bankName',
      if (accountHint.isNotEmpty) 'Account: $accountHint',
      if (sender.isNotEmpty && sender.toLowerCase() != bankName.toLowerCase())
        'Sender: $sender',
      'Imported from bank SMS alert',
    ].join(' • ');

    return SmsImportCandidate(
      externalId: externalId,
      title: title,
      amount: amount,
      date: date,
      type: type,
      paymentMethod: bankName.isNotEmpty ? bankName : 'SMS Import',
      note: note,
      rawMessage: body,
      merchantOrSender: description,
      accountHint: accountHint,
      institutionName: bankName,
      categoryId: type == EntryType.expense ? 'bank_debit' : 'bank_credit',
    );
  }

  bool _matchesSemanticDuplicate(
    SmsImportCandidate candidate,
    List<ExpenseEntry> existingEntries,
  ) {
    for (final entry in existingEntries) {
      if (entry.source != TransactionSource.sms) {
        continue;
      }
      if (entry.type != candidate.type) {
        continue;
      }
      if ((entry.amount - candidate.amount).abs() > 0.009) {
        continue;
      }

      final entryBank = entry.institutionName.trim().toLowerCase();
      final candidateBank = candidate.institutionName.trim().toLowerCase();
      if (entryBank.isNotEmpty &&
          candidateBank.isNotEmpty &&
          entryBank != candidateBank) {
        continue;
      }

      final entryAccount = entry.accountHint.trim().toLowerCase();
      final candidateAccount = candidate.accountHint.trim().toLowerCase();
      if (entryAccount.isNotEmpty &&
          candidateAccount.isNotEmpty &&
          entryAccount != candidateAccount) {
        continue;
      }

      final secondsApart = entry.date
          .difference(candidate.date)
          .inSeconds
          .abs();
      if (secondsApart > 180) {
        continue;
      }

      final entryText = _normalizeDuplicateText(
        '${entry.title} ${entry.merchantOrSender} ${entry.rawMessage}',
      );
      final candidateText = _normalizeDuplicateText(
        '${candidate.title} ${candidate.merchantOrSender} ${candidate.rawMessage}',
      );

      if (entryText.isEmpty || candidateText.isEmpty) {
        return true;
      }
      if (entryText == candidateText ||
          entryText.contains(candidateText) ||
          candidateText.contains(entryText)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeDuplicateText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  EntryType? _detectType(String message) {
    final expensePatterns = <RegExp>[
      RegExp(r'\bdebit(?:ed)?\b', caseSensitive: false),
      RegExp(r'\bdr\b', caseSensitive: false),
      RegExp(
        r'amt\s*:\s*(?:ngn|n|₦)?[\d,]+(?:\.\d{1,2})?\s*dr\b',
        caseSensitive: false,
      ),
      RegExp(r'\bwithdraw(?:al)?\b', caseSensitive: false),
      RegExp(r'\bpurchase\b', caseSensitive: false),
    ];
    final incomePatterns = <RegExp>[
      RegExp(r'\bcredit(?:ed)?\b', caseSensitive: false),
      RegExp(r'\bcr\b', caseSensitive: false),
      RegExp(
        r'amt\s*:\s*(?:ngn|n|₦)?[\d,]+(?:\.\d{1,2})?\s*cr\b',
        caseSensitive: false,
      ),
      RegExp(r'\bdeposit\b', caseSensitive: false),
      RegExp(r'\breceived\b', caseSensitive: false),
    ];

    if (expensePatterns.any((pattern) => pattern.hasMatch(message))) {
      return EntryType.expense;
    }
    if (incomePatterns.any((pattern) => pattern.hasMatch(message))) {
      return EntryType.income;
    }
    return null;
  }

  double? _extractAmount(String message) {
    final patterns = <RegExp>[
      RegExp(
        r'amt\s*:\s*(?:ngn|n|₦)?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:debit|credit)\s+alert\s*:\s*(?:ngn|n|₦)?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:dr|cr)\s*:\s*(?:ngn|n|₦)?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(r'(?:ngn|n|₦)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final rawAmount = match?.group(1);
      if (rawAmount != null) {
        final amount = double.tryParse(rawAmount.replaceAll(',', ''));
        if (amount != null) {
          return amount;
        }
      }
    }
    return null;
  }

  String _extractAccountHint(String message) {
    final match = RegExp(
      r'(?:acct|account|a/c|acc)[^\d]*(\*+\d{3,}|\d{4,})',
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractInstitutionName(String sender, String body) {
    final normalizedSender = sender.trim();
    if (normalizedSender.isNotEmpty) {
      return _normalizeInstitutionName(normalizedSender);
    }
    final bankMatch = RegExp(
      r'\b(providus|wemabank|wema\s*bank|gtbank|gt\s*bank|access\s*bank|unionbank|union\s*bank|stanbic(?:btc)?)\b',
      caseSensitive: false,
    ).firstMatch(body);
    return _normalizeInstitutionName(bankMatch?.group(0) ?? '');
  }

  String _normalizeInstitutionName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('providus')) return 'Providus';
    if (normalized.contains('wema')) return 'Wema Bank';
    if (normalized.contains('gtbank') || normalized.contains('gt bank')) {
      return 'GTBank';
    }
    if (normalized.contains('access')) return 'Access Bank';
    if (normalized.contains('union')) return 'Union Bank';
    if (normalized.contains('stanbic')) return 'Stanbic IBTC';
    if (normalized.isEmpty) return '';
    return value.trim();
  }

  String _extractDescription(String message, EntryType type) {
    final linePatterns = <RegExp>[
      RegExp(r'desc\s*:\s*(.+?)(?:\n|$)', caseSensitive: false),
      RegExp(
        r'mob\s*:\s*(.+?)(?:\n|bal:|avail|date:|dt:|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in linePatterns) {
      final match = pattern.firstMatch(message);
      final value = _cleanDescription(match?.group(1) ?? '');
      if (value.isNotEmpty) {
        return value;
      }
    }

    final fallbackPatterns = type == EntryType.expense
        ? <RegExp>[
            RegExp(
              r'\bto\s+(.+?)(?:\n|bal:|avail|date:|dt:|$)',
              caseSensitive: false,
            ),
            RegExp(
              r'\bfor\s+(.+?)(?:\n|bal:|avail|date:|dt:|$)',
              caseSensitive: false,
            ),
          ]
        : <RegExp>[
            RegExp(
              r'\bfrom\s+(.+?)(?:\n|bal:|avail|date:|dt:|$)',
              caseSensitive: false,
            ),
            RegExp(
              r'\bby\s+(.+?)(?:\n|bal:|avail|date:|dt:|$)',
              caseSensitive: false,
            ),
          ];

    for (final pattern in fallbackPatterns) {
      final match = pattern.firstMatch(message);
      final value = _cleanDescription(match?.group(1) ?? '');
      if (value.isNotEmpty) {
        return value;
      }
    }

    return type == EntryType.expense
        ? 'Debit transaction'
        : 'Credit transaction';
  }

  String _cleanDescription(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', ' ').trim();
  }

  String _buildTitle(String description, String bankName, EntryType type) {
    final cleaned = _cleanDescription(description);
    if (cleaned.isNotEmpty &&
        cleaned != 'Debit transaction' &&
        cleaned != 'Credit transaction') {
      return cleaned;
    }
    if (bankName.isNotEmpty) {
      return '$bankName ${type == EntryType.expense ? 'Debit' : 'Credit'}';
    }
    return type == EntryType.expense ? 'SMS debit alert' : 'SMS credit alert';
  }
}
