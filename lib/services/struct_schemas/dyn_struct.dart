import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:dot_cast/dot_cast.dart';

class DynamicStructField {
  final String name;
  final String type;
  final bool isArray;
  final bool isNullable;

  final DynamicStructSchema? substruct;

  DynamicStructField({
    required this.name,
    required this.type,
    this.isArray = false,
    this.isNullable = false,
    this.substruct,
  });

  static DynamicStructField fromJson(
    Map<String, dynamic> json,
  ) {
    return DynamicStructField(
      name: json['name'],
      type: json['type'],
      isArray: json['isArray'],
      isNullable: json['isNullable'],
      substruct: json['substruct'] != null
          ? DynamicStructSchema.fromJson(tryCast(json['substruct']) ?? {})
          : null,
    );
  }

  static DynamicStructField _parseField(
      String name, String type, Map<String, String> schemas) {
    if (type == "boolean") {
      return DynamicStructField(name: name, type: type);
    } else if (type == "int") {
      return DynamicStructField(name: name, type: type);
    } else if (type == "long") {
      return DynamicStructField(name: name, type: type);
    } else if (type == "float") {
      return DynamicStructField(name: name, type: type);
    } else if (type == "double") {
      return DynamicStructField(name: name, type: type);
    } else if (type.endsWith("?")) {
      String subtype = type.substring(0, type.length - 1);
      return DynamicStructField(
        name: name,
        type: subtype,
        isNullable: true,
      );
    } else if (type.endsWith("[]")) {
      String subtype = type.substring(0, type.length - 2);
      return DynamicStructField(
        name: name,
        type: subtype,
        isArray: true,
      );
    } else if (type == "string") {
      return DynamicStructField(name: name, type: "string");
    } else if (schemas.containsKey('struct:$type')) {
      return DynamicStructField(
        name: name,
        type: type,
        substruct: DynamicStructSchema(
          type: 'struct:$type',
          schemas: schemas,
        ),
      );
    } else {
      throw Exception("Unknown type: $type");
    }
  }

  DynamicStructField clone() {
    return DynamicStructField(
      name: name,
      type: type,
      isArray: isArray,
      isNullable: isNullable,
      substruct: substruct?.clone(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'isArray': isArray,
      'isNullable': isNullable,
      'substruct': substruct?.toJson(),
    };
  }
}

class DynamicStructSchema {
  final String type;
  final List<DynamicStructField> fields;

  DynamicStructSchema({
    required this.type,
    required Map<String, String> schemas,
  }) : fields = _tryParseSchema(type, schemas);

  DynamicStructSchema.raw({
    required this.type,
    required this.fields,
  });

  DynamicStructField? operator [](String key) {
    for (final field in fields) {
      if (field.name == key) {
        return field;
      }
    }

    return null;
  }

  static List<DynamicStructField> _tryParseSchema(
      String name, Map<String, String> schemas) {
    try {
      return _parseSchema(name, schemas);
    } catch (ignored) {
      return [];
    }
  }

  static List<DynamicStructField> _parseSchema(
      String name, Map<String, String> schemas) {
    List<DynamicStructField> fields = [];
    List<String>? schemaParts = schemas[name]?.split(';');

    if (schemaParts == null) {
      throw Exception("Schema not found: $name");
    }

    for (final String part in schemaParts) {
      var [type, name] = part.split(' ');
      var field = DynamicStructField._parseField(name, type, schemas);
      fields.add(field);
    }

    return fields;
  }

  @override
  String toString() {
    return fields.map((field) => "${field.name}: ${field.type}").join(", ");
  }

  DynamicStructSchema clone() {
    return DynamicStructSchema.raw(
      type: type,
      fields: fields.map((field) => field.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'fields': fields.map((field) => field.toJson()).toList(),
    };
  }

  static DynamicStructSchema fromJson(Map<String, dynamic> json) {
    return DynamicStructSchema.raw(
      type: json['type'],
      fields: (tryCast<List<dynamic>>(json['fields']) ?? [])
          .map((field) => DynamicStructField.fromJson(tryCast(field) ?? {}))
          .toList(),
    );
  }
}

sealed class DynamicStructValue {
  final Object? anyValue;

  DynamicStructValue({required this.anyValue});

  bool get boolValue => (this as DynStructBoolean).value;
  int get intValue => (this as DynStructInt).value;
  int get longValue => (this as DynStructLong).value;
  double get floatValue => (this as DynStructFloat).value;
  double get doubleValue => (this as DynStructDouble).value;
  String get stringValue => (this as DynStructString).value;
  DynamicStructValue? get nullableValue => (this as DynStructNullable).value;
  List<DynamicStructValue> get arrayValue => (this as DynStructArray).value;
  DynStruct get structValue => (this as DynStructStruct).value;
}

class DynStructBoolean extends DynamicStructValue {
  final bool value;

