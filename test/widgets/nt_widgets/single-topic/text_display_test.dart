import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> textDisplayJson = {
    'topic': 'Test/Display Value',
    'data_type': 'double',
    'period': 0.100,
    'show_submit_button': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Display Value',
          type: NT4TypeStr.kFloat64,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Display Value': 0.000001,
      },
    );
  });

  test('Text display from json', () {
    NTWidgetModel textDisplayModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Text Display',
      textDisplayJson,
    );

    expect(textDisplayModel.type, 'Text Display');
    expect(textDisplayModel.runtimeType, TextDisplayModel);

    if (textDisplayModel is! TextDisplayModel) {
      return;
    }

    expect(textDisplayModel.showSubmitButton, isTrue);
  });

  test('Text display from alias name', () {
    NTWidgetModel textDisplayModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Text View',
      textDisplayJson,
    );

    expect(textDisplayModel.type, 'Text Display');
    expect(textDisplayModel.runtimeType, TextDisplayModel);

    if (textDisplayModel is! TextDisplayModel) {
      return;
    }

    expect(textDisplayModel.showSubmitButton, isTrue);
  });

  test('Text display to json', () {
    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'double',
      period: 0.100,
      showSubmitButton: true,
    );

    expect(textDisplayModel.toJson(), textDisplayJson);
  });

  testWidgets('Text display widget test (double)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'double',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('0.000001'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), '3.53');
    expect(ntConnection.getLastAnnouncedValue('Test/Display Value'), 0.000001);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Display Value'), 3.53);
  });

  testWidgets('Text display widget test (int)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection intNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: intNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kInt,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': 0,
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'int',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), '3000');
    expect(intNTConnection.getLastAnnouncedValue('Test/Display Value'), 0);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(intNTConnection.getLastAnnouncedValue('Test/Display Value'), 3000);
  });

  testWidgets('Text display widget test (boolean)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection boolNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: boolNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kBool,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': false,
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'boolean',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('false'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), 'true');
    expect(
        boolNTConnection.getLastAnnouncedValue('Test/Display Value'), isFalse);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(
        boolNTConnection.getLastAnnouncedValue('Test/Display Value'), isTrue);
  });

  testWidgets('Text display widget test (string)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection stringNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: stringNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kString,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': 'Hello',
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'string',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), 'I Edited This Text');
    expect(stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'Hello');

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'I Edited This Text');
  });

  testWidgets('Text display widget test (int[])', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection intArrNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: intArrNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kIntArr,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': [0, 0],
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'int[]',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('[0, 0]'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), '[1, 2, 3]');
    expect(
        intArrNTConnection.getLastAnnouncedValue('Test/Display Value'), [0, 0]);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(intArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [1, 2, 3]);
  });

  testWidgets('Text display widget test (boolean[])', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection boolArrNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: boolArrNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kBoolArr,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': [false, true],
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'boolean[]',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('[false, true]'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), '[true, false, true]');
    expect(boolArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [false, true]);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(boolArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [true, false, true]);
  });

  testWidgets('Text display widget test (double[])', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection doubleArrNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: doubleArrNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kFloat64Arr,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': [0.0, 0.0],
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'double[]',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('[0.0, 0.0]'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(find.byType(TextField), '[1.0, 2.0, 3.0]');
    expect(doubleArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [0.0, 0.0]);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(doubleArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [1.0, 2.0, 3.0]);
  });

  testWidgets('Text display widget test (string[])', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection stringArrNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: stringArrNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kStringArr,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': ['Hello', 'There'],
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'string[]',
      period: 0.100,
      showSubmitButton: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('[Hello, There]'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsOneWidget);
    expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(
        find.byType(TextField), '["I", "am", "very", "tired"]');
    expect(stringArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        ['Hello', 'There']);

    await widgetTester.tap(find.byIcon(Icons.exit_to_app));
    await widgetTester.pumpAndSettle();

    expect(stringArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        ['I', 'am', 'very', 'tired']);
  });

  testWidgets('Text display widget test no submit button',
      (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection stringNTConnection;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: stringNTConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4TypeStr.kString,
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Display Value': 'There isn\'t a submit button',
        },
      ),
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: 'string',
      period: 0.100,
      showSubmitButton: false,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: textDisplayModel,
            child: const TextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('There isn\'t a submit button'), findsOneWidget);
    expect(find.byTooltip('Publish Data'), findsNothing);
    expect(find.byIcon(Icons.exit_to_app), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await widgetTester.enterText(
        find.byType(TextField), 'I\'m submitting this without a button!');
    expect(stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'There isn\'t a submit button');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'I\'m submitting this without a button!');
  });
}
