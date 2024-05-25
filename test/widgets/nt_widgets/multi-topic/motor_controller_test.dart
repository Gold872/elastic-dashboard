import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/motor_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> motorControllerJson = {
    'topic': 'Test/Motor Controller',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Motor Controller/Value',
          type: NT4TypeStr.kFloat32,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Motor Controller/Value': -0.5,
      },
    );
  });

  test('Motor controller from json', () {
    NTWidgetModel motorControllerModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Motor Controller',
      motorControllerJson,
    );

    expect(motorControllerModel.type, 'Motor Controller');
    expect(motorControllerModel.runtimeType, MotorControllerModel);
  });

  test('Nidec brushless from json', () {
    NTWidgetModel motorControllerModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Nidec Brushless',
      motorControllerJson,
    );

    expect(motorControllerModel.type, 'Motor Controller');
    expect(motorControllerModel.runtimeType, MotorControllerModel);
  });

  test('Motor controller to json', () {
    MotorControllerModel motorControllerModel = MotorControllerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Motor Controller',
      period: 0.100,
    );

    expect(motorControllerModel.toJson(), motorControllerJson);
  });

  testWidgets('Motor controller widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel motorControllerModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Motor Controller',
      motorControllerJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: motorControllerModel,
            child: const MotorController(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-0.50'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);
    expect(find.byType(LinearShapePointer), findsOneWidget);
  });
}
