import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> radialGaugeJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'start_angle': -140.0,
    'end_angle': 140.0,
    'min_value': -1.0,
    'max_value': 1.0,
    'number_of_labels': 10,
    'wrap_value': false,
    'show_pointer': true,
    'show_ticks': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Double Value',
          type: NT4TypeStr.kFloat64,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Double Value': -0.50,
      },
    );
  });

  test('Radial gauge from json', () {
    NTWidgetModel radialGaugeModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Radial Gauge',
      radialGaugeJson,
    );

    expect(radialGaugeModel.type, 'Radial Gauge');
    expect(radialGaugeModel.runtimeType, RadialGaugeModel);
    expect(
        radialGaugeModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (radialGaugeModel is! RadialGaugeModel) {
      return;
    }

    expect(radialGaugeModel.startAngle, -140.0);
    expect(radialGaugeModel.endAngle, 140.0);
    expect(radialGaugeModel.minValue, -1.0);
    expect(radialGaugeModel.maxValue, 1.0);
    expect(radialGaugeModel.numberOfLabels, 10);
    expect(radialGaugeModel.wrapValue, isFalse);
    expect(radialGaugeModel.showPointer, isTrue);
    expect(radialGaugeModel.showTicks, isTrue);
  });

  test('Radial gauge from alias name', () {
    NTWidgetModel radialGaugeModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Simple Dial',
      radialGaugeJson,
    );

    expect(radialGaugeModel.type, 'Radial Gauge');
    expect(radialGaugeModel.runtimeType, RadialGaugeModel);
    expect(
        radialGaugeModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (radialGaugeModel is! RadialGaugeModel) {
      return;
    }

    expect(radialGaugeModel.startAngle, -140.0);
    expect(radialGaugeModel.endAngle, 140.0);
    expect(radialGaugeModel.minValue, -1.0);
    expect(radialGaugeModel.maxValue, 1.0);
    expect(radialGaugeModel.numberOfLabels, 10);
    expect(radialGaugeModel.wrapValue, isFalse);
    expect(radialGaugeModel.showPointer, isTrue);
    expect(radialGaugeModel.showTicks, isTrue);
  });

  test('Radial gauge to json', () {
    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    expect(radialGaugeModel.toJson(), radialGaugeJson);
  });

  testWidgets('Radial gauge widget test with pointer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGauge(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(SfRadialGauge), findsOneWidget);
    expect(find.text('-0.50'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsOneWidget);
  });

  testWidgets('Radial gauge widget test integer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Int Value',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Int Value': -1,
      },
    );

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Int Value',
      dataType: 'int',
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGauge(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(SfRadialGauge), findsOneWidget);
    expect(find.text('-1.00'), findsNothing);
    expect(find.text('-1'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsOneWidget);
  });

  testWidgets('Radial gauge widget test no pointer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: false,
      showTicks: false,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGauge(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(SfRadialGauge), findsOneWidget);
    expect(find.text('-0.50'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsNothing);
  });
}
