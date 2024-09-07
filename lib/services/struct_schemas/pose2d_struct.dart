import 'dart:typed_data';

class Pose2dStruct {
  static const int length = 24;

  final double x;
  final double y;
  final double angle;

  const Pose2dStruct({
    required this.x,
    required this.y,
    required this.angle,
  });

  factory Pose2dStruct.valueFromBytes(Uint8List value) {
    ByteData view = ByteData.view(value.buffer);

    int length = view.lengthInBytes;

    double x = 0.0;
    double y = 0.0;
    double angle = 0.0;

    if (length >= 8) {
      x = view.getFloat64(0, Endian.little);
    }
    if (length >= 16) {
      y = view.getFloat64(8, Endian.little);
    }
    if (length >= 24) {
      angle = view.getFloat64(16, Endian.little);
    }

    return Pose2dStruct(x: x, y: y, angle: angle);
  }

  static List<Pose2dStruct> listFromBytes(Uint8List value) {
    ByteData view = ByteData.view(value.buffer);

    int viewLength = view.lengthInBytes;

    int arraySize = viewLength ~/ length;

    List<Pose2dStruct> poseList = [];

    for (int i = 0; i < arraySize; i++) {
      if (i * length + length > viewLength) {
        break;
      }

      Uint8List elementBytes =
          Uint8List.sublistView(view, i * length, i * length + length);

      poseList.add(Pose2dStruct.valueFromBytes(elementBytes));
    }

    return poseList;
  }
}
