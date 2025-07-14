import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';

extension Uint8ListToBitArray on Uint8List {
  List<bool> toBitArray() {
    List<bool> output = [];

    for (int value in this) {
      for (int shift = 0; shift < 8; shift++) {
        output.add(((1 << shift) & value) > 0);
      }
    }

    return output;
  }
}

extension BitArrayToUint8List on List<bool> {
  Uint8List toUint8List() {
    Uint8List output = Uint8List((length / 8).ceil());

    for (int i = 0; i < length; i++) {
      if (this[i]) {
        int byte = (i / 8).floor();
        int bit = i % 8;
        output[byte] |= 1 << bit;
      }
    }

    return output;
  }
}

extension ByteDataWebUtil on ByteData {
  @visibleForTesting
  int extractWebInt64(int byteOffset, [Endian endian = Endian.big]) {
    late int hi;
    late int lo;

    if (endian == Endian.big) {
      hi = getInt32(byteOffset, endian);
      lo = getUint32(byteOffset + 4, endian);
    } else {
      hi = getInt32(byteOffset + 4, endian);
      lo = getUint32(byteOffset, endian);
    }

    return (hi * 0x100000000) + lo;
  }

  @visibleForTesting
  int extractWebUint64(int byteOffset, [Endian endian = Endian.big]) {
    late int hi;
    late int lo;

    if (endian == Endian.big) {
      hi = getUint32(byteOffset, endian);
      lo = getUint32(byteOffset + 4, endian);
    } else {
      hi = getUint32(byteOffset + 4, endian);
      lo = getUint32(byteOffset, endian);
    }

    return (hi * 0x100000000) + lo;
  }

  int getInt64Web(int byteOffset, [Endian endian = Endian.big]) {
    const bool isWeb = bool.fromEnvironment('dart.library.html');

    if (isWeb) {
      return extractWebInt64(byteOffset, endian);
    }
    return getInt64(byteOffset, endian);
  }

  int getUint64Web(int byteOffset, [Endian endian = Endian.big]) {
    const bool isWeb = bool.fromEnvironment('dart.library.html');

    if (isWeb) {
      return extractWebUint64(byteOffset, endian);
    }

    return getUint64(byteOffset, endian);
  }
}

class SchemaParseException implements Exception {
  SchemaParseException([var message]);
}

/// This class is a singleton that manages the schemas of NTStructs.
/// It allows adding new schemas and retrieving existing ones by name.
/// It also provides a method to parse a schema string into a list of field schemas.
class SchemaManager {
  final Map<String, String> _uncompiledSchemas = {};
  final Map<String, NTStructSchema> _schemas = {};

  NTStructSchema? getSchema(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas[name];
  }

  void processNewSchema(String name, List<int> rawData) {
    String schema = utf8.decode(rawData);
    if (name.contains(':')) {
      name = name.split(':').last;
    }

    _uncompiledSchemas[name] = schema;

    while (_uncompiledSchemas.isNotEmpty) {
      bool compiled = false;

      List<String> newlyCompiled = [];

      for (final uncompiled in _uncompiledSchemas.entries) {
        if (!_schemas.containsKey(uncompiled.key)) {
          bool success = _addStringSchema(uncompiled.key, uncompiled.value);
          if (success) {
            newlyCompiled.add(uncompiled.key);
          }
          compiled = compiled || success;
        }
      }

      _uncompiledSchemas.removeWhere((k, v) => newlyCompiled.contains(k));

      if (!compiled) {
        break;
      }
    }
  }

  void _addSchema(String name, NTStructSchema schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    if (_schemas.containsKey(name)) {
      return;
    }

    logger.debug(
      'Adding schema: $name, $schema',
    );

    _schemas[name] = schema;
  }

  bool _addStringSchema(String name, String schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }
    name = name.trim();

    if (_schemas.containsKey(name)) {
      return true;
    }

