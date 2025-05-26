import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';

/// This class is a singleton that manages the schemas of NTStructs.
/// It allows adding new schemas and retrieving existing ones by name.
/// It also provides a method to parse a schema string into a list of field schemas.
class SchemaInfo {
  static final SchemaInfo _instance = SchemaInfo._internal();
  SchemaInfo._internal();

  factory SchemaInfo.getInstance() {
    return _instance;
  }

  final Map<String, NTStructSchema> _schemas = {};
  final List<String> knownStructs = [];

  void listen(NT4Client client) {
    client.addTopicAnnounceListener((topic) {
      if (topic.type.fragment == NT4TypeFragment.structschema) {
        String name = topic.name.split("/").last.split(':')[1];
        logger.debug("Subscribing to schema topic: ${topic.name} ($name)");
        knownStructs.add(name);

        client.subscribe(topic: topic.name).listen((data, _) {
          if (data == null) return;
          String schema = String.fromCharCodes(data as List<int>);
          String key = topic.name.split("/").last;
          addStringSchema(key, schema);
        });
      }
    });
  }

  NTStructSchema? getSchema(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas[name];
  }

  void addSchema(String name, NTStructSchema schema) {
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

  void addStringSchema(String name, String schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    if (_schemas.containsKey(name)) {
      return;
    }

    NTStructSchema parsedSchema = NTStructSchema(name: name, schema: schema);

    addSchema(name, parsedSchema);
  }

  bool isStruct(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas.containsKey(name) || knownStructs.contains(name);
  }
}

/// This class represents a field schema in an NTStruct.
/// It contains the field name and its type.
/// It also provides a method to get type information for the field if it is a struct.
class NTFieldSchema {
  final String field;
  final NT4Type type;

  NTFieldSchema({
    required this.field,
    required this.type,
  });

  static NTFieldSchema fromJson(
    Map<String, dynamic> json,
  ) {
    return NTFieldSchema(
      field: json['name'] ?? json['field'],
      type: NT4Type.parse('struct:${json['type']}'),
    );
  }

  static NTFieldSchema _parseField(String name, String type) {
    NT4Type fieldType = NT4Type.parse(type);

    if (fieldType.leaf.isStruct) {
      return NTFieldSchema(
        field: name,
        type: fieldType,
      );
    } else {
      return NTFieldSchema(
        field: name,
        type: fieldType,
      );
    }
  }

  NTFieldSchema clone() {
    return NTFieldSchema(
      field: field,
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'type': type.serialize(),
    };
  }

  NTStructSchema? get substruct =>
      type.isStruct ? SchemaInfo.getInstance().getSchema(type.name!) : null;
}

/// This class represents a schema for an NTStruct.
/// It contains the name of the struct and a list of field schemas.
class NTStructSchema {
  final String name;
  final List<NTFieldSchema> fields;

  NTStructSchema({
    required this.name,
    required String schema,
  }) : fields = _tryParseSchema(name, schema);

  NTStructSchema.raw({
    required this.name,
    required this.fields,
  });

  NTFieldSchema? operator [](String key) {
    for (final field in fields) {
      if (field.field == key) {
        return field;
      }
    }

    return null;
  }

  static List<NTFieldSchema> _tryParseSchema(String name, String schema) {
    try {
      return _parseSchema(name, schema);
    } catch (ignored) {
      return [];
    }
  }

  static List<NTFieldSchema> _parseSchema(String name, String schema) {
    List<NTFieldSchema> fields = [];
    List<String> schemaParts = schema.split(';');

    for (final String part in schemaParts) {
      var [type, name] = part.split(' ');
      var field = NTFieldSchema._parseField(name, type);
      fields.add(field);
    }

    return fields;
  }

  @override
  String toString() {
    return '$name { ${fields.map((field) => '${field.field}: ${field.type.serialize()}').join(', ')} }';
  }

  NTStructSchema clone() {
    return NTStructSchema.raw(
      name: name,
      fields: fields.map((field) => field.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fields': fields.map((field) => field.toJson()).toList(),
    };
  }

  static NTStructSchema fromJson(Map<String, dynamic> json) {
    return NTStructSchema.raw(
      name: json['name'] ?? json['type'],
      fields: (tryCast<List<dynamic>>(json['fields']) ?? [])
          .map((field) => NTFieldSchema.fromJson(tryCast(field) ?? {}))
          .toList(),
    );
  }
}

typedef ArrayValue<T> = List<NTStructValue<T>>;

/// This class represents a value in an NTStruct.
/// It can be of different types, including int, bool, double, string,
/// nullable, array, or another NTStruct.
/// It provides static methods to create instances of NTStructValue
/// for each type.
class NTStructValue<T> {
  final T value;

