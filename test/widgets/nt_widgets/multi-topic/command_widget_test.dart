import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> commandWidgetJson = {
    'topic': 'Test/Command',
    'period': 0.100,
    'show_type': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Command/running',
          type: NT4TypeStr.kBool,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Command/name',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Commnad/running': false,
        'Test/Command/name': 'Test Command',
      },
    );
  });

  test('Command widget from json', () {
    NTWidgetModel commandModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Command',
      commandWidgetJson,
    );

    expect(commandModel.type, 'Command');
    expect(commandModel.runtimeType, CommandModel);

    if (commandModel is! CommandModel) {
      return;
    }

    expect(commandModel.showType, isTrue);
  });

  test('Command widget to json', () {
    CommandModel commandModel = CommandModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Command',
      period: 0.100,
      showType: true,
    );

    expect(commandModel.toJson(), commandWidgetJson);
  });

  testWidgets('Command widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel commandModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Command',
      commandWidgetJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: commandModel,
            child: const CommandWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Command'), findsOneWidget);
    expect(find.text('Type: Test Command'), findsOneWidget);

    await widgetTester.tap(find.text('Command'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Command/running'), isTrue);

    commandModel.refresh();
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Command'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Command/running'), isFalse);

    (commandModel as CommandModel).showType = false;
    await widgetTester.pumpAndSettle();

    expect(find.text('Type: Test Command'), findsNothing);
  });
}
