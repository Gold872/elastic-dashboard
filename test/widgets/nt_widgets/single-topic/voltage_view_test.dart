import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> voltageViewJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'min_value': 4.0,
    'max_value': 13.0,
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
        'Test/Double Value': 12.0,
      },
    );
  });

  test('Voltage view from json', () {
    NTWidgetModel voltageViewModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Voltage View',
      voltageViewJson,
    );

    expect(voltageViewModel.type, 'Voltage View');
    expect(voltageViewModel.runtimeType, VoltageViewModel);
    expect(
        voltageViewModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (voltageViewModel is! VoltageViewModel) {
      return;
    }

    expect(voltageViewModel.minValue, 4.0);
    expect(voltageViewModel.maxValue, 13.0);
    expect(voltageViewModel.divisions, isNull);
    expect(voltageViewModel.inverted, isFalse);
    expect(voltageViewModel.orientation, 'horizontal');
  });

  test('Voltage view to json', () {
    VoltageViewModel voltageViewModel = VoltageViewModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: 4.0,
      maxValue: 13.0,
      divisions: null,
      inverted: false,
      orientation: 'horizontal',
    );

    expect(voltageViewModel.toJson(), voltageViewJson);
  });

  testWidgets('Voltage view widget test horizontal', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel voltageViewModel = VoltageViewModel(
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
            value: voltageViewModel,
            child: const VoltageView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('12.00 V'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .orientation,
        LinearGaugeOrientation.horizontal);
  });

  testWidgets('Voltage view widget test vertical', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel voltageViewModel = VoltageViewModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: 4.0,
      maxValue: 13.0,
      divisions: null,
      inverted: false,
      orientation: 'vertical',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: voltageViewModel,
            child: const VoltageView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('12.00 V'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .orientation,
        LinearGaugeOrientation.vertical);
  });

  testWidgets('Voltage view widget test with divisions', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel voltageViewModel = VoltageViewModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      minValue: 4.0,
      maxValue: 13.0,
      divisions: 11,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: voltageViewModel,
            child: const VoltageView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('12.00 V'), findsOneWidget);
    expect(find.byType(SfLinearGauge), findsOneWidget);

    expect(
        (find.byType(SfLinearGauge).evaluate().first.widget as SfLinearGauge)
            .interval,
        0.9);
  });
}