    try {
      NTStructSchema parsedSchema = NTStructSchema.parse(
        name: name,
        schema: schema,
        knownSchemas: _schemas,
      );
      _addSchema(name, parsedSchema);
      return true;
    } catch (err) {
      logger.info('Failed to parse schema: $name - $schema');
      return false;
    }
  }

  bool isStruct(String name) {
    name = name.trim();
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas.containsKey(name);
  }
}

enum StructValueType {
  bool('bool', 8),
  char('char', 8),
  int8('int8', 8),
  int16('int16', 16),
  int32('int32', 32),
  int64('int64', 64),
  uint8('uint8', 8),
  uint16('uint16', 16),
  uint32('uint32', 32),
  uint64('uint64', 64),
  float('float', 32),
  float32('float32', 32),
  double('double', 64),
  float64('float64', 64),
  struct('struct', 0);

  const StructValueType(this.name, this.maxBits);

  final String name;
  final int maxBits;

  static StructValueType parse(String type) {
    return StructValueType.values.firstWhereOrNull((e) => e.name == type) ??
        StructValueType.struct;
  }

  NT4Type get ntType => switch (this) {
        StructValueType.bool => NT4Type.boolean(),
        StructValueType.char ||
        StructValueType.int8 ||
        StructValueType.int16 ||
        StructValueType.int32 ||
        StructValueType.int64 ||
        StructValueType.uint8 ||
        StructValueType.uint16 ||
        StructValueType.uint32 ||
        StructValueType.uint64 =>
          NT4Type.int(),
        StructValueType.float ||
        StructValueType.float32 ||
        StructValueType.double ||
        StructValueType.float64 =>
          NT4Type.double(),
        StructValueType.struct => NT4Type.struct(name),
      };

  @override
  String toString() {
    return name;
  }
}

/// This class represents a field schema in an NTStruct.
/// It contains the field name and its type.
/// It also provides a method to get type information for the field if it is a struct.
class NTFieldSchema {
  final String fieldName;
  final String type;
  final NTStructSchema? subSchema;
  final int bitLength;
  final int? arrayLength;
  final (int start, int end) bitRange;

  StructValueType get valueType => StructValueType.parse(type);

  NT4Type get ntType {
    NT4Type innerType = valueType != StructValueType.struct
        ? valueType.ntType
        : NT4Type.struct(type);

    if (isArray) {
      return NT4Type.array(innerType);
    }
    return innerType;
  }

  bool get isArray => arrayLength != null;

  NTFieldSchema({
    required this.fieldName,
    required this.type,
    required this.bitLength,
    this.arrayLength,
    this.subSchema,
    required this.bitRange,
  });

  factory NTFieldSchema.parse({
    required int start,
    required String definition,
    required String type,
    required Map<String, NTStructSchema> knownSchemas,
  }) {
    StructValueType fieldType = StructValueType.parse(type);
    late String fieldName;
    late (int start, int end) bitRange;
    int? bitLength;
    int? arrayLength;
    NTStructSchema? subSchema;

    if (fieldType == StructValueType.struct) {
      NTStructSchema? schema = knownSchemas[type];
      if (schema == null) {
        logger.debug('Unknown struct type: $type');
        throw SchemaParseException('Unknown struct type: $type');
      }
      bitLength = schema.bitLength;
      subSchema = schema;
    }

    if (definition.contains(':')) {
      var [name, length] = definition.split(':');
      fieldName = name.trim();
      bitLength = int.tryParse(length.trim());
    } else if (definition.contains('[')) {
      List<String> split = definition.split('[');
      String rawLength = split[1].split(']')[0];
      arrayLength = int.parse(rawLength);

      bitLength = (bitLength ?? fieldType.maxBits) * arrayLength;

      fieldName = split[0];
    } else {
      fieldName = definition;
    }

    if (fieldName.contains(' ')) {
      throw SchemaParseException('Field name cannot contain spaces');
    }

    bitLength ??= fieldType.maxBits;

    bitRange = (start, start + bitLength);

    return NTFieldSchema(
      fieldName: fieldName,
      type: type,
      subSchema: subSchema,
      bitRange: bitRange,
      arrayLength: arrayLength,
      bitLength: bitLength,
    );
  }

