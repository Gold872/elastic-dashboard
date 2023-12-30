// This is a copy of AdvantageScope's StructDecoder.ts but ported into the Dart programming language
// https://github.com/Mechanical-Advantage/AdvantageScope/blob/main/src/shared/log/StructDecoder.ts

// All credit goes to Jonah from 6328

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';

class StructDecoder {
  final Map<String, String> schemaStrings = {};
  final Map<String, Schema> schemas = {};

  void addSchema(String name, Uint8List schema) {
    String schemaString = utf8.decode(schema);
    if (schemaStrings.containsKey(schemaString)) {
      return;
    }
    schemaStrings[name] = schemaString;

    while (true) {
      bool compiled = false;
      for (var schemaName in schemaStrings.keys) {
        if (!schemas.containsKey(schemaName)) {
          bool success = compileSchema(schemaName, schemaStrings[schemaName]!);
          compiled = compiled || success;
        }
      }
      if (!compiled) {
        break;
      }
    }
  }

  bool compileSchema(String name, String schema) {
    List<String> valueSchemaStrings =
        schema.split(';').where((e) => e.isNotEmpty).toList();
    List<ValueSchema> valueSchemas = [];

    for (String schemaString in valueSchemaStrings) {
      Map<int, String>? enumData;
      if (schemaString.startsWith('enum')) {
        enumData = {};
        int enumStart = schemaString.indexOf('{') + 1;
        int enumEnd = schemaString.indexOf('}');

        String enumString = schemaString
            .substring(enumStart, enumEnd)
            .split('')
            .whereNot((e) => e == ' ')
            .join();

        enumString.split(',').where((e) => e.isNotEmpty).forEach((pairStr) {
          List<String> pair = pairStr.split('=');
          if (pair.length == 2 && !int.parse(pair[1]).isNaN) {
            enumData![int.parse(pair[1])] = pair[0];
          }
        });

        schemaString = schemaString.substring(enumStart + 1);
      }

      // Remove type
      List<String> schemaStringSplit =
          schemaString.split(' ').where((e) => e.isNotEmpty).toList();
      String type = schemaStringSplit.removeAt(0);
      // Struct is missing
      if (!_validTypeStrings.contains(type) && !schemas.containsKey(type)) {
        return false;
      }

      // ValueType valueType = ValueType.values.firstWhere((e) => e.name == type);
      String nameString = schemaStringSplit.join();

      // Get name and bitlength/array stuff
      String name;
      int? bitfieldWidth;
      int? arrayLength;
      if (nameString.contains(':')) {
        // Bitfield
        List<String> split = nameString.split(':');
        name = split[0];
        bitfieldWidth = int.parse(split[1]);

        // Check for invalid bitfield
        if (!_bitfieldValidTypes.contains(type)) {
          continue;
        }
        if (type == ValueType.bool.name && bitfieldWidth != 1) {
          continue;
        }
      } else if (nameString.contains('[')) {
        // Array
        List<String> split = nameString.split('[');
        name = split[0];
        arrayLength = int.parse(split[1].split(']')[0]);
      } else {
        // Normal value
        name = nameString;
      }

      valueSchemas.add(
        ValueSchema(
          name: name,
          type: type,
          enumValue: enumData,
          bitfieldWidth: bitfieldWidth,
          arrayLength: arrayLength,
          bitRange: [0, 0],
        ),
      );
    }

    // Find bit positions
    int bitPosition = 0;
    int? bitfieldPosition;
    int? bitfieldLength;

    for (ValueSchema valueSchema in valueSchemas) {
      // References another struct
      if (!_validTypeStrings.contains(valueSchema.type)) {
        if (bitfieldPosition != null || bitfieldLength != null) {
          bitPosition += bitfieldLength! - bitfieldPosition!;
        }
        bitfieldPosition = null;
        bitfieldLength = null;

        int bitLength = schemas[valueSchema.type]!.length;
        if (valueSchema.arrayLength != null) {
          bitLength *= valueSchema.arrayLength!;
        }
        valueSchema.bitRange = [bitPosition, bitPosition + bitLength];
        bitPosition += bitLength;
      } else if (valueSchema.bitfieldWidth == null) {
        // Normal or array value
        if (bitfieldPosition != null || bitfieldLength != null) {
          bitPosition += bitfieldLength! - bitfieldPosition!;
        }
        bitfieldPosition = null;
        bitfieldLength = null;

        int bitLength = _valueTypeMaxBits[valueSchema.valueType]!;
        if (valueSchema.arrayLength != null) {
          bitLength *= valueSchema.arrayLength!;
        }
        valueSchema.bitRange = [bitPosition, bitPosition + bitLength];
        bitPosition += bitLength;
      } else {
        // Bitfield value
        int typeLength = _valueTypeMaxBits[valueSchema.valueType]!;
        int valueBitLength = min(valueSchema.bitfieldWidth!, typeLength);

        if (bitfieldPosition == null || // no bitfield started
            bitfieldLength == null || // no bitfield started
            (valueSchema.valueType != ValueType.bool &&
                bitfieldLength != typeLength) ||
            bitfieldPosition + valueBitLength > bitfieldLength) {
          // Start new bitfield
          if (bitfieldPosition != null || bitfieldLength != null) {
            bitPosition += bitfieldLength! - bitfieldPosition!;
          }
          bitfieldPosition = 0;
          bitfieldLength = typeLength;
        }
        valueSchema.bitRange = [bitPosition, bitPosition + valueBitLength];
        bitfieldPosition += valueBitLength;
        bitPosition += valueBitLength;
      }
    }
    if (bitfieldPosition != null || bitfieldLength != null) {
      bitPosition += bitfieldLength! - bitfieldPosition!;
    }

    schemas[name] = Schema(
      length: bitPosition,
      valueSchemas: valueSchemas,
    );
    return true;
  }

