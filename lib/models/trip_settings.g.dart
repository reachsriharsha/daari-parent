// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripSettingsAdapter extends TypeAdapter<TripSettings> {
  @override
  final int typeId = 1;

  @override
  TripSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripSettings(
      isTripActive: fields[0] as bool,
      currentTripId: fields[1] as int?,
      currentGroupId: fields[2] as int?,
      currentTripName: fields[3] as String?,
      tripStartTime: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TripSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.isTripActive)
      ..writeByte(1)
      ..write(obj.currentTripId)
      ..writeByte(2)
      ..write(obj.currentGroupId)
      ..writeByte(3)
      ..write(obj.currentTripName)
      ..writeByte(4)
      ..write(obj.tripStartTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