  static NTFieldSchema fromJson(
    Map<String, dynamic> json,
  ) {
    return NTFieldSchema(
      fieldName: json['name'] ?? json['field'],
      type: json['type'],
      bitLength: json['bit_length'],
      bitRange: (json['bit_range_start'], json['bit_range_end']),
      arrayLength: json['array_length'],
    );
  }

  int get startByte => (bitRange.$1 / 8).ceil();

  Object? toValue(Uint8List data) {
    final view = data.buffer.asByteData();
    return switch (valueType) {
      StructValueType.bool => view.getUint8(0) > 0,
      StructValueType.char => utf8.decode([view.getUint8(0)]),
      StructValueType.int8 => view.getInt8(0),
      StructValueType.int16 => view.getInt16(0, Endian.little),
      StructValueType.int32 => view.getInt32(0, Endian.little),
      StructValueType.int64 => view.getInt64Web(0, Endian.little),
      StructValueType.uint8 => view.getUint8(0),
      StructValueType.uint16 => view.getUint16(0, Endian.little),
      StructValueType.uint32 => view.getUint32(0, Endian.little),
      StructValueType.uint64 => view.getUint64Web(0, Endian.little),
      StructValueType.float ||
      StructValueType.float32 =>
        view.getFloat32(0, Endian.little),
      StructValueType.double ||
      StructValueType.float64 =>
        view.getFloat64(0, Endian.little),
      StructValueType.struct => () {
          if (subSchema == null) {
            return null;
          }
          return NTStruct.parse(
            schema: subSchema!,
            data: data,
          );
        }(),
    };
  }
}

/// This class represents a schema for an NTStruct.
/// It contains the name of the struct and a list of field schemas.
class NTStructSchema {
  final String name;
  final List<NTFieldSchema> fields;
  final int bitLength;

  NTStructSchema({
    required this.name,
    required this.fields,
    required this.bitLength,
  });

  factory NTStructSchema.parse({
    required String name,
    required String schema,
    Map<String, NTStructSchema> knownSchemas = const {},
  }) {
    List<NTFieldSchema> fields = [];
    List<String> schemaParts = schema.replaceAll('\n', '').split(';');

    int bitStart = 0;
    for (final String part in schemaParts.map((e) => e.trim())) {
      if (part.isEmpty) {
        continue;
      }
      var [type, definition] = [
        part.substring(0, part.indexOf(' ')),
        part.substring(part.indexOf(' ') + 1)
      ];

      NTFieldSchema field = NTFieldSchema.parse(
        start: bitStart,
        definition: definition,
        type: type,
        knownSchemas: knownSchemas,
      );
      bitStart += field.bitLength;
      fields.add(field);
    }

    int bits = 0;
    for (final field in fields) {
      bits += field.bitLength;
    }

    return NTStructSchema(name: name, fields: fields, bitLength: bits);
  }

  NTFieldSchema? operator [](String key) {
    for (final field in fields) {
      if (field.fieldName == key) {
        return field;
      }
    }

    return null;
  }

  @override
  String toString() {
    return '$name { ${fields.map((field) => '${field.fieldName}: ${field.type}').join(', ')} }';
  }

  static NTStructSchema fromJson(Map<String, dynamic> json) {
    return NTStructSchema(
      name: json['name'] ?? json['type'],
      fields: (tryCast<List<dynamic>>(json['fields']) ?? [])
          .map((field) => NTFieldSchema.fromJson(tryCast(field) ?? {}))
          .toList(),
      bitLength: json['bit_length'],
    );
  }
}

/// This class represents an NTStruct.
/// It contains a schema and a map of values.
/// It provides methods to parse data into NTStructValue instances
/// and to retrieve values by key.
class NTStruct {
  final NTStructSchema schema;
  final Map<String, Object?> values;

