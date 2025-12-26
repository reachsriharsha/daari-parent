// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      ngrokUrl: fields[0] as String?,
      idToken: fields[1] as String?,
      profId: fields[2] as String?,
      locationPermissionGranted: fields[3] as bool?,
      fcmToken: fields[4] as String?,
      homeLatitude: fields[5] as double?,
      homeLongitude: fields[6] as double?,
      homeAddress: fields[7] as String?,
      homePlaceName: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.ngrokUrl)
      ..writeByte(1)
      ..write(obj.idToken)
      ..writeByte(2)
      ..write(obj.profId)
      ..writeByte(3)
      ..write(obj.locationPermissionGranted)
      ..writeByte(4)
      ..write(obj.fcmToken)
      ..writeByte(5)
      ..write(obj.homeLatitude)
      ..writeByte(6)
      ..write(obj.homeLongitude)
      ..writeByte(7)
      ..write(obj.homeAddress)
      ..writeByte(8)
      ..write(obj.homePlaceName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
