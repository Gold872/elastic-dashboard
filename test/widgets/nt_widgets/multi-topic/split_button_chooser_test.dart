import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> splitButtonChooserJson = {
    'topic': 'Test/Split Button Chooser',
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
            name: 'Test/Split Button Chooser/options',
            type: NT4TypeStr.kStringArr,
            properties: {}),
        NT4Topic(
            name: 'Test/Split Button Chooser/active',
            type: NT4TypeStr.kString,
            properties: {}),
        NT4Topic(
            name: 'Test/Split Button Chooser/selected',
            type: NT4TypeStr.kString,
            properties: {}),
        NT4Topic(
            name: 'Test/Split Button Chooser/default',
            type: NT4TypeStr.kString,
            properties: {}),
      ],
      virtualValues: {
        'Test/Split Button Chooser/options': ['One', 'Two', 'Three'],
        'Test/Split Button Chooser/active': 'Two',
      },
    );
  });

  test('Split button chooser from json', () {
    NTWidgetModel splitButtonChooserModel =
        NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Split Button Chooser',
      splitButtonChooserJson,
    );

    expect(splitButtonChooserModel.type, 'Split Button Chooser');
    expect(splitButtonChooserModel.runtimeType, SplitButtonChooserModel);
  });

  test('Split button chooser to json', () {
    SplitButtonChooserModel splitButtonChooserModel = SplitButtonChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Split Button Chooser',
      period: 0.100,
    );

    expect(splitButtonChooserModel.toJson(), splitButtonChooserJson);
  });

  testWidgets('Split button chooser widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel splitButtonChooserModel =
        NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Split Button Chooser',
      splitButtonChooserJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: splitButtonChooserModel,
            child: const SplitButtonChooser(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(ToggleButtons), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    expect((splitButtonChooserModel as SplitButtonChooserModel).selectedChoice,
        'Two');
    expect(find.byIcon(Icons.check), findsOneWidget);

    await widgetTester.tap(find.text('One'));
    splitButtonChooserModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(splitButtonChooserModel.selectedChoice, 'One');
    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    ntConnection.updateDataFromTopicName(
        splitButtonChooserModel.activeTopicName, 'One');

    splitButtonChooserModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
