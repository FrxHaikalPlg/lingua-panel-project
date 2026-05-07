// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranslationHistoryAdapter extends TypeAdapter<TranslationHistory> {
  @override
  final int typeId = 0;

  @override
  TranslationHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranslationHistory(
      id: fields[0] as String,
      originalImagePath: fields[1] as String,
      translatedImagePath: fields[2] as String,
      timestamp: fields[3] as DateTime,
      isFavorite: fields[4] as bool,
      sourceLang: fields[5] as String,
      orientation: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TranslationHistory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originalImagePath)
      ..writeByte(2)
      ..write(obj.translatedImagePath)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.isFavorite)
      ..writeByte(5)
      ..write(obj.sourceLang)
      ..writeByte(6)
      ..write(obj.orientation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
