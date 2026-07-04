import 'package:hive/hive.dart';

import 'expense_category.dart';

enum TransactionSource { manual, sms, bankApi }

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
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntry obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.institutionName);
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
