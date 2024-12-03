import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/struct_schemas/swerve_module_state_struct.dart';

void main() {
  test('Module state with valid data', () {
    List<int> rawBytes = [
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
      0xf9,
      0x3f
    ];
    Uint8List data = Uint8List.fromList(rawBytes);

    SwerveModuleStateStruct moduleStateStruct =
        SwerveModuleStateStruct.valueFromBytes(data);

    expect(moduleStateStruct.speed, 5.0);
    expect(moduleStateStruct.angle, pi / 2);
  });

  test('Module state with missing bytes', () {
    List<int> rawBytes = [
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
      0xfb
    ];
    Uint8List data = Uint8List.fromList(rawBytes);

    SwerveModuleStateStruct moduleStateStruct =
        SwerveModuleStateStruct.valueFromBytes(data);

    expect(moduleStateStruct.speed, 5.0);
    expect(moduleStateStruct.angle, 0.0);
  });

  test('Module state with no bytes', () {
    List<int> rawBytes = [];
    Uint8List data = Uint8List.fromList(rawBytes);

    SwerveModuleStateStruct moduleStateStruct =
        SwerveModuleStateStruct.valueFromBytes(data);

    expect(moduleStateStruct.speed, 0.0);
    expect(moduleStateStruct.angle, 0.0);
  });

  test('Module state array with valid data', () {
    List<int> rawBytes = [
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
      0xf9,
      0x3f
    ];
    Uint8List data =
        Uint8List.fromList([...rawBytes, ...rawBytes, ...rawBytes]);

    List<SwerveModuleStateStruct> moduleStateStruct =
        SwerveModuleStateStruct.listFromBytes(data);

    expect(moduleStateStruct.length, 3);

    for (SwerveModuleStateStruct moduleStateStruct in moduleStateStruct) {
      expect(moduleStateStruct.speed, 5.0);
      expect(moduleStateStruct.angle, pi / 2);
    }
  });

  test('Module state array with missing data', () {
    List<int> rawBytes = [
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
      0xf9,
      0x3f
    ];
    Uint8List data = Uint8List.fromList(
        [...rawBytes, ...rawBytes, ...rawBytes, 0x00, 0x00, 0x14, 0x40]);

    List<SwerveModuleStateStruct> moduleStateStruct =
        SwerveModuleStateStruct.listFromBytes(data);

    expect(moduleStateStruct.length, 3);

    for (SwerveModuleStateStruct moduleStateStruct in moduleStateStruct) {
      expect(moduleStateStruct.speed, 5.0);
      expect(moduleStateStruct.angle, pi / 2);
    }
  });
}