  Map<String, dynamic> decode(String name, Uint8List value) {
    if (!schemas.containsKey(name)) {
      throw StateError('Undefined Schema: \'$name\'');
    }
    Map<String, dynamic> output = {};
    Schema schema = schemas[name]!;
    List<bool> boolArray = _toBoolArray(value);
    for (ValueSchema valueSchema in schema.valueSchemas) {
      List<bool> valueBoolArray =
          boolArray.slice(valueSchema.bitRange[0], valueSchema.bitRange[1]);
      if (_validTypeStrings.contains(valueSchema.type)) {
        ValueType type = valueSchema.valueType;
        if (valueSchema.arrayLength == null) {
          // Normal value
          output[valueSchema.name] = StructDecoder.decodeValue(
            StructDecoder._toUint8List(valueBoolArray),
            type,
            valueSchema.enumValue,
          );
        } else {
          // Array type
          List<dynamic> value = [];
          int itemLength =
              (valueSchema.bitRange[1] - valueSchema.bitRange[0]) ~/
                  valueSchema.arrayLength!;

          for (int position = 0;
              position < valueBoolArray.length;
              position += itemLength) {
            value.add(
              StructDecoder.decodeValue(
                StructDecoder._toUint8List(
                    valueBoolArray.slice(position, position + itemLength)),
                type,
                valueSchema.enumValue,
              ),
            );
          }
          if (type == ValueType.char) {
            output[valueSchema.name] = value.join();
          } else {
            output[valueSchema.name] = value;
          }
        }
      } else {
        // Child struct
        dynamic child = decode(
            valueSchema.type, StructDecoder._toUint8List(valueBoolArray));
        output[valueSchema.name] = child;
      }
    }

    return output;
  }

