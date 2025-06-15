import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';
import 'package:flutter_test/flutter_test.dart';

String testSchema1 = 'float32 vx;float32 vy;float32 omega';

String testSchema2 = '''
float32 vx;
float32 vy;
float32 omega;
''';

String schemaWithBitLengths = 'int32 one : 2;';

void main() {
  group('[Schema Parsing]:', () {
    test('Can parse schema with 3 floats', () {
      final schema = NTStructSchema(name: 'ChassisSpeeds', schema: testSchema1);

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type.toString(), NT4Type.float().toString());
      expect(schema.fields[0].field, 'vx');
      expect(schema.fields[0].substruct, isNull);

      expect(schema.fields[1].type.toString(), NT4Type.float().toString());
      expect(schema.fields[1].field, 'vy');
      expect(schema.fields[1].substruct, isNull);

      expect(schema.fields[2].type.toString(), NT4Type.float().toString());
      expect(schema.fields[2].field, 'omega');
      expect(schema.fields[2].substruct, isNull);
    });

    test('Can parse schema with new lines', () {
      final schema = NTStructSchema(name: 'ChassisSpeeds', schema: testSchema2);

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type.toString(), NT4Type.float().toString());
      expect(schema.fields[0].field, 'vx');
      expect(schema.fields[0].substruct, isNull);

      expect(schema.fields[1].type.toString(), NT4Type.float().toString());
      expect(schema.fields[1].field, 'vy');
      expect(schema.fields[1].substruct, isNull);

      expect(schema.fields[2].type.toString(), NT4Type.float().toString());
      expect(schema.fields[2].field, 'omega');
      expect(schema.fields[2].substruct, isNull);
    });

    test('Can parse schema with custom bit length', () {
      final schema = NTStructSchema(
        name: 'TestStruct',
        schema: schemaWithBitLengths,
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].type.toString(), NT4Type.int().toString());
      expect(schema.fields[0].field, 'one');
      expect(schema.fields[0].substruct, isNull);
      expect(schema.fields[0].bitLength, 2);
    });
  });
}
