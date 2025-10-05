import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';

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
  SchemaParseException([Object? message]);
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

  /// Processes a new schema from raw bytes and adds it into the list of known structs
  ///
  /// If processing this schema results in a new schema being updated, it will return
  /// true. Calling this method can result in 1 or more schemas being compiled, due to
  /// some schemas depending on others
  bool processNewSchema(String name, List<int> rawData) {
    String schema = utf8.decode(rawData);
    if (name.contains(':')) {
      name = name.split(':').last;
    }

    _uncompiledSchemas[name] = schema;

    bool compiledAny = false;

    while (_uncompiledSchemas.isNotEmpty) {
      bool compiled = false;

      List<String> newlyCompiled = [];

      for (final uncompiled in _uncompiledSchemas.entries) {
        if (!_schemas.containsKey(uncompiled.key)) {
          bool success = _addStringSchema(uncompiled.key, uncompiled.value);
          if (success) {
            newlyCompiled.add(uncompiled.key);
            compiledAny = true;
          }
          compiled = compiled || success;
        }
      }

      _uncompiledSchemas.removeWhere((k, v) => newlyCompiled.contains(k));

      if (!compiled) {
        break;
      }
    }

    return compiledAny;
  }

  void _addSchema(String name, NTStructSchema schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    if (_schemas.containsKey(name)) {
      return;
    }

    logger.debug('Adding schema: $name, $schema');

    _schemas[name] = schema;
  }

  /// Parses and adds a schema from a String, returns whether or not
  /// the schema was successfully parsed
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

  static StructValueType parse(String type) =>
      StructValueType.values.firstWhereOrNull((e) => e.name == type) ??
      StructValueType.struct;

  /// The [NT4Type] equivalent of the struct type
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
    StructValueType.uint64 => NT4Type.int(),
    StructValueType.float ||
    StructValueType.float32 ||
    StructValueType.double ||
    StructValueType.float64 => NT4Type.double(),
    StructValueType.struct => NT4Type.struct(name),
  };

  @override
  String toString() => name;
}

/// Data representing a field schema in an NTStruct
///
/// Contains the information needed to decode the data for a specific
/// field from the full bytes of a struct.
class NTFieldSchema {
  final String fieldName;
  final String type;
  final NTStructSchema? subSchema;
  final int bitLength;
  final int? arrayLength;
  final Map<int, String>? enumData;
  final (int start, int end) bitRange;

  StructValueType get valueType => StructValueType.parse(type);

  NT4Type get ntType {
    NT4Type innerType = valueType != StructValueType.struct
        ? valueType.ntType
        : NT4Type.struct(type);

    // If there's an enum map, use the string alias for an enum type
    if (enumData != null) {
      innerType = NT4Type(dataType: NT4DataType.string, name: 'enum');
    }

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
    this.enumData,
    required this.bitRange,
  });

  factory NTFieldSchema.parse({
    required int start,
    required String schemaString,
    required Map<String, NTStructSchema> knownSchemas,
  }) {
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

      enumString.split(',').where((e) => e.isNotEmpty).forEach((pairString) {
        List<String> pair = pairString.split('=');

        if (pair.length == 2 && !int.parse(pair[1]).isNaN) {
          enumData![int.parse(pair[1])] = pair[0];
        }
      });

      schemaString = schemaString.substring(enumEnd + 1).trim();
    }

    var [type, definition] = [
      schemaString.substring(0, schemaString.indexOf(' ')),
      schemaString.substring(schemaString.indexOf(' ') + 1),
    ];

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
      enumData: enumData,
      bitLength: bitLength,
    );
  }

  Object? toValue(Uint8List data) {
    final view = data.buffer.asByteData();
    final Object? value = switch (valueType) {
      StructValueType.bool => view.getUint8(0) > 0,
      StructValueType.char => utf8.decode(data),
      StructValueType.int8 => view.getInt8(0),
      StructValueType.int16 => view.getInt16(0, Endian.little),
      StructValueType.int32 => view.getInt32(0, Endian.little),
      StructValueType.int64 => view.getInt64Web(0, Endian.little),
      StructValueType.uint8 => view.getUint8(0),
      StructValueType.uint16 => view.getUint16(0, Endian.little),
      StructValueType.uint32 => view.getUint32(0, Endian.little),
      StructValueType.uint64 => view.getUint64Web(0, Endian.little),
      StructValueType.float ||
      StructValueType.float32 => view.getFloat32(0, Endian.little),
      StructValueType.double ||
      StructValueType.float64 => view.getFloat64(0, Endian.little),
      StructValueType.struct => () {
        if (subSchema == null) {
          return null;
        }
        return NTStruct.parse(schema: subSchema!, data: data);
      }(),
    };

    // We assume all enum values being published are mapped, if they are not
    // then we'll display it as an "unknown" string
    if (value != null && enumData != null) {
      return enumData![value] ?? 'Unknown ($value)';
    }
    return value;
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

      NTFieldSchema field = NTFieldSchema.parse(
        start: bitStart,
        schemaString: part,
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
  String toString() =>
      '$name { ${fields.map((field) => '${field.fieldName}: ${field.type}').join(', ')} }';
}

/// This class represents an NTStruct.
/// It contains a schema and a map of values.
/// It provides methods to parse data into NTStructValue instances
/// and to retrieve values by key.
class NTStruct {
  final NTStructSchema schema;
  final Map<String, Object?> values;

  NTStruct({required this.schema, required this.values});

  factory NTStruct.parse({
    required NTStructSchema schema,
    required Uint8List data,
  }) {
    List<bool> dataBitArray = data.toBitArray();

    Map<String, Object?> values = {};

    for (final field in schema.fields) {
      if (field.bitRange.$2 > dataBitArray.length) break;
      if (field.isArray) {
        List<Object?> value = [];

        int itemLength =
            (field.bitRange.$2 - field.bitRange.$1) ~/ field.arrayLength!;

        for (
          int position = field.bitRange.$1;
          position < dataBitArray.length;
          position += itemLength
        ) {
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

  dynamic operator [](String key) => values[key];

  Object? get(List<String> key) {
    Object? value = this;

    for (final k in key) {
      // Path should only be advancing through sub-structs
      // If the path is trying to point beyond a non-struct, return null
      // since it would be invalid
      if (value is NTStruct) {
        value = value[k];
      } else {
        return null;
      }
    }

    return value;
  }
}
