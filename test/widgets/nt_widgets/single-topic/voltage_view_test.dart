import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
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
    'divisions': 5,
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
    expect(voltageViewModel.divisions, 5);
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
      divisions: 5,
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
      divisions: 5,
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
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
        (find.byType(LinearGauge).evaluate().first.widget as LinearGauge)
            .gaugeOrientation,
        GaugeOrientation.horizontal);
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
      divisions: 5,
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
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
        (find.byType(LinearGauge).evaluate().first.widget as LinearGauge)
            .gaugeOrientation,
        GaugeOrientation.vertical);
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
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
        (find.byType(LinearGauge).evaluate().first.widget as LinearGauge).steps,
        0.9);
  });

  testWidgets('Voltage view edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    VoltageViewModel voltageViewModel = VoltageViewModel(
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

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Voltage View',
      childModel: voltageViewModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final orientation = find.text('Orientation');
    final minimum = find.widgetWithText(DialogTextInput, 'Min Value');
    final maximum = find.widgetWithText(DialogTextInput, 'Max Value');
    final divisions = find.widgetWithText(DialogTextInput, 'Divisions');
    final inverted = find.widgetWithText(DialogToggleSwitch, 'Inverted');

    expect(orientation, findsOneWidget);
    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(divisions, findsOneWidget);
    expect(inverted, findsOneWidget);

    expect(orientation, findsOneWidget);
    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(divisions, findsOneWidget);
    expect(inverted, findsOneWidget);

    expect(find.byType(DialogDropdownChooser<String>), findsNWidgets(2));
    await widgetTester.tap(
      find.byWidget(find
          .byType(DialogDropdownChooser<String>)
          .evaluate()
          .elementAt(1)
          .widget),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Vertical'), findsOneWidget);
    await widgetTester.tap(find.text('Vertical'));
    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.orientation, 'vertical');

    await widgetTester.enterText(minimum, '-1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.minValue, -1);

    await widgetTester.enterText(maximum, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.maxValue, 1);

    await widgetTester.enterText(divisions, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.divisions, 10);

    await widgetTester.enterText(divisions, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.divisions, 10);

    await widgetTester.tap(
      find.descendant(
        of: inverted,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(voltageViewModel.inverted, true);
  });
}
