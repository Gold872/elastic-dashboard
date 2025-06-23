import 'dart:convert';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/log.dart';

/// This class represents the different types of NT4 data.
/// It may not contain the whole type in itself (e.g. array, nullable)
enum NT4DataType {
  boolean,
  int32,
  float32,
  float64,
  string,

  json,
  raw,
  rpc,
  msgpack,
  protobuf,
  structschema,

  unknown; // published type that is not parsable;

  // i.e. "should this be displayable in a widget?"
  bool get isViewable => {
    NT4DataType.boolean,
    NT4DataType.int32,
    NT4DataType.float32,
    NT4DataType.float64,
    NT4DataType.string,
  }.contains(this); // handle crazy types like int?[][]? idk

  bool get isNumber => {
    NT4DataType.int32,
    NT4DataType.float32,
    NT4DataType.float64,
  }.contains(this);

  bool get isBinary => {
    NT4DataType.raw,
    NT4DataType.rpc,
    NT4DataType.msgpack,
    NT4DataType.protobuf,
    NT4DataType.structschema,
  }.contains(this);
}

enum NT4TypeModifier { array, struct, structarray, normal }

/// This class represents a type in NT4.
/// It can be a primitive type, an array, or a struct type.
/// It can also represent a struct type with a name.
class NT4Type {
  final NT4DataType dataType;
  final NT4TypeModifier modifier;

  /// The "display name" of the type
  ///
  /// In most cases, this will be the exact same as the data type, but
  /// in some cases it could be a display name alias. For instance, enum
  /// values in a struct use a display name "enum" when it's an underlying string
  final String name;

  NT4Type({
    required this.dataType,
    required this.name,
    this.modifier = NT4TypeModifier.normal,
  });

  factory NT4Type.boolean() {
    return NT4Type(dataType: NT4DataType.boolean, name: 'boolean');
  }

  factory NT4Type.int() {
    return NT4Type(dataType: NT4DataType.int32, name: 'int');
  }

  factory NT4Type.float() {
    return NT4Type(dataType: NT4DataType.float32, name: 'float');
  }

  factory NT4Type.double() {
    return NT4Type(dataType: NT4DataType.float64, name: 'double');
  }

  factory NT4Type.string() {
    return NT4Type(dataType: NT4DataType.string, name: 'string');
  }

  factory NT4Type.json() {
    return NT4Type(dataType: NT4DataType.json, name: 'json');
  }

  factory NT4Type.raw() {
    return NT4Type(dataType: NT4DataType.raw, name: 'raw');
  }

  factory NT4Type.rpc() {
    return NT4Type(dataType: NT4DataType.rpc, name: 'rpc');
  }

  factory NT4Type.msgpack() {
    return NT4Type(dataType: NT4DataType.msgpack, name: 'msgpack');
  }

  factory NT4Type.protobuf() {
    return NT4Type(dataType: NT4DataType.protobuf, name: 'protobuf');
  }

  factory NT4Type.structschema() {
    return NT4Type(dataType: NT4DataType.structschema, name: 'structschema');
  }

  factory NT4Type.unknown(String type) {
    return NT4Type(dataType: NT4DataType.unknown, name: type);
  }

  factory NT4Type.struct(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    NT4TypeModifier modifier = NT4TypeModifier.struct;

    if (name.contains('[]')) {
      modifier = NT4TypeModifier.structarray;
      name = name.substring(0, name.indexOf('[]'));
    }

    return NT4Type(
      dataType: NT4DataType.raw, // structs are considered raw bytes in NT4
      modifier: modifier,
      name: name,
    );
  }

  factory NT4Type.structArray(String name) {
    return NT4Type.array(NT4Type.struct(name));
  }

  factory NT4Type.array(NT4Type subType) {
    if (subType.dataType.isBinary && !subType.isStruct) {
      return subType;
    }

    if (subType.isArray) {
      return subType;
    }

    return NT4Type(
      dataType: subType.dataType,
      modifier: subType.isStruct
          ? NT4TypeModifier.structarray
          : NT4TypeModifier.array,
      name: subType.name,
    );
  }