  static dynamic decodeValue(
      Uint8List value, ValueType type, Map<int, String>? enumData) {
    Uint8List paddedValue = Uint8List(_valueTypeMaxBits[type]! ~/ 8);
    paddedValue.setAll(0, value);
    ByteData view = ByteData.view(paddedValue.buffer);
    dynamic output;
    switch (type) {
      case ValueType.bool:
        output = view.getUint8(0) > 0;
        break;
      case ValueType.char:
        output = utf8.decode(value);
        break;
      case ValueType.int8:
        output = view.getInt8(0);
        break;
      case ValueType.int16:
        output = view.getInt16(0, Endian.little);
      case ValueType.int32:
        output = view.getInt32(0, Endian.little);
        break;
      case ValueType.int64:
        output = view.getInt64(0, Endian.little);
        break;
      case ValueType.uint8:
        output = view.getUint8(0);
        break;
      case ValueType.uint16:
        output = view.getUint16(0, Endian.little);
        break;
      case ValueType.uint32:
        output = view.getUint32(0, Endian.little);
        break;
      case ValueType.uint64:
        output = view.getUint64(0, Endian.little);
        break;
      case ValueType.float:
      case ValueType.float32:
        output = view.getFloat32(0, Endian.little);
        break;
      case ValueType.double:
      case ValueType.float64:
        output = view.getFloat64(0, Endian.little);
        break;
    }

    if (enumData != null && enumData.containsKey(output)) {
      output = enumData[output];
    }

    return output;
  }

  static List<bool> _toBoolArray(Uint8List values) {
    List<bool> output = [];
    for (int value in values) {
      for (int shift = 0; shift < 8; shift++) {
        output.add(((1 << shift) & value) > 0);
      }
    }

    return output;
  }

  static Uint8List _toUint8List(List<bool> values) {
    Uint8List output = Uint8List((values.length / 8).ceil());
    for (int i = 0; i < values.length; i++) {
      if (values[i]) {
        int byte = (i / 8).floor();
        int bit = i % 8;
        output[byte] |= 1 << bit;
      }
    }

    return output;
  }
}

class Schema {
  final int length;
  final List<ValueSchema> valueSchemas;

  const Schema({
    required this.length,
    required this.valueSchemas,
  });
}

class ValueSchema {
  final String name;
  final String type;
  final Map<int, String>? enumValue;
  final int? bitfieldWidth;
  final int? arrayLength;
  List<int> bitRange;

  ValueType get valueType => ValueType.values.firstWhere((e) => e.name == type);

  ValueSchema({
    required this.name,
    required this.type,
    required this.enumValue,
    required this.bitfieldWidth,
    required this.arrayLength,
    required this.bitRange,
  });
}

enum ValueType {
  bool('bool'),
  char('char'),
  int8('int8'),
  int16('int16'),
  int32('int32'),
  int64('int64'),
  uint8('uint8'),
  uint16('uint16'),
  uint32('uint32'),
  uint64('uint64'),
  float('float'),
  float32('float32'),
  double('double'),
  float64('float64');

  const ValueType(this.name);

  final String name;

  @override
  String toString() {
    return name;
  }
}

final List<String> _validTypeStrings =
    ValueType.values.map((e) => e.name).toList();

final List<String> _bitfieldValidTypes = [
  ValueType.bool,
  ValueType.int8,
  ValueType.int16,
  ValueType.int32,
  ValueType.int64,
  ValueType.uint8,
  ValueType.uint16,
  ValueType.uint32,
  ValueType.uint64
].map((e) => e.name).toList();

final Map<ValueType, int> _valueTypeMaxBits = {
  ValueType.bool: 8,
  ValueType.char: 8,
  ValueType.int8: 8,
  ValueType.int16: 16,
  ValueType.int32: 32,
  ValueType.int64: 64,
  ValueType.uint8: 8,
  ValueType.uint16: 16,
  ValueType.uint32: 32,
  ValueType.uint64: 64,
  ValueType.float: 32,
  ValueType.float32: 32,
  ValueType.double: 64,
  ValueType.float64: 64,
};
