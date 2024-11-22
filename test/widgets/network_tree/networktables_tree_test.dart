import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import '../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  setUp(() async {
    FlutterError.onError = ignoreOverflowErrors;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('Network Tables Tree with leading slashes', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/Testing/Integer',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/Double',
          type: NT4TypeStr.kFloat64,
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/SubTable/String',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
              ntConnection: ntConnection,
              preferences: preferences,
              hideMetadata: false),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsOneWidget);
    expect(find.text('int'), findsOneWidget);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsOneWidget);

    await widgetTester.tap(find.text('SubTable'));
    await widgetTester.pumpAndSettle();

    expect(find.text('String'), findsOneWidget);
    expect(find.text('string'), findsOneWidget);
  });

  testWidgets('Network Tables Tree without leading slashes',
      (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Testing/Integer',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: 'Testing/Double',
          type: NT4TypeStr.kFloat64,
          properties: {},
        ),
        NT4Topic(
          name: 'Testing/SubTable/String',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
              ntConnection: ntConnection,
              preferences: preferences,
              hideMetadata: false),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsOneWidget);
    expect(find.text('int'), findsOneWidget);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsOneWidget);

    await widgetTester.tap(find.text('SubTable'));
    await widgetTester.pumpAndSettle();

    expect(find.text('String'), findsOneWidget);
    expect(find.text('string'), findsOneWidget);
  });

  testWidgets('Network Tables Tree searching', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/Testing/Integer',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/Double',
          type: NT4TypeStr.kFloat64,
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/SubTable/String',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
            ntConnection: ntConnection,
            preferences: preferences,
            hideMetadata: false,
            searchQuery: 'Double',
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsNothing);
    expect(find.text('int'), findsNothing);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsNothing);
  });
}
