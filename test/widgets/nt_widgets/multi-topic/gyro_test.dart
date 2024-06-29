import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> gyroJson = {
    'topic': 'Test/Gyro',
    'period': 0.100,
    'counter_clockwise_positive': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Gyro/Value',
          type: NT4TypeStr.kFloat32,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Gyro/Value': 183.5,
      },
    );
  });

  test('Gyro from json', () {
    NTWidgetModel gyroModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Gyro',
      gyroJson,
    );

    expect(gyroModel.type, 'Gyro');
    expect(gyroModel.runtimeType, GyroModel);

    if (gyroModel is! GyroModel) {
      return;
    }

    expect(gyroModel.counterClockwisePositive, isTrue);
  });

  test('Gyro to json', () {
    GyroModel gyroModel = GyroModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Gyro',
      period: 0.100,
      counterClockwisePositive: true,
    );

    expect(gyroModel.toJson(), gyroJson);
  });

  testWidgets('Gyro widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel gyroModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Gyro',
      gyroJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: gyroModel,
            child: const Gyro(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('176.50'), findsOneWidget);
    expect(find.byType(SfRadialGauge), findsOneWidget);
  });
}
