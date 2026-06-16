import 'package:hive/hive.dart';

enum DebtType { owedToMe, iOwe }

enum DebtStatus { active, settled }

enum DebtPersonSource { manual, contacts }

class DebtRecord extends HiveObject {
  DebtRecord({
    required this.id,
    required this.personName,
    required this.amount,
    required this.type,
    required this.status,
    required this.personSource,
    required this.createdAt,
    this.phoneNumber,
    this.note = '',
    this.contactId,
    this.dueDate,
  });

  final String id;
  final String personName;
  final double amount;
  final DebtType type;
  final DebtStatus status;
  final DebtPersonSource personSource;
  final DateTime createdAt;
  final String? phoneNumber;
  final String note;
  final String? contactId;
  final DateTime? dueDate;

  DebtRecord copyWith({
    String? id,
    String? personName,
    double? amount,
    DebtType? type,
    DebtStatus? status,
    DebtPersonSource? personSource,
    DateTime? createdAt,
    String? phoneNumber,
    String? note,
    String? contactId,
    DateTime? dueDate,
  }) {
    return DebtRecord(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      personSource: personSource ?? this.personSource,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      note: note ?? this.note,
      contactId: contactId ?? this.contactId,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class DebtTypeAdapter extends TypeAdapter<DebtType> {
  @override
  final int typeId = 5;

  @override
  DebtType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return DebtType.iOwe;
      case 0:
      default:
        return DebtType.owedToMe;
    }
  }

  @override
  void write(BinaryWriter writer, DebtType obj) {
    writer.writeByte(obj == DebtType.iOwe ? 1 : 0);
  }
}

class DebtStatusAdapter extends TypeAdapter<DebtStatus> {
  @override
  final int typeId = 6;

  @override
  DebtStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return DebtStatus.settled;
      case 0:
      default:
        return DebtStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, DebtStatus obj) {
    writer.writeByte(obj == DebtStatus.settled ? 1 : 0);
  }
}

class DebtPersonSourceAdapter extends TypeAdapter<DebtPersonSource> {
  @override
  final int typeId = 7;

  @override
  DebtPersonSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return DebtPersonSource.contacts;
      case 0:
      default:
        return DebtPersonSource.manual;
    }
  }

  @override
  void write(BinaryWriter writer, DebtPersonSource obj) {
    writer.writeByte(obj == DebtPersonSource.contacts ? 1 : 0);
  }
}

class DebtRecordAdapter extends TypeAdapter<DebtRecord> {
  @override
  final int typeId = 8;

  @override
  DebtRecord read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return DebtRecord(
      id: fields[0] as String,
      personName: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as DebtType,
      status: fields[4] as DebtStatus,
      personSource: fields[5] as DebtPersonSource,
      createdAt: fields[6] as DateTime,
      phoneNumber: fields[7] as String?,
      note: fields[8] as String? ?? '',
      contactId: fields[9] as String?,
      dueDate: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DebtRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.personSource)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.phoneNumber)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.contactId)
      ..writeByte(10)
      ..write(obj.dueDate);
  }
}