  NTStruct({
    required this.schema,
    required this.values,
  });

  factory NTStruct.parse({
    required NTStructSchema schema,
    required Uint8List data,
  }) {
    List<bool> dataBitArray = data.toBitArray();

    Map<String, Object?> values = {};

    for (final field in schema.fields) {
      if (field.isArray) {
        List<Object?> value = [];

        int itemLength =
            (field.bitRange.$2 - field.bitRange.$1) ~/ field.arrayLength!;

        for (int position = field.bitRange.$1;
            position < dataBitArray.length;
            position += itemLength) {
          value.add(
            field.toValue(
              dataBitArray.slice(position, position + itemLength).toUint8List(),
            ),
          );
        }

        if (field.valueType == StructValueType.char) {
          values[field.fieldName] = value.join();
        } else {
          values[field.fieldName] = value;
        }
      } else {
        final value = field.toValue(
          dataBitArray
              .slice(field.bitRange.$1, field.bitRange.$2)
              .toUint8List(),
        );

        values[field.fieldName] = value;
      }
    }

    return NTStruct(schema: schema, values: values);
  }

  dynamic operator [](String key) {
    return values[key];
  }

  Object? get(List<String> key) {
    Object? value = this;

    for (final k in key) {
      if (value is NTStruct) {
        value = value[k]!;
      } else {
        return null;
      }
    }

    return value;
  }

  // static (int, NTStructValue) _parseValue(
  //   NTFieldSchema field,
  //   Uint8List data,
  // ) {
  //   if (field.isArray) {
  //     var (consumed, value) = _parseArray(field, data, field.arrayLength!);
  //     return (consumed, value);
  //   } else {
  //     return _parseValueInner(field, data);
  //   }
  // }

  // static (int, NTStructValue) _parseValueInner(
  //     NTFieldSchema field, Uint8List data) {
  //   if (field.type.fragment == NT4TypeFragment.boolean) {
  //     return (1, NTStructValue.fromBool(data[0] != 0));
  //   } else if (field.type.fragment == NT4TypeFragment.int32) {
  //     return (
  //       4,
  //       NTStructValue.fromInt(
  //           data.buffer.asByteData().getInt32(0, Endian.little))
  //     );
  //   } else if (field.type.fragment == NT4TypeFragment.float32) {
  //     return (
  //       4,
  //       NTStructValue.fromDouble(
  //           data.buffer.asByteData().getFloat32(0, Endian.little))
  //     );
  //   } else if (field.type.fragment == NT4TypeFragment.float64) {
  //     return (
  //       8,
  //       NTStructValue.fromDouble(
  //           data.buffer.asByteData().getFloat64(0, Endian.little))
  //     );
  //   } else if (field.type.fragment == NT4TypeFragment.string) {
  //     int length = data.buffer.asByteData().getInt32(0, Endian.little);
  //     return (
  //       length + 4,
  //       NTStructValue.fromString(
  //           String.fromCharCodes(data.sublist(4, 4 + length)))
  //     );
  //   } else if (field.type.isStruct) {
  //     NTStructSchema? substruct = field.substruct;

  //     if (substruct == null) {
  //       throw Exception('No schema found for struct: ${field.type.name}');
  //     }

  //     NTStruct sub = NTStruct(
  //       schema: substruct,
  //       data: data,
  //     );

  //     return (sub.consumed, NTStructValue.fromStruct(sub));
  //   } else {
  //     throw Exception('Unknown type: ${field.type}');
  //   }
  // }

  // static (int, NTStructValue<List<NTStructValue>>) _parseArray(
  //     NTFieldSchema field, Uint8List data, int length) {
  //   List<NTStructValue> values = [];
  //   int offset = 0;

  //   for (int i = 0; i < length; i++) {
  //     var (consumed, value) = _parseValueInner(field, data.sublist(offset));
  //     values.add(value);
  //     offset += consumed;
  //   }

  //   return (offset, NTStructValue.fromArray(values));
  // }
}
