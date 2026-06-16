import 'package:hive/hive.dart';

enum BudgetPeriod { weekly, monthly }

class BudgetPlan extends HiveObject {
  BudgetPlan({
    required this.id,
    required this.name,
    required this.limit,
    required this.startDate,
    this.categoryId,
    this.period = BudgetPeriod.monthly,
  });

  final String id;
  final String name;
  final double limit;
  final String? categoryId;
  final DateTime startDate;
  final BudgetPeriod period;

  BudgetPlan copyWith({
    String? id,
    String? name,
    double? limit,
    String? categoryId,
    DateTime? startDate,
    BudgetPeriod? period,
  }) {
    return BudgetPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      limit: limit ?? this.limit,
      categoryId: categoryId ?? this.categoryId,
      startDate: startDate ?? this.startDate,
      period: period ?? this.period,
    );
  }
}

class BudgetPeriodAdapter extends TypeAdapter<BudgetPeriod> {
  @override
  final int typeId = 3;

  @override
  BudgetPeriod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return BudgetPeriod.monthly;
      case 0:
      default:
        return BudgetPeriod.weekly;
    }
  }

  @override
  void write(BinaryWriter writer, BudgetPeriod obj) {
    writer.writeByte(obj == BudgetPeriod.monthly ? 1 : 0);
  }
}

class BudgetPlanAdapter extends TypeAdapter<BudgetPlan> {
  @override
  final int typeId = 4;

  @override
  BudgetPlan read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return BudgetPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      limit: fields[2] as double,
      categoryId: fields[3] as String?,
      startDate: fields[4] as DateTime,
      period: fields[5] as BudgetPeriod? ?? BudgetPeriod.monthly,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetPlan obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.limit)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.period);
  }
}