  static NTStructValue<int> fromInt(int value) => NTStructValue._(value);

  static NTStructValue<bool> fromBool(bool value) => NTStructValue._(value);

  static NTStructValue<double> fromDouble(double value) =>
      NTStructValue._(value);

  static NTStructValue<String> fromString(String value) =>
      NTStructValue._(value);

  static NTStructValue<K?> fromNullable<K>(K? value) => NTStructValue._(value);

  static NTStructValue<ArrayValue<K>> fromArray<K>(ArrayValue<K> value) =>
      NTStructValue._(value);

  static NTStructValue<NTStruct> fromStruct(NTStruct value) =>
      NTStructValue._(value);

  NTStructValue._(this.value);
}

/// This class represents an NTStruct.
/// It contains a schema and a map of values.
/// It provides methods to parse data into NTStructValue instances
/// and to retrieve values by key.
class NTStruct {
  final NTStructSchema schema;
  late final Map<String, NTStructValue> values;
  late final int consumed;

  NTStruct({
    required this.schema,
    required Uint8List data,
  }) {
    var (consumed, values) = _parseData(schema, data);
    this.values = values;
    this.consumed = consumed;
  }

  NTStructValue? operator [](String key) {
    return values[key];
  }

  NTStructValue? get(List<String> key) {
    NTStructValue value = NTStructValue.fromStruct(this);

    for (final k in key) {
      if (value is NTStructValue<NTStruct>) {
        value = value.value[k]!;
      } else {
        return null;
      }
    }

    return value;
  }

  static (int, Map<String, NTStructValue>) _parseData(
      NTStructSchema schema, Uint8List data) {
    Map<String, NTStructValue> values = {};
    int offset = 0;

    for (final field in schema.fields) {
      var (consumed, value) = _parseValue(field, data.sublist(offset));
      values[field.field] = value;
      offset += consumed;
    }

    return (offset, values);
  }

  static (int, NTStructValue) _parseValue(NTFieldSchema field, Uint8List data) {
    if (field.type.isArray) {
      int length = data.buffer.asByteData().getInt32(0, Endian.little);
      var (consumed, value) = _parseArray(field, data.sublist(4), length);
      return (consumed + 4, value);
    } else if (field.type.isNullable) {
      bool isNull = data[0] != 0;
      if (isNull) {
        return (1, NTStructValue.fromNullable(null));
      } else {
        var (consumed, value) = _parseValueInner(field, data.sublist(1));
        return (consumed + 1, NTStructValue.fromNullable(value));
      }
    } else {
      return _parseValueInner(field, data);
    }
  }

  static (int, NTStructValue) _parseValueInner(
      NTFieldSchema field, Uint8List data) {
    if (field.type.fragment == NT4TypeFragment.boolean) {
      return (1, NTStructValue.fromBool(data[0] != 0));
    } else if (field.type.fragment == NT4TypeFragment.int32) {
      return (
        4,
        NTStructValue.fromInt(
            data.buffer.asByteData().getInt32(0, Endian.little))
      );
    } else if (field.type.fragment == NT4TypeFragment.float32) {
      return (
        4,
        NTStructValue.fromDouble(
            data.buffer.asByteData().getFloat32(0, Endian.little))
      );
    } else if (field.type.fragment == NT4TypeFragment.float64) {
      return (
        8,
        NTStructValue.fromDouble(
            data.buffer.asByteData().getFloat64(0, Endian.little))
      );
    } else if (field.type.fragment == NT4TypeFragment.string) {
      int length = data.buffer.asByteData().getInt32(0, Endian.little);
      return (
        length + 4,
        NTStructValue.fromString(
            String.fromCharCodes(data.sublist(4, 4 + length)))
      );
    } else if (field.type.isStruct) {
      NTStructSchema? substruct = field.substruct;

      if (substruct == null) {
        throw Exception('No schema found for struct: ${field.type.name}');
      }

      NTStruct sub = NTStruct(
        schema: substruct,
        data: data,
      );

      return (sub.consumed, NTStructValue.fromStruct(sub));
    } else {
      throw Exception('Unknown type: ${field.type}');
    }
  }

  static (int, NTStructValue<List<NTStructValue>>) _parseArray(
      NTFieldSchema field, Uint8List data, int length) {
    List<NTStructValue> values = [];
    int offset = 0;

    for (int i = 0; i < length; i++) {
      var (consumed, value) = _parseValueInner(field, data.sublist(offset));
      values.add(value);
      offset += consumed;
    }

    return (offset, NTStructValue.fromArray(values));
  }
}
