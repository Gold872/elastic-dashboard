import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> robotPreferencesJson = {
    'topic': 'Test/Preferences',
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
          name: 'Test/Preferences/Test Preference',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 1',
          type: NT4TypeStr.kFloat32,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 2',
          type: NT4TypeStr.kBool,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 3',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Preferences/Test Preference': 0,
        'Test/Preferences/Preference 1': 0.100,
        'Test/Preferences/Preference 2': false,
        'Test/Preferences/Preference 3': 'Original String'
      },
    );
  });

  test('Robot preferences from json', () {
    NTWidgetModel preferencesModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'RobotPreferences',
      robotPreferencesJson,
    );

    expect(preferencesModel.type, 'RobotPreferences');
    expect(preferencesModel.runtimeType, RobotPreferencesModel);
  });

  test('Robot preferences to json', () {
    RobotPreferencesModel preferencesModel = RobotPreferencesModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Preferences',
      period: 0.100,
    );

    expect(preferencesModel.toJson(), robotPreferencesJson);
  });

  testWidgets('Robot preferences widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel preferencesModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'RobotPreferences',
      robotPreferencesJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: preferencesModel,
            child: const RobotPreferences(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(5));

    expect(find.widgetWithText(TextField, 'Test Preference'), findsOneWidget);
    await widgetTester.enterText(
        find.widgetWithText(TextField, 'Test Preference'), '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
        ntConnection.getLastAnnouncedValue('Test/Preferences/Test Preference'),
        1);

    expect(find.widgetWithText(TextField, 'Preference 1'), findsOneWidget);
    await widgetTester.enterText(
        find.widgetWithText(TextField, 'Preference 1'), '0.250');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 1'),
        0.250);

    expect(find.widgetWithText(TextField, 'Preference 2'), findsOneWidget);
    await widgetTester.enterText(
        find.widgetWithText(TextField, 'Preference 2'), 'true');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 2'),
        isTrue);

    expect(find.widgetWithText(TextField, 'Preference 3'), findsOneWidget);
    await widgetTester.enterText(
        find.widgetWithText(TextField, 'Preference 3'), 'Edited String');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 3'),
        'Edited String');

    // Searching
    final searchField = find.widgetWithText(TextField, 'Search');
    expect(searchField, findsOneWidget);

    await widgetTester.enterText(searchField, 'Preference');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(5));

    await widgetTester.enterText(searchField, 'Test');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
  });
}
