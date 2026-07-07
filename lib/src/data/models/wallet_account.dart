import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum WalletKind { cash, bank, savings, business, custom }

class WalletAccount extends HiveObject {
  WalletAccount({
    required this.id,
    required this.name,
    required this.kind,
    required this.colorValue,
    required this.iconCodePoint,
    this.note = '',
    this.isDefault = false,
  });

  final String id;
  final String name;
  final WalletKind kind;
  final int colorValue;
  final int iconCodePoint;
  final String note;
  final bool isDefault;

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  WalletAccount copyWith({
    String? id,
    String? name,
    WalletKind? kind,
    int? colorValue,
    int? iconCodePoint,
    String? note,
    bool? isDefault,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      note: note ?? this.note,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class WalletKindAdapter extends TypeAdapter<WalletKind> {
  @override
  final int typeId = 12;

  @override
  WalletKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return WalletKind.bank;
      case 2:
        return WalletKind.savings;
      case 3:
        return WalletKind.business;
      case 4:
        return WalletKind.custom;
      case 0:
      default:
        return WalletKind.cash;
    }
  }

  @override
  void write(BinaryWriter writer, WalletKind obj) {
    switch (obj) {
      case WalletKind.cash:
        writer.writeByte(0);
      case WalletKind.bank:
        writer.writeByte(1);
      case WalletKind.savings:
        writer.writeByte(2);
      case WalletKind.business:
        writer.writeByte(3);
      case WalletKind.custom:
        writer.writeByte(4);
    }
  }
}

class WalletAccountAdapter extends TypeAdapter<WalletAccount> {
  @override
  final int typeId = 13;

  @override
  WalletAccount read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return WalletAccount(
      id: fields[0] as String,
      name: fields[1] as String,
      kind: fields[2] as WalletKind,
      colorValue: fields[3] as int,
      iconCodePoint: fields[4] as int,
      note: fields[5] as String? ?? '',
      isDefault: fields[6] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, WalletAccount obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kind)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.iconCodePoint)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.isDefault);
  }
}
