import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> numberBarJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'min_value': -5.0,
    'max_value': 5.0,
    'inverted': false,
    'orientation': 'horizontal',
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
        'Test/Double Value': -1.0,
      },
    );
  });

  test('Number bar from json', () {
    NTWidgetModel numberBarModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Number Bar',
      numberBarJson,
    );

    expect(numberBarModel.type, 'Number Bar');
    expect(numberBarModel.runtimeType, NumberBarModel);
    expect(
        numberBarModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (numberBarModel is! NumberBarModel) {
      return;
    }

    expect(numberBarModel.minValue, -5.0);
    expect(numberBarModel.maxValue, 5.0);
    expect(numberBarModel.divisions, isNull);
    expect(numberBarModel.inverted, isFalse);
    expect(numberBarModel.orientation, 'horizontal');
  });

  test('Number bar to json', () {
    NumberBarModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: null,
      inverted: false,
      orientation: 'horizontal',
    );

    expect(numberBarModel.toJson(), numberBarJson);
  });

  testWidgets('Number bar widget test horizontal', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: null,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .orientation,
        LinearGaugeOrientation.horizontal);
  });

  testWidgets('Number bar widget test vertical', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: null,
      inverted: false,
      orientation: 'vertical',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .orientation,
        LinearGaugeOrientation.vertical);
  });

  testWidgets('Number bar widget test integer', (widgetTester) async {
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

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Int Value',
      dataType: 'int',
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: null,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsNothing);
    expect(find.text('-1'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);
  });

  testWidgets('Number bar widget test with divisions', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 11,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .interval,
        1.0);
  });
}
