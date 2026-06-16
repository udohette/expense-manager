import 'package:hive/hive.dart';

import 'expense_category.dart';

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
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final EntryType type;
  final String paymentMethod;
  final String note;

  ExpenseEntry copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    EntryType? type,
    String? paymentMethod,
    String? note,
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
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntry obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.note);
  }
}
