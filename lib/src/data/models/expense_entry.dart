import 'package:hive/hive.dart';

import 'expense_category.dart';

enum TransactionSource { manual, sms, bankApi }

enum RecurrenceFrequency { none, weekly, monthly, yearly }

class ExpenseEntry extends HiveObject {
  ExpenseEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.type,
    required this.paymentMethod,
    this.note = '',
    this.source = TransactionSource.manual,
    this.externalId = '',
    this.merchantOrSender = '',
    this.accountHint = '',
    this.institutionName = '',
    this.rawMessage = '',
    this.importedAt,
    this.walletAccountId = '',
    this.recurrenceFrequency = RecurrenceFrequency.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.isRecurringTemplate = false,
    this.recurrenceTemplateId = '',
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final EntryType type;
  final String paymentMethod;
  final String note;
  final TransactionSource source;
  final String externalId;
  final String merchantOrSender;
  final String accountHint;
  final String institutionName;
  final String rawMessage;
  final DateTime? importedAt;
  final String walletAccountId;
  final RecurrenceFrequency recurrenceFrequency;
  final int recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final bool isRecurringTemplate;
  final String recurrenceTemplateId;

  bool get isRecurringOccurrence => recurrenceTemplateId.isNotEmpty;
  bool get hasRecurrence => recurrenceFrequency != RecurrenceFrequency.none;
  bool get hasWallet => walletAccountId.isNotEmpty;

  ExpenseEntry copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    EntryType? type,
    String? paymentMethod,
    String? note,
    TransactionSource? source,
    String? externalId,
    String? merchantOrSender,
    String? accountHint,
    String? institutionName,
    String? rawMessage,
    DateTime? importedAt,
    String? walletAccountId,
    RecurrenceFrequency? recurrenceFrequency,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    bool? isRecurringTemplate,
    String? recurrenceTemplateId,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      merchantOrSender: merchantOrSender ?? this.merchantOrSender,
      accountHint: accountHint ?? this.accountHint,
      institutionName: institutionName ?? this.institutionName,
      rawMessage: rawMessage ?? this.rawMessage,
      importedAt: importedAt ?? this.importedAt,
      walletAccountId: walletAccountId ?? this.walletAccountId,
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      isRecurringTemplate: isRecurringTemplate ?? this.isRecurringTemplate,
      recurrenceTemplateId: recurrenceTemplateId ?? this.recurrenceTemplateId,
    );
  }
}

class ExpenseEntryAdapter extends TypeAdapter<ExpenseEntry> {
  @override
  final int typeId = 2;

  @override
  ExpenseEntry read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return ExpenseEntry(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      categoryId: fields[4] as String,
      type: fields[5] as EntryType,
      paymentMethod: fields[6] as String,
      note: fields[7] as String? ?? '',
      source: fields[8] as TransactionSource? ?? TransactionSource.manual,
      externalId: fields[9] as String? ?? '',
      merchantOrSender: fields[10] as String? ?? '',
      accountHint: fields[11] as String? ?? '',
      rawMessage: fields[12] as String? ?? '',
      importedAt: fields[13] as DateTime?,
      institutionName: fields[14] as String? ?? '',
      walletAccountId: fields[15] as String? ?? '',
      recurrenceFrequency: _readRecurrenceFrequency(fields[16]),
      recurrenceInterval: fields[17] as int? ?? 1,
      recurrenceEndDate: fields[18] as DateTime?,
      isRecurringTemplate: fields[19] as bool? ?? false,
      recurrenceTemplateId: fields[20] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntry obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.paymentMethod)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.source)
      ..writeByte(9)
      ..write(obj.externalId)
      ..writeByte(10)
      ..write(obj.merchantOrSender)
      ..writeByte(11)
      ..write(obj.accountHint)
      ..writeByte(12)
      ..write(obj.rawMessage)
      ..writeByte(13)
      ..write(obj.importedAt)
      ..writeByte(14)
      ..write(obj.institutionName)
      ..writeByte(15)
      ..write(obj.walletAccountId)
      ..writeByte(16)
      ..write(obj.recurrenceFrequency)
      ..writeByte(17)
      ..write(obj.recurrenceInterval)
      ..writeByte(18)
      ..write(obj.recurrenceEndDate)
      ..writeByte(19)
      ..write(obj.isRecurringTemplate)
      ..writeByte(20)
      ..write(obj.recurrenceTemplateId);
  }

  RecurrenceFrequency _readRecurrenceFrequency(dynamic value) {
    if (value is RecurrenceFrequency) {
      return value;
    }
    if (value is String) {
      switch (value) {
        case 'weekly':
          return RecurrenceFrequency.weekly;
        case 'monthly':
          return RecurrenceFrequency.monthly;
        case 'yearly':
          return RecurrenceFrequency.yearly;
        case 'none':
        default:
          return RecurrenceFrequency.none;
      }
    }
    return RecurrenceFrequency.none;
  }
}

class TransactionSourceAdapter extends TypeAdapter<TransactionSource> {
  @override
  final int typeId = 9;

  @override
  TransactionSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return TransactionSource.sms;
      case 2:
        return TransactionSource.bankApi;
      case 0:
      default:
        return TransactionSource.manual;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionSource obj) {
    switch (obj) {
      case TransactionSource.manual:
        writer.writeByte(0);
      case TransactionSource.sms:
        writer.writeByte(1);
      case TransactionSource.bankApi:
        writer.writeByte(2);
    }
  }
}

class RecurrenceFrequencyAdapter extends TypeAdapter<RecurrenceFrequency> {
  @override
  final int typeId = 10;

  @override
  RecurrenceFrequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return RecurrenceFrequency.weekly;
      case 2:
        return RecurrenceFrequency.monthly;
      case 3:
        return RecurrenceFrequency.yearly;
      case 0:
      default:
        return RecurrenceFrequency.none;
    }
  }

  @override
  void write(BinaryWriter writer, RecurrenceFrequency obj) {
    switch (obj) {
      case RecurrenceFrequency.none:
        writer.writeByte(0);
      case RecurrenceFrequency.weekly:
        writer.writeByte(1);
      case RecurrenceFrequency.monthly:
        writer.writeByte(2);
      case RecurrenceFrequency.yearly:
        writer.writeByte(3);
    }
  }
}
