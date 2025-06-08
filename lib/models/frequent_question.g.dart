// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequent_question.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FrequentQuestionAdapter extends TypeAdapter<FrequentQuestion> {
  @override
  final int typeId = 2;

  @override
  FrequentQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FrequentQuestion(
      question: fields[0] as String,
      category: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FrequentQuestion obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrequentQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
