import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> matchTimeJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'time_display_mode': 'Minutes and Seconds',
    'red_start_time': 15,
    'yellow_start_time': 25.0,
  };

  Finder coloredText(String text, Color color) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == text &&
            widget.style != null &&
            widget.style!.color != null &&
            widget.style!.color!.value == color.value,
      );

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
        'Test/Double Value': 96.0,
      },
    );
  });

  test('Match time from json', () {
    NTWidgetModel matchTimeModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Match Time',
      matchTimeJson,
    );

    expect(matchTimeModel.type, 'Match Time');
    expect(matchTimeModel.runtimeType, MatchTimeModel);
    expect(
        matchTimeModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Graph',
          'Voltage View',
          'Radial Gauge',
          'Match Time',
        ]));

    if (matchTimeModel is! MatchTimeModel) {
      return;
    }

    expect(matchTimeModel.timeDisplayMode, 'Minutes and Seconds');
    expect(matchTimeModel.redStartTime, 15);
    expect(matchTimeModel.yellowStartTime, 25);
  });

  test('Match time to json', () {
    MatchTimeModel matchTimeModel = MatchTimeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Double Value',
      dataType: 'double',
      period: 0.100,
      timeDisplayMode: 'Minutes and Seconds',
      redStartTime: 15,
      yellowStartTime: 25,
    );

    expect(matchTimeModel.toJson(), matchTimeJson);
  });

  testWidgets('Match time widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel matchTimeModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Match Time',
      matchTimeJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: matchTimeModel as MatchTimeModel,
            child: const MatchTimeWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('1:36'), findsOneWidget);
    expect(coloredText('1:36', Colors.blue), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 55.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:55'), findsOneWidget);
    expect(coloredText('0:55', Colors.green), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 22.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:22'), findsOneWidget);
    expect(coloredText('0:22', Colors.yellow), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 13.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:13'), findsOneWidget);
    expect(coloredText('0:13', Colors.red), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 96.0);
    matchTimeModel.timeDisplayMode = 'Seconds Only';
    await widgetTester.pumpAndSettle();

    expect(find.text('96'), findsOneWidget);
    expect(coloredText('96', Colors.blue), findsOneWidget);
  });
}
