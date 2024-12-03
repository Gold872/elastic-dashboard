import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';

void main() {
  test('Pose2D struct with valid data', () {
    List<int> rawBytes = [
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x18,
      0x2d,
      0x44,
      0x54,
      0xfb,
      0x21,
      0x09,
      0x40
    ];
    Uint8List data = Uint8List.fromList(rawBytes);

    Pose2dStruct pose2dStruct = Pose2dStruct.valueFromBytes(data);

    expect(pose2dStruct.x, 5.0);
    expect(pose2dStruct.y, 5.0);
    expect(pose2dStruct.angle, pi);
  });

  test('Pose2D struct with missing bytes', () {
    List<int> rawBytes = [
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x18,
      0x2d,
      0x44,
      0x54
    ];
    Uint8List data = Uint8List.fromList(rawBytes);

    Pose2dStruct pose2dStruct = Pose2dStruct.valueFromBytes(data);

    expect(pose2dStruct.x, 5.0);
    expect(pose2dStruct.y, 5.0);
    expect(pose2dStruct.angle, 0.0);
  });

  test('Pose2D struct with no bytes', () {
    List<int> rawBytes = [];
    Uint8List data = Uint8List.fromList(rawBytes);

    Pose2dStruct pose2dStruct = Pose2dStruct.valueFromBytes(data);

    expect(pose2dStruct.x, 0.0);
    expect(pose2dStruct.y, 0.0);
    expect(pose2dStruct.angle, 0.0);
  });

  test('Pose2D array with valid data', () {
    List<int> rawBytes = [
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x18,
      0x2d,
      0x44,
      0x54,
      0xfb,
      0x21,
      0x09,
      0x40
    ];
    Uint8List data =
        Uint8List.fromList([...rawBytes, ...rawBytes, ...rawBytes]);

    List<Pose2dStruct> poseList = Pose2dStruct.listFromBytes(data);
    expect(poseList.length, 3);

    for (Pose2dStruct pose in poseList) {
      expect(pose.x, 5.0);
      expect(pose.y, 5.0);
      expect(pose.angle, pi);
    }
  });

  test('Pose2D array with missing data', () {
    List<int> rawBytes = [
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x18,
      0x2d,
      0x44,
      0x54,
      0xfb,
      0x21,
      0x09,
      0x40
    ];
    Uint8List data = Uint8List.fromList([
      ...rawBytes,
      ...rawBytes,
      ...rawBytes,
      0x00,
      0x00,
      0x00,
      0x00,
      0x14,
      0x40,
      0x00
    ]);

    List<Pose2dStruct> poseList = Pose2dStruct.listFromBytes(data);
    expect(poseList.length, 3);

    for (Pose2dStruct pose in poseList) {
      expect(pose.x, 5.0);
      expect(pose.y, 5.0);
      expect(pose.angle, pi);
    }
  });
}