  DynStructBoolean(this.value) : super(anyValue: value);
}

class DynStructInt extends DynamicStructValue {
  final int value;

  DynStructInt(this.value) : super(anyValue: value);
}

class DynStructLong extends DynamicStructValue {
  final int value;

  DynStructLong(this.value) : super(anyValue: value);
}

class DynStructFloat extends DynamicStructValue {
  final double value;

  DynStructFloat(this.value) : super(anyValue: value);
}

class DynStructDouble extends DynamicStructValue {
  final double value;

  DynStructDouble(this.value) : super(anyValue: value);
}

class DynStructString extends DynamicStructValue {
  final String value;

  DynStructString(this.value) : super(anyValue: value);
}

class DynStructNullable extends DynamicStructValue {
  final DynamicStructValue? value;

  DynStructNullable(this.value) : super(anyValue: value);
}

class DynStructArray extends DynamicStructValue {
  final List<DynamicStructValue> value;

  DynStructArray(this.value) : super(anyValue: value);
}

class DynStructStruct extends DynamicStructValue {
  final DynStruct value;

  DynStructStruct(this.value) : super(anyValue: value);
}

class DynStruct {
  final DynamicStructSchema schema;
  late final Map<String, DynamicStructValue> values;
  late final int consumed;

  DynStruct({
    required this.schema,
    required Uint8List data,
  }) {
    var (consumed, values) = _parseData(schema, data);
    this.values = values;
    this.consumed = consumed;
  }

  DynamicStructValue? operator [](String key) {
    return values[key];
  }

  DynamicStructValue? get(List<String> key) {
    DynamicStructValue value = DynStructStruct(this);

    for (final k in key) {
      if (value is DynStructStruct) {
        value = value.structValue[k]!;
      } else {
        return null;
      }
    }

    return value;
  }

  static (int, Map<String, DynamicStructValue>) _parseData(
      DynamicStructSchema schema, Uint8List data) {
    Map<String, DynamicStructValue> values = {};
    int offset = 0;

    for (final field in schema.fields) {
      var (consumed, value) = _parseValue(field, data.sublist(offset));
      values[field.name] = value;
      offset += consumed;
    }

    return (offset, values);
  }

  static (int, DynamicStructValue) _parseValue(
      DynamicStructField field, Uint8List data) {
    if (field.isArray) {
      int length = data.buffer.asByteData().getInt32(0, Endian.little);
      var (consumed, value) = _parseArray(field, data.sublist(4), length);
      return (consumed + 4, value);
    } else if (field.isNullable) {
      bool isNull = data[0] != 0;
      if (isNull) {
        return (1, DynStructNullable(null));
      } else {
        var (consumed, value) = _parseValueInner(field, data.sublist(1));
        return (consumed + 1, DynStructNullable(value));
      }
    } else {
      return _parseValueInner(field, data);
    }
  }

  static (int, DynamicStructValue) _parseValueInner(
      DynamicStructField field, Uint8List data) {
    if (field.type == "boolean") {
      return (1, DynStructBoolean(data[0] != 0));
    } else if (field.type == "int") {
      return (
        4,
        DynStructInt(data.buffer.asByteData().getInt32(0, Endian.little))
      );
    } else if (field.type == "long") {
      return (
        8,
        DynStructLong(data.buffer.asByteData().getInt64(0, Endian.little))
      );
    } else if (field.type == "float") {
      return (
        4,
        DynStructFloat(data.buffer.asByteData().getFloat32(0, Endian.little))
      );
    } else if (field.type == "double") {
      return (
        8,
        DynStructDouble(data.buffer.asByteData().getFloat64(0, Endian.little))
      );
    } else if (field.type == "string") {
      int length = data.buffer.asByteData().getInt32(0, Endian.little);
      return (
        length + 4,
        DynStructString(String.fromCharCodes(data.sublist(4, 4 + length)))
      );
    } else if (field.substruct != null) {
      DynStruct sub = DynStruct(
        schema: field.substruct!,
        data: data,
      );

      return (sub.consumed, DynStructStruct(sub));
    } else {
      throw Exception("Unknown type: ${field.type}");
    }
  }

  static (int, DynStructArray) _parseArray(
      DynamicStructField field, Uint8List data, int length) {
    List<DynamicStructValue> values = [];
    int offset = 0;

    for (int i = 0; i < length; i++) {
      var (consumed, value) = _parseValueInner(field, data.sublist(offset));
      values.add(value);
      offset += consumed;
    }

    return (offset, DynStructArray(values));
  }
}
