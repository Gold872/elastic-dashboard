import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

/// This class represents the different types of NT4 data.
/// It may not contain the whole type in itself (e.g. array, nullable)
enum NT4TypeFragment {
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

  array,
  nullable,
  unknown; // i.e. published a type that is not parsable by NT4Type.

  // i.e. "should this be displayable in a widget?"
  bool get isViewable => {
        NT4TypeFragment.boolean,
        NT4TypeFragment.int32,
        NT4TypeFragment.float32,
        NT4TypeFragment.float64,
        NT4TypeFragment.string,
      }.contains(this); // handle crazy types like int?[][]? idk

  bool get isNumber => {
        NT4TypeFragment.int32,
        NT4TypeFragment.float32,
        NT4TypeFragment.float64,
      }.contains(this);
}

/// This class represents a type in NT4.
/// It can be a primitive type, an array, or a nullable type.
/// It can also represent a struct type with a name.
class NT4Type {
  final NT4TypeFragment fragment;
  final NT4Type? tail;

  /// Only available if this is a struct type, or cannot be parsed.
  final String? name;

  NT4Type({required this.fragment, this.tail, this.name});

  factory NT4Type.boolean() {
    return NT4Type(fragment: NT4TypeFragment.boolean);
  }

  factory NT4Type.int() {
    return NT4Type(fragment: NT4TypeFragment.int32);
  }

  factory NT4Type.float() {
    return NT4Type(fragment: NT4TypeFragment.float32);
  }

  factory NT4Type.double() {
    return NT4Type(fragment: NT4TypeFragment.float64);
  }

  factory NT4Type.string() {
    return NT4Type(fragment: NT4TypeFragment.string);
  }

  factory NT4Type.json() {
    return NT4Type(fragment: NT4TypeFragment.json);
  }

  factory NT4Type.raw() {
    return NT4Type(fragment: NT4TypeFragment.raw);
  }

  factory NT4Type.rpc() {
    return NT4Type(fragment: NT4TypeFragment.rpc);
  }

  factory NT4Type.msgpack() {
    return NT4Type(fragment: NT4TypeFragment.msgpack);
  }

  factory NT4Type.protobuf() {
    return NT4Type(fragment: NT4TypeFragment.protobuf);
  }

  factory NT4Type.structschema() {
    return NT4Type(fragment: NT4TypeFragment.structschema);
  }

  factory NT4Type.unknown(String type) {
    return NT4Type(fragment: NT4TypeFragment.unknown, name: type);
  }

  factory NT4Type.struct(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return NT4Type(
      fragment: NT4TypeFragment.raw, // structs are considered raw bytes in NT4
      name: name,
    );
  }

  factory NT4Type.array(NT4Type subType) {
    return NT4Type(fragment: NT4TypeFragment.array, tail: subType);
  }

  factory NT4Type.nullable(NT4Type subType) {
    return NT4Type(fragment: NT4TypeFragment.nullable, tail: subType);
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

  static NT4Type parse(String type) {
    if (_constructorMap.containsKey(type)) {
      return _constructorMap[type]!();
    } else if (type.endsWith('[]')) {
      String subType = type.substring(0, type.length - 2);
      NT4Type sub = parse(subType);
      return NT4Type.array(sub);
    } else if (type.endsWith('?')) {
      String subType = type.substring(0, type.length - 1);
      NT4Type sub = parse(subType);
      return NT4Type.nullable(sub);
    } else if (type.startsWith('struct:') ||
        SchemaInfo.getInstance().isStruct(type)) {
      return NT4Type.struct(type);
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

    switch (fragment) {
      case NT4TypeFragment.nullable:
        if (str.isEmpty || str == 'null') {
          return null;
        } else {
          return tail!.convertString(str);
        }
      case NT4TypeFragment.boolean:
        return bool.tryParse(str);
      case NT4TypeFragment.int32:
        return int.tryParse(str);
      case NT4TypeFragment.float32:
      case NT4TypeFragment.float64:
        return double.tryParse(str);
      case NT4TypeFragment.string:
        return str;
      case NT4TypeFragment.array:
        if (str.startsWith('[')) {
          str = str.substring(1, str.length - 1);
        }

        if (str.isEmpty) {
          return [];
        } else {
          List<String> items = str.split(',');
          return items.map((e) => tail!.convertString(e.trim())).toList();
        }
      default:
        return null; // structs and other types are not viewable
    }
  }

  bool get isArray => fragment == NT4TypeFragment.array;
  bool get isNullable => fragment == NT4TypeFragment.nullable;
  bool get isStruct => name != null;
  bool get isLeaf => tail == null;
  bool get isViewable => leaf.fragment.isViewable;
  NT4Type get leaf => tail?.leaf ?? this;
  NT4Type get nonNullable => isNullable ? tail!.nonNullable : this;

  String serialize() {
    if (isStruct) {
      return 'struct:$name';
    }

    return switch (fragment) {
      NT4TypeFragment.boolean => 'boolean',
      NT4TypeFragment.int32 => 'int',
      NT4TypeFragment.float32 => 'float',
      NT4TypeFragment.float64 => 'double',
      NT4TypeFragment.string => 'string',
      NT4TypeFragment.json => 'json',
      NT4TypeFragment.raw => 'raw',
      NT4TypeFragment.rpc => 'rpc',
      NT4TypeFragment.msgpack => 'msgpack',
      NT4TypeFragment.protobuf => 'protobuf',
      NT4TypeFragment.structschema => 'structschema',
      NT4TypeFragment.array => '${tail!.serialize()}[]',
      NT4TypeFragment.nullable => '${tail!.serialize()}?',
      NT4TypeFragment.unknown => name ?? 'raw',
    };
  }

  int get typeId {
    return switch (fragment) {
      NT4TypeFragment.boolean => 0,
      NT4TypeFragment.float64 => 1,
      NT4TypeFragment.int32 => 2,
      NT4TypeFragment.float32 => 3,
      NT4TypeFragment.string || NT4TypeFragment.json => 4,
      NT4TypeFragment.raw ||
      NT4TypeFragment.rpc ||
      NT4TypeFragment.msgpack ||
      NT4TypeFragment.protobuf ||
      NT4TypeFragment.structschema ||
      NT4TypeFragment.unknown =>
        5,
      NT4TypeFragment.array => 16 + tail!.typeId,
      NT4TypeFragment.nullable => tail!.typeId,
    };
  }

  @override
  String toString() {
    return 'NT4Type(${serialize()})';
  }
}
