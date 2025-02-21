import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class DynStructField {
  final String name;
  final String type;
  final bool isArray;
  final bool isNullable;

  final DynStructSchema? substruct;

  DynStructField({
    required this.name,
    required this.type,
    this.isArray = false,
    this.isNullable = false,
    this.substruct,
  });

  static DynStructField _parseField(
      String name, String type, Map<String, String> schemas) {
    if (type == "boolean") {
      return DynStructField(name: name, type: type);
    } else if (type == "int") {
      return DynStructField(name: name, type: type);
    } else if (type == "long") {
      return DynStructField(name: name, type: type);
    } else if (type == "float") {
      return DynStructField(name: name, type: type);
    } else if (type == "double") {
      return DynStructField(name: name, type: type);
    } else if (type.endsWith("?")) {
      String subtype = type.substring(0, type.length - 1);
      return DynStructField(
        name: name,
        type: subtype,
        isNullable: true,
      );
    } else if (type.endsWith("[]")) {
      String subtype = type.substring(0, type.length - 2);
      return DynStructField(
        name: name,
        type: subtype,
        isArray: true,
      );
    } else if (type == "string") {
      return DynStructField(name: name, type: "string");
    } else if (schemas.containsKey('struct:$type')) {
      return DynStructField(
        name: name,
        type: type,
        substruct: DynStructSchema(
          type: 'struct:$type',
          schemas: schemas,
        ),
      );
    } else {
      throw Exception("Unknown type: $type");
    }
  }

  DynStructField clone() {
    return DynStructField(
      name: name,
      type: type,
      isArray: isArray,
      isNullable: isNullable,
      substruct: substruct?.clone(),
    );
  }
}

class DynStructSchema {
  final String type;
  final List<DynStructField> fields;

  DynStructSchema({
    required this.type,
    required Map<String, String> schemas,
  }) : fields = _parseSchema(type, schemas);

  DynStructSchema.raw({
    required this.type,
    required this.fields,
  });

  DynStructField? operator [](String key) {
    for (final field in fields) {
      if (field.name == key) {
        return field;
      }
    }

    return null;
  }

  static List<DynStructField> _parseSchema(
      String name, Map<String, String> schemas) {
    List<DynStructField> fields = [];
    List<String>? schemaParts = schemas[name]?.split(';');

    if (schemaParts == null) {
      throw Exception("Schema not found: $name");
    }

    for (final String part in schemaParts) {
      var [type, name] = part.split(' ');
      var field = DynStructField._parseField(name, type, schemas);
      fields.add(field);
    }

    return fields;
  }

  @override
  String toString() {
    return fields.map((field) => "${field.name}: ${field.type}").join(", ");
  }

  DynStructSchema clone() {
    return DynStructSchema.raw(
      type: type,
      fields: fields.map((field) => field.clone()).toList(),
    );
  }
}

sealed class DynStructValue {
  get boolValue => (this as DynStructBoolean).value;
  get intValue => (this as DynStructInt).value;
  get longValue => (this as DynStructLong).value;
  get floatValue => (this as DynStructFloat).value;
  get doubleValue => (this as DynStructDouble).value;
  get stringValue => (this as DynStructString).value;
  get nullableValue => (this as DynStructNullable).value;
  get arrayValue => (this as DynStructArray).value;
  get structValue => (this as DynStructStruct).value;
}

class DynStructBoolean extends DynStructValue {
  final bool value;

  DynStructBoolean(this.value);
}

class DynStructInt extends DynStructValue {
  final int value;

  DynStructInt(this.value);
}

class DynStructLong extends DynStructValue {
  final int value;

  DynStructLong(this.value);
}

class DynStructFloat extends DynStructValue {
  final double value;

  DynStructFloat(this.value);
}

class DynStructDouble extends DynStructValue {
  final double value;

  DynStructDouble(this.value);
}

class DynStructString extends DynStructValue {
  final String value;

  DynStructString(this.value);
}

class DynStructNullable extends DynStructValue {
  final DynStructValue? value;

  DynStructNullable(this.value);
}

class DynStructArray extends DynStructValue {
  final List<DynStructValue> value;

  DynStructArray(this.value);
}

class DynStructStruct extends DynStructValue {
  final DynStruct value;

  DynStructStruct(this.value);
}

class DynStruct {
  final DynStructSchema schema;
  late final Map<String, DynStructValue> values;
  late final int consumed;

  DynStruct({
    required this.schema,
    required Uint8List data,
  }) {
    var (consumed, values) = _parseData(schema, data);
    this.values = values;
    this.consumed = consumed;
  }

  DynStructValue? operator [](String key) {
    return values[key];
  }

  static (int, Map<String, DynStructValue>) _parseData(
      DynStructSchema schema, Uint8List data) {
    Map<String, DynStructValue> values = {};
    int offset = 0;

    for (final field in schema.fields) {
      var (consumed, value) = _parseValue(field, data.sublist(offset));
      values[field.name] = value;
      offset += consumed;
    }

    return (offset, values);
  }

  static (int, DynStructValue) _parseValue(
      DynStructField field, Uint8List data) {
    if (field.isArray) {
      int length = data.buffer.asByteData().getInt32(0);
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

  static (int, DynStructValue) _parseValueInner(
      DynStructField field, Uint8List data) {
    if (field.type == "boolean") {
      return (1, DynStructBoolean(data[0] != 0));
    } else if (field.type == "int") {
      return (4, DynStructInt(data.buffer.asByteData().getInt32(0)));
    } else if (field.type == "long") {
      return (8, DynStructLong(data.buffer.asByteData().getInt64(0)));
    } else if (field.type == "float") {
      return (4, DynStructFloat(data.buffer.asByteData().getFloat32(0)));
    } else if (field.type == "double") {
      return (8, DynStructDouble(data.buffer.asByteData().getFloat64(0)));
    } else if (field.type == "string") {
      int length = data.buffer.asByteData().getInt32(0);
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
      DynStructField field, Uint8List data, int length) {
    List<DynStructValue> values = [];
    int offset = 0;

    for (int i = 0; i < length; i++) {
      var (consumed, value) = _parseValueInner(field, data.sublist(offset));
      values.add(value);
      offset += consumed;
    }

    return (offset, DynStructArray(values));
  }
}