  static final Map<String, NT4Type Function()> _constructorMap = {
    'boolean': NT4Type.boolean,
    'int': NT4Type.int,
    'float': NT4Type.float,
    'double': NT4Type.double,
    'string': NT4Type.string,
    'json': NT4Type.json,
    'raw': NT4Type.raw,
    'rpc': NT4Type.rpc,
    'msgpack': NT4Type.msgpack,
    'protobuf': NT4Type.protobuf,
    'structschema': NT4Type.structschema,
  };

  static NT4Type? parseNullable(String? type) {
    if (type == null) {
      return null;
    }
    return parse(type);
  }

  static NT4Type parse(String type) {
    if (_constructorMap.containsKey(type)) {
      return _constructorMap[type]!();
    } else if (type.startsWith('struct:')) {
      return NT4Type.struct(type);
    } else if (type.endsWith('[]')) {
      String subType = type.substring(0, type.length - 2);
      NT4Type sub = parse(subType);
      return NT4Type.array(sub);
    } else if (type == 'enum') {
      // Enum is a string alias for enum types in a struct
      return NT4Type(dataType: NT4DataType.string, name: 'enum');
    } else {
      logger.debug('Could not parse type $type, falling back to String');
      return NT4Type.unknown(type);
    }
  }

  /// Parse the string to whatever type this is
  /// i.e. if this.fragment == bool, then parseStr("true") returns `true`, etc.
  /// this will not deserialize structs. this only works if isViewable is true
  dynamic convertString(String str) {
    if (!isViewable) return null;

    if (modifier == NT4TypeModifier.array) {
      final dynamicList = tryCast<List<dynamic>>(jsonDecode(str));
      return switch (dataType) {
        NT4DataType.boolean => dynamicList?.whereType<bool>().toList(),
        NT4DataType.float32 ||
        NT4DataType.float64 => dynamicList?.whereType<num>().toList(),
        NT4DataType.int32 =>
          dynamicList?.whereType<num>().map((e) => e.toInt()).toList(),
        NT4DataType.string => dynamicList?.whereType<String>().toList(),
        _ => null,
      };
    }

    switch (dataType) {
      case NT4DataType.boolean:
        return bool.tryParse(str);
      case NT4DataType.int32:
        return int.tryParse(str);
      case NT4DataType.float32:
      case NT4DataType.float64:
        return double.tryParse(str);
      case NT4DataType.string:
        return str;
      default:
        return null; // structs and other types are not viewable
    }
  }

  bool get isArray =>
      modifier == NT4TypeModifier.array ||
      modifier == NT4TypeModifier.structarray;
  bool get isStruct =>
      modifier == NT4TypeModifier.struct ||
      modifier == NT4TypeModifier.structarray;

  bool get isViewable => dataType.isViewable;

  String serialize() {
    if (modifier == NT4TypeModifier.struct) {
      return 'struct:$name';
    } else if (modifier == NT4TypeModifier.structarray) {
      return 'struct:$name[]';
    }

    if (modifier == NT4TypeModifier.array) {
      return '$name[]';
    }
    return name;
  }

  int get typeId {
    if (modifier == NT4TypeModifier.array) {
      return switch (dataType) {
        NT4DataType.boolean => 16,
        NT4DataType.float64 => 17,
        NT4DataType.int32 => 18,
        NT4DataType.float32 => 19,
        NT4DataType.string => 20,
        _ => 5,
      };
    }

    return switch (dataType) {
      NT4DataType.boolean => 0,
      NT4DataType.float64 => 1,
      NT4DataType.int32 => 2,
      NT4DataType.float32 => 3,
      NT4DataType.string || NT4DataType.json => 4,
      NT4DataType.raw ||
      NT4DataType.rpc ||
      NT4DataType.msgpack ||
      NT4DataType.protobuf ||
      NT4DataType.structschema ||
      NT4DataType.unknown => 5,
    };
  }

  @override
  String toString() {
    return 'NT4Type(${serialize()})';
  }

  @override
  bool operator ==(Object other) {
    return other is NT4Type &&
        dataType == other.dataType &&
        modifier == other.modifier &&
        name == other.name;
  }

  @override
  int get hashCode => Object.hashAll([dataType, modifier, name]);
}
