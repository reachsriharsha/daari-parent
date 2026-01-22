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
      currentGroupId: fields[2] as int?,
      currentTripName: fields[3] as String?,
      tripStartTime: fields[4] as DateTime?,
      watchingTripName: fields[5] as String?,
      watchingGroupId: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TripSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.isTripActive)
      ..writeByte(2)
      ..write(obj.currentGroupId)
      ..writeByte(3)
      ..write(obj.currentTripName)
      ..writeByte(4)
      ..write(obj.tripStartTime)
      ..writeByte(5)
      ..write(obj.watchingTripName)
      ..writeByte(6)
      ..write(obj.watchingGroupId);
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
