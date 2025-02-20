import 'dart:typed_data';

class DynStructField {
  final String name;
  final String type;
  final Object? value;

  DynStructField({required this.name, required this.type, required this.value});

  int get intValue => value as int;
  double get doubleValue => value as double;
  bool get boolValue => value as bool;
  List<Object?> get listValue => value as List<Object?>;
  DynStruct get structValue => value as DynStruct;
  Object? get nullableValue => value;
}

class DynStruct {
  final String name;
  final Map<String, DynStructField> fields;

  DynStruct(
      {required this.name,
      required Map<String, String> schemas,
      required Uint8List bytes})
      : fields = _parseSchema(name, schemas, bytes);

  DynStructField? operator [](String key) {
    return fields[key];
  }

  static Map<String, DynStructField> _parseSchema(
      String name, Map<String, String> schemas, Uint8List bytes) {
    Map<String, DynStructField> fields = {};
    List<String> schemaParts = schemas[name]!.split(';');
    int consumed = 0;

    for (final String part in schemaParts) {
      var [type, name] = part.split(' ');
      var (value, newConsumed) = _parseValue(type, bytes, schemas, consumed);
      fields[name] = DynStructField(name: name, type: type, value: value);
      consumed = newConsumed;
    }

    return fields;
  }

  static (Object?, int) _parseValue(
      String type, Uint8List bytes, Map<String, String> schemas, int offset) {
    if (type == "boolean") {
      int boolValue = bytes[offset++];
      return (boolValue == 1, offset);
    } else if (type == "int") {
      int intValue = bytes.buffer.asByteData().getInt32(offset);
      return (intValue, offset + 4);
    } else if (type == "long") {
      int longValue = bytes.buffer.asByteData().getInt64(offset);
      return (longValue, offset + 8);
    } else if (type == "float") {
      double floatValue = bytes.buffer.asByteData().getFloat32(offset);
      return (floatValue, offset + 4);
    } else if (type == "double") {
      double doubleValue = bytes.buffer.asByteData().getFloat64(offset);
      return (doubleValue, offset + 8);
    } else if (type.endsWith("?")) {
      bool isNull = bytes[offset++] == 0;
      if (isNull) return (null, offset);
      String subtype = type.substring(0, type.length - 1);
      return _parseValue(subtype, bytes, schemas, offset);
    } else if (type.endsWith("[]")) {
      int length = bytes.buffer.asByteData().getInt32(offset);
      List<Object?> list = [];
      String subtype = type.substring(0, type.length - 2);
      offset += 4;

      for (int i = 0; i < length; i++) {
        var (value, newOffset) = _parseValue(subtype, bytes, schemas, offset);
        list.add(value);
        offset = newOffset;
      }

      return (list, offset);
    } else if (schemas.containsKey('struct:$type')) {
      String structName = 'struct:$type';
      DynStruct struct = DynStruct(
          name: structName, schemas: schemas, bytes: bytes.sublist(offset));

      return (struct, offset);
    } else {
      throw Exception("Unknown type: $type");
    }
  }
}
