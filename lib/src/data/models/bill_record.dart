import 'package:hive/hive.dart';

import 'expense_entry.dart';

class BillRecord extends HiveObject {
  BillRecord({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.frequency,
    this.reminderDaysBefore = 3,
    this.isPaid = false,
    this.note = '',
    this.walletAccountId = '',
  });

  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final RecurrenceFrequency frequency;
  final int reminderDaysBefore;
  final bool isPaid;
  final String note;
  final String walletAccountId;

  DateTime get reminderDate =>
      dueDate.subtract(Duration(days: reminderDaysBefore));

  BillRecord copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    RecurrenceFrequency? frequency,
    int? reminderDaysBefore,
    bool? isPaid,
    String? note,
    String? walletAccountId,
  }) {
    return BillRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      isPaid: isPaid ?? this.isPaid,
      note: note ?? this.note,
      walletAccountId: walletAccountId ?? this.walletAccountId,
    );
  }
}

class BillRecordAdapter extends TypeAdapter<BillRecord> {
  @override
  final int typeId = 14;

  @override
  BillRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return BillRecord(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double,
      dueDate: fields[3] as DateTime,
      frequency:
          fields[4] as RecurrenceFrequency? ?? RecurrenceFrequency.monthly,
      reminderDaysBefore: fields[5] as int? ?? 3,
      isPaid: fields[6] as bool? ?? false,
      note: fields[7] as String? ?? '',
      walletAccountId: fields[8] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, BillRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.reminderDaysBefore)
      ..writeByte(6)
      ..write(obj.isPaid)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.walletAccountId);
  }
}
