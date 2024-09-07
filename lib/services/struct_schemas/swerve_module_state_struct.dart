import 'dart:typed_data';

class SwerveModuleStateStruct {
  static const int length = 16;

  final double speed;
  final double angle;

  const SwerveModuleStateStruct({required this.speed, required this.angle});

  factory SwerveModuleStateStruct.valueFromBytes(Uint8List value) {
    ByteData view = ByteData.view(value.buffer);

    int length = view.lengthInBytes;

    double speed = 0.0;
    double angle = 0.0;

    if (length >= 8) {
      speed = view.getFloat64(0, Endian.little);
    }
    if (length >= 16) {
      angle = view.getFloat64(8, Endian.little);
    }

    return SwerveModuleStateStruct(speed: speed, angle: angle);
  }

  static List<SwerveModuleStateStruct> listFromBytes(Uint8List value) {
    ByteData view = ByteData.view(value.buffer);

    int viewLength = view.lengthInBytes;

    int arraySize = viewLength ~/ length;

    List<SwerveModuleStateStruct> poseList = [];

    for (int i = 0; i < arraySize; i++) {
      if (i * length + length > viewLength) {
        break;
      }

      Uint8List elementBytes =
          Uint8List.sublistView(view, i * length, i * length + length);

      poseList.add(SwerveModuleStateStruct.valueFromBytes(elementBytes));
    }

    return poseList;
  }
}
