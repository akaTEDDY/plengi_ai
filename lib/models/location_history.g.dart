// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocationHistoryAdapter extends TypeAdapter<LocationHistory> {
  @override
  final int typeId = 3;

  @override
  LocationHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocationHistory(
      location: (fields[0] as Map?)?.cast<String, dynamic>(),
      place: (fields[1] as Map?)?.cast<String, dynamic>(),
      district: (fields[2] as Map?)?.cast<String, dynamic>(),
      timestamp: fields[3] as DateTime,
      formattedTime: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LocationHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.location)
      ..writeByte(1)
      ..write(obj.place)
      ..writeByte(2)
      ..write(obj.district)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.formattedTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
