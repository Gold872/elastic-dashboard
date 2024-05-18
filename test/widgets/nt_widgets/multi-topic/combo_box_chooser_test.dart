import 'package:flutter/material.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> comboBoxChooserJson = {
    'topic': 'Test/Combo Box Chooser',
    'period': 0.100,
    'sort_options': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
            name: 'Test/Combo Box Chooser/options',
            type: NT4TypeStr.kStringArr,
            properties: {}),
        NT4Topic(
            name: 'Test/Combo Box Chooser/active',
            type: NT4TypeStr.kString,
            properties: {}),
        NT4Topic(
            name: 'Test/Combo Box Chooser/selected',
            type: NT4TypeStr.kString,
            properties: {}),
        NT4Topic(
            name: 'Test/Combo Box Chooser/default',
            type: NT4TypeStr.kString,
            properties: {}),
      ],
      virtualValues: {
        'Test/Combo Box Chooser/options': ['One', 'Two', 'Three'],
        'Test/Combo Box Chooser/active': 'Two',
      },
    );
  });

  test('Combo box chooser from json', () {
    NTWidgetModel comboBoxChooserModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'ComboBox Chooser',
      comboBoxChooserJson,
    );

    expect(comboBoxChooserModel.type, 'ComboBox Chooser');
    expect(comboBoxChooserModel.runtimeType, ComboBoxChooserModel);

    if (comboBoxChooserModel is! ComboBoxChooserModel) {
      return;
    }

    expect(comboBoxChooserModel.sortOptions, isTrue);
  });

  test('Combo box chooser alias name', () {
    NTWidgetModel comboBoxChooserModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'String Chooser',
      comboBoxChooserJson,
    );

    expect(comboBoxChooserModel.type, 'ComboBox Chooser');
    expect(comboBoxChooserModel.runtimeType, ComboBoxChooserModel);

    if (comboBoxChooserModel is! ComboBoxChooserModel) {
      return;
    }

    expect(comboBoxChooserModel.sortOptions, isTrue);
  });

  test('Combo box chooser to json', () {
    ComboBoxChooserModel comboBoxChooserModel = ComboBoxChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Combo Box Chooser',
      period: 0.100,
      sortOptions: true,
    );

    expect(comboBoxChooserModel.toJson(), comboBoxChooserJson);
  });

  testWidgets('Combo box chooser widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel comboBoxChooserModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'ComboBox Chooser',
      comboBoxChooserJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: comboBoxChooserModel,
            child: const ComboBoxChooser(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(DropdownButton2<String>), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsNothing);
    expect(
        (comboBoxChooserModel as ComboBoxChooserModel).selectedChoice, 'Two');
    expect(find.byIcon(Icons.check), findsOneWidget);

    await widgetTester.tap(find.byType(DropdownButton2<String>));
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNWidgets(2));
    expect(find.text('Three'), findsOneWidget);

    await widgetTester.tap(find.text('One'));
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three'), findsNothing);

    expect(comboBoxChooserModel.selectedChoice, 'One');
    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    ntConnection.updateDataFromTopicName(
        comboBoxChooserModel.activeTopicName, 'One');

    comboBoxChooserModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
