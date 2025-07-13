import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

String testSchema1 = 'float32 vx;float32 vy;float32 omega';

String testSchema2 = '''
float32 vx;
float32 vy;
float32 omega;
''';

String schemaWithBitLengths = 'int32 one : 2;';

void main() {
  group('[Schema Parsing]:', () {
    test('Schema with 3 floats', () {
      final schema = NTStructSchema.parse(
        name: 'ChassisSpeeds',
        schema: testSchema1,
      );

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type.toString(), 'float32');
      expect(schema.fields[0].fieldName, 'vx');
      expect(schema.fields[0].subSchema, isNull);

      expect(schema.fields[1].type.toString(), 'float32');
      expect(schema.fields[1].fieldName, 'vy');
      expect(schema.fields[1].subSchema, isNull);

      expect(schema.fields[2].type.toString(), 'float32');
      expect(schema.fields[2].fieldName, 'omega');
      expect(schema.fields[2].subSchema, isNull);
    });

    test('Schema with new lines', () {
      final schema = NTStructSchema.parse(
        name: 'ChassisSpeeds',
        schema: testSchema2,
      );

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type, 'float32');
      expect(schema.fields[0].fieldName, 'vx');
      expect(schema.fields[0].subSchema, isNull);

      expect(schema.fields[1].type, 'float32');
      expect(schema.fields[1].fieldName, 'vy');
      expect(schema.fields[1].subSchema, isNull);

      expect(schema.fields[2].type, 'float32');
      expect(schema.fields[2].fieldName, 'omega');
      expect(schema.fields[2].subSchema, isNull);
    });

    test('Schema with custom bit length', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema: schemaWithBitLengths,
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].type, 'int32');
      expect(schema.fields[0].valueType, StructValueType.int32);
      expect(schema.fields[0].fieldName, 'one');
      expect(schema.fields[0].subSchema, isNull);
      expect(schema.fields[0].bitLength, 2);
    });

    test('Schema with array', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema: 'int32 one[3];',
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].fieldName, 'one');
      expect(schema.fields[0].type, 'int32');
      expect(schema.fields[0].isArray, true);
      expect(schema.fields[0].arrayLength, 3);
    });

    group('Error Handling:', () {
      test('Unknown sub-schemas', () {
        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'SubSchema subType;',
          ),
          throwsException,
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'int32 one; SubSchema subType;',
          ),
          throwsException,
        );
      });

      test('Invalid data types', () {
        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'invalid one;',
          ),
          throwsA(isA<SchemaParseException>()),
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'long one;',
          ),
          throwsA(isA<SchemaParseException>()),
        );
      });

      test('Syntax errors', () {
        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'int32 one float32 two',
          ),
          throwsA(isA<SchemaParseException>()),
          reason: 'Missing semicolon',
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'int32 one[];',
          ),
          throwsException,
          reason: 'Unspecified array length',
        );
      });
    });
  });

  group('[Schema Manager]:', () {
    test('Registering new schema', () {
      SchemaManager schemaManager = SchemaManager();

      schemaManager.processNewSchema(
        'TestStruct',
        utf8.encode('int32 field1; int32 field2;'),
      );

      expect(schemaManager.getSchema('TestStruct'), isNotNull);

      expect(schemaManager.isStruct('TestStruct'), true);
    });

    test('Registering schemas with dependencies', () {
      SchemaManager schemaManager = SchemaManager();

      schemaManager.processNewSchema(
        'Pose2d',
        utf8.encode('Translation2d translation; Rotation2d rotation'),
      );

      expect(schemaManager.getSchema('Pose2d'), isNull);
      expect(schemaManager.isStruct('Pose2d'), false);

      schemaManager.processNewSchema('Rotation2d', utf8.encode('double value'));

      expect(schemaManager.getSchema('Rotation2d'), isNotNull);
      expect(schemaManager.isStruct('Rotation2d'), true);

      expect(schemaManager.getSchema('Pose2d'), isNull);
      expect(schemaManager.isStruct('Pose2d'), false);

      schemaManager.processNewSchema(
        'Translation2d',
        utf8.encode('double x; double y'),
      );

      expect(schemaManager.getSchema('Translation2d'), isNotNull);
      expect(schemaManager.isStruct('Translation2d'), true);

      expect(schemaManager.getSchema('Pose2d'), isNotNull);
      expect(schemaManager.isStruct('Pose2d'), true);
    });
  });
}
