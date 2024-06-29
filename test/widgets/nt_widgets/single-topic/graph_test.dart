import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> graphJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'time_displayed': 10.0,
    'max_value': 1.0,
    'color': Colors.green.value,
    'line_width': 3.0,
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
        'Test/Double Value': 0.0,
      },
    );
  });

  test('Graph from json', () {
    NTWidgetModel graphModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Graph',
      graphJson,
    );

    expect(graphModel.type, 'Graph');
    expect(graphModel.runtimeType, GraphModel);
    expect(
        graphModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (graphModel is! GraphModel) {
      return;
    }

    expect(graphModel.timeDisplayed, 10.0);
    expect(graphModel.minValue, isNull);
    expect(graphModel.maxValue, 1.0);
    expect(graphModel.mainColor, Color(Colors.green.value));
    expect(graphModel.lineWidth, 3.0);
  });

  test('Graph model to json', () {
    GraphModel graphModel = GraphModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      timeDisplayed: 10.0,
      maxValue: 1.0,
      mainColor: Colors.green,
      lineWidth: 3.0,
    );

    expect(graphModel.toJson(), graphJson);
  });

  testWidgets('Graph widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel graphModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Graph',
      graphJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: graphModel,
            child: const GraphWidget(),
          ),
        ),
      ),
    );

    expect(find.byType(SfCartesianChart), findsOneWidget);
  });
}
